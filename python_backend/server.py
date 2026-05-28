"""
server.py
=========
Flask REST API backend handling Hybrid DTW single-sample matching,
and Fuzzy SequenceMatching for AES-encrypted STT phrases.
"""

import os
import re
import time
import uuid
import json
import tempfile
import logging
import difflib

from flask import Flask, request, jsonify
from flask_cors import CORS
from functools import wraps

# Updated dependencies
from voice_processor import extract_hybrid_features
from voice_comparator import compare_hybrid
from vault_db import VaultDB
from cryptography.fernet import Fernet
import speech_recognition as sr

# ---------------------------------------------------------------------------
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

DATA_DIR       = "data"
PROFILE_FILE   = os.path.join(DATA_DIR, "voice_profile.json")
AUTH_STATE_FILE = os.path.join(DATA_DIR, "auth_state.json")
os.makedirs(DATA_DIR, exist_ok=True)

MAX_FAILED_ATTEMPTS = 5
LOCKOUT_DURATION    = 300
SESSION_TTL         = 600

sessions: dict[str, float] = {}
vault_db = VaultDB()


def _load_auth_state() -> dict:
    if os.path.exists(AUTH_STATE_FILE):
        with open(AUTH_STATE_FILE) as f:
            return json.load(f)
    return {"failed_attempts": 0, "lockout_until": 0}

def _save_auth_state(state: dict):
    with open(AUTH_STATE_FILE, "w") as f:
        json.dump(state, f)

def _is_locked_out() -> tuple[bool, int]:
    state = _load_auth_state()
    remaining = int(state.get("lockout_until", 0) - time.time())
    if remaining > 0:
        return True, remaining
    return False, 0

def require_session(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get("X-Session-Token", "")
        if not token or token not in sessions:
            return jsonify({"error": "Unauthorized — please log in first"}), 401
        if sessions[token] < time.time():
            sessions.pop(token, None)
            return jsonify({"error": "Session expired — please log in again"}), 401
        return f(*args, **kwargs)
    return decorated

# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.route("/status", methods=["GET"])
def status():
    return jsonify({
        "enrolled": os.path.exists(PROFILE_FILE),
        "locked_out": _is_locked_out()[0],
        "lockout_remaining_seconds": _is_locked_out()[1]
    })


@app.route("/enroll", methods=["POST"])
def enroll():
    if "audio" not in request.files:
        return jsonify({"error": "Missing 'audio' field"}), 400

    audio_file = request.files["audio"]
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        audio_file.save(tmp.name)
        tmp_path = tmp.name

    try:
        # 1. Standardize Audio & Extract Features (SNR & Duration built-in)
        hybrid_features = extract_hybrid_features(tmp_path)
        
        # 2. Extract Transcript (STT)
        recognizer = sr.Recognizer()
        with sr.AudioFile(tmp_path) as source:
            audio_data = recognizer.record(source)
            # Upgraded to Vosk Neural Offline STT (supports Indian-English and exact names beautifully)
            vosk_json = recognizer.recognize_vosk(audio_data)
            stt_text = json.loads(vosk_json).get("text", "").lower()
            
        # Normalize text: strip punctuation and whitespace bounds
        normalized_text = re.sub(r'[^a-z0-9\s]', '', stt_text).strip()
        logger.info(f"Enrolled STT Speech: '{normalized_text}'")

    except sr.UnknownValueError:
        return jsonify({"error": "Could not understand speech. Please speak clearly!"}), 400
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": f"Extraction error: {e}"}), 400
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)

    # 3. Secure the phrase text instead of hashing, so we can fuzzy-match.
    fernet_key = Fernet.generate_key()
    f = Fernet(fernet_key)
    encrypted_phrase = f.encrypt(normalized_text.encode('utf-8'))

    profile = {
        "features": hybrid_features,
        "enrolled_at": time.time(),
        "key": fernet_key.decode('utf-8'),
        "phrase": encrypted_phrase.decode('utf-8')
    }
    with open(PROFILE_FILE, "w") as f_out:
        json.dump(profile, f_out)

    _save_auth_state({"failed_attempts": 0, "lockout_until": 0})
    return jsonify({"success": True, "message": "Voice dynamically enrolled"})


@app.route("/verify", methods=["POST"])
def verify():
    # Anti-replay protection
    try:
        ts = float(request.form.get("timestamp", 0))
        if abs(time.time() - ts) > 30:
            return jsonify({"error": "Request timestamp expired"}), 400
    except (TypeError, ValueError):
        return jsonify({"error": "Invalid timestamp"}), 400

    locked, remaining = _is_locked_out()
    if locked:
        return jsonify({
            "success": False,
            "error": "Account locked",
            "lockout_remaining_seconds": remaining
        }), 403

    if not os.path.exists(PROFILE_FILE):
        return jsonify({"error": "No voice enrolled yet"}), 400

    if "audio" not in request.files:
        return jsonify({"error": "Missing 'audio' field"}), 400

    audio_file = request.files["audio"]
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        audio_file.save(tmp.name)
        tmp_path = tmp.name

    try:
        # Extract features (fails fast if SNR or Duration bounds are hit)
        candidate_features = extract_hybrid_features(tmp_path)
        
        # Audio STT Processing
        recognizer = sr.Recognizer()
        with sr.AudioFile(tmp_path) as source:
            audio_data = recognizer.record(source)
            # Offline Vosk STT
            vosk_json = recognizer.recognize_vosk(audio_data)
            candidate_text = json.loads(vosk_json).get("text", "").lower()
        candidate_text = re.sub(r'[^a-z0-9\s]', '', candidate_text).strip()
        
    except sr.UnknownValueError:
        logger.warning("STT Engine could not hear clear speech.")
        candidate_text = ""  # Let it aggressively fail fuzzy match
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 400
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)

    # 1. Decrypt Phrase from Profile securely
    with open(PROFILE_FILE) as f_in:
        profile = json.load(f_in)
        
    f = Fernet(profile["key"].encode('utf-8'))
    enrolled_text = f.decrypt(profile["phrase"].encode('utf-8')).decode('utf-8')

    # 2. Strict Fuzzy Text Matching
    # Standard difflib ratio divides by average length, allowing extra words to slip by >0.85
    # To fix this, we calculate matching blocks over the MAX length to heavily penalize insertions (like the word 'not').
    s = difflib.SequenceMatcher(None, enrolled_text, candidate_text)
    match_len = sum(triple.size for triple in s.get_matching_blocks())
    max_len = max(len(enrolled_text), len(candidate_text))
    strict_ratio = match_len / max_len if max_len > 0 else 0.0
    
    # Strict threshold restored to 0.85.
    # Powered by Vosk Neural Subword dictionary so wild hallucination drops are completely gone.
    phrase_matched = strict_ratio >= 0.85
    text_ratio = strict_ratio  # pass into logging

    # 3. Hybrid DTW + Cosine Match
    # Note: earlier version just took mfcc, but we structured 
    # it in dict to capture matrix and vector. We expect old profiles to fail here.
    if "features" not in profile:
         return jsonify({"error": "Old profile detected. Please re-enroll!"}), 400
         
    result = compare_hybrid(profile["features"], candidate_features)
    state = _load_auth_state()

    # Final Verification
    # Phrase matching is STRICTLY restored now that Vosk transcription provides high fidelity!
    if result["match"] and phrase_matched:
        _save_auth_state({"failed_attempts": 0, "lockout_until": 0})
        token = str(uuid.uuid4())
        sessions[token] = time.time() + SESSION_TTL
        logger.info(f"VERIFIED! Score: {result['confidence']}% | Text Match: {text_ratio:.2f}")
        return jsonify({
            "success": True,
            "token": token,
            "score": result["score"],
            "threshold": result["threshold"],
            "confidence": result["confidence"],
            "text_ratio": round(text_ratio, 2)
        })
    else:
        attempts = state.get("failed_attempts", 0) + 1
        lockout_until = 0
        if attempts >= MAX_FAILED_ATTEMPTS:
            lockout_until = time.time() + LOCKOUT_DURATION
            attempts = 0
        _save_auth_state({"failed_attempts": attempts, "lockout_until": lockout_until})

        reason = "Unknown Error"
        if not phrase_matched:
            reason = f"Phrase mismatch (Fuzzy Tolerance {text_ratio:.2f} < 0.85)\nSaid: '{candidate_text}'\nExpected: '{enrolled_text}'"
        if not result["match"]:
            reason = f"Voice biometrics rejected (Confidence: {result['confidence']}%)"
        if not result["match"] and not phrase_matched:
            reason = f"Voice & Phrase mismatch (Voice %: {result['confidence']}, Text Lvl: {text_ratio:.2f})"

        logger.warning(f"Failed Login. Reason: {reason}")
        return jsonify({
            "success": False,
            "score": result["score"],
            "threshold": result["threshold"],
            "confidence": result["confidence"],
            "text_ratio": round(text_ratio, 2),
            "reason": reason,
            "failed_attempts": attempts,
            "remaining_attempts": MAX_FAILED_ATTEMPTS - attempts if lockout_until == 0 else 0,
        })

@app.route("/vault/entries", methods=["GET"])
@require_session
def get_entries():
    return jsonify({"entries": vault_db.get_all_entries()})

@app.route("/vault/search", methods=["POST"])
@require_session
def search_entries():
    query = (request.json or {}).get("query", "")
    return jsonify({"entries": vault_db.search_entries(query)})

@app.route("/vault/add", methods=["POST"])
@require_session
def add_entry():
    d = request.json or {}
    entry_id = vault_db.add_entry(
        title=d.get("title", ""),
        category=d.get("category", "password"),
        username=d.get("username", ""),
        password=d.get("password", ""),
        notes=d.get("notes", ""),
        url=d.get("url", "")
    )
    return jsonify({"success": True, "id": entry_id})

@app.route("/vault/update/<int:entry_id>", methods=["PUT"])
@require_session
def update_entry(entry_id):
    vault_db.update_entry(entry_id, request.json or {})
    return jsonify({"success": True})

@app.route("/vault/delete/<int:entry_id>", methods=["DELETE"])
@require_session
def delete_entry(entry_id):
    vault_db.delete_entry(entry_id)
    return jsonify({"success": True})

@app.route("/reset", methods=["POST"])
def reset_enrollment():
    if os.path.exists(PROFILE_FILE):
        os.remove(PROFILE_FILE)
    _save_auth_state({"failed_attempts": 0, "lockout_until": 0})
    sessions.clear()
    return jsonify({"success": True, "message": "Enrollment reset. Please re-enroll."})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8765, debug=False)

"""
vault_db.py
===========
Manages encrypted vault storage using SQLite + AES-256-GCM.

AES-256-GCM:
  - 256-bit key = 2^256 possible keys (practically unbreakable)
  - GCM mode = encryption + authenticity check (detects tampering)
  - Each entry uses a fresh random 12-byte nonce (prevents patterns)

Encryption flow:
  dict → JSON → UTF-8 bytes
       → AES-GCM encrypt (nonce + ciphertext)
       → Base64 string → stored in SQLite

Decryption flow (reverse):
  Base64 → nonce(12 bytes) + ciphertext
          → AES-GCM decrypt → UTF-8 → JSON → dict

Key management:
  A random 32-byte AES key is generated once and saved to data/vault.key.
  In a production app, protect this file with OS Keystore / Keychain.
"""

import sqlite3
import os
import json
import base64
import secrets
from datetime import datetime
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

DATA_DIR = "data"
KEY_FILE  = os.path.join(DATA_DIR, "vault.key")
DB_FILE   = os.path.join(DATA_DIR, "vault.db")


class VaultDB:
    def __init__(self):
        os.makedirs(DATA_DIR, exist_ok=True)
        # Load (or generate) the AES-256 key.
        self.key = self._load_or_create_key()
        self.aesgcm = AESGCM(self.key)
        self._init_db()

    # ------------------------------------------------------------------
    # Key management
    # ------------------------------------------------------------------

    def _load_or_create_key(self) -> bytes:
        """Return stored key, or generate a fresh 32-byte key."""
        if os.path.exists(KEY_FILE):
            with open(KEY_FILE, "rb") as f:
                return f.read()
        key = secrets.token_bytes(32)          # 256-bit random AES key
        with open(KEY_FILE, "wb") as f:
            f.write(key)
        return key

    # ------------------------------------------------------------------
    # Database setup
    # ------------------------------------------------------------------

    def _init_db(self):
        """Create vault_entries table if it does not yet exist."""
        conn = sqlite3.connect(DB_FILE)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS vault_entries (
                id             INTEGER PRIMARY KEY AUTOINCREMENT,
                title          TEXT    NOT NULL,
                category       TEXT    DEFAULT 'password',
                encrypted_data TEXT    NOT NULL,
                created_at     TEXT,
                updated_at     TEXT
            )
        """)
        conn.commit()
        conn.close()

    # ------------------------------------------------------------------
    # Encryption / Decryption helpers
    # ------------------------------------------------------------------

    def _encrypt(self, data: dict) -> str:
        """Encrypt a dict and return a Base64 string.
        Format stored: Base64( nonce(12 bytes) + ciphertext )
        """
        plaintext = json.dumps(data).encode("utf-8")
        nonce = secrets.token_bytes(12)              # fresh nonce every time
        ciphertext = self.aesgcm.encrypt(nonce, plaintext, None)
        return base64.b64encode(nonce + ciphertext).decode("utf-8")

    def _decrypt(self, encrypted_b64: str) -> dict:
        """Decrypt a Base64 string back into a dict."""
        raw = base64.b64decode(encrypted_b64)
        nonce      = raw[:12]
        ciphertext = raw[12:]
        plaintext  = self.aesgcm.decrypt(nonce, ciphertext, None)
        return json.loads(plaintext.decode("utf-8"))

    # ------------------------------------------------------------------
    # CRUD operations
    # ------------------------------------------------------------------

    def add_entry(self, title: str, category: str, username: str,
                  password: str, notes: str, url: str = "") -> int:
        """Add a new encrypted entry; returns the new row id."""
        encrypted = self._encrypt({"username": username,
                                   "password": password,
                                   "notes": notes, "url": url})
        now = datetime.now().isoformat()
        conn = sqlite3.connect(DB_FILE)
        cur  = conn.execute(
            "INSERT INTO vault_entries (title, category, encrypted_data, "
            "created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
            (title, category, encrypted, now, now)
        )
        entry_id = cur.lastrowid
        conn.commit()
        conn.close()
        return entry_id

    def get_all_entries(self) -> list:
        """Return all decrypted entries, newest first."""
        conn = sqlite3.connect(DB_FILE)
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT * FROM vault_entries ORDER BY created_at DESC"
        ).fetchall()
        conn.close()

        results = []
        for row in rows:
            try:
                dec = self._decrypt(row["encrypted_data"])
                results.append({
                    "id": row["id"], "title": row["title"],
                    "category": row["category"],
                    "created_at": row["created_at"],
                    "updated_at": row["updated_at"],
                    **dec
                })
            except Exception:
                pass          # skip corrupted entries silently
        return results

    def search_entries(self, query: str) -> list:
        """Full-text search across title, username, and notes."""
        q = query.lower()
        return [e for e in self.get_all_entries()
                if q in e.get("title", "").lower()
                or q in e.get("username", "").lower()
                or q in e.get("notes", "").lower()]

    def update_entry(self, entry_id: int, data: dict):
        """Update an existing entry by id."""
        encrypted = self._encrypt({
            "username": data.get("username", ""),
            "password": data.get("password", ""),
            "notes":    data.get("notes", ""),
            "url":      data.get("url", ""),
        })
        conn = sqlite3.connect(DB_FILE)
        conn.execute(
            "UPDATE vault_entries SET title=?, category=?, encrypted_data=?,"
            " updated_at=? WHERE id=?",
            (data.get("title", ""), data.get("category", "password"),
             encrypted, datetime.now().isoformat(), entry_id)
        )
        conn.commit()
        conn.close()

    def delete_entry(self, entry_id: int):
        """Permanently delete an entry."""
        conn = sqlite3.connect(DB_FILE)
        conn.execute("DELETE FROM vault_entries WHERE id=?", (entry_id,))
        conn.commit()
        conn.close()

    def clear_all(self):
        """Delete all vault entries (used during re-enrollment reset)."""
        conn = sqlite3.connect(DB_FILE)
        conn.execute("DELETE FROM vault_entries")
        conn.commit()
        conn.close()

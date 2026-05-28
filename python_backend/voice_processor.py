"""
voice_processor.py
==================
Extracts robust hybrid MFCC features from a WAV audio file.
Enforces SNR and Duration constraints to reject poor samples.
"""

import librosa
import numpy as np
import scipy.signal
import logging

logger = logging.getLogger(__name__)

N_MFCC = 13
TARGET_SR = 16000

def extract_hybrid_features(audio_path: str):
    """
    Validates audio and extracts dual features for DTW + Cosine.
    Returns:
        {
            "matrix": list of lists (13xT) for DTW,
            "vector": list of 26 floats (mean + variance) for Cosine
        }
    """
    y, sr = librosa.load(audio_path, sr=TARGET_SR, mono=True)

    # 1. Duration check BEFORE trim (1s to 6s)
    duration = len(y) / sr
    if duration < 1.0 or duration > 6.0:
        raise ValueError(f"Audio duration must be 1-6s (got {duration:.1f}s)")

    # 2. SNR Check
    # A simple SNR calculation: Signal RMS / Noise RMS
    signal_rms = np.sqrt(np.mean(y**2) + 1e-10)
    noise_floor = np.percentile(np.abs(y), 15) # lowest 15% amplitudes as noise isolation
    noise_rms = np.sqrt(np.mean(y[np.abs(y) <= noise_floor]**2) + 1e-10)
    
    snr_db = 20 * np.log10(signal_rms / noise_rms)
    logger.info(f"Signal SNR: {snr_db:.2f} dB")
    
    if snr_db < 8.0:
        raise ValueError(f"Audio quality too noisy! SNR {snr_db:.1f}dB < 8dB. Speak closer to the mic.")

    # 3. Trim Silence
    y, _ = librosa.effects.trim(y, top_db=25)
    if len(y) < TARGET_SR * 0.3:
        raise ValueError("Audio too short after removing silence.")

    # 4. Wiener Filter for Noise Reduction
    y = scipy.signal.wiener(y)

    # 5. Amplitude Normalization
    y = librosa.util.normalize(y)

    # 6. Pre-emphasis filter to boost voice frequencies
    y = librosa.effects.preemphasis(y)

    # 7. Extract High-Res MFCC sequence
    # Extract 20 coefficients, then forcefully drop the 0th coefficient [1:, :]
    # The 0th coefficient tracks raw volume/energy limits which falsely matches people 
    # saying the same words loudly. Dropping it mandates pure vocal tract timbre matching.
    mfcc_full = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=20)
    mfcc = mfcc_full[1:, :]

    # 8. Extract Delta features (Velocity of vocal tract transitions)
    # Imposters cannot easily mimic the exact muscular movement speed between shapes
    mfcc_delta = librosa.feature.delta(mfcc)

    # 9. Compute Mean + Variance for base & delta sequences = 76 dims
    mfcc_mean = np.mean(mfcc, axis=1)
    mfcc_var = np.var(mfcc, axis=1)
    delta_mean = np.mean(mfcc_delta, axis=1)
    delta_var = np.var(mfcc_delta, axis=1)
    feature_vector = np.concatenate((mfcc_mean, mfcc_var, delta_mean, delta_var))

    return {
        "matrix": mfcc.tolist(),           # for DTW temporal matching
        "vector": feature_vector.tolist()  # 76-D for Statistical structural matching
    }

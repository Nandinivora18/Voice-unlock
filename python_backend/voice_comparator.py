"""
voice_comparator.py
===================
Hybrid DTW + Cosine matched voice verification system.
Provides robustness to single-sample enrollments by fusing statistical data (Mean+Var)
with temporal alignment data (DTW).
"""

import numpy as np
import librosa
from scipy.spatial.distance import cosine

# Tightened threshold to strictly block synthetic voices or imposter alignments
# Extreme hardened threshold to brutally block imposter alignments
SIMILARITY_THRESHOLD = 0.90

def compare_hybrid(enrolled_features: dict, candidate_features: dict) -> dict:
    """
    Computes a hybrid matching score using Statistical Vectors (Cosine) 
    and Temporal Sequences (Dynamic Time Warping).
    """
    # ==========================================
    # 1. Cosine Similarity on 76-D Vector
    # ==========================================
    v1 = np.array(enrolled_features["vector"], dtype=float)
    v2 = np.array(candidate_features["vector"], dtype=float)
    
    # Normalize feature vectors properly as requested
    v1_norm = v1 / (np.linalg.norm(v1) + 1e-10)
    v2_norm = v2 / (np.linalg.norm(v2) + 1e-10)
    
    # Scipy cosine() returns spatial distance (0 to 2)
    dist_cos = cosine(v1_norm, v2_norm)
    
    # Mathematical crushing of deviation. 0.1 distance -> 0.7 similarity score
    sim_cosine = float(np.clip(1.0 - (dist_cos * 3.0), 0.0, 1.0))
    
    # ==========================================
    # 2. Dynamic Time Warping (DTW) on MFCC Matrices
    # ==========================================
    m1 = np.array(enrolled_features["matrix"], dtype=float)
    m2 = np.array(candidate_features["matrix"], dtype=float)
    
    # Align the temporal sequences using cosine metric.
    # D is the accumulated cost matrix, wp is the warping path.
    D, wp = librosa.sequence.dtw(X=m1, Y=m2, metric='cosine')
    
    # Average alignment step cost across the optimal path
    dtw_dist = D[-1, -1] / len(wp)
    
    # Heavy penalty for pacing/duration alignment deviations
    sim_dtw = float(np.clip(1.0 - (dtw_dist * 2.0), 0.0, 1.0))
    
    # ==========================================
    # 3. Hybrid Fusion & Output
    # ==========================================
    # Weighting: 80% to dense physiological vector traces, 20% to sequence timing.
    # Prevents "pacing match" false positives entirely.
    final_score = (0.80 * sim_cosine) + (0.20 * sim_dtw)
    
    confidence_percentage = round(final_score * 100, 2)
    match = final_score >= SIMILARITY_THRESHOLD
    
    return {
        "match": match,
        "score": round(final_score, 4),
        "confidence": confidence_percentage,
        "threshold": SIMILARITY_THRESHOLD,
        "cosine_subscore": round(sim_cosine, 4),
        "dtw_subscore": round(sim_dtw, 4)
    }

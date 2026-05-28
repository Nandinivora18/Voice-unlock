// about_screen.dart
// Displays project information, security model, and tech stack details.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ABOUT')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── App banner ─────────────────────────────────────────
          Center(
            child: Column(children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.4), width: 2),
                ),
                child: const Icon(Icons.security,
                    color: AppTheme.primary, size: 40),
              ),
              const SizedBox(height: 12),
              const Text('CryptWhisper',
                  style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)),
              const Text('v1.0.0 — Secure Offline Vault',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 28),

          // ── How authentication works ───────────────────────────
          _card(
            title: 'How Authentication Works',
            icon: Icons.fingerprint,
            content: [
              _point('🎙️', 'Enrollment',
                  'You record your voice once. The system extracts 13 MFCC coefficients across time and stores only the mean vector — your voice fingerprint. Raw audio is never saved.'),
              _point('🔐', 'Login',
                  'You speak the same phrase. Your live MFCCs are compared to the enrolled fingerprint using cosine similarity. Score ≥ 80% = access granted.'),
              _point('❌', 'Dual rejection',
                  'If your voice does not match OR someone else speaks the correct phrase, access is denied.'),
            ],
          ),
          const SizedBox(height: 12),

          // ── Security model ─────────────────────────────────────
          _card(
            title: 'Security Model',
            icon: Icons.shield_outlined,
            content: [
              _point('🔒', 'AES-256-GCM',
                  'All vault entries are encrypted with AES-256-GCM before being written to SQLite. Each entry uses a fresh random nonce.'),
              _point('⏱️', 'Anti-replay',
                  'Every /verify request must include a Unix timestamp within ±30 seconds. Old requests are rejected.'),
              _point('🚫', 'Lockout',
                  '5 failed logins trigger a 5-minute account lockout with exponential back-off.'),
              _point('🕐', 'Session expiry',
                  'Session tokens expire after 10 minutes of inactivity.'),
            ],
          ),
          const SizedBox(height: 12),

          // ── Tech stack ─────────────────────────────────────────
          _card(
            title: 'Tech Stack',
            icon: Icons.code,
            content: [
              _point('📱', 'Flutter (Dart)', 'UI, navigation, audio recording'),
              _point('🐍', 'Python + Flask', 'Voice processing server'),
              _point('🎵', 'librosa', 'MFCC feature extraction'),
              _point('📐', 'scipy', 'Cosine similarity calculation'),
              _point('🔑', 'cryptography (AES-GCM)', 'Vault encryption'),
              _point('🗄️', 'SQLite', 'Local encrypted storage'),
            ],
          ),
          const SizedBox(height: 24),

          // ── Future improvements ────────────────────────────────
          _card(
            title: 'Future Improvements',
            icon: Icons.rocket_launch_outlined,
            content: [
              _point('🎯', 'GMM/i-vector model',
                  'Replace cosine similarity with a Gaussian Mixture Model for better accuracy.'),
              _point('🔑', 'Biometric key derivation',
                  'Derive AES key directly from MFCC hash (fuzzy vault).'),
              _point('📱', 'Biometric fallback',
                  'Add fingerprint as a secondary auth method.'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          ...content,
        ],
      ),
    );
  }

  Widget _point(String emoji, String heading, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                children: [
                  TextSpan(
                      text: '$heading: ',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600)),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

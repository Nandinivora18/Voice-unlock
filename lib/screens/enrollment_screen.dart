// enrollment_screen.dart
// Guides the user through recording their voice for the first time.
// Flow: Instruction → Record (4 s auto-stop) → Confirm/Re-record → Enroll

import 'dart:async';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/audio_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/recording_indicator.dart';
import 'home_screen.dart';

class EnrollmentScreen extends StatefulWidget {
  const EnrollmentScreen({super.key});

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  // ── State ────────────────────────────────────────────────────────
  bool   _isRecording   = false;
  bool   _hasRecording  = false;
  bool   _isUploading   = false;
  int    _countdown     = AppConstants.recordingDuration;
  String _statusMessage = 'Press the mic and speak naturally.';
  Color  _statusColor   = AppTheme.textSecondary;

  Timer?  _timer;
  dynamic _audioFile;   // File from audio_service

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Recording logic ──────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    _timer?.cancel();
    setState(() {
      _isRecording   = true;
      _hasRecording  = false;
      _countdown     = AppConstants.recordingDuration;
      _statusMessage = 'Recording… speak naturally now!';
      _statusColor   = AppTheme.error;
    });

    final path = await AudioService.startRecording();
    if (path == null) {
      setState(() {
        _isRecording   = false;
        _statusMessage = 'Microphone permission denied.';
        _statusColor   = AppTheme.error;
      });
      return;
    }

    // Auto-stop after recordingDuration seconds.
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        _stopRecording();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final file = await AudioService.stopRecording();
    setState(() {
      _isRecording   = false;
      _audioFile     = file;
      _hasRecording  = file != null;
      _statusMessage = file != null
          ? 'Recording saved. Confirm or re-record below.'
          : 'Recording failed. Please try again.';
      _statusColor =
          file != null ? AppTheme.success : AppTheme.error;
    });
  }

  // ── Enrollment upload ────────────────────────────────────────────

  Future<void> _enroll() async {
    if (_audioFile == null) return;
    setState(() {
      _isUploading   = true;
      _statusMessage = 'Uploading voice profile…';
      _statusColor   = AppTheme.textSecondary;
    });

    final result = await ApiService.enroll(_audioFile);

    if (!mounted) return;
    setState(() => _isUploading = false);

    if (result != null && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Voice enrolled successfully!')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } else {
      setState(() {
        _statusMessage =
            result?['error'] ?? 'Enrollment failed. Please try again.';
        _statusColor = AppTheme.error;
      });
    }
  }

  // ── UI ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ENROLL VOICE')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Info banner ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppTheme.primary, size: 28),
                    const SizedBox(height: 8),
                    const Text(
                      'You will record your voice once.\n'
                      'Your MFCC voice fingerprint is stored — '
                      'NOT the raw audio.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),



              // ── Mic button ─────────────────────────────────────
              RecordingIndicator(
                isRecording: _isRecording,
                onTap: _isUploading ? () {} : _toggleRecording,
              ),

              // Countdown
              if (_isRecording)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Auto-stop in $_countdown s',
                    style: const TextStyle(
                        color: AppTheme.error, fontSize: 13),
                  ),
                ),

              const SizedBox(height: 12),

              // Status text
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: _statusColor, fontSize: 14),
              ),

              const SizedBox(height: 36),

              // ── Action buttons ─────────────────────────────────
              if (_hasRecording && !_isRecording) ...[
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _enroll,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.check_circle_outline),
                  label:
                      Text(_isUploading ? 'Enrolling…' : 'Confirm & Enroll'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : _startRecording,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Re-record'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

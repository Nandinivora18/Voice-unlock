// home_screen.dart  (Login)
// The user records their voice; the audio is sent to /verify.
// Displays the similarity score and pass/fail result.
// Handles lockout state with countdown.

import 'dart:async';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/audio_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/recording_indicator.dart';
import 'vault_dashboard.dart';
import 'enrollment_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── State ────────────────────────────────────────────────────────
  bool   _isRecording   = false;
  bool   _isProcessing  = false;
  int    _countdown     = AppConstants.recordingDuration;
  String _statusMessage = 'Tap the mic and speak naturally.';
  Color  _statusColor   = AppTheme.textSecondary;
  double? _score;
  double  _threshold = 0.75;
  
  // Lockout
  bool _lockedOut          = false;
  int  _lockoutRemaining   = 0;
  int  _remainingAttempts  = 5;
  Timer? _timer;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _refreshLockout();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  // ── Lockout polling ──────────────────────────────────────────────

  Future<void> _refreshLockout() async {
    final status = await ApiService.getStatus();
    if (!mounted || status == null) return;
    final locked    = status['locked_out'] == true;
    final remaining = (status['lockout_remaining_seconds'] as num?)?.toInt() ?? 0;
    setState(() {
      _lockedOut        = locked;
      _lockoutRemaining = remaining;
    });
    if (locked) _startLockoutCountdown(remaining);
  }

  void _startLockoutCountdown(int seconds) {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _lockoutRemaining = (_lockoutRemaining - 1).clamp(0, 99999);
      });
      if (_lockoutRemaining == 0) {
        t.cancel();
        setState(() => _lockedOut = false);
        _refreshLockout();
      }
    });
  }

  // ── Recording logic ──────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_lockedOut || _isProcessing) return;
    _isRecording ? await _stopAndVerify() : await _startRecording();
  }

  Future<void> _startRecording() async {
    _timer?.cancel();
    setState(() {
      _isRecording   = true;
      _countdown     = AppConstants.recordingDuration;
      _statusMessage = 'Listening… speak clearly!';
      _statusColor   = AppTheme.error;
      _score         = null;
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

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        _stopAndVerify();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _stopAndVerify() async {
    _timer?.cancel();
    final file = await AudioService.stopRecording();
    setState(() {
      _isRecording  = false;
      _isProcessing = true;
      _statusMessage = 'Analysing voice…';
      _statusColor   = AppTheme.textSecondary;
    });

    if (file == null) {
      setState(() {
        _isProcessing  = false;
        _statusMessage = 'Recording failed. Try again.';
        _statusColor   = AppTheme.error;
      });
      return;
    }

    final result = await ApiService.verify(file);
    if (!mounted) return;

    setState(() => _isProcessing = false);

    if (result == null) {
      setState(() {
        _statusMessage = 'Server error. Is the backend running?';
        _statusColor   = AppTheme.warning;
      });
      return;
    }

    // Lockout response
    if (result['lockout_remaining_seconds'] != null) {
      final rem = (result['lockout_remaining_seconds'] as num).toInt();
      setState(() {
        _lockedOut        = true;
        _lockoutRemaining = rem;
        _statusMessage    = 'Too many failed attempts. Locked out.';
        _statusColor      = AppTheme.error;
      });
      _startLockoutCountdown(rem);
      return;
    }

    final success   = result['success'] == true;
    final score     = (result['score'] as num?)?.toDouble();
    final threshold = (result['threshold'] as num?)?.toDouble() ?? 0.80;
    final token     = result['token'] as String?;
    final remaining = (result['remaining_attempts'] as num?)?.toInt();

    setState(() {
      _score         = score;
      _threshold     = threshold;
            _statusColor   = success ? AppTheme.success : AppTheme.error;
      if (success) {
        _statusMessage = 'Voice verified! Score: ${score?.toStringAsFixed(3)}';
      } else {
        _remainingAttempts = remaining ?? _remainingAttempts;
        final reason = result['reason'] as String? ?? 'Voice mismatch';
        _statusMessage = '$reason\n($_remainingAttempts attempt(s) left.)';
      }
    });

    if (success && token != null) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VaultDashboard(sessionToken: token),
        ),
      );
    }
  }

  // ── UI ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRYPTWHISPER'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              const SizedBox(height: 24),



              // ── Lockout banner or mic button ───────────────────
              if (_lockedOut)
                _LockoutBanner(remaining: _lockoutRemaining)
              else ...[
                RecordingIndicator(
                  isRecording: _isRecording,
                  onTap: _isProcessing ? () {} : _toggleRecording,
                ),
                if (_isRecording)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Auto-stop in $_countdown s',
                        style: const TextStyle(
                            color: AppTheme.error, fontSize: 13)),
                  ),
                if (_isProcessing) ...[
                  const SizedBox(height: 12),
                  const CircularProgressIndicator(color: AppTheme.primary),
                ],
              ],
              const SizedBox(height: 24),

              // ── Status / score ─────────────────────────────────
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: _statusColor, fontSize: 16, fontWeight: FontWeight.w500),
              ),

              // Score bar
              if (_score != null) ...[
                const SizedBox(height: 20),
                _ScoreBar(score: _score!, threshold: _threshold),
              ],

              const SizedBox(height: 48),

              // ── Re-enroll link ─────────────────────────────────
              TextButton.icon(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EnrollmentScreen()),
                ),
                icon: const Icon(Icons.mic_external_on,
                    color: AppTheme.textSecondary, size: 24),
                label: const Text('Re-enroll voice',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────

class _LockoutBanner extends StatelessWidget {
  final int remaining;
  const _LockoutBanner({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final m = remaining ~/ 60;
    final s = remaining % 60;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.10),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        const Icon(Icons.lock, color: AppTheme.error, size: 36),
        const SizedBox(height: 8),
        const Text('Account Locked',
            style: TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          'Too many failed attempts.\nTry again in ${m}m ${s}s.',
          textAlign: TextAlign.center,
          style:
              const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ]),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final double score;
  final double threshold;
  const _ScoreBar({required this.score, required this.threshold});

  @override
  Widget build(BuildContext context) {
    final color = score >= threshold
        ? AppTheme.success
        : score >= threshold - 0.15
            ? AppTheme.warning
            : AppTheme.error;
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Voice similarity',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
          Text('${(score * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: score.clamp(0.0, 1.0),
          minHeight: 8,
          backgroundColor: AppTheme.surface,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
      const SizedBox(height: 4),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 2,
            height: 10,
            color: AppTheme.primary.withValues(alpha: 0.6),
            margin: EdgeInsets.only(
                right: (1.0 - threshold) * MediaQuery.of(context).size.width * 0.5),
          ),
          const Text('threshold',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 10)),
        ],
      ),
    ]);
  }
}

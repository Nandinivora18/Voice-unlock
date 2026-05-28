// splash_screen.dart
// First screen shown on startup.
// Checks if the Python backend is reachable and whether the user
// has already enrolled a voice profile, then routes accordingly.

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'enrollment_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>    _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    await Future.delayed(const Duration(milliseconds: 1800));

    final status = await ApiService.getStatus();

    if (!mounted) return;

    if (status == null) {
      // Backend not reachable — show error dialog.
      _showServerError();
      return;
    }

    final enrolled = status['enrolled'] == true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            enrolled ? const HomeScreen() : const EnrollmentScreen(),
      ),
    );
  }

  void _showServerError() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
          SizedBox(width: 8),
          Text('Backend Offline',
              style: TextStyle(color: AppTheme.textPrimary)),
        ]),
        content: const Text(
          'Cannot reach the Python server.\n\n'
          '1. Open python_backend/\n'
          '2. Double-click start_server.bat\n\n'
          'For physical device: also run\n'
          '  adb reverse tcp:8765 tcp:8765',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkStatus(); // retry
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lock + shield icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  border:
                      Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 2),
                ),
                child: const Icon(Icons.security,
                    color: AppTheme.primary, size: 50),
              ),
              const SizedBox(height: 28),
              const Text(
                'CRYPTWHISPER',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Voice Biometric Vault',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Connecting to local server…',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

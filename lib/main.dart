// main.dart
// CryptWhisper — Secure Offline Voice Biometric Vault
// Entry point: initialises the dark theme and launches SplashScreen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait for consistent UI.
  SystemChrome.setPreferredOrientations([





























































































    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Use a dark status bar for the security aesthetic.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const CryptWhisperApp());
}

class CryptWhisperApp extends StatelessWidget {
  const CryptWhisperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CryptWhisper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}

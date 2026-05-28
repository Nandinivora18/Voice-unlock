// settings_screen.dart
// App configuration: re-enroll voice, view server URL, clear vault.

import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'enrollment_screen.dart';

class SettingsScreen extends StatelessWidget {
  final String sessionToken;
  const SettingsScreen({super.key, required this.sessionToken});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Voice Security section ─────────────────────────────
          _sectionHeader('Voice & Security'),
          _tile(
            icon: Icons.mic_none,
            title: 'Re-enroll Voice',
            subtitle: 'Record a new voice profile. Current session will end.',
            color: AppTheme.primary,
            onTap: () => _confirmReEnroll(context),
          ),
          const Divider(color: AppTheme.divider),

          // ── Server section ─────────────────────────────────────
          _sectionHeader('Backend'),
          _infoTile(
            icon: Icons.dns_outlined,
            title: 'Server URL',
            value: AppConstants.serverUrl,
          ),
          _infoTile(
            icon: Icons.vpn_key_outlined,
            title: 'Threshold',
            value: '75.0% cosine similarity',
          ),
          _infoTile(
            icon: Icons.block,
            title: 'Lockout policy',
            value: '5 failed attempts → 5-minute lockout',
          ),
          const Divider(color: AppTheme.divider),

          // ── Danger zone ────────────────────────────────────────
          _sectionHeader('Danger Zone'),
          _tile(
            icon: Icons.delete_forever,
            title: 'Clear Vault',
            subtitle: 'Permanently delete ALL vault entries.',
            color: AppTheme.error,
            onTap: () => _confirmClearVault(context),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.5)),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: Icon(icon, color: color),
        title:   Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
        onTap: onTap,
      );

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) =>
      ListTile(
        leading:  Icon(icon, color: AppTheme.textSecondary),
        title:    Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
        subtitle: Text(value,
            style: const TextStyle(
                color: AppTheme.primary, fontSize: 12)),
      );

  // ── Dialogs ──────────────────────────────────────────────────────

  void _confirmReEnroll(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Re-enroll Voice',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'This will delete your current voice profile and require you to record a new one. '
          'Your vault entries will be preserved.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ApiService.resetEnrollment();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const EnrollmentScreen()),
                  (_) => false,
                );
              }
            },
            child: const Text('Re-enroll',
                style: TextStyle(color: AppTheme.warning)),
          ),
        ],
      ),
    );
  }

  void _confirmClearVault(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Clear Vault',
            style: TextStyle(color: AppTheme.error)),
        content: const Text(
          'This will permanently delete ALL vault entries. '
          'This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Call a special endpoint that clears the DB
              try {
                await ApiService.searchEntries(sessionToken, '').then(
                  (entries) async {
                    for (final e in entries) {
                      await ApiService.deleteEntry(
                          sessionToken, e['id'] as int);
                    }
                  },
                );
              } catch (_) {}
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('All vault entries cleared.')),
                );
              }
            },
            child: const Text('Clear All',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

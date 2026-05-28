// vault_entry_card.dart
// Card widget for displaying a single vault entry.
// Supports reveal/hide password, copy to clipboard, edit, and delete.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class VaultEntryCard extends StatefulWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const VaultEntryCard({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<VaultEntryCard> createState() => _VaultEntryCardState();
}

class _VaultEntryCardState extends State<VaultEntryCard> {
  bool _showPassword = false;

  IconData get _categoryIcon {
    switch (widget.entry['category']) {
      case 'note':   return Icons.sticky_note_2_outlined;
      case 'card':   return Icons.credit_card_outlined;
      default:       return Icons.lock_outline;
    }
  }

  Color get _categoryColor {
    switch (widget.entry['category']) {
      case 'note':   return AppTheme.warning;
      case 'card':   return Colors.purpleAccent;
      default:       return AppTheme.primary;
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e        = widget.entry;
    final title    = e['title']    as String? ?? '';
    final username = e['username'] as String? ?? '';
    final password = e['password'] as String? ?? '';
    final notes    = e['notes']    as String? ?? '';
    final category = e['category'] as String? ?? 'password';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_categoryIcon, color: _categoryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
                // Edit
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: AppTheme.textSecondary, size: 20),
                  onPressed: widget.onEdit,
                  tooltip: 'Edit',
                ),
                // Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.error, size: 20),
                  onPressed: () => _confirmDelete(context),
                  tooltip: 'Delete',
                ),
              ],
            ),
            // ── Username ────────────────────────────────────────────
            if (username.isNotEmpty) ...[
              const SizedBox(height: 8),
              _fieldRow(
                label: 'Username',
                value: username,
                icon: Icons.person_outline,
                onCopy: () => _copy(username, 'Username'),
              ),
            ],
            // ── Password ────────────────────────────────────────────
            if (password.isNotEmpty && category != 'note') ...[
              const SizedBox(height: 4),
              _fieldRow(
                label: 'Password',
                value: _showPassword ? password : '•' * password.length.clamp(6, 16),
                icon: Icons.password,
                onCopy: () => _copy(password, 'Password'),
                trailing: IconButton(
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppTheme.textSecondary,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
            ],
            // ── Notes ───────────────────────────────────────────────
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              _fieldRow(
                label: 'Notes',
                value: notes,
                icon: Icons.notes,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fieldRow({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onCopy,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onCopy != null)
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy, size: 15, color: AppTheme.primary),
            ),
          ),
        if (trailing != null) trailing,
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Entry',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
            'Delete "${widget.entry['title']}"? This cannot be undone.',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

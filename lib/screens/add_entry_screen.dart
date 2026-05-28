// add_entry_screen.dart
// Form for adding a new vault entry or editing an existing one.
// Supports three categories: password, note, card.

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AddEntryScreen extends StatefulWidget {
  final String sessionToken;
  final Map<String, dynamic>? existingEntry; // null = add mode

  const AddEntryScreen({
    super.key,
    required this.sessionToken,
    this.existingEntry,
  });

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _titleCtrl    = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  final _urlCtrl      = TextEditingController();

  String _category     = 'password';
  bool   _showPassword = false;
  bool   _isSaving     = false;

  bool get _isEdit => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existingEntry;
    if (e != null) {
      _titleCtrl.text    = e['title']    ?? '';
      _usernameCtrl.text = e['username'] ?? '';
      _passwordCtrl.text = e['password'] ?? '';
      _notesCtrl.text    = e['notes']    ?? '';
      _urlCtrl.text      = e['url']      ?? '';
      _category          = e['category'] ?? 'password';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _notesCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final data = {
      'title':    _titleCtrl.text.trim(),
      'category': _category,
      'username': _usernameCtrl.text.trim(),
      'password': _passwordCtrl.text,
      'notes':    _notesCtrl.text.trim(),
      'url':      _urlCtrl.text.trim(),
    };

    bool success;
    if (_isEdit) {
      success = await ApiService.updateEntry(
          widget.sessionToken, widget.existingEntry!['id'], data);
    } else {
      success = await ApiService.addEntry(widget.sessionToken, data);
    }

    setState(() => _isSaving = false);

    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true); // signal refresh
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save entry. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'EDIT ENTRY' : 'ADD ENTRY'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Category chips ─────────────────────────────────
              const Text('Category',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['password', 'note', 'card'].map((cat) {
                  final selected = _category == cat;
                  return ChoiceChip(
                    label: Text(cat[0].toUpperCase() + cat.substring(1)),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = cat),
                    selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                    backgroundColor: AppTheme.surface,
                    labelStyle: TextStyle(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.textSecondary),
                    side: BorderSide(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.divider),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Title ──────────────────────────────────────────
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 14),

              // ── Username ───────────────────────────────────────
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username / Email',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 14),

              // ── Password (hidden for notes) ────────────────────
              if (_category != 'note')
                Column(children: [
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 14),
                ]),

              // ── URL ────────────────────────────────────────────
              if (_category != 'note')
                Column(children: [
                  TextFormField(
                    controller: _urlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'URL (optional)',
                      prefixIcon: Icon(Icons.link),
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 14),
                ]),

              // ── Notes ──────────────────────────────────────────
              TextFormField(
                controller: _notesCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 32),

              // ── Save button ────────────────────────────────────
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving
                    ? 'Saving…'
                    : _isEdit
                        ? 'Update Entry'
                        : 'Save Entry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

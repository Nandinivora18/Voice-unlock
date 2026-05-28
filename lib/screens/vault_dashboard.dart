// vault_dashboard.dart
// Main screen shown after successful voice authentication.
// Lists all vault entries, supports search, add, edit, delete, and logout.

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/vault_entry_card.dart';
import 'add_entry_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'home_screen.dart';

class VaultDashboard extends StatefulWidget {
  final String sessionToken;
  const VaultDashboard({super.key, required this.sessionToken});

  @override
  State<VaultDashboard> createState() => _VaultDashboardState();
}

class _VaultDashboardState extends State<VaultDashboard> {
  List<Map<String, dynamic>> _entries        = [];
  List<Map<String, dynamic>> _filteredEntries = [];
  bool   _isLoading  = false;
  String _filter     = 'all';        // all | password | note | card
  String _searchQuery = '';
  final  _searchCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    final entries =
        await ApiService.getEntries(widget.sessionToken);
    setState(() {
      _entries         = entries;
      _isLoading       = false;
      _applyFilter();
    });
  }

  Future<void> _search(String query) async {
    setState(() => _searchQuery = query);
    if (query.isEmpty) {
      _applyFilter();
      return;
    }
    final results =
        await ApiService.searchEntries(widget.sessionToken, query);
    setState(() {
      _filteredEntries = _category == 'all'
          ? results
          : results.where((e) => e['category'] == _filter).toList();
    });
  }

  void _applyFilter() {
    setState(() {
      _filteredEntries = _filter == 'all'
          ? List.from(_entries)
          : _entries.where((e) => e['category'] == _filter).toList();
    });
  }

  String get _category => _filter;

  // ── Navigation ───────────────────────────────────────────────────

  Future<void> _openAddEntry([Map<String, dynamic>? existing]) async {
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEntryScreen(
          sessionToken: widget.sessionToken,
          existingEntry: existing,
        ),
      ),
    );
    if (refreshed == true) _loadEntries();
  }

  Future<void> _deleteEntry(int id) async {
    await ApiService.deleteEntry(widget.sessionToken, id);
    _loadEntries();
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  // ── UI ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VAULT'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddEntry,
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.background,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _search,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search entries…',
                prefixIcon:
                    const Icon(Icons.search, color: AppTheme.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: AppTheme.textSecondary),
                        onPressed: () {
                          _searchCtrl.clear();
                          _search('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ── Category filter chips ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _filterChip('all', 'All', Icons.all_inbox_outlined),
                const SizedBox(width: 8),
                _filterChip('password', 'Passwords', Icons.lock_outline),
                const SizedBox(width: 8),
                _filterChip('note', 'Notes', Icons.sticky_note_2_outlined),
                const SizedBox(width: 8),
                _filterChip('card', 'Cards', Icons.credit_card_outlined),
              ],
            ),
          ),

          // ── Entry count ────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Text(
                '${_filteredEntries.length} item(s)',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
            ]),
          ),

          // ── List ───────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : _filteredEntries.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _loadEntries,
                        color: AppTheme.primary,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.only(bottom: 80),
                          itemCount: _filteredEntries.length,
                          itemBuilder: (_, i) {
                            final e = _filteredEntries[i];
                            return VaultEntryCard(
                              entry: e,
                              onEdit: () => _openAddEntry(e),
                              onDelete: () =>
                                  _deleteEntry(e['id'] as int),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, IconData icon) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        _search(_searchQuery);
        _applyFilter();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.15)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.divider),
        ),
        child: Row(children: [
          Icon(icon,
              size: 14,
              color: selected ? AppTheme.primary : AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: selected
                      ? AppTheme.primary
                      : AppTheme.textSecondary)),
        ]),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox, color: AppTheme.textSecondary.withValues(alpha: 0.4),
            size: 64),
        const SizedBox(height: 12),
        Text(
          _searchQuery.isNotEmpty
              ? 'No results for "$_searchQuery"'
              : 'No entries yet. Tap + to add one.',
          style: const TextStyle(color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppTheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: AppTheme.surfaceLight,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.security, color: AppTheme.primary, size: 36),
                    const SizedBox(height: 8),
                    const Text('CryptWhisper',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    Text('${_entries.length} entries stored',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ]),
            ),
            ListTile(
              leading:
                  const Icon(Icons.settings_outlined, color: AppTheme.primary),
              title: const Text('Settings',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                            sessionToken: widget.sessionToken)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: AppTheme.primary),
              title: const Text('About',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()));
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.error),
              title: const Text('Logout',
                  style: TextStyle(color: AppTheme.error)),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../models/farmer_model.dart';
import '../../models/user_model.dart';
import '../database/database_service.dart';
import '_onboarded_list.dart';
import 'onboarded_export_service.dart';

class UserSchoolBookshopsPage extends StatefulWidget {
  const UserSchoolBookshopsPage({super.key});

  @override
  State<UserSchoolBookshopsPage> createState() =>
      _UserSchoolBookshopsPageState();
}

class _UserSchoolBookshopsPageState extends State<UserSchoolBookshopsPage> {
  final DatabaseService _dbService = DatabaseService();
  late Future<_BookshopData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_BookshopData> _loadData() async {
    final all = await _dbService.getAllSchools();
    final bookshops =
        all
            .where((s) => (s.dealerType ?? '').toLowerCase() == 'bookshop')
            .toList();
    final users = await _dbService.getAllUsers();
    return _BookshopData(items: bookshops, users: users);
  }

  void _refresh() {
    setState(() {
      _future = _loadData();
    });
  }

  Future<void> _exportPdf(_BookshopData data) async {
    if (data.items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No bookshops to export.')));
      return;
    }
    final byUser = <String, List<SchoolModel>>{};
    for (final s in data.items) {
      final uid = (s.capturedBy ?? '').trim();
      if (uid.isEmpty) continue;
      byUser.putIfAbsent(uid, () => <SchoolModel>[]).add(s);
    }
    final rows =
        data.users
            .map(
              (u) => OnboardedExportRow(
                user: u,
                items: byUser[u.id] ?? const <SchoolModel>[],
              ),
            )
            .where((r) => r.items.isNotEmpty)
            .toList()
          ..sort((a, b) => b.items.length.compareTo(a.items.length));

    try {
      await OnboardedExportService.exportPerUserBreakdown(
        context: context,
        reportTitle: 'Bookshops · Per-User Breakdown',
        reportSubtitle:
            'All onboarded bookshops grouped by the agent who captured them',
        totalItems: data.items.length,
        rows: rows,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _userDisplayName(UserModel u) {
    final n = (u.fullName ?? '').trim();
    return n.isNotEmpty ? n : u.email;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookshops'),
        backgroundColor: AppColors.accentOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF',
            onPressed: () async {
              final snap = await _future;
              if (!mounted) return;
              await _exportPdf(snap);
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: FutureBuilder<_BookshopData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load bookshops: ${snapshot.error}'),
            );
          }
          final data =
              snapshot.data ??
              const _BookshopData(items: <SchoolModel>[], users: <UserModel>[]);

          final byUser = <String, List<SchoolModel>>{};
          for (final s in data.items) {
            final uid = (s.capturedBy ?? '').trim();
            if (uid.isEmpty) continue;
            byUser.putIfAbsent(uid, () => <SchoolModel>[]).add(s);
          }

          final userRows =
              data.users
                  .map(
                    (u) => _UserBreakdownRow(
                      user: u,
                      items: byUser[u.id] ?? const <SchoolModel>[],
                    ),
                  )
                  .where((r) => r.items.isNotEmpty)
                  .toList()
                ..sort((a, b) => b.items.length.compareTo(a.items.length));

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accentOrange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.store_mall_directory_outlined,
                        color: AppColors.accentOrange,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${data.items.length} Bookshop${data.items.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentOrange,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'All onboarded bookshops in the system',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionLabel('All bookshops'),
                const SizedBox(height: 8),
                OnboardedListSection(
                  items: data.items,
                  emptyLabel: 'No bookshops onboarded yet.',
                  color: AppColors.accentOrange,
                ),
                const SizedBox(height: 20),
                _SectionLabel('Per-user breakdown · Bookshops'),
                const SizedBox(height: 8),
                if (userRows.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          color: Colors.grey,
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No users have onboarded bookshops yet.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...userRows.map(
                    (row) => _buildUserBreakdownCard(
                      context,
                      row: row,
                      color: AppColors.accentOrange,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserBreakdownCard(
    BuildContext context, {
    required _UserBreakdownRow row,
    required Color color,
  }) {
    final name = _userDisplayName(row.user);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(
            _initials(name),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          'Role ${row.user.role} • ${row.items.length} bookshop${row.items.length == 1 ? '' : 's'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        children: row.items
            .map(
              (s) => ListTile(
                dense: true,
                leading: Icon(Icons.store, color: color, size: 20),
                title: Text(s.name),
                subtitle: Text(
                  [
                    if (s.county.trim().isNotEmpty) s.county,
                    if (s.phone.trim().isNotEmpty) s.phone,
                  ].join(' • '),
                ),
                trailing: Text(
                  s.isSynced ? 'Synced' : 'Pending',
                  style: TextStyle(
                    color: s.isSynced ? AppColors.primaryGreen : Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _BookshopData {
  const _BookshopData({required this.items, required this.users});
  final List<SchoolModel> items;
  final List<UserModel> users;
}

class _UserBreakdownRow {
  const _UserBreakdownRow({required this.user, required this.items});
  final UserModel user;
  final List<SchoolModel> items;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
        letterSpacing: 1.2,
      ),
    );
  }
}

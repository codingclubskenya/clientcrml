import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../models/farmer_model.dart';
import '../../models/user_model.dart';
import '../database/database_service.dart';
import '_onboarded_list.dart';
import 'onboarded_export_service.dart';

class UserSchoolTodayOnboardedPage extends StatefulWidget {
  const UserSchoolTodayOnboardedPage({super.key, required this.today});

  final DateTime today;

  @override
  State<UserSchoolTodayOnboardedPage> createState() =>
      _UserSchoolTodayOnboardedPageState();
}

class _UserSchoolTodayOnboardedPageState
    extends State<UserSchoolTodayOnboardedPage> {
  final DatabaseService _dbService = DatabaseService();
  late Future<_TodayData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_TodayData> _loadData() async {
    final all = await _dbService.getAllSchools();
    final users = await _dbService.getAllUsers();
    final dayStart = DateTime(
      widget.today.year,
      widget.today.month,
      widget.today.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));

    bool isToday(DateTime? d) {
      if (d == null) return false;
      return !d.isBefore(dayStart) && d.isBefore(dayEnd);
    }

    final todayAll = all.where((s) => isToday(s.createdAt)).toList();
    final schools =
        todayAll.where((s) => !_isBookshop(s) && !_isInstitution(s)).toList();
    final bookshops = todayAll.where(_isBookshop).toList();
    final institutions = todayAll.where(_isInstitution).toList();
    return _TodayData(
      schools: schools,
      bookshops: bookshops,
      institutions: institutions,
      users: users,
    );
  }

  bool _isBookshop(SchoolModel s) =>
      (s.dealerType ?? '').toLowerCase() == 'bookshop';

  bool _isInstitution(SchoolModel s) =>
      (s.dealerType ?? '').toLowerCase() == 'institution';

  void _refresh() {
    setState(() {
      _future = _loadData();
    });
  }

  Future<void> _exportPdf(_TodayData data) async {
    final all = <SchoolModel>[
      ...data.schools,
      ...data.bookshops,
      ...data.institutions,
    ];
    if (all.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing onboarded today to export.')),
      );
      return;
    }
    final byUser = <String, List<SchoolModel>>{};
    for (final s in all) {
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
        reportTitle: "Today's Onboarded · Per-User Breakdown",
        reportSubtitle:
            'Schools, institutions and bookshops added today, grouped by agent',
        totalItems: all.length,
        rows: rows,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  String _formatDate(DateTime d) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
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
        title: const Text("Today's Onboarded"),
        backgroundColor: AppColors.primaryGreen,
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
      body: FutureBuilder<_TodayData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load: ${snapshot.error}'));
          }
          final data =
              snapshot.data ??
              const _TodayData(
                schools: <SchoolModel>[],
                bookshops: <SchoolModel>[],
                institutions: <SchoolModel>[],
                users: <UserModel>[],
              );
          final all = <SchoolModel>[
            ...data.schools,
            ...data.bookshops,
            ...data.institutions,
          ];

          final byUser = <String, List<SchoolModel>>{};
          for (final s in all) {
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
                    color: AppColors.primaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.today_outlined,
                        color: AppColors.primaryGreen,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate(widget.today),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${all.length} record${all.length == 1 ? '' : 's'} onboarded today',
                              style: const TextStyle(
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _miniStat(
                        'Schools',
                        data.schools.length,
                        AppColors.primaryDark,
                        Icons.school_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniStat(
                        'Bookshops',
                        data.bookshops.length,
                        AppColors.accentOrange,
                        Icons.store_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniStat(
                        'Institutions',
                        data.institutions.length,
                        AppColors.infoBlue,
                        Icons.account_balance_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionHeader(
                  icon: Icons.school_outlined,
                  title: 'Schools',
                  count: data.schools.length,
                ),
                OnboardedListSection(
                  items: data.schools,
                  emptyLabel: 'No schools onboarded today.',
                  color: AppColors.primaryDark,
                ),
                const SizedBox(height: 16),
                _SectionHeader(
                  icon: Icons.store_outlined,
                  title: 'Bookshops',
                  count: data.bookshops.length,
                ),
                OnboardedListSection(
                  items: data.bookshops,
                  emptyLabel: 'No bookshops onboarded today.',
                  color: AppColors.accentOrange,
                ),
                const SizedBox(height: 16),
                _SectionHeader(
                  icon: Icons.account_balance_outlined,
                  title: 'Institutions',
                  count: data.institutions.length,
                ),
                OnboardedListSection(
                  items: data.institutions,
                  emptyLabel: 'No institutions onboarded today.',
                  color: AppColors.infoBlue,
                ),
                const SizedBox(height: 20),
                const _SectionLabel('Per-user breakdown · Today'),
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
                            'No users onboarded anything today.',
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
                      totalByType: _countByType(row.items),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<String, int> _countByType(List<SchoolModel> items) {
    var schools = 0, bookshops = 0, institutions = 0;
    for (final s in items) {
      if (_isBookshop(s)) {
        bookshops++;
      } else if (_isInstitution(s)) {
        institutions++;
      } else {
        schools++;
      }
    }
    return {
      'schools': schools,
      'bookshops': bookshops,
      'institutions': institutions,
    };
  }

  Widget _buildUserBreakdownCard(
    BuildContext context, {
    required _UserBreakdownRow row,
    required Map<String, int> totalByType,
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
          backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
          child: Text(
            _initials(name),
            style: const TextStyle(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              if (totalByType['schools']! > 0)
                _typeChip(
                  '${totalByType['schools']} school${totalByType['schools'] == 1 ? '' : 's'}',
                  AppColors.primaryDark,
                ),
              if (totalByType['bookshops']! > 0)
                _typeChip(
                  '${totalByType['bookshops']} bookshop${totalByType['bookshops'] == 1 ? '' : 's'}',
                  AppColors.accentOrange,
                ),
              if (totalByType['institutions']! > 0)
                _typeChip(
                  '${totalByType['institutions']} institution${totalByType['institutions'] == 1 ? '' : 's'}',
                  AppColors.infoBlue,
                ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        children: row.items
            .map(
              (s) => ListTile(
                dense: true,
                leading: Icon(
                  _isBookshop(s)
                      ? Icons.store
                      : _isInstitution(s)
                      ? Icons.account_balance
                      : Icons.school,
                  color:
                      _isBookshop(s)
                          ? AppColors.accentOrange
                          : _isInstitution(s)
                          ? AppColors.infoBlue
                          : AppColors.primaryDark,
                  size: 20,
                ),
                title: Text(s.name),
                subtitle: Text(
                  [
                    _isBookshop(s)
                        ? 'Bookshop'
                        : _isInstitution(s)
                        ? 'Institution'
                        : 'School',
                    if (s.county.trim().isNotEmpty) s.county,
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

  Widget _typeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _miniStat(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayData {
  const _TodayData({
    required this.schools,
    required this.bookshops,
    required this.institutions,
    required this.users,
  });
  final List<SchoolModel> schools;
  final List<SchoolModel> bookshops;
  final List<SchoolModel> institutions;
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

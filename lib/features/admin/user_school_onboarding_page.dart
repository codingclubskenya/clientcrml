import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../models/farmer_model.dart';
import '../../models/user_model.dart';
import '../database/database_service.dart';
import 'onboarded_export_service.dart';
import 'user_school_bookshops_page.dart';
import 'user_school_institutions_page.dart';
import 'user_school_today_onboarded_page.dart';

class UserSchoolOnboardingPage extends StatefulWidget {
  const UserSchoolOnboardingPage({super.key});

  @override
  State<UserSchoolOnboardingPage> createState() =>
      _UserSchoolOnboardingPageState();
}

class _UserSchoolOnboardingPageState extends State<UserSchoolOnboardingPage> {
  final DatabaseService _dbService = DatabaseService();
  late Future<_UserSchoolData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_UserSchoolData> _loadData() async {
    final users = await _dbService.getAllUsers();
    final schools = await _dbService.getAllSchools();
    return _UserSchoolData(users: users, schools: schools);
  }

  void _refresh() {
    setState(() {
      _future = _loadData();
    });
  }

  Future<void> _exportPdf(_UserSchoolData data) async {
    if (data.schools.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No data to export.')));
      return;
    }
    final byUser = <String, List<SchoolModel>>{};
    for (final s in data.schools) {
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
        reportTitle: 'User Onboarding · Per-User Breakdown',
        reportSubtitle:
            'All onboarded schools, bookshops and institutions grouped by agent',
        totalItems: data.schools.length,
        rows: rows,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  String _typeOf(SchoolModel s) {
    final t = (s.dealerType ?? '').toLowerCase();
    if (t == 'bookshop') return 'bookshop';
    if (t == 'institution') return 'institution';
    return 'school';
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Onboarding Tracker'),
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
      body: FutureBuilder<_UserSchoolData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load data: ${snapshot.error}'),
            );
          }

          final data =
              snapshot.data ??
              const _UserSchoolData(
                users: <UserModel>[],
                schools: <SchoolModel>[],
              );

          final bookshops = data.schools
              .where((s) => _typeOf(s) == 'bookshop')
              .toList(growable: false);
          final institutions = data.schools
              .where((s) => _typeOf(s) == 'institution')
              .toList(growable: false);
          final today = DateTime.now();
          final todaySchools = data.schools
              .where((s) => _isSameDay(s.createdAt, today))
              .toList(growable: false);

          final schoolsByUser = <String, List<SchoolModel>>{};
          for (final school in data.schools) {
            final userId = (school.capturedBy ?? '').trim();
            if (userId.isEmpty) continue;
            schoolsByUser
                .putIfAbsent(userId, () => <SchoolModel>[])
                .add(school);
          }

          final userRows =
              data.users.map((user) {
                  final userSchools = schoolsByUser[user.id] ?? <SchoolModel>[];
                  return _UserSchoolRow(user: user, schools: userSchools);
                }).toList()
                ..sort((a, b) => b.schools.length.compareTo(a.schools.length));

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(
                  users: data.users.length,
                  schools: data.schools.length,
                  bookshops: bookshops.length,
                  institutions: institutions.length,
                ),
                const SizedBox(height: 16),
                const _SectionLabel('Sub-pages'),
                const SizedBox(height: 8),
                _buildSubPageCard(
                  context,
                  icon: Icons.store_mall_directory_outlined,
                  title: 'Bookshops',
                  subtitle: 'All onboarded bookshops',
                  count: bookshops.length,
                  color: AppColors.accentOrange,
                  destination: const UserSchoolBookshopsPage(),
                ),
                _buildSubPageCard(
                  context,
                  icon: Icons.account_balance_outlined,
                  title: 'Institutions',
                  subtitle: 'All onboarded institutions',
                  count: institutions.length,
                  color: AppColors.infoBlue,
                  destination: const UserSchoolInstitutionsPage(),
                ),
                _buildSubPageCard(
                  context,
                  icon: Icons.today_outlined,
                  title: "Today's Onboarded",
                  subtitle: 'Schools, institutions & bookshops added today',
                  count: todaySchools.length,
                  color: AppColors.primaryGreen,
                  destination: UserSchoolTodayOnboardedPage(today: today),
                ),
                const SizedBox(height: 20),
                const _SectionLabel('Per-user breakdown'),
                const SizedBox(height: 8),
                if (userRows.isEmpty)
                  _buildEmptyCard('No users found yet.')
                else
                  ...userRows.map((row) => _buildUserCard(row)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required int users,
    required int schools,
    required int bookshops,
    required int institutions,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(child: _metric('Users', '$users')),
          Expanded(child: _metric('Schools', '$schools')),
          Expanded(child: _metric('Bookshops', '$bookshops')),
          Expanded(child: _metric('Institutions', '$institutions')),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSubPageCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int count,
    required Color color,
    required Widget destination,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => destination),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(_UserSchoolRow row) {
    final name =
        (row.user.fullName?.trim().isNotEmpty ?? false)
            ? row.user.fullName!.trim()
            : row.user.email;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: AppColors.primaryGreen),
          ),
        ),
        title: Text(name),
        subtitle: Text('Role ${row.user.role} • ${row.schools.length} schools'),
        children: [
          if (row.schools.isEmpty)
            const ListTile(title: Text('No schools onboarded yet.'))
          else
            ...row.schools.map(
              (school) => ListTile(
                title: Text(school.name),
                subtitle: Text(
                  '${_typeOf(school).toUpperCase()} • ${school.county} • ${school.phone}',
                ),
                trailing: Text(
                  school.isSynced ? 'Synced' : 'Pending',
                  style: TextStyle(
                    color:
                        school.isSynced
                            ? AppColors.primaryGreen
                            : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
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

class _UserSchoolData {
  const _UserSchoolData({required this.users, required this.schools});

  final List<UserModel> users;
  final List<SchoolModel> schools;
}

class _UserSchoolRow {
  const _UserSchoolRow({required this.user, required this.schools});

  final UserModel user;
  final List<SchoolModel> schools;
}

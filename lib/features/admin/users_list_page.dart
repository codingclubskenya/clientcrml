import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../database/database_service.dart';
import '../../models/user_model.dart';
import 'add_team_member_form.dart';

class UsersListPage extends StatefulWidget {
  const UsersListPage({super.key});

  @override
  State<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _dbService.getAllUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _filteredUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load users: $e')));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers =
            _users.where((user) {
              final name = (user.fullName ?? '').toLowerCase();
              final email = user.email.toLowerCase();
              return name.contains(query.toLowerCase()) ||
                  email.contains(query.toLowerCase());
            }).toList();
      }
    });
  }

  void _showUserProfile(BuildContext context, UserModel user) {
    final name = user.fullName ?? user.email;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primaryGreen.withValues(
                      alpha: 0.1,
                    ),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const Divider(height: 32),
                  _buildProfileRow(Icons.perm_identity, 'User ID', user.id),
                  // Note: If your UserModel exposes getters for 'role' and 'region',
                  // uncomment the following lines to display them in the profile!
                  // const SizedBox(height: 12),
                  // _buildProfileRow(Icons.badge_outlined, 'Role ID', user.role?.toString() ?? 'N/A'),
                  // const SizedBox(height: 12),
                  // _buildProfileRow(Icons.map_outlined, 'Region', user.region ?? 'No Region'),
                  const SizedBox(height: 12),
                  _buildProfileRow(
                    Icons.badge_outlined,
                    'Role ID',
                    user.role.toString(),
                  ),
                  const SizedBox(height: 12),
                  _buildProfileRow(
                    Icons.map_outlined,
                    'Region',
                    user.region ?? 'No Region',
                  ),
                  const SizedBox(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "PERFORMANCE",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPerformanceSection(user),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close Profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryGreen),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(UserModel user) {
    // For now, this returns the same default target metrics as the SalesDashboard.
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.3,
      children: [
        _metricCard(
          "School Target",
          "15",
          Icons.ads_click,
          AppColors.secondaryOrange,
        ),
        _metricCard(
          "Weekly Target",
          "80",
          Icons.flag_outlined,
          AppColors.primaryGreen,
        ),
        _metricCard(
          "Institution Leads",
          "08",
          Icons.location_on_outlined,
          AppColors.secondaryOrange,
        ),
        _metricCard(
          "Weekly Visits",
          "42",
          Icons.trending_up,
          AppColors.primaryGreen,
        ),
      ],
    );
  }

  Widget _buildPerformanceSection(UserModel user) {
    if (user.role == 5) {
      return _buildRole5PerformanceOverview();
    }
    return _buildMetricsGrid(user);
  }

  Widget _buildRole5PerformanceOverview() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.18,
      children: const [
        _PeriodPerformanceCard(
          period: 'Daily',
          score: '87%',
          icon: Icons.today_outlined,
          accentColor: AppColors.primaryGreen,
          schoolTarget: '15',
          weeklyTarget: '80',
          institutionLeads: '08',
          weeklyVisits: '12',
        ),
        _PeriodPerformanceCard(
          period: 'Weekly',
          score: '90%',
          icon: Icons.view_week_outlined,
          accentColor: AppColors.primaryDark,
          schoolTarget: '35',
          weeklyTarget: '200',
          institutionLeads: '20',
          weeklyVisits: '30',
        ),
        _PeriodPerformanceCard(
          period: 'Monthly',
          score: '91%',
          icon: Icons.calendar_month_outlined,
          accentColor: AppColors.secondaryOrange,
          schoolTarget: '60',
          weeklyTarget: '320',
          institutionLeads: '34',
          weeklyVisits: '48',
        ),
        _PeriodPerformanceCard(
          period: 'Quarterly',
          score: '89%',
          icon: Icons.date_range_outlined,
          accentColor: AppColors.primaryGreen,
          schoolTarget: '180',
          weeklyTarget: '960',
          institutionLeads: '102',
          weeklyVisits: '144',
        ),
        _PeriodPerformanceCard(
          period: 'Yearly',
          score: '93%',
          icon: Icons.insights_outlined,
          accentColor: AppColors.secondaryOrange,
          schoolTarget: '720',
          weeklyTarget: '3840',
          institutionLeads: '408',
          weeklyVisits: '576',
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Directory'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_rounded),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                builder: (_) => const AddTeamMemberForm(),
              ).then((_) => _loadUsers());
            },
            tooltip: 'Add Team Member',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterUsers,
                      decoration: const InputDecoration(
                        labelText: 'Search Users',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Expanded(
                    child:
                        _filteredUsers.isEmpty
                            ? const Center(
                              child: Text('No team members found.'),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: _filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = _filteredUsers[index];
                                final name = user.fullName ?? user.email;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 0,
                                  color: AppColors.surfaceWhite,
                                  shape: RoundedRectangleBorder(
                                    side: const BorderSide(
                                      color: AppColors.borderGrey,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primaryPale,
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: AppColors.primaryGreen,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(user.email),
                                    trailing: const Icon(
                                      Icons.person_search_outlined,
                                      color: AppColors.textMuted,
                                    ),
                                    onTap:
                                        () => _showUserProfile(context, user),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }
}

class _PeriodPerformanceCard extends StatelessWidget {
  const _PeriodPerformanceCard({
    required this.period,
    required this.score,
    required this.icon,
    required this.accentColor,
    required this.schoolTarget,
    required this.weeklyTarget,
    required this.institutionLeads,
    required this.weeklyVisits,
  });

  final String period;
  final String score;
  final IconData icon;
  final Color accentColor;
  final String schoolTarget;
  final String weeklyTarget;
  final String institutionLeads;
  final String weeklyVisits;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Text(
                period,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            score,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 4),
          _metricRow('School Target', schoolTarget),
          _metricRow('Weekly Target', weeklyTarget),
          _metricRow('Institution Leads', institutionLeads),
          _metricRow('Weekly Visits', weeklyVisits),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/agent_screens.dart';
import '../../core/constants/colors.dart';
import '../../features/admin/regions_management_page.dart';
import '../../features/admin/target_performance_page.dart';
import '../../features/admin/team_attendance_page.dart';
import '../../features/admin/user_school_onboarding_page.dart';
import '../../features/dashboard/daily_check_in_page.dart';
import '../../features/dashboard/my_shops_page.dart';
import '../../features/dashboard/visit_tracker_map_page.dart';
import '../../features/events/events_list_page.dart';

class AgentDashboardPage extends StatefulWidget {
  const AgentDashboardPage({super.key});

  @override
  State<AgentDashboardPage> createState() => _AgentDashboardPageState();
}

class _AgentDashboardPageState extends State<AgentDashboardPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _supervisorName = 'Supervisor';
  String _regionName = 'Nairobi Region'; // Default/Fallback

  // Region Summary Metrics
  int _totalAgentsInRegion = 0;
  int _totalSchoolsInRegion = 0;

  // Personal Performance Metrics
  double _monthlyTarget = 100.0;
  double _achievedTarget = 0.0;
  int _visitsCompleted = 0;

  @override
  void initState() {
    super.initState();
    _fetchSupervisorDashboardData();
  }

  Future<void> _fetchSupervisorDashboardData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Fetch Supervisor Details & Region
      final profileResponse =
          await _supabase
              .from('profiles')
              .select('full_name, region_id, regions(name)')
              .eq('id', user.id)
              .maybeSingle();

      if (profileResponse != null) {
        _supervisorName = profileResponse['full_name'] ?? 'Supervisor';
        if (profileResponse['regions'] != null) {
          _regionName = profileResponse['regions']['name'] ?? 'Assigned Region';
        }
      }

      final regionId = profileResponse?['region_id'];

      if (regionId != null) {
        // 2. Fetch Regional Metrics (Count of Agents & Schools in region)
        final agentsCount = await _supabase
            .from('profiles')
            .select('id')
            .eq('region_id', regionId)
            .eq('role', 'agent');

        final schoolsCount = await _supabase
            .from('schools')
            .select('id')
            .eq('region_id', regionId);

        _totalAgentsInRegion = (agentsCount as List).length;
        _totalSchoolsInRegion = (schoolsCount as List).length;
      }

      // 3. Fetch Personal Supervisor Performance
      final performanceResponse =
          await _supabase
              .from('agent_performance')
              .select('target, achieved, visits_count')
              .eq('user_id', user.id)
              .maybeSingle();

      if (performanceResponse != null) {
        _monthlyTarget = (performanceResponse['target'] ?? 100).toDouble();
        _achievedTarget = (performanceResponse['achieved'] ?? 0).toDouble();
        _visitsCompleted = performanceResponse['visits_count'] ?? 0;
      }
    } catch (e) {
      debugPrint('Error fetching supervisor dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateTo(Widget destination) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    double progressRatio =
        _monthlyTarget > 0 ? (_achievedTarget / _monthlyTarget) : 0.0;
    if (progressRatio > 1.0) progressRatio = 1.0;

    final isWideScreen = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Supervisor Dashboard'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchSupervisorDashboardData();
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _supabase.auth.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: !isWideScreen ? Drawer(child: _buildSideMenuContent()) : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sticky Side Menu for wider screens / Web / Tablet
          if (isWideScreen)
            Container(
              width: 250,
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                border: Border(right: BorderSide(color: Colors.grey.shade200)),
              ),
              child: _buildSideMenuContent(),
            ),

          // Main Scrollable Content Area
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                      onRefresh: _fetchSupervisorDashboardData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- WELCOME HEADER ---
                            Text(
                              'Welcome back, $_supervisorName!',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _regionName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // --- DAILY CHECK-IN BUTTON ---
                            _buildDailyCheckInButton(context),
                            const SizedBox(height: 20),

                            // --- REGION SUMMARY SECTION ---
                            const Text(
                              'Region Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Agents Managed',
                                    value: '$_totalAgentsInRegion',
                                    icon: Icons.people_alt_outlined,
                                    color: AppColors.infoBlue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Regional Schools',
                                    value: '$_totalSchoolsInRegion',
                                    icon: Icons.school_outlined,
                                    color: AppColors.accentOrange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // --- MY PERFORMANCE SUMMARY ---
                            _buildPerformanceCard(progressRatio),
                            const SizedBox(height: 20),

                            // --- QUICK ACTIONS ---
                            _buildQuickActions(context),
                            const SizedBox(height: 20),

                            // --- MENU GRID ---
                            const Text(
                              'Menu Navigation',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: isWideScreen ? 3 : 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.1,
                              children: [
                                _buildDashboardCard(
                                  context,
                                  Icons.school_outlined,
                                  'My Schools',
                                  AppColors.infoBlue,
                                  const MyShopsPage(),
                                ),
                                _buildDashboardCard(
                                  context,
                                  Icons.directions_car_outlined,
                                  'Route Plans',
                                  AppColors.primaryGreen,
                                  const AgentRoutePlanScreen(),
                                ),
                                _buildDashboardCard(
                                  context,
                                  Icons.assignment_turned_in_outlined,
                                  'School Visits',
                                  AppColors.infoBlue,
                                  const AgentSchoolVisitsScreen(),
                                ),
                                _buildDashboardCard(
                                  context,
                                  Icons.shopping_bag_outlined,
                                  'Submit Order',
                                  AppColors.accentOrange,
                                  const AgentSubmitOrderScreen(),
                                ),
                                _buildDashboardCard(
                                  context,
                                  Icons.menu_book_outlined,
                                  'Distribute Samples',
                                  AppColors.softGold,
                                  const AgentDistributeSamplesScreen(),
                                ),
                                _buildDashboardCard(
                                  context,
                                  Icons.insights,
                                  'Detailed Target',
                                  AppColors.primaryDark,
                                  const TargetPerformancePage(),
                                ),
                                _buildDashboardCard(
                                  context,
                                  Icons.map_outlined,
                                  'Visit Tracker Map',
                                  AppColors.primaryGreen,
                                  const VisitTrackerMapPage(),
                                ),
                                _buildDashboardCard(
                                  context,
                                  Icons.fact_check_outlined,
                                  'Team Attendance',
                                  AppColors.infoBlue,
                                  const TeamAttendancePage(),
                                ),
                                _buildDashboardCard(
                                  context,
                                  Icons.map_outlined,
                                  'Regions',
                                  AppColors.primaryGreen,
                                  const RegionsManagementPage(),
                                ),
                                _buildDashboardCard(
                                  context,
                                  Icons.school_outlined,
                                  'User Schools',
                                  AppColors.infoBlue,
                                  const UserSchoolOnboardingPage(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  // Sticky Side Navigation Bar Content
  Widget _buildSideMenuContent() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        UserAccountsDrawerHeader(
          decoration: const BoxDecoration(color: AppColors.primaryDark),
          accountName: Text(
            _supervisorName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          accountEmail: Text(_regionName),
          currentAccountPicture: const CircleAvatar(
            backgroundColor: AppColors.primaryGreen,
            child: Icon(Icons.person, color: Colors.white, size: 36),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.fingerprint, color: AppColors.primaryGreen),
          title: const Text('Daily Check-In'),
          onTap: () => _navigateTo(const DailyCheckInPage()),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.school_outlined, color: AppColors.infoBlue),
          title: const Text('My Schools'),
          onTap: () => _navigateTo(const MyShopsPage()),
        ),
        ListTile(
          leading: const Icon(
            Icons.directions_car_outlined,
            color: AppColors.primaryGreen,
          ),
          title: const Text('Route Plans'),
          onTap: () => _navigateTo(const AgentRoutePlanScreen()),
        ),
        ListTile(
          leading: const Icon(
            Icons.assignment_turned_in_outlined,
            color: AppColors.infoBlue,
          ),
          title: const Text('School Visits'),
          onTap: () => _navigateTo(const AgentSchoolVisitsScreen()),
        ),
        ListTile(
          leading: const Icon(
            Icons.shopping_bag_outlined,
            color: AppColors.accentOrange,
          ),
          title: const Text('Submit Order'),
          onTap: () => _navigateTo(const AgentSubmitOrderScreen()),
        ),
        ListTile(
          leading: const Icon(
            Icons.menu_book_outlined,
            color: AppColors.softGold,
          ),
          title: const Text('Distribute Samples'),
          onTap: () => _navigateTo(const AgentDistributeSamplesScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.insights, color: AppColors.primaryDark),
          title: const Text('Detailed Target'),
          onTap: () => _navigateTo(const TargetPerformancePage()),
        ),
        ListTile(
          leading: const Icon(
            Icons.map_outlined,
            color: AppColors.primaryGreen,
          ),
          title: const Text('Visit Tracker Map'),
          onTap: () => _navigateTo(const VisitTrackerMapPage()),
        ),
        ListTile(
          leading: const Icon(
            Icons.fact_check_outlined,
            color: AppColors.infoBlue,
          ),
          title: const Text('Team Attendance'),
          onTap: () => _navigateTo(const TeamAttendancePage()),
        ),
        ListTile(
          leading: const Icon(
            Icons.map_outlined,
            color: AppColors.primaryGreen,
          ),
          title: const Text('Regions'),
          onTap: () => _navigateTo(const RegionsManagementPage()),
        ),
        ListTile(
          leading: const Icon(Icons.school_outlined, color: AppColors.infoBlue),
          title: const Text('User Schools'),
          onTap: () => _navigateTo(const UserSchoolOnboardingPage()),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.event, color: AppColors.infoBlue),
          title: const Text('Events'),
          onTap: () => _navigateTo(const EventsListPage()),
        ),
      ],
    );
  }

  // Widget: Regional Metric Summary Card
  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // Widget: Personal Performance Overview
  Widget _buildPerformanceCard(double progressRatio) {
    final percentVal = (progressRatio * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Performance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$percentVal% Achieved',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progressRatio,
            backgroundColor: Colors.grey.shade200,
            color: AppColors.primaryGreen,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target: ${_monthlyTarget.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                'Visits Done: $_visitsCompleted',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget: Quick Actions Section
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                context,
                Icons.event,
                'Events',
                AppColors.infoBlue,
                const EventsListPage(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                context,
                Icons.add_business_outlined,
                'New Lead',
                AppColors.accentOrange,
                const MyShopsPage(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    Widget destination,
  ) {
    return Card(
      color: color.withValues(alpha: 0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: () => _navigateTo(destination),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }

  // Widget: Daily Check-In Button (top of dashboard)
  Widget _buildDailyCheckInButton(BuildContext context) {
    return Card(
      color: AppColors.primaryGreen,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateTo(const DailyCheckInPage()),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Check-In / Out',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tap to start or end your day',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    Widget destination,
  ) {
    return Card(
      color: AppColors.surfaceWhite,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateTo(destination),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

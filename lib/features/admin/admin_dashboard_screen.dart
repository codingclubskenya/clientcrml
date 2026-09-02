import 'regions_management_page.dart';
import 'targets_page.dart';
import 'target_performance_page.dart';
import 'ai_assistant_page.dart';
import 'package:flutter/material.dart';
import 'analytics_page.dart';
import 'import_schools_page.dart';
import 'assign_books_page.dart';
import '../dashboard/my_shops_page.dart';
import 'admin_geofence_map_screen.dart';
import 'admin_agent_tracker_screen.dart';
import 'admin_pipeline_data_page.dart';
import 'admin_social_pipeline_page.dart';
import 'sample_receipts_page.dart';
import 'project_form_builder_page.dart';
import 'role3_supervision_dashboard_page.dart';
import 'role2_route_plan_page.dart';
import 'role2_schools_outreach_page.dart';
import 'role2_manager_dashboard_page.dart';
import '../dashboard/agrovet_onboarding.dart';
import '../profile/messages_page.dart';
import '../events/events_list_page.dart';
import '../catalog/product_list_screen.dart';
import '../consignments/consignment_list_screen.dart';
import '../welcome/auth/login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/agent_dashboard_page.dart';
import '../../../features/profile/profile_page.dart';
import '../../../core/constants/bas_dashboard_page.dart';
import '../database/database_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService();
  int _totalTasks = 0;
  int _totalGeofences = 0;
  int _totalSchools = 0;

  @override
  void initState() {
    super.initState();
    _enforceRoleAndLoad();
  }

  Future<void> _enforceRoleAndLoad() async {
    final role = await _dbService.getCurrentUserRole();
    // Roles 1-4 are admin; redirect only when field agent (5)
    if (role == 5 && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AgentDashboardPage()),
        (route) => false,
      );
      return;
    }
    _refreshData();
  }

  Future<void> _refreshData() async {
    try {
      final taskCount = await _supabase.from('tasks').count(CountOption.exact);
      final geofenceCount = await _supabase
          .from('geofences')
          .count(CountOption.exact);
      final schoolCount = await _supabase
          .from('schools')
          .count(CountOption.exact);
      if (mounted) {
        setState(() {
          _totalTasks = taskCount;
          _totalGeofences = geofenceCount;
          _totalSchools = schoolCount;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard counts: $e');
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DeHeusLogin()),
        (route) => false,
      );
    }
  }

  void _closeDrawerIfOpen() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar:
          isDesktop
              ? null
              : AppBar(
                title: const Text('Sales Manager Dashboard'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refreshData,
                    tooltip: 'Refresh Data',
                  ),
                  IconButton(
                    icon: const Icon(Icons.event),
                    onPressed: () => Navigator.pushNamed(context, '/events'),
                    tooltip: 'Events',
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: _signOut,
                    tooltip: 'Sign Out',
                  ),
                ],
              ),
      drawer: isDesktop ? null : _buildMobileDrawer(),
      body: Row(
        children: [
          if (isDesktop) ...[
            _buildSideNav(),
            const VerticalDivider(thickness: 1, width: 1),
          ],
          Expanded(
            child:
                isDesktop
                    ? Scaffold(
                      appBar: AppBar(
                        title: const Text('Sales Manager Dashboard'),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _refreshData,
                            tooltip: 'Refresh Data',
                          ),
                          IconButton(
                            icon: const Icon(Icons.event),
                            onPressed:
                                () => Navigator.pushNamed(context, '/events'),
                            tooltip: 'Events',
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout),
                            onPressed: _signOut,
                            tooltip: 'Sign Out',
                          ),
                        ],
                      ),
                      body: _buildDashboardContent(),
                    )
                    : _buildDashboardContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.manage_accounts,
                  size: 48,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 16),
                const Text(
                  'Sales Manager',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildNavItem(Icons.dashboard, 'Dashboard', () {}),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Team',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildNavItem(Icons.manage_accounts, 'Manage Regions', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegionsManagementPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.track_changes, 'Targets', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TargetsPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.insights, 'Performance', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TargetPerformancePage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.smart_toy, 'AI Assistant', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AiAssistantPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.person_pin_circle, 'Agent Tracker', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminAgentTrackerScreen(),
                    ),
                  );
                }),
                _buildNavItem(Icons.chat_bubble_outline, 'Messages', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MessagesPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.event, 'Events', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EventsListPage(),
                    ),
                  );
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Catalog',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildNavItem(Icons.inventory_2_outlined, 'Product Catalog', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductListScreen(),
                    ),
                  );
                }),
                _buildNavItem(Icons.local_shipping_outlined, 'Stock Assignments', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ConsignmentListScreen(),
                    ),
                  );
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Schools',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildNavItem(Icons.school_outlined, 'My Schools (100km)', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyShopsPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.ads_click_rounded, 'Full Onboarding', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SchoolOnboarding(),
                    ),
                  );
                }),
                _buildNavItem(Icons.upload_file, 'Import Schools CSV', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ImportSchoolsPage(),
                    ),
                  );
                }),
                _buildNavItem(
                  Icons.local_shipping_outlined,
                  'Assign Books',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AssignBooksPage(),
                      ),
                    );
                  },
                ),
                _buildNavItem(Icons.map, 'Assign Geofence', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminGeofenceMapScreen(),
                    ),
                  );
                }),
                _buildNavItem(Icons.campaign_outlined, 'Schools Outreach', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Role2SchoolsOutreachPage(),
                    ),
                  );
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Planning',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildNavItem(Icons.assignment_outlined, 'Project Forms', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProjectFormBuilderPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.route, 'Route Plans', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Role2RoutePlanPage(),
                    ),
                  );
                }),
                _buildNavItem(
                  Icons.supervisor_account_outlined,
                  'Role 3 Command',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => const Role3SupervisionDashboardPage(),
                      ),
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Insights',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildNavItem(Icons.analytics_outlined, 'Analytics', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnalyticsPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.dashboard, 'Manager Dashboard', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Role2ManagerDashboardPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.account_tree_outlined, 'Pipeline Data', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminPipelineDataPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.campaign_outlined, 'FB & WhatsApp', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminSocialPipelinePage(),
                    ),
                  );
                }),
                _buildNavItem(
                  Icons.receipt_long_outlined,
                  'Sample Receipts',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SampleReceiptsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: _signOut,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSideNav() {
    return Container(
      width: 250,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Icon(
                  Icons.manage_accounts,
                  color: Theme.of(context).primaryColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Sales Manager',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(Icons.dashboard, 'Dashboard', () {}),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Team',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildNavItem(Icons.manage_accounts, 'Manage Regions', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegionsManagementPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.track_changes, 'Targets', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TargetsPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.insights, 'Performance', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TargetPerformancePage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.smart_toy, 'AI Assistant', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AiAssistantPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.person_pin_circle, 'Agent Tracker', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminAgentTrackerScreen(),
                    ),
                  );
                }),
                _buildNavItem(Icons.chat_bubble_outline, 'Messages', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MessagesPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.event, 'Events', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EventsListPage(),
                    ),
                  );
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Catalog',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildNavItem(Icons.inventory_2_outlined, 'Product Catalog', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductListScreen(),
                    ),
                  );
                }),
                _buildNavItem(Icons.local_shipping_outlined, 'Stock Assignments', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ConsignmentListScreen(),
                    ),
                  );
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Schools',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildNavItem(Icons.school_outlined, 'My Schools (100km)', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyShopsPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.ads_click_rounded, 'Full Onboarding', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SchoolOnboarding(),
                    ),
                  );
                }),
                _buildNavItem(Icons.upload_file, 'Import Schools CSV', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ImportSchoolsPage(),
                    ),
                  );
                }),
                _buildNavItem(
                  Icons.local_shipping_outlined,
                  'Assign Books',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AssignBooksPage(),
                      ),
                    );
                  },
                ),
                _buildNavItem(Icons.map, 'Assign Geofence', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminGeofenceMapScreen(),
                    ),
                  );
                }),
                _buildNavItem(Icons.campaign_outlined, 'Schools Outreach', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Role2SchoolsOutreachPage(),
                    ),
                  );
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Planning',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildNavItem(Icons.assignment_outlined, 'Project Forms', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProjectFormBuilderPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.route, 'Route Plans', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Role2RoutePlanPage(),
                    ),
                  );
                }),
                _buildNavItem(
                  Icons.supervisor_account_outlined,
                  'Role 3 Command',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => const Role3SupervisionDashboardPage(),
                      ),
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Insights',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildNavItem(Icons.analytics_outlined, 'Analytics', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnalyticsPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.dashboard, 'Manager Dashboard', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Role2ManagerDashboardPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.account_tree_outlined, 'Pipeline Data', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminPipelineDataPage(),
                    ),
                  );
                }),
                _buildNavItem(Icons.campaign_outlined, 'FB & WhatsApp', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminSocialPipelinePage(),
                    ),
                  );
                }),
                _buildNavItem(
                  Icons.receipt_long_outlined,
                  'Sample Receipts',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SampleReceiptsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: _signOut,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      selected: false,
      selectedTileColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      onTap: () {
        _closeDrawerIfOpen();
        onTap();
      },
    );
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            _buildStatsRow(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final email = _supabase.auth.currentUser?.email ?? 'Sales Manager';
    final name = email.split('@').first;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'S',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          'Welcome back, $name',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: const Text('Sales Manager'),
        trailing: Icon(
          Icons.waving_hand_rounded,
          color: Theme.of(context).primaryColor,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildStatCard(
              label: 'Total Tasks',
              value: _totalTasks.toString(),
              icon: Icons.assignment_turned_in_rounded,
              color: Theme.of(context).primaryColor,
            ),
            _buildStatCard(
              label: 'Active Geofences',
              value: _totalGeofences.toString(),
              icon: Icons.map_rounded,
              color: Colors.green,
            ),
            _buildStatCard(
              label: 'Schools',
              value: _totalSchools.toString(),
              icon: Icons.school_rounded,
              color: Colors.blue,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

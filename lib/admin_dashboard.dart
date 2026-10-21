import 'package:flutter/material.dart';
import 'features/admin/project_form_builder_page.dart';
import 'services/api_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _api = ApiService();
  late Future<Map<String, dynamic>> _dashboardDataFuture;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _fetchDashboardData();
  }

  Future<Map<String, dynamic>> _fetchDashboardData() async {
    final dashboard = await _api.getAdminDashboard();
    final rawCounts = Map<String, dynamic>.from(dashboard['counts'] as Map);
    final currentUserProfile = dashboard['currentUserProfile'] == null
        ? null
        : Map<String, dynamic>.from(dashboard['currentUserProfile'] as Map);

    return {
      'counts': {
        'Users': (rawCounts['users'] as num).toInt(),
        'Schools': (rawCounts['schools'] as num).toInt(),
        'Tasks': (rawCounts['tasks'] as num).toInt(),
        'Orders': (rawCounts['orders'] as num).toInt(),
        'Visits': (rawCounts['visits'] as num).toInt(),
        'Catalog Items': (rawCounts['catalog_items'] as num).toInt(),
      },
      'recentOrders': dashboard['recentOrders'],
      'currentUserProfile': currentUserProfile,
    };
  }

  Future<void> _refreshData() async {
    setState(() {
      _dashboardDataFuture = _fetchDashboardData();
    });
  }

  Future<void> _signOut() async {
    await _api.logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
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
                title: _buildAppBarTitle(),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refreshData,
                    tooltip: 'Refresh Data',
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
                        title: _buildAppBarTitle(),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _refreshData,
                            tooltip: 'Refresh Data',
                          ),
                        ],
                      ),
                      body: _buildSelectedContent(),
                    )
                    : _buildSelectedContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return const Text('Dashboard Overview');
      case 1:
        return const Text('Users Management');
      case 2:
        return const Text('Schools Management');
      case 3:
        return const Text('Orders Management');
      case 4:
        return const Text('Project Forms');
      default:
        return const Text('Admin Panel');
    }
  }

  Widget _buildSelectedContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return const Center(child: Text('Users Management - Coming Soon'));
      case 2:
        return const Center(child: Text('Schools Management - Coming Soon'));
      case 3:
        return const Center(child: Text('Orders Management - Coming Soon'));
      case 4:
        return const ProjectFormBuilderPage();
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading dashboard: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final data = snapshot.data!;
          final counts = data['counts'] as Map<String, int>;
          final recentOrders = data['recentOrders'] as List<dynamic>;
          final userProfile =
              data['currentUserProfile'] as Map<String, dynamic>?;

          final adminName =
              userProfile?['full_name'] ??
              userProfile?['email'] ??
              'Super Admin';
          final region = userProfile?['region'] ?? 'All Regions';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.admin_panel_settings),
                    ),
                    title: Text(
                      'Welcome back, $adminName',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Super Admin • Region: $region'),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Overview',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatsGrid(counts),
                const SizedBox(height: 32),
                Text(
                  'Recent Orders',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRecentOrdersTable(recentOrders),
              ],
            ),
          );
        },
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
                  Icons.admin_panel_settings,
                  color: Theme.of(context).primaryColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Admin Panel',
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
                _buildNavItem(Icons.dashboard, 'Dashboard', 0),
                _buildNavItem(Icons.people, 'Users', 1),
                _buildNavItem(Icons.school, 'Schools', 2),
                _buildNavItem(Icons.shopping_cart, 'Orders', 3),
                _buildNavItem(Icons.assignment_outlined, 'Project', 4),
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
                  Icons.admin_panel_settings,
                  size: 48,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 16),
                const Text(
                  'Admin Panel',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildNavItem(Icons.dashboard, 'Dashboard', 0, isMobile: true),
                _buildNavItem(Icons.people, 'Users', 1, isMobile: true),
                _buildNavItem(Icons.school, 'Schools', 2, isMobile: true),
                _buildNavItem(Icons.shopping_cart, 'Orders', 3, isMobile: true),
                _buildNavItem(
                  Icons.assignment_outlined,
                  'Project',
                  4,
                  isMobile: true,
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

  Widget _buildNavItem(
    IconData icon,
    String title,
    int index, {
    bool isMobile = false,
  }) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).primaryColor : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      onTap: () {
        setState(() => _selectedIndex = index);
        if (isMobile) {
          Navigator.pop(context); // Close drawer
        }
      },
    );
  }

  Widget _buildStatsGrid(Map<String, int> counts) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: counts.length,
      itemBuilder: (context, index) {
        final key = counts.keys.elementAt(index);
        final value = counts[key];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value.toString(),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  key,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentOrdersTable(List<dynamic> orders) {
    if (orders.isEmpty) {
      return const Text('No recent orders available.');
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Order #')),
            DataColumn(label: Text('School')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Amount')),
          ],
          rows:
              orders.map((order) {
                return DataRow(
                  cells: [
                    DataCell(Text(order['order_number'].toString())),
                    DataCell(Text(order['school_name'].toString())),
                    DataCell(Text(order['status'].toString().toUpperCase())),
                    DataCell(Text('\$${order['checkout_amount'].toString()}')),
                  ],
                );
              }).toList(),
        ),
      ),
    );
  }
}

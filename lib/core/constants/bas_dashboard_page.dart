import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/bas_screens.dart';
import '../../core/constants/colors.dart';
import '../../features/admin/users_list_page.dart';
import '../../features/admin/role3_supervision_dashboard_page.dart';
import '../../features/profile/bas_alerts_page.dart';
import '../../features/dashboard/my_shops_page.dart';
import '../../features/admin/target_performance_page.dart';
import '../../features/events/events_list_page.dart';
import '../../features/consignments/consignment_list_screen.dart';

class BasDashboardPage extends StatelessWidget {
  const BasDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final displayName = currentUser?.userMetadata?['full_name']?.toString() ??
        currentUser?.userMetadata?['name']?.toString() ??
        currentUser?.email?.split('@').first ??
        'BAS User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('BAS Dashboard'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome, BAS User!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage your regional overview and approvals below.',
              style: TextStyle(fontSize: 16, color: AppColors.textMuted),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildDashboardCard(
                    context,
                    Icons.inventory_2_outlined,
                    'My Consignments',
                    AppColors.primaryGreen,
                    ConsignmentListScreen(
                      businessAssociateId: currentUser?.id,
                      businessAssociateName: displayName,
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    Icons.school_outlined,
                    'My Schools (100km)',
                    AppColors.primaryGreen,
                    const MyShopsPage(),
                  ),
                  _buildDashboardCard(
                    context,
                    Icons.map_outlined,
                    'Regional Coverage',
                    AppColors.infoBlue,
                    const BasRegionalCoverageScreen(),
                  ),
                  _buildDashboardCard(
                    context,
                    Icons.analytics_outlined,
                    'Sales Reports',
                    AppColors.primaryGreen,
                    const BasSalesReportsScreen(),
                  ),
                  _buildDashboardCard(
                    context,
                    Icons.approval_outlined,
                    'Approve Orders',
                    AppColors.accentOrange,
                    const BasApproveOrdersScreen(),
                  ),
                  _buildDashboardCard(
                    context,
                    Icons.group_outlined,
                    'Team Overview',
                    AppColors.softGold,
                    const UsersListPage(),
                  ),
                  _buildDashboardCard(
                    context,
                    Icons.supervisor_account_outlined,
                    'Role 3 Command Center',
                    AppColors.primaryDark,
                    const Role3SupervisionDashboardPage(),
                  ),
                  _buildDashboardCard(
                    context,
                    Icons.assignment_turned_in_outlined,
                    'Assigned Tasks & Geofences',
                    AppColors.infoBlue,
                    const BasAlertsPage(),
                  ),
                  _buildDashboardCard(
                    context,
                    Icons.insights,
                    'Performance',
                    AppColors.primaryDark,
                    const TargetPerformancePage(),
                  ),
                  _buildDashboardCard(
                    context,
                    Icons.event,
                    'Events',
                    AppColors.infoBlue,
                    const EventsListPage(),
                  ),
                ],
              ),
            ),
          ],
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
      elevation: 2,
      clipBehavior:
          Clip.antiAlias, // Ensures the ripple effect doesn't break rounded corners
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'admin_assign_task_screen.dart';
import 'admin_create_route_screen.dart';
import 'admin_geofence_map_screen.dart';
import 'admin_agent_tracker_screen.dart';
import '../welcome/auth/login_page.dart';
import '../../services/api_service.dart';

class SuperadminDashboardScreen extends StatefulWidget {
  const SuperadminDashboardScreen({super.key});

  @override
  State<SuperadminDashboardScreen> createState() =>
      _SuperadminDashboardScreenState();
}

class _SuperadminDashboardScreenState extends State<SuperadminDashboardScreen> {
  int _totalTasks = 0;
  int _totalGeofences = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final counts = await Future.wait([
        _countRows('tasks'),
        _countRows('geofences'),
      ]);
      if (mounted) {
        setState(() {
          _totalTasks = counts[0];
          _totalGeofences = counts[1];
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard counts: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<int> _countRows(String table) async {
    var count = 0;
    var offset = 0;
    while (true) {
      final page = await ApiService().getAll(table, limit: 500, offset: offset);
      count += page.length;
      if (page.length < 500) return count;
      offset += page.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Superadmin Dashboard'),
        backgroundColor: Colors.deepPurple, // Distinct color for superadmin
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiService().logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const DeHeusLogin()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminAssignTaskScreen(),
            ),
          );
          _refreshData();
        },
        icon: const Icon(Icons.add_task),
        label: const Text('Add Task'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Dashboard Statistics Cards
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Assigned Tasks',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : Text(
                                '$_totalTasks',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    color: Colors.green.withValues(alpha: 0.1),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Active Geofences',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : Text(
                                '$_totalGeofences',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // You can add Superadmin-exclusive functions here later, such as User/Role Management.
            _buildDashboardCard(
              context: context,
              icon: Icons.route,
              title: 'Create Route Plan',
              subtitle: 'Assign a sequence of schools to a user for a date.',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminCreateRouteScreen(),
                  ),
                );
                _refreshData();
              },
            ),
            const SizedBox(height: 16),
            _buildDashboardCard(
              context: context,
              icon: Icons.map,
              title: 'Assign Geofence',
              subtitle: 'Define a map area and tag a user to cover it.',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminGeofenceMapScreen(),
                  ),
                );
                _refreshData();
              },
            ),
            const SizedBox(height: 16),
            _buildDashboardCard(
              context: context,
              icon: Icons.person_pin_circle,
              title: 'Agent Tracker',
              subtitle:
                  'Check assigned route plans and geofences for an agent.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminAgentTrackerScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
          child: Icon(icon, color: Colors.deepPurple),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

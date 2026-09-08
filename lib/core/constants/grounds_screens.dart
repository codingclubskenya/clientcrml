import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'colors.dart';

// Include all pages from dashboard for grounds operations here:
// import '../../features/dashboard/your_other_page.dart';

class GroundsRoutePlanScreen extends StatefulWidget {
  const GroundsRoutePlanScreen({super.key});

  @override
  State<GroundsRoutePlanScreen> createState() => _GroundsRoutePlanScreenState();
}

class _GroundsRoutePlanScreenState extends State<GroundsRoutePlanScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _routePlans = [];

  @override
  void initState() {
    super.initState();
    _fetchRoutePlans();
  }

  Future<void> _fetchRoutePlans() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('route_plans')
          .select()
          .eq('assigned_to', userId)
          .order('route_date', ascending: true);

      setState(() {
        _routePlans = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading route plans: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grounds Route Plan'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _routePlans.isEmpty
              ? const Center(child: Text('No route plans assigned to you.'))
              : ListView.builder(
                itemCount: _routePlans.length,
                itemBuilder: (context, index) {
                  final plan = _routePlans[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: AppColors.surfaceWhite,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryPale,
                        child: Icon(
                          Icons.local_shipping_outlined,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      title: Text(
                        plan['title'] ?? 'Route Plan',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Date: ${plan['route_date']} \nStatus: ${plan['status']} \nNotes: ${plan['notes'] ?? 'None'}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
    );
  }
}

class GroundsSchoolVisitsScreen extends StatefulWidget {
  const GroundsSchoolVisitsScreen({super.key});

  @override
  State<GroundsSchoolVisitsScreen> createState() =>
      _GroundsSchoolVisitsScreenState();
}

class _GroundsSchoolVisitsScreenState extends State<GroundsSchoolVisitsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _visits = [];

  @override
  void initState() {
    super.initState();
    _fetchVisits();
  }

  Future<void> _fetchVisits() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('school_visits')
          .select('*, schools(name)')
          .eq('agent_id', userId)
          .order('visited_at', ascending: false);

      setState(() {
        _visits = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading visits: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Safety & Checks'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _visits.isEmpty
              ? const Center(child: Text('No checks recorded.'))
              : ListView.builder(
                itemCount: _visits.length,
                itemBuilder: (context, index) {
                  final visit = _visits[index];
                  final schoolName =
                      visit['schools']?['name'] ?? 'Unknown School';
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: AppColors.surfaceWhite,
                    child: ListTile(
                      leading: const Icon(
                        Icons.security_outlined,
                        color: AppColors.infoBlue,
                        size: 36,
                      ),
                      title: Text(
                        schoolName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Outcome: ${visit['outcome'] ?? 'N/A'}\nNotes: ${visit['notes'] ?? ''}',
                      ),
                      trailing: Text(
                        visit['visit_status']?.toString().toUpperCase() ?? '',
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
    );
  }
}

class GroundsDeliveriesScreen extends StatefulWidget {
  const GroundsDeliveriesScreen({super.key});

  @override
  State<GroundsDeliveriesScreen> createState() =>
      _GroundsDeliveriesScreenState();
}

class _GroundsDeliveriesScreenState extends State<GroundsDeliveriesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _deliveries = [];

  @override
  void initState() {
    super.initState();
    _fetchDeliveries();
  }

  Future<void> _fetchDeliveries() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Grounds typically distribute 'Operations' materials like 'Delivery Check Sheets'
      final response = await Supabase.instance.client
          .from('school_sample_distributions')
          .select('*, schools(name)')
          .eq('agent_id', userId)
          .order('distributed_at', ascending: false);

      setState(() {
        _deliveries = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading deliveries: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Check Sheets'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _deliveries.isEmpty
              ? const Center(child: Text('No delivery checks recorded.'))
              : ListView.builder(
                itemCount: _deliveries.length,
                itemBuilder: (context, index) {
                  final delivery = _deliveries[index];
                  final schoolName =
                      delivery['schools']?['name'] ?? 'Unknown School';
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: AppColors.surfaceWhite,
                    child: ListTile(
                      leading: const Icon(
                        Icons.fact_check_outlined,
                        color: AppColors.softGold,
                        size: 36,
                      ),
                      title: Text(
                        delivery['sample_name'] ?? 'Delivery Note',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'School: $schoolName\nQty: ${delivery['quantity']}\nNotes: ${delivery['notes']}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
    );
  }
}

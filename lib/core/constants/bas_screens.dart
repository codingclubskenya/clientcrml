import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'colors.dart';

// --- REGIONAL COVERAGE SCREEN ---
class BasRegionalCoverageScreen extends StatefulWidget {
  const BasRegionalCoverageScreen({super.key});

  @override
  State<BasRegionalCoverageScreen> createState() =>
      _BasRegionalCoverageScreenState();
}

class _BasRegionalCoverageScreenState extends State<BasRegionalCoverageScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _schools = [];

  @override
  void initState() {
    super.initState();
    _fetchSchools();
  }

  Future<void> _fetchSchools() async {
    try {
      // Fetch schools to show regional footprint
      final response = await ApiService().getAll(
        'schools', orderBy: 'created_at', orderDir: 'DESC', limit: 500,
      );

      if (mounted) {
        setState(() {
          _schools = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading coverage: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regional Coverage'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _schools.isEmpty
              ? const Center(child: Text('No regional school data found.'))
              : ListView.builder(
                itemCount: _schools.length,
                itemBuilder: (context, index) {
                  final school = _schools[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryPale,
                      child: Icon(Icons.school, color: AppColors.infoBlue),
                    ),
                    title: Text(
                      school['name'] ?? 'Unknown School',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'County: ${school['county'] ?? 'Unassigned'}',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () {},
                  );
                },
              ),
    );
  }
}

// --- SALES REPORTS SCREEN ---
class BasSalesReportsScreen extends StatelessWidget {
  const BasSalesReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildReportCard(
            'Monthly Revenue',
            'KES 245,500',
            Icons.trending_up,
            AppColors.primaryGreen,
          ),
          _buildReportCard(
            'Orders Processed',
            '42',
            Icons.inventory_2_outlined,
            AppColors.infoBlue,
          ),
          _buildReportCard(
            'Pending Approvals',
            '8',
            Icons.pending_actions,
            AppColors.accentOrange,
          ),
          _buildReportCard(
            'Active Regions',
            '12',
            Icons.map_outlined,
            AppColors.softGold,
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      color: AppColors.surfaceWhite,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// --- APPROVE ORDERS SCREEN ---
class BasApproveOrdersScreen extends StatefulWidget {
  const BasApproveOrdersScreen({super.key});

  @override
  State<BasApproveOrdersScreen> createState() => _BasApproveOrdersScreenState();
}

class _BasApproveOrdersScreenState extends State<BasApproveOrdersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingOrders = [];

  @override
  void initState() {
    super.initState();
    _fetchPendingOrders();
  }

  Future<void> _fetchPendingOrders() async {
    try {
      // Try to fetch orders where status is pending
      final response = await ApiService().getAll(
        'orders', filter: {'status': 'pending'},
        orderBy: 'created_at', orderDir: 'DESC', limit: 500,
      );

      if (mounted) {
        setState(() {
          _pendingOrders = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending orders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approve Orders'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _pendingOrders.isEmpty
              ? const Center(
                child: Text('No pending orders currently require approval.'),
              )
              : ListView.builder(
                itemCount: _pendingOrders.length,
                itemBuilder: (context, index) {
                  final order = _pendingOrders[index];
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
                          Icons.receipt_long,
                          color: AppColors.accentOrange,
                        ),
                      ),
                      title: Text(
                        'Order #${order['order_number'] ?? order['id']}',
                      ),
                      subtitle: Text('Status: ${order['status']}'),
                      trailing: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Order approved!')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Approve'),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

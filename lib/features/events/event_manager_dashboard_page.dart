import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/colors.dart';
import '../database/database_service.dart';
import 'event_date_format.dart';

class EventManagerDashboardPage extends StatefulWidget {
  const EventManagerDashboardPage({super.key});

  @override
  State<EventManagerDashboardPage> createState() =>
      _EventManagerDashboardPageState();
}

class _EventManagerDashboardPageState extends State<EventManagerDashboardPage> {
  final DatabaseService _dbService = DatabaseService();
  final _supabase = Supabase.instance.client;

  Map<String, dynamic> _dashboardData = {};
  List<Map<String, dynamic>> _topEvents = [];
  List<Map<String, dynamic>> _regionPerformance = [];
  bool _loading = true;
  String? _selectedRegion;
  String _timeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      DateTime? startDate;
      if (_timeFilter == 'week') {
        startDate = now.subtract(const Duration(days: 7));
      } else if (_timeFilter == 'month') {
        startDate = DateTime(now.year, now.month, 1);
      } else if (_timeFilter == 'quarter') {
        startDate = DateTime(now.year, now.month - 3, 1);
      } else if (_timeFilter == 'year') {
        startDate = DateTime(now.year, 1, 1);
      }

      final dashboard = await _dbService.getEventsDashboard(
        region: _selectedRegion,
        startDate: startDate,
        endDate: now,
      );

      final topEvents = await _dbService.getTopPerformingEvents();

      final regionPerf = await _loadRegionPerformance();

      setState(() {
        _dashboardData = dashboard;
        _topEvents = topEvents;
        _regionPerformance = regionPerf;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load dashboard: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadRegionPerformance() async {
    try {
      final events = List<Map<String, dynamic>>.from(
        _dashboardData['events'] ?? [],
      );
      final regionMap = <String, Map<String, dynamic>>{};

      for (final event in events) {
        final region = event['region']?.toString() ?? 'Unknown';
        if (!regionMap.containsKey(region)) {
          regionMap[region] = {
            'region': region,
            'total_events': 0,
            'active_events': 0,
            'total_budget': 0.0,
            'total_expenses': 0.0,
            'total_leads': 0,
            'total_orders': 0,
          };
        }
        regionMap[region]!['total_events'] =
            (regionMap[region]!['total_events'] as int) + 1;
        if (event['status'] == 'active' || event['status'] == 'in_progress') {
          regionMap[region]!['active_events'] =
              (regionMap[region]!['active_events'] as int) + 1;
        }
        final budget = event['budget'];
        if (budget is num) {
          regionMap[region]!['total_budget'] =
              (regionMap[region]!['total_budget'] as double) +
              budget.toDouble();
        }

        final eventId = event['id']?.toString();
        if (eventId != null) {
          final summary = await _dbService.getEventSummary(eventId);
          regionMap[region]!['total_leads'] =
              (regionMap[region]!['total_leads'] as int) +
              ((summary['leads'] as int?) ?? 0);
          regionMap[region]!['total_orders'] =
              (regionMap[region]!['total_orders'] as int) +
              ((summary['orders'] as int?) ?? 0);
          regionMap[region]!['total_expenses'] =
              (regionMap[region]!['total_expenses'] as double) +
              ((summary['expenses'] as double?) ?? 0);
        }
      }

      return regionMap.values.toList();
    } catch (e) {
      debugPrint('Error loading region performance: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<String>> _getRegions() async {
    try {
      final data = await _supabase
          .from('events')
          .select('region')
          .not('region', 'is', null);
      final regions =
          (data as List)
              .map((e) => e['region']?.toString() ?? '')
              .where((r) => r.isNotEmpty)
              .toSet()
              .toList();
      regions.sort();
      return regions;
    } catch (_) {
      return <String>[];
    }
  }

  void _openEventsList() {
    Navigator.pushNamed(context, '/events');
  }

  void _openEventCreate() {
    Navigator.pushNamed(context, '/events/create');
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Manager Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadDashboard,
                child: ListView(
                  padding: EdgeInsets.all(isNarrow ? 12 : 20),
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 16),
                    _buildFiltersRow(isNarrow),
                    const SizedBox(height: 16),
                    _buildMetricsGrid(isNarrow),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Events Overview'),
                    const SizedBox(height: 12),
                    _buildEventsOverview(isNarrow),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Performance by Region'),
                    const SizedBox(height: 12),
                    _buildRegionPerformanceTable(isNarrow),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Top Performing Events'),
                    const SizedBox(height: 12),
                    _buildTopEventsList(isNarrow),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Revenue & ROI'),
                    const SizedBox(height: 12),
                    _buildRevenueCard(isNarrow),
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEventCreate,
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen,
            AppColors.primaryGreen.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Event Performance Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track events, leads, sales, and ROI across all regions',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow(bool isNarrow) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        FutureBuilder<List<String>>(
          future: _getRegions(),
          builder: (context, snapshot) {
            final regions = snapshot.data ?? <String>[];
            return SizedBox(
              width: 180,
              child: DropdownButtonFormField<String?>(
                value: _selectedRegion,
                decoration: InputDecoration(
                  labelText: 'Region',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Regions'),
                  ),
                  ...regions.map(
                    (r) => DropdownMenuItem(value: r, child: Text(r)),
                  ),
                ],
                onChanged: (val) {
                  setState(() => _selectedRegion = val);
                  _loadDashboard();
                },
              ),
            );
          },
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            value: _timeFilter,
            decoration: InputDecoration(
              labelText: 'Time Period',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Time')),
              DropdownMenuItem(value: 'week', child: Text('Last 7 Days')),
              DropdownMenuItem(value: 'month', child: Text('This Month')),
              DropdownMenuItem(value: 'quarter', child: Text('This Quarter')),
              DropdownMenuItem(value: 'year', child: Text('This Year')),
            ],
            onChanged: (val) {
              setState(() => _timeFilter = val!);
              _loadDashboard();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(bool isNarrow) {
    final metrics = [
      _MetricData(
        label: 'Total Events',
        value: '${_dashboardData['total_events'] ?? 0}',
        icon: Icons.event,
        color: AppColors.primaryGreen,
      ),
      _MetricData(
        label: 'Active Events',
        value: '${_dashboardData['active_events'] ?? 0}',
        icon: Icons.play_circle,
        color: Colors.blue,
      ),
      _MetricData(
        label: 'Upcoming',
        value: '${_dashboardData['upcoming_events'] ?? 0}',
        icon: Icons.schedule,
        color: Colors.orange,
      ),
      _MetricData(
        label: 'Completed',
        value: '${_dashboardData['completed_events'] ?? 0}',
        icon: Icons.check_circle,
        color: Colors.green,
      ),
      _MetricData(
        label: 'Leads Captured',
        value: '${_dashboardData['total_leads'] ?? 0}',
        icon: Icons.people,
        color: Colors.purple,
      ),
      _MetricData(
        label: 'Orders',
        value: '${_dashboardData['total_orders'] ?? 0}',
        icon: Icons.shopping_cart,
        color: AppColors.accentOrange,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isNarrow ? 2 : 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final m = metrics[index];
        return _buildMetricCard(m);
      },
    );
  }

  Widget _buildMetricCard(_MetricData metric) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(metric.icon, color: metric.color, size: 24),
          const SizedBox(height: 8),
          Text(
            metric.value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: metric.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventsOverview(bool isNarrow) {
    final events = List<Map<String, dynamic>>.from(
      _dashboardData['events'] ?? [],
    );
    final activeEvents =
        events
            .where(
              (e) => e['status'] == 'active' || e['status'] == 'in_progress',
            )
            .toList();
    final upcomingEvents =
        events.where((e) => e['status'] == 'scheduled').toList();

    return Column(
      children: [
        if (activeEvents.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Active Events',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          ...activeEvents.take(3).map((e) => _buildEventTile(e)),
        ],
        if (upcomingEvents.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Upcoming Events',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          ...upcomingEvents.take(3).map((e) => _buildEventTile(e)),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openEventsList,
          icon: const Icon(Icons.list),
          label: const Text('View All Events'),
        ),
      ],
    );
  }

  Widget _buildEventTile(Map<String, dynamic> event) {
    final name = event['name']?.toString() ?? 'Untitled';
    final region = event['region']?.toString() ?? '';
    final startAt = EventDateFormat.formatShort(event['start_at']);
    final status = event['status']?.toString() ?? '';

    Color statusColor;
    switch (status) {
      case 'active':
      case 'in_progress':
        statusColor = Colors.green;
        break;
      case 'scheduled':
        statusColor = Colors.orange;
        break;
      case 'completed':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('$region • $startAt'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap:
            () => Navigator.pushNamed(
              context,
              '/events/detail',
              arguments: {'id': event['id']},
            ),
      ),
    );
  }

  Widget _buildRegionPerformanceTable(bool isNarrow) {
    if (_regionPerformance.isEmpty) {
      return _buildEmptyCard('No region data available');
    }

    if (isNarrow) {
      return Column(
        children: _regionPerformance.map((r) => _buildRegionCard(r)).toList(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Region')),
            DataColumn(label: Text('Events')),
            DataColumn(label: Text('Active')),
            DataColumn(label: Text('Leads')),
            DataColumn(label: Text('Orders')),
            DataColumn(label: Text('Budget')),
            DataColumn(label: Text('Expenses')),
          ],
          rows:
              _regionPerformance.map((r) {
                return DataRow(
                  cells: [
                    DataCell(Text(r['region']?.toString() ?? '')),
                    DataCell(Text('${r['total_events'] ?? 0}')),
                    DataCell(Text('${r['active_events'] ?? 0}')),
                    DataCell(Text('${r['total_leads'] ?? 0}')),
                    DataCell(Text('${r['total_orders'] ?? 0}')),
                    DataCell(
                      Text('KES ${_formatNumber(r['total_budget'] ?? 0)}'),
                    ),
                    DataCell(
                      Text('KES ${_formatNumber(r['total_expenses'] ?? 0)}'),
                    ),
                  ],
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildRegionCard(Map<String, dynamic> region) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              region['region']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniStat('Events', '${region['total_events'] ?? 0}'),
                _buildMiniStat('Active', '${region['active_events'] ?? 0}'),
                _buildMiniStat('Leads', '${region['total_leads'] ?? 0}'),
                _buildMiniStat('Orders', '${region['total_orders'] ?? 0}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildTopEventsList(bool isNarrow) {
    if (_topEvents.isEmpty) {
      return _buildEmptyCard('No events to display');
    }

    return Column(
      children:
          _topEvents.map((e) {
            final metrics = e['metrics'] as Map<String, dynamic>? ?? {};
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryGreen.withValues(
                    alpha: 0.1,
                  ),
                  child: const Icon(Icons.event, color: AppColors.primaryGreen),
                ),
                title: Text(
                  e['name']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text('${e['region'] ?? ''} • ${e['venue'] ?? ''}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${metrics['orders'] ?? 0} orders',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '${metrics['leads'] ?? 0} leads',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                onTap:
                    () => Navigator.pushNamed(
                      context,
                      '/events/detail',
                      arguments: {'id': e['id']},
                    ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildRevenueCard(bool isNarrow) {
    final totalRevenue =
        (_dashboardData['total_revenue'] as num?)?.toDouble() ?? 0;
    final totalBudget =
        (_dashboardData['total_budget'] as num?)?.toDouble() ?? 0;
    final totalExpenses =
        (_dashboardData['total_expenses'] as num?)?.toDouble() ?? 0;
    final roi = (_dashboardData['roi'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRevenueItem('Revenue', totalRevenue, Colors.green),
              _buildRevenueItem('Budget', totalBudget, Colors.blue),
              _buildRevenueItem('Expenses', totalExpenses, Colors.red),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                roi >= 0 ? Icons.trending_up : Icons.trending_down,
                color: roi >= 0 ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                'ROI: ${roi.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: roi >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          'KES ${_formatNumber(value)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.charcoalGrey,
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }

  String _formatNumber(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

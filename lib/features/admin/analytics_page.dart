import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final _supabase = Supabase.instance.client;
  static const Set<String> _activePipelineStages = {
    'lead',
    'contacted',
    'meeting_scheduled',
    'sample_issued',
    'quotation_sent',
    'decision_pending',
    'negotiation',
  };

  bool _isLoading = true;

  // Task metrics
  int _openTasks = 0;
  int _inProgressTasks = 0;
  int _closedTasks = 0;

  // Revenue metrics (Orders)
  double _approvedRevenue = 0;
  double _pendingRevenue = 0;

  // Sales metrics (School Sales)
  double _wonSales = 0;
  double _pipelineSales = 0;

  // Advanced Analytics
  Map<String, int> _funnelStages = {};
  List<_RepStat> _topRevenueReps = [];
  List<_RepStat> _topVisitReps = [];
  Map<String, int> _churnBuckets = {
    'Active (<30d)': 0,
    'At Risk (30-60d)': 0,
    'Churned (60-90d)': 0,
    'Inactive (>90d)': 0,
  };

  // Global metrics
  int _totalUsers = 0;
  int _totalSchools = 0;
  int _manualSchools = 0;
  int _googleSchools = 0;
  int _unattributedSchools = 0;
  List<FlSpot> _userGrowthSpots = [];
  double _maxUserCount = 0;
  List<_OnboarderStat> _topOnboarders = <_OnboarderStat>[];
  DateTime? _lastUpdatedAt;

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      // Fetch Tasks
      final tasks = await _supabase.from('tasks').select('status');
      int open = 0, inProgress = 0, closed = 0;
      for (var task in tasks) {
        if (task['status'] == 'open') open++;
        if (task['status'] == 'in_progress') inProgress++;
        if (task['status'] == 'closed') closed++;
      }

      // Fetch Orders for Revenue Analysis
      final orders = await _supabase
          .from('orders')
          .select('checkout_amount, status');
      double approved = 0, pending = 0;
      for (var order in orders) {
        final amount = (order['checkout_amount'] as num?)?.toDouble() ?? 0.0;
        if (order['status'] == 'approved' || order['status'] == 'paid') {
          approved += amount;
        } else {
          pending += amount;
        }
      }

      // Fetch School Sales for Pipeline Analysis
      final sales = await _supabase
          .from('school_sales')
          .select('expected_value, sale_status, agent_id');
      double wonSales = 0, pipelineSales = 0;
      Map<String, int> funnel = {
        'lead': 0,
        'contacted': 0,
        'meeting_scheduled': 0,
        'sample_issued': 0,
        'quotation_sent': 0,
        'decision_pending': 0,
        'negotiation': 0,
        'won': 0,
      };
      final revenueByRep = <String, double>{};

      for (var sale in sales) {
        final amount = (sale['expected_value'] as num?)?.toDouble() ?? 0.0;
        final stage = (sale['sale_status'] as String?)?.toLowerCase() ?? '';
        final agentId = (sale['agent_id'] as String?) ?? 'unassigned';

        if (funnel.containsKey(stage)) {
          funnel[stage] = funnel[stage]! + 1;
        }

        if (stage == 'won') {
          wonSales += amount;
          revenueByRep[agentId] = (revenueByRep[agentId] ?? 0) + amount;
        } else if (_activePipelineStages.contains(stage)) {
          pipelineSales += amount;
        }
      }

      // Fetch Visits for Leaderboard
      final visitsRes = await _supabase
          .from('school_visits')
          .select('agent_id, school_id, visited_at');
      final visitsByRep = <String, int>{};
      final lastVisitBySchool = <String, DateTime>{};

      for (var v in visitsRes) {
        final agentId = (v['agent_id'] as String?) ?? 'unassigned';
        visitsByRep[agentId] = (visitsByRep[agentId] ?? 0) + 1;
        final schoolId = (v['school_id'] as String?) ?? '';
        if (schoolId.isNotEmpty) {
          final visitedAt = DateTime.tryParse(
            v['visited_at']?.toString() ?? '',
          );
          if (visitedAt != null) {
            final existing = lastVisitBySchool[schoolId];
            if (existing == null || visitedAt.isAfter(existing)) {
              lastVisitBySchool[schoolId] = visitedAt;
            }
          }
        }
      }

      // Fetch Global counts and User Growth
      final usersRes = await _supabase
          .from('users')
          .select('id, full_name, email, created_at');
      final schoolsRes = await _supabase
          .from('schools')
          .select('id, source, captured_by');

      // Calculate User Growth
      int currentYear = DateTime.now().year;
      List<int> monthlyCounts = List.filled(12, 0);
      int cumulativePrevYears = 0;

      for (var u in usersRes) {
        if (u['created_at'] != null) {
          DateTime date = DateTime.parse(u['created_at']);
          if (date.year == currentYear) {
            monthlyCounts[date.month - 1]++;
          } else if (date.year < currentYear) {
            cumulativePrevYears++;
          }
        }
      }

      List<FlSpot> growthSpots = [];
      int cumulative = cumulativePrevYears;
      for (int i = 0; i < 12; i++) {
        cumulative += monthlyCounts[i];
        growthSpots.add(FlSpot(i.toDouble(), cumulative.toDouble()));
      }

      int manualSchools = 0;
      int googleSchools = 0;
      int unattributedSchools = 0;
      final userNameById = <String, String>{
        for (final user in usersRes)
          user['id'].toString():
              ((user['full_name'] as String?)?.trim().isNotEmpty ?? false)
                  ? user['full_name'].toString().trim()
                  : user['email'].toString(),
      };
      final onboardCountByUserId = <String, int>{};
      for (final school in schoolsRes) {
        final source =
            (school['source'] as String?)?.toLowerCase().trim() ?? 'manual';
        if (source == 'google') {
          googleSchools++;
        } else {
          manualSchools++;
        }

        final capturedBy = (school['captured_by'] as String?)?.trim();
        if (capturedBy == null || capturedBy.isEmpty) {
          unattributedSchools++;
        } else {
          onboardCountByUserId[capturedBy] =
              (onboardCountByUserId[capturedBy] ?? 0) + 1;
        }
      }
      final topOnboarders =
          onboardCountByUserId.entries
              .map(
                (entry) => _OnboarderStat(
                  userId: entry.key,
                  displayName: userNameById[entry.key] ?? entry.key,
                  count: entry.value,
                ),
              )
              .toList()
            ..sort((a, b) => b.count.compareTo(a.count));

      final topRevenueReps =
          revenueByRep.entries
              .map(
                (e) => _RepStat(
                  name: userNameById[e.key] ?? e.key,
                  value: e.value,
                ),
              )
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      final topVisitReps =
          visitsByRep.entries
              .map(
                (e) => _RepStat(
                  name: userNameById[e.key] ?? e.key,
                  value: e.value.toDouble(),
                ),
              )
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      // Calculate Churn Buckets using actual last visit date instead of createdAt
      final now = DateTime.now();
      Map<String, int> churnBuckets = {
        'Active (<30d)': 0,
        'At Risk (30-60d)': 0,
        'Churned (60-90d)': 0,
        'Inactive (>90d)': 0,
      };
      for (var school in schoolsRes) {
        final lastVisit = lastVisitBySchool[school['id'].toString()];
        final activityDate =
            lastVisit ??
            DateTime.tryParse(school['created_at']?.toString() ?? '') ??
            now;
        final daysDiff = now.difference(activityDate).inDays;
        if (daysDiff < 30)
          churnBuckets['Active (<30d)'] = churnBuckets['Active (<30d)']! + 1;
        else if (daysDiff < 60)
          churnBuckets['At Risk (30-60d)'] =
              churnBuckets['At Risk (30-60d)']! + 1;
        else if (daysDiff < 90)
          churnBuckets['Churned (60-90d)'] =
              churnBuckets['Churned (60-90d)']! + 1;
        else
          churnBuckets['Inactive (>90d)'] =
              churnBuckets['Inactive (>90d)']! + 1;
      }

      if (mounted) {
        setState(() {
          _openTasks = open;
          _inProgressTasks = inProgress;
          _closedTasks = closed;
          _approvedRevenue = approved;
          _pendingRevenue = pending;
          _wonSales = wonSales;
          _pipelineSales = pipelineSales;
          _funnelStages = funnel;
          _topRevenueReps = topRevenueReps.take(5).toList();
          _topVisitReps = topVisitReps.take(5).toList();
          _churnBuckets = churnBuckets;
          _totalUsers = usersRes.length;
          _totalSchools = schoolsRes.length;
          _manualSchools = manualSchools;
          _googleSchools = googleSchools;
          _unattributedSchools = unattributedSchools;
          _userGrowthSpots = growthSpots;
          _maxUserCount = cumulative.toDouble();
          _topOnboarders = topOnboarders.take(5).toList();
          _lastUpdatedAt = DateTime.now();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching analytics: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load analytics: $e')));
      }
    }
  }

  Future<void> _exportAnalyticsPdf() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final pdf = pw.Document();
      final generatedAt = DateTime.now();

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.all(24),
          ),
          build: (context) {
            return [
              pw.Text(
                'Analytics Report',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: ${_formatDateTime(generatedAt)}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
              pw.SizedBox(height: 16),
              _buildAnalyticsPdfSummary(),
              pw.SizedBox(height: 16),
              _buildAnalyticsPdfLeaderboards(),
            ];
          },
        ),
      );

      final fileName =
          'analytics_report_${_formatDateTime(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF exported: $fileName')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export PDF: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  pw.Widget _buildAnalyticsPdfSummary() {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)},
      children: [
        _pdfRow('Total Users', '$_totalUsers'),
        _pdfRow('Total Schools', '$_totalSchools'),
        _pdfRow('Approved Revenue', 'KES $_approvedRevenue'),
        _pdfRow('Pipeline Sales', 'KES $_pipelineSales'),
        _pdfRow('Open Tasks', '$_openTasks'),
        _pdfRow('In Progress Tasks', '$_inProgressTasks'),
        _pdfRow('Closed Tasks', '$_closedTasks'),
        _pdfRow('Google Schools', '$_googleSchools'),
        _pdfRow('Manual Schools', '$_manualSchools'),
      ],
    );
  }

  pw.Widget _buildAnalyticsPdfLeaderboards() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Top Revenue Reps',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        ..._topRevenueReps
            .take(5)
            .map(
              (s) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text('${s.name}: KES ${s.value.toStringAsFixed(0)}'),
              ),
            ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Top Visit Reps',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        ..._topVisitReps
            .take(5)
            .map(
              (s) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text('${s.name}: ${s.value.toInt()} visits'),
              ),
            ),
      ],
    );
  }

  pw.TableRow _pdfRow(String label, String value) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, style: pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1000;
    final isTablet = width >= 700 && width < 1000;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            onPressed: _exportAnalyticsPdf,
            icon: const Icon(Icons.picture_as_pdf),
          ),
          IconButton(
            tooltip: 'Update Data',
            onPressed: _fetchAnalyticsData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _fetchAnalyticsData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_lastUpdatedAt != null)
                            Text(
                              'Last updated: ${_lastUpdatedAt!.year}-${_lastUpdatedAt!.month.toString().padLeft(2, '0')}-${_lastUpdatedAt!.day.toString().padLeft(2, '0')} ${_lastUpdatedAt!.hour.toString().padLeft(2, '0')}:${_lastUpdatedAt!.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 10),
                          _buildSummaryCards(width),
                          const SizedBox(height: 32),
                          if (isDesktop) ...[
                            _buildTwoChartRow(
                              titleA: 'User Growth (Current Year)',
                              chartA: _buildUserGrowthChart(),
                              titleB: 'Orders Revenue Overview',
                              chartB: _buildRevenueBarChart(),
                            ),
                            const SizedBox(height: 32),
                            _buildTwoChartRow(
                              titleA: 'Sales Pipeline Value',
                              chartA: _buildSalesPipelineChart(),
                              titleB: 'Task Status Breakdown',
                              chartB: _buildTaskPieChart(),
                            ),
                          ] else if (isTablet) ...[
                            _buildChartSection(
                              title: 'User Growth (Current Year)',
                              chart: _buildUserGrowthChart(),
                            ),
                            const SizedBox(height: 24),
                            _buildChartSection(
                              title: 'Orders Revenue Overview',
                              chart: _buildRevenueBarChart(),
                            ),
                            const SizedBox(height: 24),
                            _buildChartSection(
                              title: 'Sales Pipeline Value',
                              chart: _buildSalesPipelineChart(),
                            ),
                            const SizedBox(height: 24),
                            _buildChartSection(
                              title: 'Task Status Breakdown',
                              chart: _buildTaskPieChart(),
                            ),
                          ] else ...[
                            const Text(
                              'User Growth (Current Year)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildUserGrowthChart(),
                            const SizedBox(height: 32),
                            const Text(
                              'Orders Revenue Overview',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildRevenueBarChart(),
                            const SizedBox(height: 32),
                            const Text(
                              'Sales Pipeline Value',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildSalesPipelineChart(),
                            const SizedBox(height: 32),
                            const Text(
                              'Task Status Breakdown',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTaskPieChart(),
                          ],
                          const SizedBox(height: 32),
                          const Text(
                            'Advanced Sales Intelligence',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isDesktop) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildChartSection(
                                    title: 'Sales Funnel',
                                    chart: _buildFunnelChart(),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _buildChartSection(
                                    title: 'Churn Risk (30/60/90d)',
                                    chart: _buildChurnPieChart(),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            _buildChartSection(
                              title: 'Sales Funnel',
                              chart: _buildFunnelChart(),
                            ),
                            const SizedBox(height: 24),
                            _buildChartSection(
                              title: 'Churn Risk (30/60/90d)',
                              chart: _buildChurnPieChart(),
                            ),
                          ],
                          const SizedBox(height: 32),
                          const Text(
                            'Rep Performance Leaderboards',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildLeaderboardsRow(isDesktop),
                          const SizedBox(height: 32),
                          const Text(
                            'School Onboarding Insights',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildOnboardingInsightsCard(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildUserGrowthChart() {
    return AspectRatio(
      aspectRatio: 1.5,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine:
                    (value) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      const months = [
                        'Jan',
                        'Feb',
                        'Mar',
                        'Apr',
                        'May',
                        'Jun',
                        'Jul',
                        'Aug',
                        'Sep',
                        'Oct',
                        'Nov',
                        'Dec',
                      ];
                      // Display every other month to prevent crowding
                      if (value >= 0 && value < 12 && value.toInt() % 2 == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            months[value.toInt()],
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value == value.toInt()) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: 11,
              minY: 0,
              maxY:
                  _maxUserCount > 0
                      ? _maxUserCount + (_maxUserCount * 0.2)
                      : 10,
              lineBarsData: [
                LineChartBarData(
                  spots: _userGrowthSpots,
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blue.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueBarChart() {
    return AspectRatio(
      aspectRatio: 1.5,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      switch (value.toInt()) {
                        case 0:
                          return const Text('Approved/Paid');
                        case 1:
                          return const Text('Pending');
                        default:
                          return const Text('');
                      }
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: false,
                  ), // Hide Y-axis to save space
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                BarChartGroupData(
                  x: 0,
                  barRods: [
                    BarChartRodData(
                      toY: _approvedRevenue,
                      color: Colors.green,
                      width: 40,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 1,
                  barRods: [
                    BarChartRodData(
                      toY: _pendingRevenue,
                      color: Colors.orange,
                      width: 40,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSalesPipelineChart() {
    return AspectRatio(
      aspectRatio: 1.5,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      switch (value.toInt()) {
                        case 0:
                          return const Text('Won');
                        case 1:
                          return const Text('Pipeline');
                        default:
                          return const Text('');
                      }
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                BarChartGroupData(
                  x: 0,
                  barRods: [
                    BarChartRodData(
                      toY: _wonSales,
                      color: Colors.teal,
                      width: 40,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 1,
                  barRods: [
                    BarChartRodData(
                      toY: _pipelineSales,
                      color: Colors.purple,
                      width: 40,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskPieChart() {
    if (_openTasks == 0 && _inProgressTasks == 0 && _closedTasks == 0) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No tasks available')),
      );
    }

    return AspectRatio(
      aspectRatio: 1.5,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: [
              if (_openTasks > 0)
                PieChartSectionData(
                  color: Colors.blue,
                  value: _openTasks.toDouble(),
                  title: 'Open\n$_openTasks',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              if (_inProgressTasks > 0)
                PieChartSectionData(
                  color: Colors.amber,
                  value: _inProgressTasks.toDouble(),
                  title: 'In Prog\n$_inProgressTasks',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              if (_closedTasks > 0)
                PieChartSectionData(
                  color: Colors.green,
                  value: _closedTasks.toDouble(),
                  title: 'Closed\n$_closedTasks',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(double width) {
    final crossAxisCount =
        width >= 1200
            ? 6
            : width >= 900
            ? 3
            : 2;
    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio:
          width >= 1200
              ? 1.35
              : width >= 900
              ? 1.4
              : 1.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          'Total Users',
          '$_totalUsers',
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          'Total Schools',
          '$_totalSchools',
          Icons.school,
          Colors.orange,
        ),
        _buildStatCard(
          'Approved Orders',
          'KES ${_approvedRevenue.toStringAsFixed(0)}',
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Pipeline Sales',
          'KES ${_pipelineSales.toStringAsFixed(0)}',
          Icons.trending_up,
          Colors.purple,
        ),
        _buildStatCard(
          'Google Schools',
          '$_googleSchools',
          Icons.public,
          Colors.teal,
        ),
        _buildStatCard(
          'Manual Schools',
          '$_manualSchools',
          Icons.edit_location_alt,
          Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildTwoChartRow({
    required String titleA,
    required Widget chartA,
    required String titleB,
    required Widget chartB,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildChartSection(title: titleA, chart: chartA)),
        const SizedBox(width: 24),
        Expanded(child: _buildChartSection(title: titleB, chart: chartB)),
      ],
    );
  }

  Widget _buildChartSection({required String title, required Widget chart}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        chart,
      ],
    );
  }

  Widget _buildFunnelChart() {
    final stages = _funnelStages.entries.toList();
    if (stages.isEmpty) return const Center(child: Text('No pipeline data'));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children:
              stages.map((e) {
                final index = stages.indexOf(e);
                final widthFactor = 1.0 - (index * 0.1);
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  width: double.infinity,
                  height: 34,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      FractionallySizedBox(
                        widthFactor: widthFactor,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(
                              alpha: 0.1 + (index * 0.1),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Text(
                        '${e.key.toUpperCase()}: ${e.value}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildChurnPieChart() {
    final sections =
        _churnBuckets.entries.map((e) {
          final color = switch (e.key) {
            'Active (<30d)' => Colors.green,
            'At Risk (30-60d)' => Colors.orange,
            'Churned (60-90d)' => Colors.red,
            _ => Colors.grey,
          };
          return PieChartSectionData(
            color: color,
            value: e.value.toDouble(),
            title: '${e.value}',
            radius: 40,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList();

    return AspectRatio(
      aspectRatio: 1.5,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(
              child: PieChart(
                PieChartData(sections: sections, centerSpaceRadius: 30),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    _churnBuckets.keys
                        .map(
                          (k) => Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                color: _churnColor(k),
                              ),
                              const SizedBox(width: 4),
                              Text(k, style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _churnColor(String bucket) {
    return switch (bucket) {
      'Active (<30d)' => Colors.green,
      'At Risk (30-60d)' => Colors.orange,
      'Churned (60-90d)' => Colors.red,
      _ => Colors.grey,
    };
  }

  Widget _buildLeaderboardsRow(bool isDesktop) {
    if (isDesktop) {
      return Row(
        children: [
          Expanded(
            child: _buildLeaderboardCard(
              'Top Revenue Reps',
              _topRevenueReps,
              isCurrency: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildLeaderboardCard('Top Visit Reps', _topVisitReps),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildLeaderboardCard(
              'Top Onboarders',
              _topOnboarders
                  .map(
                    (e) => _RepStat(
                      name: e.displayName,
                      value: e.count.toDouble(),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        _buildLeaderboardCard(
          'Top Revenue Reps',
          _topRevenueReps,
          isCurrency: true,
        ),
        const SizedBox(height: 16),
        _buildLeaderboardCard('Top Visit Reps', _topVisitReps),
      ],
    );
  }

  Widget _buildLeaderboardCard(
    String title,
    List<_RepStat> stats, {
    bool isCurrency = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            if (stats.isEmpty)
              const Text('No data available', style: TextStyle(fontSize: 12)),
            ...stats.map(
              (s) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  isCurrency
                      ? 'KES ${s.value.toStringAsFixed(0)}'
                      : '${s.value.toInt()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingInsightsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _insightChip('Manual', _manualSchools, Colors.indigo),
                _insightChip('Google', _googleSchools, Colors.teal),
                _insightChip(
                  'No Onboarder',
                  _unattributedSchools,
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Top Onboarders',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_topOnboarders.isEmpty)
              const Text('No onboarded school attribution data yet.')
            else
              ..._topOnboarders.map(
                (entry) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text(
                      entry.displayName.isNotEmpty
                          ? entry.displayName[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${entry.count}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _insightChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 110;
          final iconSize = compact ? 26.0 : 36.0;
          final titleSize = compact ? 12.0 : 14.0;
          final valueSize = compact ? 16.0 : 20.0;
          final vGap = compact ? 6.0 : 12.0;

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: iconSize, color: color),
                SizedBox(height: vGap),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: titleSize, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: valueSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OnboarderStat {
  const _OnboarderStat({
    required this.userId,
    required this.displayName,
    required this.count,
  });

  final String userId;
  final String displayName;
  final int count;
}

class _RepStat {
  const _RepStat({required this.name, required this.value});
  final String name;
  final double value;
}

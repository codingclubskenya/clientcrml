import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

import '../../core/constants/colors.dart';

class RegionsPage extends StatefulWidget {
  const RegionsPage({super.key, this.isEmbedded = false});
  final bool isEmbedded;

  @override
  State<RegionsPage> createState() => _RegionsPageState();
}

class _RegionsPageState extends State<RegionsPage> {

  bool _isLoading = true;
  DateTime? _lastUpdatedAt;

  String _selectedPeriod = 'Week';
  String _selectedRegion = 'All Regions';

  List<String> _regions = const ['All Regions'];
  final Map<String, _RegionMetrics> _metricsByRegion = {};
  _RegionMetrics _department = _RegionMetrics('Department');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final now = DateTime.now();
    final currentPeriod = _buildCurrentPeriod(now);
    final previousPeriod = DateTimeRange(
      start: DateTime(
        currentPeriod.start.year - 1,
        currentPeriod.start.month,
        currentPeriod.start.day,
      ),
      end: DateTime(
        currentPeriod.end.year - 1,
        currentPeriod.end.month,
        currentPeriod.end.day,
        23,
        59,
        59,
        999,
      ),
    );
    final todayRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
    );
    final currentYear = now.year;
    final previousYear = now.year - 1;
    final yearLength =
        DateTime(
          now.year + 1,
          1,
          1,
        ).difference(DateTime(now.year, 1, 1)).inDays;
    final yearProgress = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
    final periodDays =
        currentPeriod.end.difference(currentPeriod.start).inDays + 1;
    final periodRatio = periodDays / yearLength;
    final ytdRatio = yearProgress / yearLength;
    final previousYearStartIso = DateTime(previousYear, 1, 1).toIso8601String();
    final nowIso = now.toIso8601String();

    final results = await Future.wait<List<Map<String, dynamic>>>([
      _fetchRows(() => ApiService().getAll('users', limit: 500), 'users'),
      _fetchRows(
        () => ApiService().getAll('schools', limit: 500),
        'schools',
      ),
      _fetchRows(
        () => ApiService().getAll('school_visits', filter: {
          'visited_at': {'gte': previousYearStartIso, 'lte': nowIso},
        }, limit: 500),
        'visits',
      ),
      _fetchRows(
        () => ApiService().getAll('school_sales', filter: {'sale_status': 'won'}, limit: 500),
        'sales',
      ),
      _fetchRows(
        () => ApiService().getAll('opportunity_activities', filter: {
          'created_at': {'gte': previousYearStartIso, 'lte': nowIso},
        }, limit: 500),
        'activities',
      ),
    ]);

    final users = results[0];
    final schools = results[1];
    final visits = results[2];
    final sales = results[3];
    final activities = results[4];

    final userRegionById = <String, String>{};
    for (final user in users) {
      final region = _normalizeRegion(user['region']);
      if (region != 'Unassigned') {
        userRegionById[user['id'].toString()] = region;
      }
    }

    final schoolById = <String, Map<String, dynamic>>{
      for (final school in schools) school['id'].toString(): school,
    };

    final metricsByRegion = <String, _RegionMetrics>{};
    _RegionMetrics bucketFor(String region) {
      return metricsByRegion.putIfAbsent(region, () => _RegionMetrics(region));
    }

    final department = _RegionMetrics('Department');

    for (final school in schools) {
      final region = _regionForSchool(school, userRegionById);
      final bucket = bucketFor(region);
      final isBookshop = _isBookshopOutlet(school);
      bucket.schoolBaseCount += 1;
      department.schoolBaseCount += 1;
      if (isBookshop) {
        bucket.bookshopBaseCount += 1;
        department.bookshopBaseCount += 1;
      }
    }

    for (final sale in sales) {
      final school = schoolById[sale['school_id']?.toString()];
      final region = _regionForSchool(school, userRegionById);
      final bucket = bucketFor(region);
      final amount = _toDouble(sale['expected_value']);
      final status = (sale['sale_status'] ?? '').toString().toLowerCase();
      final date = _pickSaleDate(sale);
      if (status != 'won') {
        continue;
      }

      bucket.recordSales(
        date,
        amount,
        currentPeriod,
        previousPeriod,
        currentYear,
        previousYear,
      );
      department.recordSales(
        date,
        amount,
        currentPeriod,
        previousPeriod,
        currentYear,
        previousYear,
      );
    }

    for (final visit in visits) {
      final school = schoolById[visit['school_id']?.toString()];
      final region = _regionForSchool(school, userRegionById);
      final bucket = bucketFor(region);
      final date = _parseDate(visit['visited_at']) ?? now;
      final schoolId = visit['school_id']?.toString();
      final isBookshop = school != null && _isBookshopOutlet(school);
      if (isBookshop) {
        bucket.recordBookshopVisit(
          date,
          currentPeriod,
          previousPeriod,
          todayRange,
          currentYear,
          previousYear,
          schoolId: schoolId,
        );
        department.recordBookshopVisit(
          date,
          currentPeriod,
          previousPeriod,
          todayRange,
          currentYear,
          previousYear,
          schoolId: schoolId,
        );
      } else {
        bucket.recordSchoolVisit(
          date,
          currentPeriod,
          previousPeriod,
          todayRange,
          currentYear,
          previousYear,
          schoolId: schoolId,
        );
        department.recordSchoolVisit(
          date,
          currentPeriod,
          previousPeriod,
          todayRange,
          currentYear,
          previousYear,
          schoolId: schoolId,
        );
      }
    }

    for (final activity in activities) {
      if (!_isCallActivity(activity)) {
        continue;
      }
      final school = schoolById[activity['school_id']?.toString()];
      final region = _regionForSchool(school, userRegionById);
      final bucket = bucketFor(region);
      final date = _parseDate(activity['created_at']) ?? now;
      final schoolId = activity['school_id']?.toString();
      final isBookshop = school != null && _isBookshopOutlet(school);
      if (isBookshop) {
        bucket.recordBookshopCall(
          date,
          currentPeriod,
          previousPeriod,
          todayRange,
          currentYear,
          previousYear,
          schoolId: schoolId,
        );
        department.recordBookshopCall(
          date,
          currentPeriod,
          previousPeriod,
          todayRange,
          currentYear,
          previousYear,
          schoolId: schoolId,
        );
      } else {
        bucket.recordSchoolCall(
          date,
          currentPeriod,
          previousPeriod,
          todayRange,
          currentYear,
          previousYear,
          schoolId: schoolId,
        );
        department.recordSchoolCall(
          date,
          currentPeriod,
          previousPeriod,
          todayRange,
          currentYear,
          previousYear,
          schoolId: schoolId,
        );
      }
    }

    for (final bucket in metricsByRegion.values) {
      bucket.computeTargets(
        yearLength: yearLength,
        periodRatio: periodRatio,
        ytdRatio: ytdRatio,
      );
    }
    department.computeTargets(
      yearLength: yearLength,
      periodRatio: periodRatio,
      ytdRatio: ytdRatio,
    );

    final sortedRegions = metricsByRegion.keys.toList()..sort();
    final orderedRegions = <String>['All Regions', ...sortedRegions];

    if (!mounted) return;
    setState(() {
      _metricsByRegion
        ..clear()
        ..addAll(metricsByRegion);
      _department = department;
      _regions = orderedRegions;
      if (!_regions.contains(_selectedRegion)) {
        _selectedRegion = 'All Regions';
      }
      _lastUpdatedAt = now;
      _isLoading = false;
    });
  }

  DateTimeRange _buildCurrentPeriod(DateTime now) {
    if (_selectedPeriod == 'Day') {
      return DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: now,
      );
    }
    if (_selectedPeriod == 'Month') {
      return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    }
    if (_selectedPeriod == 'YTD') {
      return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
    }
    final start = now.subtract(Duration(days: now.weekday - 1));
    return DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: now,
    );
  }

  List<Map<String, dynamic>> _asRows(dynamic response) {
    if (response is List) {
      return response
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> _fetchRows(
    Future<dynamic> Function() loader,
    String label,
  ) async {
    try {
      final response = await loader();
      return _asRows(response);
    } catch (e) {
      debugPrint('Regions page $label load error: $e');
      return <Map<String, dynamic>>[];
    }
  }

  static String _normalizeRegion(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return 'Unassigned';
    return text;
  }

  static String _regionForSchool(
    Map<String, dynamic>? school,
    Map<String, String> userRegionById,
  ) {
    if (school == null) {
      return 'Unassigned';
    }
    final county = _normalizeRegion(school['county']);
    if (county != 'Unassigned') {
      return county;
    }
    final capturedBy = school['captured_by']?.toString();
    if (capturedBy != null && userRegionById.containsKey(capturedBy)) {
      return userRegionById[capturedBy]!;
    }
    return 'Unassigned';
  }

  static bool _isBookshopOutlet(Map<String, dynamic> school) {
    final buffer = [
          school['dealer_type'],
          school['shop_category'],
          school['selected_product'],
          school['partner_subtype'],
          school['book_category'],
          school['name'],
        ]
        .where((value) => value != null)
        .map((value) => value.toString().toLowerCase())
        .join(' ');

    return buffer.contains('bookshop') ||
        buffer.contains('book shop') ||
        buffer.contains('bookstore') ||
        buffer.contains('book store') ||
        buffer.contains('retail') ||
        buffer.contains('dealer') ||
        buffer.contains('stockist');
  }

  static bool _isCallActivity(Map<String, dynamic> activity) {
    final buffer = [
          activity['activity_type'],
          activity['activity_outcome'],
          activity['notes'],
          activity['next_action'],
        ]
        .where((value) => value != null)
        .map((value) => value.toString().toLowerCase())
        .join(' ');

    return buffer.contains('call');
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static DateTime _pickSaleDate(Map<String, dynamic> sale) {
    return _parseDate(sale['closed_at']) ??
        _parseDate(sale['stage_updated_at']) ??
        _parseDate(sale['created_at']) ??
        DateTime.now();
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  _RegionMetrics _visibleMetrics() {
    if (_selectedRegion == 'All Regions') {
      return _department;
    }
    return _metricsByRegion[_selectedRegion] ?? _RegionMetrics(_selectedRegion);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _visibleMetrics();
    final rows =
        _selectedRegion == 'All Regions'
            ? _metricsByRegion.values.toList()
            : <_RegionMetrics>[metrics];

    rows.sort((a, b) => b.salesActualSelected.compareTo(a.salesActualSelected));

    final innerContent = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroCard(metrics),
            const SizedBox(height: 16),
            _buildFilterBar(),
            const SizedBox(height: 8),
            Text(
              'Targets are benchmarked from prior-year performance and active outlet counts because the current schema does not store explicit regional target tables.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _buildSummaryGrid(metrics),
            const SizedBox(height: 24),
            _buildSalesSection(rows, metrics),
            const SizedBox(height: 24),
            _buildSchoolSection(rows, metrics),
            const SizedBox(height: 24),
            _buildBookshopSection(rows, metrics),
            const SizedBox(height: 24),
            _buildDailySection(rows, metrics),
            const SizedBox(height: 24),
            _buildTrendSection(),
          ],
        ),
      ),
    );

    if (widget.isEmbedded) {
      return _isLoading
          ? const Center(child: CircularProgressIndicator())
          : innerContent;
    }

    final content =
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: innerContent,
              ),
            );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Regions'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildHeroCard(_RegionMetrics metrics) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D273F), Color(0xFF80AC4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.public, color: Colors.white, size: 34),
          const SizedBox(height: 10),
          const Text(
            'Regional Performance Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sales, school coverage, bookshop coverage, daily activity, and YoY growth across the department.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroPill(
                'Regions',
                _selectedRegion == 'All Regions'
                    ? '${_regions.length - 1}'
                    : '1',
              ),
              _buildHeroPill(
                'Sales Achievement',
                '${metrics.salesAchievement.toStringAsFixed(1)}%',
              ),
              _buildHeroPill(
                'School Activity',
                _formatInt(
                  metrics.selectedSchoolVisits + metrics.selectedSchoolCalls,
                ),
              ),
              _buildHeroPill(
                'Bookshop Activity',
                _formatInt(
                  metrics.selectedBookshopVisits +
                      metrics.selectedBookshopCalls,
                ),
              ),
            ],
          ),
          if (_lastUpdatedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Last updated: ${_formatDateTime(_lastUpdatedAt!)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Day', label: Text('Day')),
            ButtonSegment(value: 'Week', label: Text('Week')),
            ButtonSegment(value: 'Month', label: Text('Month')),
            ButtonSegment(value: 'YTD', label: Text('YTD')),
          ],
          selected: {_selectedPeriod},
          onSelectionChanged: (selection) {
            setState(() {
              _selectedPeriod = selection.first;
            });
            _loadData();
          },
        ),
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<String>(
            value: _selectedRegion,
            decoration: const InputDecoration(
              labelText: 'Region',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items:
                _regions
                    .map(
                      (region) => DropdownMenuItem(
                        value: region,
                        child: Text(region, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedRegion = value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryGrid(_RegionMetrics metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth =
            constraints.maxWidth >= 1100
                ? (constraints.maxWidth - 36) / 4
                : constraints.maxWidth >= 600
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;

        Widget buildCard(Widget child) =>
            SizedBox(width: cardWidth, child: child);

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            buildCard(
              _summaryCard(
                title: 'Sales Performance',
                icon: Icons.payments_outlined,
                accent: const Color(0xFF80AC4A),
                lines: [
                  'Target: ${_formatCurrency(metrics.selectedSalesTarget)}',
                  'Actual: ${_formatCurrency(metrics.salesActualSelected)}',
                  'Achievement: ${metrics.salesAchievement.toStringAsFixed(1)}%',
                  'YoY: ${_formatGrowthValue(metrics.salesYoYAbsolute, metrics.salesYoYPercent)}',
                ],
              ),
            ),
            buildCard(
              _summaryCard(
                title: 'School Coverage',
                icon: Icons.school_outlined,
                accent: Colors.blue,
                lines: [
                  'Visits: ${_formatInt(metrics.selectedSchoolVisits)} / ${_formatInt(metrics.selectedSchoolVisitTarget)}',
                  'Calls: ${_formatInt(metrics.selectedSchoolCalls)} / ${_formatInt(metrics.selectedSchoolCallTarget)}',
                  'YTD Visits Target: ${_formatInt(metrics.schoolVisitYtdTarget)}',
                  'YTD Calls Target: ${_formatInt(metrics.schoolCallYtdTarget)}',
                ],
              ),
            ),
            buildCard(
              _summaryCard(
                title: 'Bookshop Coverage',
                icon: Icons.storefront_outlined,
                accent: Colors.deepOrange,
                lines: [
                  'Visits: ${_formatInt(metrics.selectedBookshopVisits)} / ${_formatInt(metrics.selectedBookshopVisitTarget)}',
                  'Calls: ${_formatInt(metrics.selectedBookshopCalls)} / ${_formatInt(metrics.selectedBookshopCallTarget)}',
                  'YTD Visits Target: ${_formatInt(metrics.bookshopVisitYtdTarget)}',
                  'YTD Calls Target: ${_formatInt(metrics.bookshopCallYtdTarget)}',
                ],
              ),
            ),
            buildCard(
              _summaryCard(
                title: 'Daily Coverage',
                icon: Icons.today_outlined,
                accent: Colors.purple,
                lines: [
                  'Schools visited today: ${_formatInt(metrics.todaySchoolVisits)}',
                  'Schools called today: ${_formatInt(metrics.todaySchoolCalls)}',
                  'Bookshops visited today: ${_formatInt(metrics.todayBookshopVisits)}',
                  'Bookshops called today: ${_formatInt(metrics.todayBookshopCalls)}',
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard({
    required String title,
    required IconData icon,
    required Color accent,
    required List<String> lines,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: TextStyle(color: Colors.grey.shade800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesSection(List<_RegionMetrics> rows, _RegionMetrics metrics) {
    return _tableSection(
      title: 'Sales Performance by Region',
      subtitle: 'Sales target vs actual achievement and YoY movement.',
      columns: const [
        'Region',
        'Target',
        'Actual',
        'Achievement',
        'YoY Growth',
      ],
      rows:
          rows
              .map(
                (row) => [
                  row.region,
                  _formatCurrency(row.selectedSalesTarget),
                  _formatCurrency(row.salesActualSelected),
                  '${row.salesAchievement.toStringAsFixed(1)}%',
                  _formatGrowthValue(row.salesYoYAbsolute, row.salesYoYPercent),
                ],
              )
              .toList(),
      totalRow: [
        'Department Total',
        _formatCurrency(metrics.selectedSalesTarget),
        _formatCurrency(metrics.salesActualSelected),
        '${metrics.salesAchievement.toStringAsFixed(1)}%',
        _formatGrowthValue(metrics.salesYoYAbsolute, metrics.salesYoYPercent),
      ],
    );
  }

  Widget _buildSchoolSection(
    List<_RegionMetrics> rows,
    _RegionMetrics metrics,
  ) {
    return _tableSection(
      title: 'School Coverage',
      subtitle: 'Weekly targets, YTD targets, actual visits and calls.',
      columns: const [
        'Region',
        'Weekly Visits',
        'Weekly Calls',
        'YTD Visits',
        'YTD Calls',
        'Actual Visits',
        'Actual Calls',
        'YoY Growth',
      ],
      rows:
          rows
              .map(
                (row) => [
                  row.region,
                  _formatInt(row.schoolVisitWeeklyTarget),
                  _formatInt(row.schoolCallWeeklyTarget),
                  _formatInt(row.schoolVisitYtdTarget),
                  _formatInt(row.schoolCallYtdTarget),
                  _formatInt(row.selectedSchoolVisits),
                  _formatInt(row.selectedSchoolCalls),
                  _formatGrowthValue(
                    row.schoolActivityYoYAbsolute,
                    row.schoolActivityYoYPercent,
                  ),
                ],
              )
              .toList(),
      totalRow: [
        'Department Total',
        _formatInt(metrics.schoolVisitWeeklyTarget),
        _formatInt(metrics.schoolCallWeeklyTarget),
        _formatInt(metrics.schoolVisitYtdTarget),
        _formatInt(metrics.schoolCallYtdTarget),
        _formatInt(metrics.selectedSchoolVisits),
        _formatInt(metrics.selectedSchoolCalls),
        _formatGrowthValue(
          metrics.schoolActivityYoYAbsolute,
          metrics.schoolActivityYoYPercent,
        ),
      ],
    );
  }

  Widget _buildBookshopSection(
    List<_RegionMetrics> rows,
    _RegionMetrics metrics,
  ) {
    return _tableSection(
      title: 'Bookshop Coverage',
      subtitle: 'Weekly targets, YTD targets, actual visits and calls.',
      columns: const [
        'Region',
        'Weekly Visits',
        'Weekly Calls',
        'YTD Visits',
        'YTD Calls',
        'Actual Visits',
        'Actual Calls',
        'YoY Growth',
      ],
      rows:
          rows
              .map(
                (row) => [
                  row.region,
                  _formatInt(row.bookshopVisitWeeklyTarget),
                  _formatInt(row.bookshopCallWeeklyTarget),
                  _formatInt(row.bookshopVisitYtdTarget),
                  _formatInt(row.bookshopCallYtdTarget),
                  _formatInt(row.selectedBookshopVisits),
                  _formatInt(row.selectedBookshopCalls),
                  _formatGrowthValue(
                    row.bookshopActivityYoYAbsolute,
                    row.bookshopActivityYoYPercent,
                  ),
                ],
              )
              .toList(),
      totalRow: [
        'Department Total',
        _formatInt(metrics.bookshopVisitWeeklyTarget),
        _formatInt(metrics.bookshopCallWeeklyTarget),
        _formatInt(metrics.bookshopVisitYtdTarget),
        _formatInt(metrics.bookshopCallYtdTarget),
        _formatInt(metrics.selectedBookshopVisits),
        _formatInt(metrics.selectedBookshopCalls),
        _formatGrowthValue(
          metrics.bookshopActivityYoYAbsolute,
          metrics.bookshopActivityYoYPercent,
        ),
      ],
    );
  }

  Widget _buildDailySection(List<_RegionMetrics> rows, _RegionMetrics metrics) {
    return _tableSection(
      title: 'Daily Coverage per Region',
      subtitle: 'Actual activity today compared with expected daily targets.',
      columns: const [
        'Region',
        'Expected Visits',
        'Expected Calls',
        'Today Visits',
        'Today Calls',
        'Schools Today',
        'Bookshops Today',
      ],
      rows:
          rows
              .map(
                (row) => [
                  row.region,
                  _formatInt(row.dailySchoolVisitTarget),
                  _formatInt(row.dailySchoolCallTarget),
                  _formatInt(row.todaySchoolVisits),
                  _formatInt(row.todaySchoolCalls),
                  _formatInt(row.todaySchoolsCoveredIds.length),
                  _formatInt(row.todayBookshopsCoveredIds.length),
                ],
              )
              .toList(),
      totalRow: [
        'Department Total',
        _formatInt(metrics.dailySchoolVisitTarget),
        _formatInt(metrics.dailySchoolCallTarget),
        _formatInt(metrics.todaySchoolVisits),
        _formatInt(metrics.todaySchoolCalls),
        _formatInt(metrics.todaySchoolsCoveredIds.length),
        _formatInt(metrics.todayBookshopsCoveredIds.length),
      ],
    );
  }

  Widget _tableSection({
    required String title,
    required String subtitle,
    required List<String> columns,
    required List<List<String>> rows,
    required List<String> totalRow,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(title, subtitle),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns:
                    columns
                        .map(
                          (column) => DataColumn(
                            label: Text(
                              column,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                rows: [
                  ...rows.map(
                    (row) => DataRow(
                      cells:
                          row
                              .map(
                                (cell) => DataCell(
                                  Text(
                                    cell,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  DataRow(
                    cells:
                        totalRow
                            .map(
                              (cell) => DataCell(
                                Text(
                                  cell,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendSection() {
    final metrics =
        _selectedRegion == 'All Regions'
            ? _department
            : _metricsByRegion[_selectedRegion] ?? _department;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
              'Year-over-Year Growth Analysis',
              'Current year vs previous year monthly trend for the selected region scope.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildTrendCard(
                  title: 'Sales',
                  currentSeries: metrics.salesMonthlyCurrentYear,
                  previousSeries: metrics.salesMonthlyPreviousYear,
                  currentColor: AppColors.primaryGreen,
                  previousColor: Colors.grey,
                  valueFormatter: _formatCurrencyShort,
                ),
                _buildTrendCard(
                  title: 'School Coverage',
                  currentSeries: metrics.schoolActivityMonthlyCurrentYear,
                  previousSeries: metrics.schoolActivityMonthlyPreviousYear,
                  currentColor: Colors.blue,
                  previousColor: Colors.grey,
                  valueFormatter: _formatIntShort,
                ),
                _buildTrendCard(
                  title: 'Bookshop Coverage',
                  currentSeries: metrics.bookshopActivityMonthlyCurrentYear,
                  previousSeries: metrics.bookshopActivityMonthlyPreviousYear,
                  currentColor: Colors.deepOrange,
                  previousColor: Colors.grey,
                  valueFormatter: _formatIntShort,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard({
    required String title,
    required List<double> currentSeries,
    required List<double> previousSeries,
    required Color currentColor,
    required Color previousColor,
    required String Function(double value) valueFormatter,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 400 ? constraints.maxWidth : 400.0;
        return SizedBox(
          width: width,
          child: Card(
            elevation: 0,
            color: AppColors.primaryPale.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    children: [
                      _legendDot(currentColor, 'Current year'),
                      _legendDot(previousColor, 'Previous year'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AspectRatio(
                    aspectRatio: 1.5,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine:
                              (value) => FlLine(
                                color: Colors.grey.withValues(alpha: 0.18),
                                strokeWidth: 1,
                              ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
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
                                if (value >= 0 &&
                                    value < 12 &&
                                    value.toInt() % 2 == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
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
                              reservedSize: 34,
                              getTitlesWidget:
                                  (value, meta) => Text(
                                    valueFormatter(value),
                                    style: const TextStyle(fontSize: 9),
                                  ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: 11,
                        minY: 0,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _buildMonthlySpots(currentSeries),
                            isCurved: true,
                            color: currentColor,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: currentColor.withValues(alpha: 0.12),
                            ),
                          ),
                          LineChartBarData(
                            spots: _buildMonthlySpots(previousSeries),
                            isCurved: true,
                            color: previousColor,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
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

  List<FlSpot> _buildMonthlySpots(List<double> values) {
    return List<FlSpot>.generate(
      12,
      (index) => FlSpot(index.toDouble(), values[index]),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
      ],
    );
  }

  static String _formatInt(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  static String _formatIntShort(double value) {
    return _formatInt(value.round());
  }

  static String _formatCurrency(double value) {
    return 'KES ${_formatDoubleWithCommas(value)}';
  }

  static String _formatCurrencyShort(double value) {
    if (value >= 1000000) {
      return 'KES ${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return 'KES ${(value / 1000).toStringAsFixed(1)}K';
    }
    return 'KES ${value.toStringAsFixed(0)}';
  }

  static String _formatDoubleWithCommas(double value) {
    final whole = value.toStringAsFixed(0);
    return whole.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  static String _formatGrowthValue(double absolute, double? percent) {
    final sign = absolute > 0 ? '+' : '';
    final absText =
        absolute.abs() >= 1000
            ? _formatDoubleWithCommas(absolute.abs())
            : absolute.abs().toStringAsFixed(0);
    final percentText =
        percent == null ? '--' : '${percent.toStringAsFixed(1)}%';
    return '$sign$absText ($percentText)';
  }

  static String _formatDateTime(DateTime value) {
    final date =
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

class _RegionMetrics {
  _RegionMetrics(this.region);

  final String region;

  int schoolBaseCount = 0;
  int bookshopBaseCount = 0;

  double salesActualSelected = 0;
  double salesPreviousSelected = 0;
  double salesCurrentYear = 0;
  double salesPreviousYear = 0;

  int selectedSchoolVisits = 0;
  int selectedSchoolCalls = 0;
  int selectedSchoolVisitsPrevious = 0;
  int selectedSchoolCallsPrevious = 0;
  int currentSchoolVisitsYear = 0;
  int currentSchoolCallsYear = 0;
  int previousSchoolVisitsYear = 0;
  int previousSchoolCallsYear = 0;

  int selectedBookshopVisits = 0;
  int selectedBookshopCalls = 0;
  int selectedBookshopVisitsPrevious = 0;
  int selectedBookshopCallsPrevious = 0;
  int currentBookshopVisitsYear = 0;
  int currentBookshopCallsYear = 0;
  int previousBookshopVisitsYear = 0;
  int previousBookshopCallsYear = 0;

  int todaySchoolVisits = 0;
  int todaySchoolCalls = 0;
  int todayBookshopVisits = 0;
  int todayBookshopCalls = 0;
  final Set<String> todaySchoolsCoveredIds = <String>{};
  final Set<String> todayBookshopsCoveredIds = <String>{};

  final List<double> salesMonthlyCurrentYear = List<double>.filled(12, 0);
  final List<double> salesMonthlyPreviousYear = List<double>.filled(12, 0);
  final List<double> schoolActivityMonthlyCurrentYear = List<double>.filled(
    12,
    0,
  );
  final List<double> schoolActivityMonthlyPreviousYear = List<double>.filled(
    12,
    0,
  );
  final List<double> bookshopActivityMonthlyCurrentYear = List<double>.filled(
    12,
    0,
  );
  final List<double> bookshopActivityMonthlyPreviousYear = List<double>.filled(
    12,
    0,
  );

  double annualSalesTarget = 0;
  double annualSchoolVisitTarget = 0;
  double annualSchoolCallTarget = 0;
  double annualBookshopVisitTarget = 0;
  double annualBookshopCallTarget = 0;

  double selectedSalesTarget = 0;
  int selectedSchoolVisitTarget = 0;
  int selectedSchoolCallTarget = 0;
  int selectedBookshopVisitTarget = 0;
  int selectedBookshopCallTarget = 0;

  int schoolVisitWeeklyTarget = 0;
  int schoolCallWeeklyTarget = 0;
  int schoolVisitYtdTarget = 0;
  int schoolCallYtdTarget = 0;
  int bookshopVisitWeeklyTarget = 0;
  int bookshopCallWeeklyTarget = 0;
  int bookshopVisitYtdTarget = 0;
  int bookshopCallYtdTarget = 0;
  int dailySchoolVisitTarget = 0;
  int dailySchoolCallTarget = 0;
  int dailyBookshopVisitTarget = 0;
  int dailyBookshopCallTarget = 0;

  double salesYoYAbsolute = 0;
  double? salesYoYPercent;
  double schoolActivityYoYAbsolute = 0;
  double? schoolActivityYoYPercent;
  double bookshopActivityYoYAbsolute = 0;
  double? bookshopActivityYoYPercent;

  double get salesAchievement =>
      selectedSalesTarget <= 0
          ? 0
          : (salesActualSelected / selectedSalesTarget) * 100;

  void recordSales(
    DateTime date,
    double amount,
    DateTimeRange currentPeriod,
    DateTimeRange previousPeriod,
    int currentYear,
    int previousYear,
  ) {
    if (date.year == currentYear) {
      salesCurrentYear += amount;
      salesMonthlyCurrentYear[date.month - 1] += amount;
    }
    if (date.year == previousYear) {
      salesPreviousYear += amount;
      salesMonthlyPreviousYear[date.month - 1] += amount;
    }
    if (_within(date, currentPeriod)) {
      salesActualSelected += amount;
    }
    if (_within(date, previousPeriod)) {
      salesPreviousSelected += amount;
    }
  }

  void recordSchoolVisit(
    DateTime date,
    DateTimeRange currentPeriod,
    DateTimeRange previousPeriod,
    DateTimeRange todayRange,
    int currentYear,
    int previousYear, {
    String? schoolId,
  }) {
    if (date.year == currentYear) {
      currentSchoolVisitsYear += 1;
      schoolActivityMonthlyCurrentYear[date.month - 1] += 1;
    }
    if (date.year == previousYear) {
      previousSchoolVisitsYear += 1;
      schoolActivityMonthlyPreviousYear[date.month - 1] += 1;
    }
    if (_within(date, currentPeriod)) {
      selectedSchoolVisits += 1;
    }
    if (_within(date, previousPeriod)) {
      selectedSchoolVisitsPrevious += 1;
    }
    if (_within(date, todayRange)) {
      todaySchoolVisits += 1;
      if (schoolId != null && schoolId.isNotEmpty) {
        todaySchoolsCoveredIds.add(schoolId);
      }
    }
  }

  void recordSchoolCall(
    DateTime date,
    DateTimeRange currentPeriod,
    DateTimeRange previousPeriod,
    DateTimeRange todayRange,
    int currentYear,
    int previousYear, {
    String? schoolId,
  }) {
    if (date.year == currentYear) {
      currentSchoolCallsYear += 1;
      schoolActivityMonthlyCurrentYear[date.month - 1] += 1;
    }
    if (date.year == previousYear) {
      previousSchoolCallsYear += 1;
      schoolActivityMonthlyPreviousYear[date.month - 1] += 1;
    }
    if (_within(date, currentPeriod)) {
      selectedSchoolCalls += 1;
    }
    if (_within(date, previousPeriod)) {
      selectedSchoolCallsPrevious += 1;
    }
    if (_within(date, todayRange)) {
      todaySchoolCalls += 1;
      if (schoolId != null && schoolId.isNotEmpty) {
        todaySchoolsCoveredIds.add(schoolId);
      }
    }
  }

  void recordBookshopVisit(
    DateTime date,
    DateTimeRange currentPeriod,
    DateTimeRange previousPeriod,
    DateTimeRange todayRange,
    int currentYear,
    int previousYear, {
    String? schoolId,
  }) {
    if (date.year == currentYear) {
      currentBookshopVisitsYear += 1;
      bookshopActivityMonthlyCurrentYear[date.month - 1] += 1;
    }
    if (date.year == previousYear) {
      previousBookshopVisitsYear += 1;
      bookshopActivityMonthlyPreviousYear[date.month - 1] += 1;
    }
    if (_within(date, currentPeriod)) {
      selectedBookshopVisits += 1;
    }
    if (_within(date, previousPeriod)) {
      selectedBookshopVisitsPrevious += 1;
    }
    if (_within(date, todayRange)) {
      todayBookshopVisits += 1;
      if (schoolId != null && schoolId.isNotEmpty) {
        todayBookshopsCoveredIds.add(schoolId);
      }
    }
  }

  void recordBookshopCall(
    DateTime date,
    DateTimeRange currentPeriod,
    DateTimeRange previousPeriod,
    DateTimeRange todayRange,
    int currentYear,
    int previousYear, {
    String? schoolId,
  }) {
    if (date.year == currentYear) {
      currentBookshopCallsYear += 1;
      bookshopActivityMonthlyCurrentYear[date.month - 1] += 1;
    }
    if (date.year == previousYear) {
      previousBookshopCallsYear += 1;
      bookshopActivityMonthlyPreviousYear[date.month - 1] += 1;
    }
    if (_within(date, currentPeriod)) {
      selectedBookshopCalls += 1;
    }
    if (_within(date, previousPeriod)) {
      selectedBookshopCallsPrevious += 1;
    }
    if (_within(date, todayRange)) {
      todayBookshopCalls += 1;
      if (schoolId != null && schoolId.isNotEmpty) {
        todayBookshopsCoveredIds.add(schoolId);
      }
    }
  }

  void computeTargets({
    required int yearLength,
    required double periodRatio,
    required double ytdRatio,
  }) {
    final salesBase = math.max<double>(
      salesPreviousYear * 1.1,
      math.max<double>(1.0, (schoolBaseCount + bookshopBaseCount) * 10000.0),
    );
    final schoolVisitBase = math.max<double>(
      previousSchoolVisitsYear * 1.1,
      math.max<double>(1.0, schoolBaseCount * 12.0),
    );
    final schoolCallBase = math.max<double>(
      previousSchoolCallsYear * 1.1,
      math.max<double>(1.0, schoolBaseCount * 24.0),
    );
    final bookshopVisitBase = math.max<double>(
      previousBookshopVisitsYear * 1.1,
      math.max<double>(1.0, bookshopBaseCount * 10.0),
    );
    final bookshopCallBase = math.max<double>(
      previousBookshopCallsYear * 1.1,
      math.max<double>(1.0, bookshopBaseCount * 20.0),
    );

    annualSalesTarget = salesBase;
    annualSchoolVisitTarget = schoolVisitBase;
    annualSchoolCallTarget = schoolCallBase;
    annualBookshopVisitTarget = bookshopVisitBase;
    annualBookshopCallTarget = bookshopCallBase;

    selectedSalesTarget = annualSalesTarget * periodRatio;
    selectedSchoolVisitTarget = (annualSchoolVisitTarget * periodRatio).round();
    selectedSchoolCallTarget = (annualSchoolCallTarget * periodRatio).round();
    selectedBookshopVisitTarget =
        (annualBookshopVisitTarget * periodRatio).round();
    selectedBookshopCallTarget =
        (annualBookshopCallTarget * periodRatio).round();

    schoolVisitWeeklyTarget = (annualSchoolVisitTarget / 52).round();
    schoolCallWeeklyTarget = (annualSchoolCallTarget / 52).round();
    schoolVisitYtdTarget = (annualSchoolVisitTarget * ytdRatio).round();
    schoolCallYtdTarget = (annualSchoolCallTarget * ytdRatio).round();
    bookshopVisitWeeklyTarget = (annualBookshopVisitTarget / 52).round();
    bookshopCallWeeklyTarget = (annualBookshopCallTarget / 52).round();
    bookshopVisitYtdTarget = (annualBookshopVisitTarget * ytdRatio).round();
    bookshopCallYtdTarget = (annualBookshopCallTarget * ytdRatio).round();
    dailySchoolVisitTarget = (annualSchoolVisitTarget / yearLength).round();
    dailySchoolCallTarget = (annualSchoolCallTarget / yearLength).round();
    dailyBookshopVisitTarget = (annualBookshopVisitTarget / yearLength).round();
    dailyBookshopCallTarget = (annualBookshopCallTarget / yearLength).round();

    salesYoYAbsolute = salesActualSelected - salesPreviousSelected;
    salesYoYPercent = _growthPercent(
      salesPreviousSelected,
      salesActualSelected,
    );

    final currentSchoolTotal = selectedSchoolVisits + selectedSchoolCalls;
    final previousSchoolTotal =
        selectedSchoolVisitsPrevious + selectedSchoolCallsPrevious;
    schoolActivityYoYAbsolute =
        currentSchoolTotal.toDouble() - previousSchoolTotal.toDouble();
    schoolActivityYoYPercent = _growthPercent(
      previousSchoolTotal.toDouble(),
      currentSchoolTotal.toDouble(),
    );

    final currentBookshopTotal = selectedBookshopVisits + selectedBookshopCalls;
    final previousBookshopTotal =
        selectedBookshopVisitsPrevious + selectedBookshopCallsPrevious;
    bookshopActivityYoYAbsolute =
        currentBookshopTotal.toDouble() - previousBookshopTotal.toDouble();
    bookshopActivityYoYPercent = _growthPercent(
      previousBookshopTotal.toDouble(),
      currentBookshopTotal.toDouble(),
    );
  }

  static bool _within(DateTime date, DateTimeRange range) {
    return !date.isBefore(range.start) && !date.isAfter(range.end);
  }

  static double? _growthPercent(double previous, double current) {
    if (previous == 0) {
      if (current == 0) return 0;
      return null;
    }
    return ((current - previous) / previous) * 100;
  }
}

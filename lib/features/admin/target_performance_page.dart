import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/colors.dart';
import '../../core/config/api_config.dart';
import '../../models/target_model.dart';
import '../../models/region_model.dart';
import '../../models/user_model.dart';
import '../database/database_service.dart';
import 'utils/csv_download_stub.dart'
    if (dart.library.html) 'utils/csv_download_web.dart'
    if (dart.library.io) 'utils/csv_download_io.dart';

class _PerformanceRow {
  final UserModel user;
  final Map<String, Map<String, int>> productTargets;
  final Map<String, int> visitTargets;
  final Map<String, int> collectionTargets;
  final Map<String, int> customerTargets;
  final Map<String, int> sampleTargets;
  final Map<String, int> consignmentTargets;
  final Map<String, int> actualProducts;
  final Map<String, int> actualVisits;
  final Map<String, int> actualCollections;
  final Map<String, int> actualCustomers;
  final Map<String, int> actualSamples;
  final Map<String, int> actualSampleReturns;
  final Map<String, int> actualConsignments;
  final Map<String, double> percentages;
  final Map<String, int> actualSchools;
  final Map<String, int> actualInstitutions;
  final Map<String, int> actualBookshops;
  final Map<String, int> pipeline;
  final Map<String, int> daysWorked;

  _PerformanceRow({
    required this.user,
    required this.productTargets,
    required this.visitTargets,
    required this.collectionTargets,
    required this.customerTargets,
    required this.sampleTargets,
    required this.consignmentTargets,
    required this.actualProducts,
    required this.actualVisits,
    required this.actualCollections,
    required this.actualCustomers,
    required this.actualSamples,
    required this.actualSampleReturns,
    required this.actualConsignments,
    required this.percentages,
    required this.actualSchools,
    required this.actualInstitutions,
    required this.actualBookshops,
    required this.pipeline,
    required this.daysWorked,
  });
}

class _CardMetric {
  final String label;
  final String value;

  const _CardMetric({required this.label, required this.value});
}

class _ReportSummary {
  final List<_PerformanceRow> rows;
  final int totalAssignees;
  final int totalTargets;
  final int totalSales;
  final int totalVisits;
  final int totalCustomers;
  final int totalInstitutions;
  final int totalBookshops;
  final int avgSales;
  final _PerformanceRow? bestPerformer;

  const _ReportSummary({
    required this.rows,
    required this.totalAssignees,
    required this.totalTargets,
    required this.totalSales,
    required this.totalVisits,
    required this.totalCustomers,
    required this.totalInstitutions,
    required this.totalBookshops,
    required this.avgSales,
    required this.bestPerformer,
  });
}

class TargetPerformancePage extends StatefulWidget {
  const TargetPerformancePage({super.key});

  @override
  State<TargetPerformancePage> createState() => _TargetPerformancePageState();
}

class _TargetPerformancePageState extends State<TargetPerformancePage>
    with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  int _currentUserRole = 5;
  String? _currentUserId;
  String _selectedScope = 'regional';
  late TabController _tabController;
  List<RegionModel> _regions = [];
  List<UserModel> _agents = [];
  List<UserModel> _businessAdvisors = [];
  List<UserModel> _salesReps = [];
  List<_PerformanceRow> _rows = [];

  // Dynamic Filter State
  List<String> _scopeOptions = [];
  List<String> _targetPeriodOptions = [];
  List<Map<String, String>> _regionOptions = [];
  List<Map<String, String>> _assigneeOptions = [];
  String? _selectedTargetPeriod;
  String? _selectedRegionOptionId;
  String? _selectedAssigneeOptionId;
  DateTime _startDate = DateTime(2026, 1, 22);
  DateTime _endDate = DateTime(2026, 7, 13);
  String _sortBy = 'All';

  String? _defaultScopeForRole(int role) {
    switch (role) {
      case 3:
        return 'business_advisor';
      case 4:
        return 'agent';
      case 5:
        return 'sales_rep';
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final user = await _dbService.getUser(currentUser.id);
        _currentUserId = currentUser.id;
        _currentUserRole = user?.role ?? 5;
      }

      if (_currentUserRole > 2) {
        _selectedScope = _defaultScopeForRole(_currentUserRole) ?? 'regional';
      }

      final regions = await _dbService.getAllRegions();
      final users = await _dbService.getAllUsers();
      final agents = users.where((u) => u.role == 4).toList();
      final businessAdvisors = users.where((u) => u.role == 3).toList();
      final salesReps = users.where((u) => u.role == 5).toList();

      final scopeOptions = await _dbService.getDistinctTargetScopes();
      final targetPeriodOptions = await _dbService.getDistinctTargetPeriods();
      final regionOptions = await _dbService.getRegionOptions();
      final assigneeOptions =
          _currentUserRole <= 2
              ? await _dbService.getAssignableUsersByRoles(const [3, 4, 5])
              : await _dbService.getAssignableUsersByRoles([_currentUserRole]);

      if (!mounted) return;
      setState(() {
        _regions = regions;
        _agents = agents;
        _businessAdvisors = businessAdvisors;
        _salesReps = salesReps;
        _scopeOptions = scopeOptions;
        _targetPeriodOptions = targetPeriodOptions;
        _regionOptions = regionOptions;
        _assigneeOptions = assigneeOptions;
        _isLoading = false;
      });

      await _loadPerformance();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading performance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<TargetModel>> _loadTargets() async {
    try {
      var query = Supabase.instance.client.from('targets').select();

      if (_selectedScope.isNotEmpty) {
        query = query.eq('scope', _selectedScope);
      }
      if (_selectedTargetPeriod case final value?) {
        query = query.eq('target_period', value);
      }
      if (_selectedRegionOptionId case final value?) {
        query = query.eq('region_id', value);
      }
      if (_selectedAssigneeOptionId case final value?) {
        query = query.eq('assigned_to', value);
      }

      final data = await query.order('created_at', ascending: false);
      return (data as List)
          .map((item) => TargetModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error loading targets: $e');
      return <TargetModel>[];
    }
  }

  Future<void> _loadPerformance() async {
    setState(() => _isLoading = true);
    try {
      final targets = await _loadTargets();
      final assignees = _getAssigneeList();
      final rows = await Future.wait(
        assignees.map((user) => _buildRow(user, targets)),
      );
      if (!mounted) return;
      setState(() => _rows = rows);
      _isLoading = false;
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading performance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<UserModel> _getAssigneeList() {
    if (_currentUserRole > 2) {
      switch (_selectedScope) {
        case 'agent':
          return _agents;
        case 'business_advisor':
          return _businessAdvisors;
        case 'sales_rep':
          return _salesReps;
        case 'individual':
          for (final list in [_agents, _businessAdvisors, _salesReps]) {
            for (final u in list) {
              if (u.id == _selectedAssigneeOptionId) return [u];
            }
          }
          return _roleAssignees();
        default:
          return _roleAssignees();
      }
    }
    switch (_selectedScope) {
      case 'regional':
        if (_selectedRegionOptionId != null) {
          return _agents
              .where((a) => a.regionId == _selectedRegionOptionId)
              .toList();
        }
        return _agents;
      case 'agent':
        return _selectedAssigneeOptionId == null
            ? _agents
            : _agents.where((a) => a.id == _selectedAssigneeOptionId).toList();
      case 'business_advisor':
        return _selectedAssigneeOptionId == null
            ? _businessAdvisors
            : _businessAdvisors
                .where((a) => a.id == _selectedAssigneeOptionId)
                .toList();
      case 'sales_rep':
        return _selectedAssigneeOptionId == null
            ? _salesReps
            : _salesReps
                .where((a) => a.id == _selectedAssigneeOptionId)
                .toList();
      case 'individual':
        for (final list in [_agents, _businessAdvisors, _salesReps]) {
          for (final u in list) {
            if (u.id == _selectedAssigneeOptionId) return [u];
          }
        }
        return <UserModel>[];
      default:
        return <UserModel>[];
    }
  }

  List<UserModel> _roleAssignees() {
    switch (_currentUserRole) {
      case 3:
        return _businessAdvisors;
      case 4:
        return _agents;
      case 5:
        return _salesReps;
      default:
        return <UserModel>[];
    }
  }

  void _applyPeriodDateRange(String? period) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;
    switch (period) {
      case 'daily':
        start = DateTime(now.year, now.month, now.day);
        end = start;
        break;
      case 'weekly':
        start = now.subtract(const Duration(days: 6));
        end = now;
        break;
      case 'monthly':
        start = DateTime(now.year, now.month, 1);
        end = now;
        break;
      case 'quarterly':
        final quarter = ((now.month - 1) / 3).floor();
        start = DateTime(now.year, quarter * 3 + 1, 1);
        end = now;
        break;
      case 'yearly':
        start = DateTime(now.year, 1, 1);
        end = now;
        break;
      case 'ytd':
        start = DateTime(now.year, 1, 1);
        end = now;
        break;
      default:
        return;
    }
    setState(() {
      _startDate = start;
      _endDate = end;
    });
  }

  void _updateFilters(VoidCallback update, {bool reload = true}) {
    setState(update);
    if (reload) {
      _loadPerformance();
    }
  }

  String _scopeLabel(String scope) {
    switch (scope) {
      case 'regional':
        return 'Regional';
      case 'agent':
        return 'Agent';
      case 'business_advisor':
        return 'Business Advisor';
      case 'sales_rep':
        return 'Sales Rep';
      case 'individual':
        return 'Individual';
      default:
        return scope;
    }
  }

  String _selectedRegionLabel() {
    if (_selectedRegionOptionId == null) return 'All Regions';
    return _regionOptions.firstWhere(
          (r) => r['id'] == _selectedRegionOptionId,
          orElse: () => {'label': _selectedRegionOptionId!},
        )['label'] ??
        _selectedRegionOptionId!;
  }

  String _selectedAssigneeLabel() {
    if (_selectedAssigneeOptionId == null) return 'All Assignees';
    return _assigneeOptions.firstWhere(
          (a) => a['id'] == _selectedAssigneeOptionId,
          orElse: () => {'label': _selectedAssigneeOptionId!},
        )['label'] ??
        _selectedAssigneeOptionId!;
  }

  String _formatDateStamp(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _safeFilePart(String value) {
    final cleaned = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'report' : cleaned;
  }

  List<_PerformanceRow> _getSortedRows() {
    final rows = List<_PerformanceRow>.from(_rows);
    final periodKey = _selectedPeriodKey();

    if (_sortBy == 'All') {
      rows.sort(
        (a, b) => _periodValue(
          b.actualVisits,
          periodKey,
        ).compareTo(_periodValue(a.actualVisits, periodKey)),
      );
    } else if (_sortBy == 'School') {
      rows.sort(
        (a, b) => _periodValue(
          b.actualSchools,
          periodKey,
        ).compareTo(_periodValue(a.actualSchools, periodKey)),
      );
    } else if (_sortBy == 'Institution') {
      rows.sort(
        (a, b) => _periodValue(
          b.actualInstitutions,
          periodKey,
        ).compareTo(_periodValue(a.actualInstitutions, periodKey)),
      );
    } else if (_sortBy == 'Bookshop') {
      rows.sort(
        (a, b) => _periodValue(
          b.actualBookshops,
          periodKey,
        ).compareTo(_periodValue(a.actualBookshops, periodKey)),
      );
    }

    return rows;
  }

  _ReportSummary _buildReportSummaryData([List<_PerformanceRow>? rows]) {
    final reportRows = rows ?? _getSortedRows();
    final periodKey = _selectedPeriodKey();

    final totalAssignees = reportRows.length;
    final totalTargets = reportRows.fold<int>(0, (sum, r) {
      return sum +
          r.productTargets.values.fold<int>(
            0,
            (s, v) => s + v.values.fold<int>(0, (ss, vv) => ss + vv),
          ) +
          r.visitTargets.values.fold<int>(0, (s, v) => s + v) +
          r.collectionTargets.values.fold<int>(0, (s, v) => s + v) +
          r.customerTargets.values.fold<int>(0, (s, v) => s + v) +
          r.sampleTargets.values.fold<int>(0, (s, v) => s + v);
    });
    final totalSales = reportRows.fold<int>(
      0,
      (sum, r) => sum + _periodValue(r.actualProducts, periodKey),
    );
    final totalVisits = reportRows.fold<int>(
      0,
      (sum, r) => sum + _combinedVisitValue(r, periodKey),
    );
    final totalCustomers = reportRows.fold<int>(
      0,
      (sum, r) => sum + _periodValue(r.actualCustomers, periodKey),
    );
    final totalInstitutions = reportRows.fold<int>(
      0,
      (sum, r) => sum + _periodValue(r.actualInstitutions, periodKey),
    );
    final totalBookshops = reportRows.fold<int>(
      0,
      (sum, r) => sum + _periodValue(r.actualBookshops, periodKey),
    );
    final bestPerformer =
        reportRows.isEmpty
            ? null
            : reportRows.reduce(
              (a, b) =>
                  _periodValue(a.actualProducts, periodKey) >=
                          _periodValue(b.actualProducts, periodKey)
                      ? a
                      : b,
            );
    final avgSales =
        totalAssignees > 0 ? (totalSales / totalAssignees).round() : 0;

    return _ReportSummary(
      rows: reportRows,
      totalAssignees: totalAssignees,
      totalTargets: totalTargets,
      totalSales: totalSales,
      totalVisits: totalVisits,
      totalCustomers: totalCustomers,
      totalInstitutions: totalInstitutions,
      totalBookshops: totalBookshops,
      avgSales: avgSales,
      bestPerformer: bestPerformer,
    );
  }

  List<List<String>> _buildExportRows(List<_PerformanceRow> rows) {
    final periodKey = _selectedPeriodKey();
    return [
      for (var i = 0; i < rows.length; i++)
        [
          '${i + 1}',
          rows[i].user.fullName ?? rows[i].user.email,
          _roleLabel(rows[i].user.role),
          _periodValue(rows[i].actualProducts, periodKey).toString(),
          _periodValue(rows[i].actualVisits, periodKey).toString(),
          _periodValue(rows[i].actualCustomers, periodKey).toString(),
          _periodValue(rows[i].actualInstitutions, periodKey).toString(),
          _periodValue(rows[i].actualBookshops, periodKey).toString(),
          _periodValue(rows[i].pipeline, periodKey).toString(),
          _periodValue(rows[i].actualSamples, periodKey).toString(),
          _periodValue(rows[i].actualSampleReturns, periodKey).toString(),
          _periodValue(rows[i].daysWorked, periodKey).toString(),
        ],
    ];
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<void> _showExportOptions() async {
    if (_isLoading) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Download PDF'),
                onTap: () => Navigator.pop(sheetContext, 'pdf'),
              ),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Download Excel'),
                subtitle: const Text('CSV format'),
                onTap: () => Navigator.pop(sheetContext, 'excel'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || choice == null) return;
    if (choice == 'pdf') {
      await _exportPdf();
    } else if (choice == 'excel') {
      await _exportExcel();
    }
  }

  Future<void> _exportPdf() async {
    final summary = _buildReportSummaryData();
    if (summary.rows.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No data to export.')));
      return;
    }

    final pdf = pw.Document();
    final fileName =
        'target_performance_${_safeFilePart(_selectedScope)}_${_formatDateStamp(DateTime.now())}.pdf';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Text(
              'Target Performance Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Scope: ${_scopeLabel(_selectedScope)} | Region: ${_selectedRegionLabel()} | Assignee: ${_selectedAssigneeLabel()} | Period: ${_selectedTargetPeriod ?? 'All Periods'} | ${_formatDateStamp(_startDate)} to ${_formatDateStamp(_endDate)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 14),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pdfMetricCard('Assignees', '${summary.totalAssignees}'),
                _pdfMetricCard('Targets Matched', '${summary.totalTargets}'),
                _pdfMetricCard('Total Sales', _formatCount(summary.totalSales)),
                _pdfMetricCard('Total Visits', _formatCount(summary.totalVisits)),
                _pdfMetricCard(
                  'Schools Visited',
                  _formatCount(summary.totalCustomers),
                ),
                _pdfMetricCard(
                  'Institutions Visited',
                  _formatCount(summary.totalInstitutions),
                ),
                _pdfMetricCard(
                  'Bookshops Visited',
                  _formatCount(summary.totalBookshops),
                ),
                _pdfMetricCard('Avg Sales', _formatCount(summary.avgSales)),
                if (summary.bestPerformer != null)
                  _pdfMetricCard(
                    'Top Performer',
                    summary.bestPerformer!.user.fullName ??
                        summary.bestPerformer!.user.email,
                  ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: const [
                '#',
                'Name',
                'Role',
                'Sales',
                'Visits',
                'Schools',
                'Institutions',
                'Bookshops',
                'Pipeline',
                'Samples',
                'Returns',
                'Days Worked',
              ],
              data: _buildExportRows(summary.rows),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: const {
                0: pw.FixedColumnWidth(18),
                1: pw.FlexColumnWidth(2.2),
                2: pw.FlexColumnWidth(1.3),
                3: pw.FixedColumnWidth(42),
                4: pw.FixedColumnWidth(42),
                5: pw.FixedColumnWidth(42),
                6: pw.FixedColumnWidth(52),
                7: pw.FixedColumnWidth(48),
                8: pw.FixedColumnWidth(44),
                9: pw.FixedColumnWidth(44),
                10: pw.FixedColumnWidth(44),
                11: pw.FixedColumnWidth(50),
              },
            ),
          ];
        },
      ),
    );

    try {
      await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export started: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export PDF: $e')));
      }
    }
  }

  Future<void> _exportExcel() async {
    final summary = _buildReportSummaryData();
    if (summary.rows.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No data to export.')));
      return;
    }

    final headers = [
      'Rank',
      'Name',
      'Role',
      'Sales',
      'Visits',
      'Schools',
      'Institutions',
      'Bookshops',
      'Pipeline',
      'Samples',
      'Returns',
      'Days Worked',
    ];
    final buffer = StringBuffer();
    buffer.writeln(_csvEscape('Target Performance Report'));
    buffer.writeln(
      _csvEscape(
        'Scope: ${_scopeLabel(_selectedScope)} | Region: ${_selectedRegionLabel()} | Assignee: ${_selectedAssigneeLabel()} | Period: ${_selectedTargetPeriod ?? 'All Periods'} | ${_formatDateStamp(_startDate)} to ${_formatDateStamp(_endDate)}',
      ),
    );
    buffer.writeln(
      _csvEscape(
        'Assignees: ${summary.totalAssignees} | Targets Matched: ${summary.totalTargets} | Total Sales: ${_formatCount(summary.totalSales)} | Total Visits: ${_formatCount(summary.totalVisits)} | Schools Visited: ${_formatCount(summary.totalCustomers)} | Institutions Visited: ${_formatCount(summary.totalInstitutions)} | Bookshops Visited: ${_formatCount(summary.totalBookshops)} | Avg Sales: ${_formatCount(summary.avgSales)}',
      ),
    );
    buffer.writeln();
    buffer.writeln(headers.map(_csvEscape).join(','));

    for (final row in _buildExportRows(summary.rows)) {
      buffer.writeln(row.map(_csvEscape).join(','));
    }

    final fileName =
        'target_performance_${_safeFilePart(_selectedScope)}_${_formatDateStamp(DateTime.now())}.csv';

    try {
      await downloadCsvTemplate(fileName, buffer.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel export started: $fileName')),
        );
      }
    } on UnsupportedError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download not supported on this device.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export Excel: $e')));
      }
    }
  }

  pw.Widget _pdfMetricCard(String label, String value) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            maxLines: 1,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  bool _targetMatches(TargetModel target, UserModel user) {
    if (_selectedScope == 'regional') {
      final regionMatch =
          _selectedRegionOptionId == null ||
          target.regionId == _selectedRegionOptionId;
      return target.scope == 'regional' && regionMatch;
    }

    if (target.scope != _selectedScope) return false;

    if (_selectedAssigneeOptionId != null) {
      return target.assignedTo == _selectedAssigneeOptionId;
    }

    return target.assignedTo == null || target.assignedTo == user.id;
  }

  Future<_PerformanceRow> _buildRow(
    UserModel user,
    List<TargetModel> targets,
  ) async {
    final relevantTargets =
        targets.where((target) => _targetMatches(target, user)).toList();

    final selectedStart = _startDate;
    final selectedEnd = _endDate;

    final productTargets = <String, Map<String, int>>{};
    final visitTargets = <String, int>{};
    final collectionTargets = <String, int>{};
    final customerTargets = <String, int>{};
    final sampleTargets = <String, int>{};
    final consignmentTargets = <String, int>{};

    for (final target in relevantTargets) {
      final data = target.targetData;
      switch (target.targetType) {
        case 'product_sales':
          productTargets[target.targetPeriod] = {
            'exercise_books': (data['exercise_books'] as int?) ?? 0,
            'pens': (data['pens'] as int?) ?? 0,
            'rulers': (data['rulers'] as int?) ?? 0,
          };
          break;
        case 'customer_visits':
          visitTargets[target.targetPeriod] =
              ((data['schools'] as int?) ?? 0) +
              ((data['institutions'] as int?) ?? 0) +
              ((data['bookshops'] as int?) ?? 0);
          break;
        case 'collections':
          collectionTargets[target.targetPeriod] =
              (data['amount'] as int?) ?? 0;
          break;
        case 'new_customers':
          customerTargets[target.targetPeriod] = (data['count'] as int?) ?? 0;
          break;
        case 'sample_distribution':
          sampleTargets[target.targetPeriod] =
              ((data['exercise_book_samples'] as int?) ?? 0) +
              ((data['pen_samples'] as int?) ?? 0);
          break;
        case 'consignment':
          consignmentTargets['max_active'] =
              (data['max_active_consignments'] as int?) ?? 0;
          consignmentTargets['max_overdue'] =
              (data['max_overdue_consignments'] as int?) ?? 0;
          consignmentTargets['max_value'] =
              (data['max_consignment_value'] as int?) ?? 0;
          break;
      }
    }

    final rangeMetrics = await _dbService.getIndividualPerformance(
      agentId: user.id,
      start: selectedStart,
      end: selectedEnd,
    );

    final actualProducts = <String, int>{
      'range': rangeMetrics['wonSales'] ?? 0,
      'daily': rangeMetrics['wonSales'] ?? 0,
      'weekly': rangeMetrics['wonSales'] ?? 0,
      'monthly': rangeMetrics['wonSales'] ?? 0,
      'ytd': rangeMetrics['wonSales'] ?? 0,
    };

    final actualVisits = <String, int>{
      'range': rangeMetrics['visits'] ?? 0,
      'daily': rangeMetrics['visits'] ?? 0,
      'weekly': rangeMetrics['visits'] ?? 0,
      'monthly': rangeMetrics['visits'] ?? 0,
      'ytd': rangeMetrics['visits'] ?? 0,
    };

    final actualCollections = <String, int>{
      'range': rangeMetrics['orders'] ?? 0,
      'daily': rangeMetrics['orders'] ?? 0,
      'weekly': rangeMetrics['orders'] ?? 0,
      'monthly': rangeMetrics['orders'] ?? 0,
      'ytd': rangeMetrics['orders'] ?? 0,
    };

    final actualCustomers = <String, int>{
      'range': rangeMetrics['visitedSchools'] ?? 0,
      'daily': rangeMetrics['visitedSchools'] ?? 0,
      'weekly': rangeMetrics['visitedSchools'] ?? 0,
      'monthly': rangeMetrics['visitedSchools'] ?? 0,
      'ytd': rangeMetrics['visitedSchools'] ?? 0,
    };

    final actualSamples = <String, int>{
      'range': rangeMetrics['samples'] ?? 0,
      'daily': rangeMetrics['samples'] ?? 0,
      'weekly': rangeMetrics['samples'] ?? 0,
      'monthly': rangeMetrics['samples'] ?? 0,
      'ytd': rangeMetrics['samples'] ?? 0,
    };

    final actualSampleReturns = <String, int>{
      'range': rangeMetrics['sampleReturns'] ?? 0,
      'daily': rangeMetrics['sampleReturns'] ?? 0,
      'weekly': rangeMetrics['sampleReturns'] ?? 0,
      'monthly': rangeMetrics['sampleReturns'] ?? 0,
      'ytd': rangeMetrics['sampleReturns'] ?? 0,
    };

    final actualConsignments = <String, int>{
      'range': 0,
      'max_active': 0,
      'max_overdue': 0,
      'max_value': 0,
    };

    final actualSchools = <String, int>{
      'range': rangeMetrics['schools'] ?? 0,
      'daily': rangeMetrics['schools'] ?? 0,
      'weekly': rangeMetrics['schools'] ?? 0,
      'monthly': rangeMetrics['schools'] ?? 0,
      'ytd': rangeMetrics['schools'] ?? 0,
    };

    final actualInstitutions = <String, int>{
      'range': rangeMetrics['institutions'] ?? 0,
      'daily': rangeMetrics['institutions'] ?? 0,
      'weekly': rangeMetrics['institutions'] ?? 0,
      'monthly': rangeMetrics['institutions'] ?? 0,
      'ytd': rangeMetrics['institutions'] ?? 0,
    };

    final actualBookshops = <String, int>{
      'range': rangeMetrics['bookshops'] ?? 0,
      'daily': rangeMetrics['bookshops'] ?? 0,
      'weekly': rangeMetrics['bookshops'] ?? 0,
      'monthly': rangeMetrics['bookshops'] ?? 0,
      'ytd': rangeMetrics['bookshops'] ?? 0,
    };

    final pipeline = <String, int>{
      'range': rangeMetrics['pipeline'] ?? 0,
      'daily': rangeMetrics['pipeline'] ?? 0,
      'weekly': rangeMetrics['pipeline'] ?? 0,
      'monthly': rangeMetrics['pipeline'] ?? 0,
      'ytd': rangeMetrics['pipeline'] ?? 0,
    };

    final daysWorked = <String, int>{
      'range': rangeMetrics['daysWorked'] ?? 0,
      'daily': rangeMetrics['daysWorked'] ?? 0,
      'weekly': rangeMetrics['daysWorked'] ?? 0,
      'monthly': rangeMetrics['daysWorked'] ?? 0,
      'ytd': rangeMetrics['daysWorked'] ?? 0,
    };

    final percentages = <String, double>{};
    for (final period in ['daily', 'weekly', 'monthly', 'ytd']) {
      final productTarget = productTargets[period];
      final productActual = actualProducts[period] ?? 0;
      final productTargetValue =
          productTarget?.values.fold(0, (s, v) => s + v) ?? 0;
      percentages['$period-products'] = _pct(productActual, productTargetValue);

      final visitTarget = visitTargets[period] ?? 0;
      final visitActual = actualVisits[period] ?? 0;
      percentages['$period-visits'] = _pct(visitActual, visitTarget);

      final collectionTarget = collectionTargets[period] ?? 0;
      final collectionActual = actualCollections[period] ?? 0;
      percentages['$period-collections'] = _pct(
        collectionActual,
        collectionTarget,
      );

      final customerTarget = customerTargets[period] ?? 0;
      final customerActual = actualCustomers[period] ?? 0;
      percentages['$period-customers'] = _pct(customerActual, customerTarget);

      final sampleTarget = sampleTargets[period] ?? 0;
      final sampleActual = actualSamples[period] ?? 0;
      percentages['$period-samples'] = _pct(sampleActual, sampleTarget);
    }

    return _PerformanceRow(
      user: user,
      productTargets: productTargets,
      visitTargets: visitTargets,
      collectionTargets: collectionTargets,
      customerTargets: customerTargets,
      sampleTargets: sampleTargets,
      consignmentTargets: consignmentTargets,
      actualProducts: actualProducts,
      actualVisits: actualVisits,
      actualCollections: actualCollections,
      actualCustomers: actualCustomers,
      actualSamples: actualSamples,
      actualSampleReturns: actualSampleReturns,
      actualConsignments: actualConsignments,
      percentages: percentages,
      actualSchools: actualSchools,
      actualInstitutions: actualInstitutions,
      actualBookshops: actualBookshops,
      pipeline: pipeline,
      daysWorked: daysWorked,
    );
  }

  double _pct(int actual, int target) {
    if (target == 0) return actual > 0 ? 100.0 : 0.0;
    final raw = (actual / target) * 100;
    return raw > 100.0 ? 100.0 : (raw < 0.0 ? 0.0 : raw);
  }

  String _selectedPeriodKey() {
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
    final spanDays = end.difference(start).inDays.abs() + 1;

    const buckets = <String, int>{
      'daily': 1,
      'weekly': 7,
      'monthly': 30,
      'ytd': 365,
    };

    var bestKey = 'monthly';
    var bestDistance = 1 << 30;
    buckets.forEach((key, bucketDays) {
      final distance = (spanDays - bucketDays).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestKey = key;
      }
    });

    return bestKey;
  }

  int _periodValue(Map<String, int> values, String periodKey) {
    return values['range'] ??
        values[periodKey] ??
        values['monthly'] ??
        values['weekly'] ??
        values['daily'] ??
        values['ytd'] ??
        0;
  }

  int _combinedVisitValue(_PerformanceRow row, String periodKey) {
    return _periodValue(row.actualCustomers, periodKey) +
        _periodValue(row.actualInstitutions, periodKey) +
        _periodValue(row.actualBookshops, periodKey);
  }

  String _formatCount(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  List<_CardMetric> _buildPersonMetrics(_PerformanceRow row, String periodKey) {
    final schoolsVisited = _periodValue(row.actualSchools, periodKey);
    final bookshopsVisited = _periodValue(row.actualBookshops, periodKey);
    final institutionsVisited = _periodValue(row.actualInstitutions, periodKey);
    final pipeline = _periodValue(row.pipeline, periodKey);
    final samples = _periodValue(row.actualSamples, periodKey);
    final sampleReturns = _periodValue(row.actualSampleReturns, periodKey);
    final daysWorked = _periodValue(row.daysWorked, periodKey);

    return [
      _CardMetric(label: 'Schools Visited', value: '$schoolsVisited'),
      _CardMetric(label: 'Bookshops Visited', value: '$bookshopsVisited'),
      _CardMetric(label: 'Institutions Visited', value: '$institutionsVisited'),
      _CardMetric(label: 'Pipeline', value: '$pipeline'),
      _CardMetric(label: 'Samples Distributed', value: '$samples'),
      _CardMetric(label: 'Samples Returned', value: '$sampleReturns'),
      _CardMetric(label: 'Days Worked', value: '$daysWorked'),
    ];
  }

  String _roleLabel(int role) {
    switch (role) {
      case 1:
        return 'Admin';
      case 2:
        return 'Manager';
      case 3:
        return 'Business Advisor';
      case 4:
        return 'Agent';
      case 5:
        return 'Sales Rep';
      default:
        return 'User';
    }
  }

  String _buildPerformanceContext() {
    final periodKey = _selectedPeriodKey();
    return 'Filters: scope=$_selectedScope, region=${_selectedRegionLabel()}, assignee=${_selectedAssigneeLabel()}, targetPeriod=$_selectedTargetPeriod, dateRange=${_startDate.toIso8601String()} to ${_endDate.toIso8601String()}, period=$periodKey. '
        'Performance: ${_rows.map((r) => '${r.user.fullName ?? r.user.email}: Sales=${_periodValue(r.actualProducts, periodKey)}, Visits=${_periodValue(r.actualVisits, periodKey)}, Schools=${_periodValue(r.actualCustomers, periodKey)}').join(' | ')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildFilterBar(screenWidth),
              const SizedBox(height: 20),
              _buildReportDateBanner(),
              const SizedBox(height: 16),
              if (!_isLoading) _buildReportSummary(),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                  : _buildPerformanceGrid(screenWidth),
            ],
          ),
        ),
      ),
    );
  }

  // Header matching the "EOD Reports" Top Bar
  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'EOD Reports',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'End of day team performance summary',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        );

        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_currentUserRole <= 2)
              IconButton(
                icon: const Icon(Icons.smart_toy, color: AppColors.primaryDark),
                onPressed: _showAiAssistant,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                padding: EdgeInsets.zero,
              ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
              onPressed: _loadPerformance,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
            ),
            OutlinedButton.icon(
              onPressed: _showExportOptions,
              icon: const Icon(
                Icons.download_outlined,
                size: 16,
                color: Color(0xFF334155),
              ),
              label: const Text(
                'Export',
                style: TextStyle(color: Color(0xFF334155), fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 36),
              ),
            ),
          ],
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EOD Reports',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'End of day team performance summary',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              actions,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: actions,
            ),
          ],
        );
      },
    );
  }

  // Horizontal Filters Container Box
  Widget _buildFilterBar(double screenWidth) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 800;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildDropdownField(
                    'Scope',
                    _selectedScope,
                    _scopeOptions,
                    (v) {
                      if (v != null) {
                        _updateFilters(() {
                          _selectedScope = v;
                          if (v == 'regional') {
                            _selectedAssigneeOptionId = null;
                          } else {
                            _selectedRegionOptionId = null;
                          }
                        });
                      }
                    },
                    width: isWide ? 130 : double.infinity,
                    displayBuilder: (value) {
                      switch (value) {
                        case 'regional':
                          return 'Regional';
                        case 'agent':
                          return 'Agent';
                        case 'business_advisor':
                          return 'Business Advisor';
                        case 'sales_rep':
                          return 'Sales Rep';
                        default:
                          return value;
                      }
                    },
                  ),
                  if (_selectedScope == 'regional') ...[
                    _buildDropdownField(
                      'Region',
                      _selectedRegionOptionId ?? '',
                      List<String>.from(
                        [''] + _regionOptions.map((r) => r['id']!).toList(),
                      ),
                      (v) {
                        if (v != null) {
                          _updateFilters(() {
                            _selectedRegionOptionId = v.isEmpty ? null : v;
                          });
                        }
                      },
                      width: isWide ? 140 : double.infinity,
                      displayBuilder: (value) {
                        if (value == null || value.isEmpty)
                          return 'All Regions';
                        final match = _regionOptions.firstWhere(
                          (r) => r['id'] == value,
                          orElse: () => {'label': value},
                        );
                        return match['label'] ?? value;
                      },
                    ),
                  ],
                  if (_selectedScope != 'regional')
                    _buildDropdownField(
                      'Assignee',
                      _selectedAssigneeOptionId ?? '',
                      List<String>.from(
                        [''] + _assigneeOptions.map((a) => a['id']!).toList(),
                      ),
                      (v) {
                        if (v != null) {
                          _updateFilters(
                            () =>
                                _selectedAssigneeOptionId =
                                    v.isEmpty ? null : v,
                          );
                        }
                      },
                      width: isWide ? 170 : double.infinity,
                      displayBuilder: (value) {
                        if (value == null || value.isEmpty)
                          return 'All Assignees';
                        final match = _assigneeOptions.firstWhere(
                          (a) => a['id'] == value,
                          orElse: () => {'label': value},
                        );
                        return match['label'] ?? value;
                      },
                    ),
                  if (_selectedScope != 'regional') ...[
                    _buildDropdownField(
                      'Target Period',
                      _selectedTargetPeriod ?? '',
                      List<String>.from([''] + _targetPeriodOptions),
                      (v) {
                        if (v != null) {
                          _updateFilters(
                            () => _selectedTargetPeriod = v.isEmpty ? null : v,
                            reload: false,
                          );
                          _applyPeriodDateRange(v.isEmpty ? null : v);
                          _loadPerformance();
                        }
                      },
                      width: isWide ? 130 : double.infinity,
                      displayBuilder: (value) {
                        if (value.isEmpty) return 'All Periods';
                        return '${value[0].toUpperCase()}${value.substring(1)}';
                      },
                    ),
                    _buildDateField('Start Date', _startDate, (date) {
                      if (date != null) {
                        _updateFilters(() => _startDate = date);
                      }
                    }, width: isWide ? 130 : double.infinity),
                    _buildDateField('End Date', _endDate, (date) {
                      if (date != null) {
                        _updateFilters(() => _endDate = date);
                      }
                    }, width: isWide ? 130 : double.infinity),
                    _buildDropdownField(
                      'Sort By',
                      _sortBy,
                      ['All', 'School', 'Institution', 'Bookshop'],
                      (v) {
                        if (v != null) {
                          setState(() => _sortBy = v);
                        }
                      },
                      width: isWide ? 130 : double.infinity,
                    ),
                    SizedBox(
                      width: isWide ? 110 : double.infinity,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: _loadPerformance,
                        icon: const Icon(
                          Icons.search,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Get Report',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D273F),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    required double width,
    String Function(String value)? displayBuilder,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                items:
                    items
                        .map(
                          (String i) => DropdownMenuItem(
                            value: i,
                            child: Text(
                              displayBuilder != null ? displayBuilder(i) : i,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
    String label,
    DateTime date,
    ValueChanged<DateTime?> onSelected, {
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              onSelected(picked);
            },
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${_monthName(date.month).substring(0, 3)} ${date.day}, ${date.year}",
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Widget _buildReportDateBanner() {
    final regionLabel =
        _selectedRegionOptionId == null
            ? 'All Regions'
            : (_regionOptions.firstWhere(
                  (r) => r['id'] == _selectedRegionOptionId,
                  orElse: () => {'label': _selectedRegionOptionId!},
                )['label'] ??
                _selectedRegionOptionId);
    final assigneeLabel =
        _selectedAssigneeOptionId == null
            ? 'All Assignees'
            : (_assigneeOptions.firstWhere(
                  (a) => a['id'] == _selectedAssigneeOptionId,
                  orElse: () => {'label': _selectedAssigneeOptionId!},
                )['label'] ??
                _selectedAssigneeOptionId);
    final targetPeriodLabel = _selectedTargetPeriod ?? 'All Periods';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF7DD3FC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report: $_selectedScope${_selectedTargetPeriod != null ? " | $targetPeriodLabel" : ""}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$regionLabel | $assigneeLabel | ${_monthName(_startDate.month)} ${_startDate.day}, ${_startDate.year} - ${_monthName(_endDate.month)} ${_endDate.day}, ${_endDate.year}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSummary() {
    if (_rows.isEmpty) return const SizedBox.shrink();
    final periodKey = _selectedPeriodKey();

    final totalAssignees = _rows.length;
    final totalTargets = _rows.fold<int>(0, (sum, r) {
      return sum +
          r.productTargets.values.fold<int>(
            0,
            (s, v) => s + v.values.fold<int>(0, (ss, vv) => ss + vv),
          ) +
          r.visitTargets.values.fold<int>(0, (s, v) => s + v) +
          r.collectionTargets.values.fold<int>(0, (s, v) => s + v) +
          r.customerTargets.values.fold<int>(0, (s, v) => s + v) +
          r.sampleTargets.values.fold<int>(0, (s, v) => s + v);
    });
    final totalActualSales = _rows.fold<int>(
      0,
      (sum, r) => sum + _periodValue(r.actualProducts, periodKey),
    );
    final totalActualVisits = _rows.fold<int>(
      0,
      (sum, r) => sum + _combinedVisitValue(r, periodKey),
    );
    final totalActualCustomers = _rows.fold<int>(
      0,
      (sum, r) => sum + _periodValue(r.actualCustomers, periodKey),
    );
    final totalActualInstitutions = _rows.fold<int>(
      0,
      (sum, r) => sum + _periodValue(r.actualInstitutions, periodKey),
    );
    final totalActualBookshops = _rows.fold<int>(
      0,
      (sum, r) => sum + _periodValue(r.actualBookshops, periodKey),
    );
    final bestPerformer =
        _rows.isEmpty
            ? null
            : _rows.reduce(
              (a, b) =>
                  _periodValue(a.actualProducts, periodKey) >=
                          _periodValue(b.actualProducts, periodKey)
                      ? a
                      : b,
            );
    final avgSales =
        totalAssignees > 0 ? (totalActualSales / totalAssignees).round() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Summary',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final items = [
                {'label': 'Assignees', 'value': '$totalAssignees'},
                {'label': 'Targets Matched', 'value': '$totalTargets'},
                {
                  'label': 'Total Sales',
                  'value': _formatCount(totalActualSales),
                },
                {
                  'label': 'Total Visits',
                  'value': _formatCount(totalActualVisits),
                },
                {
                  'label': 'Schools Visited',
                  'value': _formatCount(totalActualCustomers),
                },
                {
                  'label': 'Institutions Visited',
                  'value': _formatCount(totalActualInstitutions),
                },
                {
                  'label': 'Bookshops Visited',
                  'value': _formatCount(totalActualBookshops),
                },
                {'label': 'Avg Sales', 'value': _formatCount(avgSales)},
                if (bestPerformer != null)
                  {
                    'label': 'Top Performer',
                    'value':
                        bestPerformer.user.fullName ?? bestPerformer.user.email,
                  },
              ];
              final crossAxisCount =
                  constraints.maxWidth > 800
                      ? 4
                      : (constraints.maxWidth > 500 ? 3 : 2);
              final gap = 12.0;
              final cardWidth =
                  (constraints.maxWidth - (gap * (crossAxisCount - 1))) /
                  crossAxisCount;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children:
                    items.map((item) {
                      return SizedBox(
                        width: cardWidth,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(minHeight: 76),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item['label']!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['value']!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // Multi-column cards grid layout
  Widget _buildPerformanceGrid(double screenWidth) {
    if (_rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text('No performance data found.'),
        ),
      );
    }

    var sortedRows = List<_PerformanceRow>.from(_rows);
    final periodKey = _selectedPeriodKey();
    if (_sortBy == 'All') {
      sortedRows.sort(
        (a, b) => _periodValue(
          b.actualVisits,
          periodKey,
        ).compareTo(_periodValue(a.actualVisits, periodKey)),
      );
    } else if (_sortBy == 'School') {
      sortedRows.sort(
        (a, b) => _periodValue(
          b.actualSchools,
          periodKey,
        ).compareTo(_periodValue(a.actualSchools, periodKey)),
      );
    } else if (_sortBy == 'Institution') {
      sortedRows.sort(
        (a, b) => _periodValue(
          b.actualInstitutions,
          periodKey,
        ).compareTo(_periodValue(a.actualInstitutions, periodKey)),
      );
    } else if (_sortBy == 'Bookshop') {
      sortedRows.sort(
        (a, b) => _periodValue(
          b.actualBookshops,
          periodKey,
        ).compareTo(_periodValue(a.actualBookshops, periodKey)),
      );
    }

    int crossAxisCount = screenWidth > 1200 ? 3 : (screenWidth > 768 ? 2 : 1);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemCount: sortedRows.length,
      itemBuilder: (context, index) {
        return _buildPersonCard(sortedRows[index], index + 1);
      },
    );
  }

  // Individual Team Member Card matching exact reference design
  Widget _buildPersonCard(_PerformanceRow row, int rank) {
    final periodKey = _selectedPeriodKey();
    final totalSales = _periodValue(row.actualProducts, periodKey);
    final metrics = _buildPersonMetrics(row, periodKey);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFF6D273F),
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          row.user.fullName ?? row.user.email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Total Sales',
                      style: TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                    ),
                    Text(
                      _formatCount(totalSales),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: metrics.length,
              itemBuilder: (context, idx) {
                final isZebra = idx % 2 == 1;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  color: isZebra ? const Color(0xFFF8FAFC) : Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        metrics[idx].label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF475569),
                        ),
                      ),
                      Text(
                        metrics[idx].value,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAiAssistant() async {
    final messages = <Map<String, String>>[];
    final controller = TextEditingController();
    final contextSummary = _buildPerformanceContext();
    bool isWaiting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.smart_toy, color: AppColors.primaryDark),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('AI Assistant')),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isUser = msg['role'] == 'user';
                          return Align(
                            alignment:
                                isUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    isUser
                                        ? AppColors.primaryDark
                                        : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                msg['content'] ?? '',
                                style: TextStyle(
                                  color: isUser ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (isWaiting)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'Ask about performance...',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isEmpty || isWaiting) return;
                          _sendAiMessage(
                            controller,
                            messages,
                            setState,
                            contextSummary,
                            (v) {
                              setState(() => isWaiting = v);
                            },
                          ).then((_) {
                            controller.clear();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed:
                          isWaiting
                              ? null
                              : () {
                                if (controller.text.trim().isEmpty) return;
                                _sendAiMessage(
                                  controller,
                                  messages,
                                  setState,
                                  contextSummary,
                                  (v) {
                                    setState(() => isWaiting = v);
                                  },
                                ).then((_) {
                                  controller.clear();
                                });
                              },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendAiMessage(
    TextEditingController controller,
    List<Map<String, String>> messages,
    StateSetter setState,
    String contextSummary,
    void Function(bool) setWaiting,
  ) async {
    final userMessage = controller.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      messages.add({'role': 'user', 'content': userMessage});
    });

    try {
      setWaiting(true);
      final response = await http.post(
        Uri.parse(ApiConfig.aiChatUrl()),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messages':
              messages
                  .map((m) => {'role': m['role'], 'content': m['content']})
                  .toList(),
          'context': contextSummary,
        }),
      );

      setWaiting(false);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final assistantMessage =
            data['choices']?[0]?['message']?['content'] ??
            'Sorry, I could not generate a response.';
        setState(() {
          messages.add({'role': 'assistant', 'content': assistantMessage});
        });
      } else {
        setState(() {
          messages.add({
            'role': 'assistant',
            'content': 'Error: ${response.statusCode}',
          });
        });
      }
    } catch (e) {
      setWaiting(false);
      setState(() {
        messages.add({'role': 'assistant', 'content': 'Error: $e'});
      });
    }
  }
}

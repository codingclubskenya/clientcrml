import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';

import '../../core/constants/colors.dart';
import '../../features/database/database_service.dart';
import '../../../models/farmer_model.dart';
import '../../../models/order_item_model.dart';
import '../../../models/order_model.dart';
import '../../../models/pipeline_stage.dart';
import '../../../models/region_model.dart';
import '../../../models/school_sale_model.dart';
import '../../../models/target_model.dart';
import '../../../models/user_model.dart';
import '../../../services/outreach_report_service.dart';
import 'utils/csv_download_stub.dart'
    if (dart.library.html) 'utils/csv_download_web.dart'
    if (dart.library.io) 'utils/csv_download_io.dart'
    show downloadCsvTemplate;

class Role2SchoolsOutreachPage extends StatefulWidget {
  const Role2SchoolsOutreachPage({super.key});

  @override
  State<Role2SchoolsOutreachPage> createState() =>
      _Role2SchoolsOutreachPageState();
}

class _Role2SchoolsOutreachPageState extends State<Role2SchoolsOutreachPage> {
  final DatabaseService _dbService = DatabaseService();
  final _supabase = Supabase.instance.client;

  List<UserModel> _agents = <UserModel>[];
  List<RegionModel> _regions = <RegionModel>[];
  List<SchoolModel> _schools = <SchoolModel>[];
  List<OrderModel> _orders = <OrderModel>[];
  List<OrderItemModel> _orderItems = <OrderItemModel>[];
  List<SchoolSaleModel> _sales = <SchoolSaleModel>[];
  List<Map<String, dynamic>> _visits = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _activities = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _debts = <Map<String, dynamic>>[];
  List<TargetModel> _targets = <TargetModel>[];

  String? _selectedRegionId;
  String? _selectedAgentId;

  bool _isLoading = true;
  String? _error;
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await _dbService.getAllUsers();
      final regions = await _dbService.getAllRegions();

      final agents = users.where((u) => u.role == 4).toList();
      final agentIds = agents.map((a) => a.id).toSet().toList();

      final regionIdFilter = _selectedRegionId;
      final agentIdFilter = _selectedAgentId;

      final filteredAgentIds = <String>{};
      if (regionIdFilter != null) {
        for (final a in agents) {
          if (a.regionId == regionIdFilter) filteredAgentIds.add(a.id);
        }
      }
      if (agentIdFilter != null) {
        filteredAgentIds.add(agentIdFilter);
      }
      if (regionIdFilter == null && agentIdFilter == null) {
        filteredAgentIds.addAll(agentIds);
      }

      final schoolsQuery = _supabase
          .from('schools')
          .select()
          .order('created_at', ascending: false)
          .limit(500);
      final schoolsAll = (await schoolsQuery) as List;
      final schools = schoolsAll
          .map((s) => SchoolModel.fromMap(Map<String, dynamic>.from(s)))
          .where((s) {
            if (s.capturedBy == null || s.capturedBy!.isEmpty) return false;
            return filteredAgentIds.contains(s.capturedBy);
          })
          .toList();

      final schoolIds = schools.map((s) => s.id).toList();

      final ordersQuery = _supabase
          .from('orders')
          .select()
          .order('created_at', ascending: false)
          .limit(1000);
      final ordersData = await ordersQuery;
      final orders = (ordersData as List)
          .map((o) => OrderModel.fromMap(Map<String, dynamic>.from(o)))
          .where((o) => o.agentId == null ? false : filteredAgentIds.contains(o.agentId))
          .toList();

      final orderIds = orders.map((o) => o.id).toList();
      final orderItems = <OrderItemModel>[];
      if (orderIds.isNotEmpty) {
        final itemsQuery = _supabase
            .from('order_items')
            .select()
            .limit(5000);
        final items = await itemsQuery;
        orderItems.addAll(
          (items as List).map((i) => OrderItemModel.fromMap(Map<String, dynamic>.from(i))).where((i) => orderIds.contains(i.orderId)).toList(),
        );
      }

      final sales = <SchoolSaleModel>[];
      if (schoolIds.isNotEmpty) {
        final salesQuery = _supabase
            .from('school_sales')
            .select()
            .order('created_at', ascending: false)
            .limit(1000);
        final salesData = await salesQuery;
        sales.addAll(
          (salesData as List).map((s) => SchoolSaleModel.fromMap(Map<String, dynamic>.from(s))).where((s) => schoolIds.contains(s.schoolId)).toList(),
        );
      }

      final visits = <Map<String, dynamic>>[];
      if (schoolIds.isNotEmpty) {
        final visitsData = await _supabase
            .from('school_visits')
            .select()
            .order('visited_at', ascending: false)
            .limit(1000);
        visits.addAll(List<Map<String, dynamic>>.from(visitsData as List).where((v) => schoolIds.contains((v['school_id'] ?? '').toString())).toList());
      }

      final activities = <Map<String, dynamic>>[];
      if (schoolIds.isNotEmpty) {
        final activitiesData = await _supabase
            .from('opportunity_activities')
            .select()
            .order('created_at', ascending: false)
            .limit(1000);
        activities.addAll(List<Map<String, dynamic>>.from(activitiesData as List).where((a) => schoolIds.contains((a['school_id'] ?? '').toString())).toList());
      }

      final debts = <Map<String, dynamic>>[];
      if (schoolIds.isNotEmpty) {
        final debtsData = await _supabase
            .from('debt_collections')
            .select()
            .limit(1000);
        debts.addAll(List<Map<String, dynamic>>.from(debtsData as List).where((d) => schoolIds.contains((d['school_id'] ?? '').toString())).toList());
      }

      final targetsData = await _supabase
          .from('targets')
          .select()
          .limit(500);
      final targets = (targetsData as List)
          .map((item) => TargetModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted) return;
      setState(() {
        _agents = agents;
        _regions = regions;
        _schools = schools;
        _orders = orders;
        _orderItems = orderItems;
        _sales = sales;
        _visits = visits;
        _activities = activities;
        _debts = debts;
        _targets = targets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _buildReportRows() {
    final agents = _agents;
    final regions = _regions;
    final schools = _schools;
    final orders = _orders;
    final orderItems = _orderItems;
    final sales = _sales;
    final targets = _targets;
    final visits = _visits;
    final activities = _activities;
    final debts = _debts;

    final regionMap = <String, RegionModel>{};
    for (final r in regions) {
      if (r.id != null && r.id!.isNotEmpty) regionMap[r.id!] = r;
    }

    final userMap = <String, UserModel>{};
    for (final u in agents) {
      userMap[u.id] = u;
    }

    final agentSchoolMap = <String, List<SchoolModel>>{};
    for (final s in schools) {
      final agentId = s.capturedBy;
      if (agentId == null || agentId.isEmpty) continue;
      agentSchoolMap.putIfAbsent(agentId, () => <SchoolModel>[]).add(s);
    }

    final agentVisitsMap = <String, int>{};
    for (final v in visits) {
      final actorId = (v['actor_id'] ?? '').toString();
      final schoolId = (v['school_id'] ?? '').toString();
      if (actorId.isNotEmpty && userMap.containsKey(actorId)) {
        agentVisitsMap[actorId] = (agentVisitsMap[actorId] ?? 0) + 1;
      } else if (schoolId.isNotEmpty) {
        final schoolMatches = schools.where((s) => s.id == schoolId).toList();
        final school = schoolMatches.isNotEmpty ? schoolMatches.first : null;
        final agentId = school?.capturedBy;
        if (agentId != null && agentId.isNotEmpty) {
          agentVisitsMap[agentId] = (agentVisitsMap[agentId] ?? 0) + 1;
        }
      }
    }

    final agentCallsMap = <String, int>{};
    for (final a in activities) {
      final type = (a['activity_type'] ?? '').toString().toLowerCase();
      if (type != 'call' && type != 'phone') continue;
      final actorId = (a['actor_id'] ?? '').toString();
      final schoolId = (a['school_id'] ?? '').toString();
      if (actorId.isNotEmpty && userMap.containsKey(actorId)) {
        agentCallsMap[actorId] = (agentCallsMap[actorId] ?? 0) + 1;
      } else if (schoolId.isNotEmpty) {
        final schoolMatches = schools.where((s) => s.id == schoolId).toList();
        final school = schoolMatches.isNotEmpty ? schoolMatches.first : null;
        final agentId = school?.capturedBy;
        if (agentId != null && agentId.isNotEmpty) {
          agentCallsMap[agentId] = (agentCallsMap[agentId] ?? 0) + 1;
        }
      }
    }

    final agentOrderQtyMap = <String, int>{};
    final agentClosedQtyMap = <String, int>{};
    final agentDebtMap = <String, double>{};

    final paidOrderIds = <String>{};
    for (final o in orders) {
      if (o.status.toLowerCase() == 'paid') paidOrderIds.add(o.id);
    }

    for (final item in orderItems) {
      final orderMatches = orders.where((o) => o.id == item.orderId).toList();
      final order = orderMatches.isNotEmpty ? orderMatches.first : null;
      final agentId = order?.agentId;
      if (agentId == null || agentId.isEmpty) continue;
      final qty = item.quantity;
      if (paidOrderIds.contains(item.orderId)) {
        agentClosedQtyMap[agentId] = (agentClosedQtyMap[agentId] ?? 0) + qty;
      }
      agentOrderQtyMap[agentId] = (agentOrderQtyMap[agentId] ?? 0) + qty;
    }

    for (final d in debts) {
      final collectedBy = (d['collected_by'] ?? '').toString();
      if (collectedBy.isEmpty || !userMap.containsKey(collectedBy)) continue;
      final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
      agentDebtMap[collectedBy] = (agentDebtMap[collectedBy] ?? 0.0) + amount;
    }

    final weeklyTargetMap = <String, int>{};
    for (final t in targets) {
      if (t.targetType != 'product_sales' || t.targetPeriod != 'weekly') continue;
      final agentId = t.assignedTo;
      if (agentId == null || agentId.isEmpty) continue;
      final productTarget = t.targetData['product'] ?? t.targetData['total'] ?? 0;
      final qty = productTarget is int
          ? productTarget
          : productTarget is double
              ? productTarget.toInt()
              : int.tryParse(productTarget.toString()) ?? 0;
      weeklyTargetMap[agentId] = qty;
    }

    final selectedAgentIds = _selectedAgentId == null ? null : <String>{_selectedAgentId!};
    final selectedRegionIds = _selectedRegionId == null
        ? null
        : _regions
            .where((r) => r.id == _selectedRegionId)
            .map((r) => r.id!)
            .toSet();

    final rows = <Map<String, dynamic>>[];
    for (final agent in agents) {
      if (selectedAgentIds != null && !selectedAgentIds.contains(agent.id)) continue;
      final agentSchools = agentSchoolMap[agent.id] ?? <SchoolModel>[];
      if (selectedRegionIds != null && selectedRegionIds.isNotEmpty) {
        final agentRegionId = agent.regionId;
        if (agentRegionId == null || !selectedRegionIds.contains(agentRegionId)) continue;
      }

      final region = agent.regionId != null ? regionMap[agent.regionId] : null;
      final regionName = region?.region ?? agent.region ?? '';

      for (final school in agentSchools) {
        final schoolVisits = visits.where((v) => v['school_id'] == school.id).toList();
        final schoolCalls = activities.where((a) => a['school_id'] == school.id && (a['activity_type'] ?? '').toString().toLowerCase() == 'call').toList();
        final interactionType = schoolVisits.isNotEmpty ? 'Visit' : schoolCalls.isNotEmpty ? 'Phone Call' : '';

        final schoolSalesList = sales.where((s) => s.schoolId == school.id).toList();
        final closedWonQty = schoolSalesList.where((s) => s.stage == PipelineStage.won).length;

        final schoolDebtsList = debts.where((d) => d['school_id'] == school.id);
        final schoolDebtTotal = schoolDebtsList.fold<double>(0.0, (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0.0));

        rows.add({
          'region': regionName,
          'agent': agent.fullName ?? agent.email,
          'date': school.capturedAt != null ? _formatDate(school.capturedAt!) : '',
          'school': school.name,
          'type': '${school.dealerType ?? ''}${school.dealerType != null && school.bookCategory != null ? ' / ' : ''}${school.bookCategory ?? ''}',
          'competitor': school.competitorAnalysis ?? '',
          'level': school.schoolLevel ?? '',
          'status': school.captureStatus ?? '',
          'population': school.schoolPopulation?.toString() ?? '',
          'interaction': interactionType,
          'contact': school.contactName ?? '',
          'designation': school.designation ?? '',
          'contacts': school.phone,
          'feedback': '${school.feedback ?? ''} ${school.notes ?? ''}'.trim(),
          'projectedQty': school.projectedQuantity?.toString() ?? '',
          'closedWonQty': closedWonQty.toString(),
          'debtKes': schoolDebtTotal.toStringAsFixed(0),
          'agentSchoolsCount': agentSchools.length.toString(),
          'agentVisits': (agentVisitsMap[agent.id] ?? 0).toString(),
          'agentCalls': (agentCallsMap[agent.id] ?? 0).toString(),
          'agentProjectedQty': agentSchools.fold<int>(0, (sum, s) => sum + (s.projectedQuantity ?? 0)).toString(),
          'agentClosedQty': (agentClosedQtyMap[agent.id] ?? 0).toString(),
          'agentDebtKes': (agentDebtMap[agent.id] ?? 0.0).toStringAsFixed(0),
          'weeklyTarget': (weeklyTargetMap[agent.id] ?? 0).toString(),
          'achieved': (agentClosedQtyMap[agent.id] ?? 0).toString(),
        });
      }

      if (agentSchools.isEmpty) {
        rows.add({
          'region': regionName,
          'agent': agent.fullName ?? agent.email,
          'date': '',
          'school': '',
          'type': '',
          'competitor': '',
          'level': '',
          'status': '',
          'population': '',
          'interaction': '',
          'contact': '',
          'designation': '',
          'contacts': '',
          'feedback': '',
          'projectedQty': '',
          'closedWonQty': '',
          'debtKes': '',
          'agentSchoolsCount': '0',
          'agentVisits': (agentVisitsMap[agent.id] ?? 0).toString(),
          'agentCalls': (agentCallsMap[agent.id] ?? 0).toString(),
          'agentProjectedQty': '0',
          'agentClosedQty': '0',
          'agentDebtKes': '0',
          'weeklyTarget': (weeklyTargetMap[agent.id] ?? 0).toString(),
          'achieved': '0',
        });
      }
    }

    return rows;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _exportCsv() async {
    final rows = _buildReportRows();
    if (rows.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export.')),
      );
      return;
    }

    final headers = [
      'Region',
      'Sales Agent',
      'Date',
      'Name of School',
      'School Type',
      'Competitor Analysis',
      'School Level',
      'Status',
      'Population',
      'Visit/Phone Call',
      'Contact Person',
      'Designation',
      'Contacts',
      'Feedback and Next Steps',
      'Projected Sales (Quantities)',
      'Closed/Won (Quantities)',
      'Debts Collected (KES)',
      'Schools',
      'Total No of Visits',
      'Total No of phone calls',
      'Sum of projected (Quantities)',
      'Total closed (Quantities)',
      'Debts collected (KES)',
      'Weekly Target (Quantities)',
      'Achieved (Quantities)',
      'Variance (Quantities)',
      'Balance carried forward (Quantities)',
    ];

    final buffer = StringBuffer('${headers.map(_csvEscape).join(',')}\n');

    for (final row in rows) {
      final weeklyTarget = int.tryParse(row['weeklyTarget'].toString()) ?? 0;
      final achieved = int.tryParse(row['achieved'].toString()) ?? 0;
      final variance = weeklyTarget - achieved;

      final values = [
        row['region'].toString(),
        row['agent'].toString(),
        row['date'].toString(),
        row['school'].toString(),
        row['type'].toString(),
        row['competitor'].toString(),
        row['level'].toString(),
        row['status'].toString(),
        row['population'].toString(),
        row['interaction'].toString(),
        row['contact'].toString(),
        row['designation'].toString(),
        row['contacts'].toString(),
        row['feedback'].toString(),
        row['projectedQty'].toString(),
        row['closedWonQty'].toString(),
        row['debtKes'].toString(),
        row['agentSchoolsCount'].toString(),
        row['agentVisits'].toString(),
        row['agentCalls'].toString(),
        row['agentProjectedQty'].toString(),
        row['agentClosedQty'].toString(),
        row['agentDebtKes'].toString(),
        weeklyTarget.toString(),
        achieved.toString(),
        variance.toString(),
        '0',
      ];
      buffer.writeln(values.map(_csvEscape).join(','));
    }

    final fileName = 'schools_outreach_report_${_formatDate(DateTime.now())}.csv';
    try {
      await downloadCsvTemplate(fileName, buffer.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to Downloads: $fileName')),
      );
    } on UnsupportedError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download not supported on this device.'),
        ),
      );
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _isExportingPdf = true);
    try {
      final reportService = OutreachReportService();
      final pdfBytes = await reportService.generateOutreachPdf(
        agents: _agents,
        regions: _regions,
        schools: _schools,
        visits: _visits,
        activities: _activities,
        debts: _debts,
        orders: _orders,
        orderItems: _orderItems,
        sales: _sales,
        targets: _targets,
        selectedRegionId: _selectedRegionId,
        selectedAgentId: _selectedAgentId,
      );

      final fileName = 'schools_outreach_report_${_formatDate(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF exported: $fileName')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        title: const Text('Schools Outreach'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isExportingPdf
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf),
            onPressed: _isExportingPdf ? null : _exportPdf,
            tooltip: 'Export PDF',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportCsv,
            tooltip: 'Export CSV',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildFilters(),
        Expanded(child: _buildTable()),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedRegionId,
            decoration: const InputDecoration(
              labelText: 'Region',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            hint: const Text('All Regions'),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('All Regions')),
              ..._regions.map((r) => DropdownMenuItem<String>(value: r.id, child: Text(r.region))),
            ],
            onChanged: (value) => setState(() => _selectedRegionId = value),
          ),
          DropdownButtonFormField<String>(
            value: _selectedAgentId,
            decoration: const InputDecoration(
              labelText: 'Sales Agent',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            hint: const Text('All Agents'),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('All Agents')),
              ..._agents.map((a) => DropdownMenuItem<String>(value: a.id, child: Text(a.fullName ?? a.email))),
            ],
            onChanged: (value) => setState(() => _selectedAgentId = value),
          ),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final rows = _buildReportRows();
    if (rows.isEmpty) {
      return const Center(
        child: Text('No outreach data found for the selected filters.'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Region')),
            DataColumn(label: Text('Sales Agent')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Name of School')),
            DataColumn(label: Text('School Type')),
            DataColumn(label: Text('Competitor Analysis')),
            DataColumn(label: Text('School Level')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Population')),
            DataColumn(label: Text('Visit/Phone Call')),
            DataColumn(label: Text('Contact Person')),
            DataColumn(label: Text('Designation')),
            DataColumn(label: Text('Contacts')),
            DataColumn(label: Text('Feedback and Next Steps')),
            DataColumn(label: Text('Projected Sales')),
            DataColumn(label: Text('Closed/Won')),
            DataColumn(label: Text('Debts Collected (KES)')),
            DataColumn(label: Text('Schools')),
            DataColumn(label: Text('Total Visits')),
            DataColumn(label: Text('Total Phone Calls')),
            DataColumn(label: Text('Sum of projected')),
            DataColumn(label: Text('Total closed')),
            DataColumn(label: Text('Debts collected (KES)')),
            DataColumn(label: Text('Weekly Target')),
            DataColumn(label: Text('Achieved')),
            DataColumn(label: Text('Variance')),
            DataColumn(label: Text('Balance carried forward')),
          ],
          rows: rows.map((row) {
            final weeklyTarget = int.tryParse(row['weeklyTarget'].toString()) ?? 0;
            final achieved = int.tryParse(row['achieved'].toString()) ?? 0;
            final variance = weeklyTarget - achieved;

            return DataRow(
              cells: [
                DataCell(Text(row['region'].toString())),
                DataCell(Text(row['agent'].toString())),
                DataCell(Text(row['date'].toString())),
                DataCell(Text(row['school'].toString())),
                DataCell(Text(row['type'].toString())),
                DataCell(Text(row['competitor'].toString())),
                DataCell(Text(row['level'].toString())),
                DataCell(Text(row['status'].toString())),
                DataCell(Text(row['population'].toString())),
                DataCell(Text(row['interaction'].toString())),
                DataCell(Text(row['contact'].toString())),
                DataCell(Text(row['designation'].toString())),
                DataCell(Text(row['contacts'].toString())),
                DataCell(Text(_truncate(row['feedback'].toString(), 40))),
                DataCell(Text(row['projectedQty'].toString())),
                DataCell(Text(row['closedWonQty'].toString())),
                DataCell(Text(row['debtKes'].toString())),
                DataCell(Text(row['agentSchoolsCount'].toString())),
                DataCell(Text(row['agentVisits'].toString())),
                DataCell(Text(row['agentCalls'].toString())),
                DataCell(Text(row['agentProjectedQty'].toString())),
                DataCell(Text(row['agentClosedQty'].toString())),
                DataCell(Text(row['agentDebtKes'].toString())),
                DataCell(Text(weeklyTarget.toString())),
                DataCell(Text(achieved.toString())),
                DataCell(Text(variance.toString())),
                DataCell(const Text('0')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _truncate(String value, int max) {
    if (value.length <= max) return value;
    return '${value.substring(0, max)}...';
  }
}

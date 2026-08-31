import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/farmer_model.dart';
import '../../models/order_item_model.dart';
import '../../models/order_model.dart';
import '../../models/pipeline_stage.dart';
import '../../models/region_model.dart';
import '../../models/school_sale_model.dart';
import '../../models/target_model.dart';
import '../../models/user_model.dart';

class OutreachReportService {
  Future<Uint8List> generateOutreachPdf({
    required List<UserModel> agents,
    required List<RegionModel> regions,
    required List<SchoolModel> schools,
    required List<Map<String, dynamic>> visits,
    required List<Map<String, dynamic>> activities,
    required List<Map<String, dynamic>> debts,
    required List<OrderModel> orders,
    required List<OrderItemModel> orderItems,
    required List<SchoolSaleModel> sales,
    required List<TargetModel> targets,
    String? selectedRegionId,
    String? selectedAgentId,
  }) async {
    final pdf = pw.Document();
    final generatedAt = DateTime.now();

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
    final lastVisitBySchool = <String, DateTime>{};
    for (final v in visits) {
      final actorId = (v['actor_id'] ?? '').toString();
      final schoolId = (v['school_id'] ?? '').toString();
      if (actorId.isNotEmpty && userMap.containsKey(actorId)) {
        agentVisitsMap[actorId] = (agentVisitsMap[actorId] ?? 0) + 1;
      } else if (schoolId.isNotEmpty) {
        final schoolMatches = schools.where((s) => s.id == schoolId).toList();
        final school = schoolMatches.isNotEmpty ? schoolMatches.first : null;
        final capturedBy = school?.capturedBy;
        if (capturedBy != null && capturedBy.isNotEmpty) {
          agentVisitsMap[capturedBy] = (agentVisitsMap[capturedBy] ?? 0) + 1;
        }
      }
      if (schoolId.isNotEmpty) {
        final visitedAt = DateTime.tryParse(v['visited_at']?.toString() ?? '');
        if (visitedAt != null) {
          final existing = lastVisitBySchool[schoolId];
          if (existing == null || visitedAt.isAfter(existing)) {
            lastVisitBySchool[schoolId] = visitedAt;
          }
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
        final capturedBy = school?.capturedBy;
        if (capturedBy != null && capturedBy.isNotEmpty) {
          agentCallsMap[capturedBy] = (agentCallsMap[capturedBy] ?? 0) + 1;
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

    final selectedAgentIds = selectedAgentId == null ? null : <String>{selectedAgentId};
    final selectedRegionIds = selectedRegionId == null
        ? null
        : <String>{selectedRegionId};

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

        final lastVisit = lastVisitBySchool[school.id];
        final lastVisitStr = lastVisit != null ? _formatDateTime(lastVisit) : 'No visits';
        final capturedAtStr = school.capturedAt != null ? _formatDateTime(school.capturedAt!) : 'N/A';
        final isActiveLast5Days = lastVisit != null && generatedAt.difference(lastVisit).inDays <= 5;

        rows.add({
          'region': regionName,
          'agent': agent.fullName ?? agent.email,
          'onboardedBy': agent.fullName ?? agent.email,
          'onboardingDate': capturedAtStr,
          'school': school.name,
          'status': school.captureStatus ?? 'Active',
          'lastVisit': lastVisitStr,
          'activeLast5Days': isActiveLast5Days ? 'Yes' : 'No',
          'type': '${school.dealerType ?? ''}${school.dealerType != null && school.bookCategory != null ? ' / ' : ''}${school.bookCategory ?? ''}',
          'level': school.schoolLevel ?? '',
          'population': school.schoolPopulation?.toString() ?? '',
          'interaction': interactionType,
          'contact': school.contactName ?? '',
          'contacts': school.phone,
          'projectedQty': school.projectedQuantity?.toString() ?? '0',
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
          'onboardedBy': agent.fullName ?? agent.email,
          'onboardingDate': 'N/A',
          'school': 'No schools assigned',
          'status': 'N/A',
          'lastVisit': 'N/A',
          'activeLast5Days': 'No',
          'type': '',
          'level': '',
          'population': '',
          'interaction': '',
          'contact': '',
          'contacts': '',
          'projectedQty': '0',
          'closedWonQty': '0',
          'debtKes': '0',
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

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
        ),
        build: (context) {
          return [
            _buildHeader(generatedAt, selectedRegionId, selectedAgentId, regionMap, userMap),
            pw.SizedBox(height: 16),
            _buildSummaryTable(rows),
            pw.SizedBox(height: 20),
            _buildAgentSummary(rows),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(DateTime generatedAt, String? selectedRegionId, String? selectedAgentId, Map<String, RegionModel> regionMap, Map<String, UserModel> userMap) {
    final regionName = selectedRegionId != null ? regionMap[selectedRegionId]?.region ?? 'All Regions' : 'All Regions';
    final agentName = selectedAgentId != null ? userMap[selectedAgentId]?.fullName ?? 'All Agents' : 'All Agents';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Schools Outreach Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Generated: ${_formatDateTime(generatedAt)}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
        pw.SizedBox(height: 4),
        pw.Text('Region: $regionName', style: pw.TextStyle(fontSize: 10)),
        pw.Text('Agent: $agentName', style: pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildSummaryTable(List<Map<String, dynamic>> rows) {
    final headers = [
      'Agent',
      'Onboarded By',
      'School',
      'Status',
      'Last Visit',
      'Active (5d)',
      'Interaction',
      'Closed/Won',
      'Debt (KES)',
      'Visits',
      'Calls',
      'Weekly Target',
      'Achieved',
      'Variance',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Outreach Details', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.2),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(1.4),
            3: pw.FlexColumnWidth(0.8),
            4: pw.FlexColumnWidth(1.0),
            5: pw.FlexColumnWidth(0.7),
            6: pw.FlexColumnWidth(0.8),
            7: pw.FlexColumnWidth(0.7),
            8: pw.FlexColumnWidth(0.8),
            9: pw.FlexColumnWidth(0.6),
            10: pw.FlexColumnWidth(0.6),
            11: pw.FlexColumnWidth(0.8),
            12: pw.FlexColumnWidth(0.7),
            13: pw.FlexColumnWidth(0.7),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: headers.map((h) => pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))).toList(),
            ),
            for (final row in rows)
              pw.TableRow(
                children: [
                  _cell(row['agent'].toString()),
                  _cell(row['onboardedBy'].toString()),
                  _cell(row['school'].toString()),
                  _cell(row['status'].toString()),
                  _cell(row['lastVisit'].toString()),
                  _cell(row['activeLast5Days'].toString()),
                  _cell(row['interaction'].toString()),
                  _cell(row['closedWonQty'].toString()),
                  _cell(row['debtKes'].toString()),
                  _cell(row['agentVisits'].toString()),
                  _cell(row['agentCalls'].toString()),
                  _cell(row['weeklyTarget'].toString()),
                  _cell(row['achieved'].toString()),
                  _cell((((int.tryParse(row['weeklyTarget'].toString()) ?? 0) - (int.tryParse(row['achieved'].toString()) ?? 0))).toString()),
                ],
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildAgentSummary(List<Map<String, dynamic>> rows) {
    final agentSummary = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final agent = row['agent'].toString();
      if (!agentSummary.containsKey(agent)) {
        agentSummary[agent] = {
          'schools': 0,
          'visits': 0,
          'calls': 0,
          'closed': 0,
          'debt': 0.0,
          'target': 0,
          'achieved': 0,
        };
      }
      final summary = agentSummary[agent]!;
      summary['schools'] = (summary['schools'] as int) + 1;
      summary['visits'] = (summary['visits'] as int) + (int.tryParse(row['agentVisits'].toString()) ?? 0);
      summary['calls'] = (summary['calls'] as int) + (int.tryParse(row['agentCalls'].toString()) ?? 0);
      summary['closed'] = (summary['closed'] as int) + (int.tryParse(row['closedWonQty'].toString()) ?? 0);
      summary['debt'] = (summary['debt'] as double) + (double.tryParse(row['debtKes'].toString()) ?? 0.0);
      summary['target'] = (summary['target'] as int) + (int.tryParse(row['weeklyTarget'].toString()) ?? 0);
      summary['achieved'] = (summary['achieved'] as int) + (int.tryParse(row['achieved'].toString()) ?? 0);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Agent Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: pw.FlexColumnWidth(1.5),
            1: pw.FlexColumnWidth(0.8),
            2: pw.FlexColumnWidth(0.8),
            3: pw.FlexColumnWidth(0.8),
            4: pw.FlexColumnWidth(1.0),
            5: pw.FlexColumnWidth(0.8),
            6: pw.FlexColumnWidth(0.8),
            7: pw.FlexColumnWidth(0.8),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: ['Agent', 'Schools', 'Visits', 'Calls', 'Closed Qty', 'Debt (KES)', 'Target', 'Achieved'].map((h) => pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))).toList(),
            ),
            for (final entry in agentSummary.entries)
              pw.TableRow(
                children: [
                  _cell(entry.key),
                  _cell(entry.value['schools'].toString()),
                  _cell(entry.value['visits'].toString()),
                  _cell(entry.value['calls'].toString()),
                  _cell(entry.value['closed'].toString()),
                  _cell((entry.value['debt'] as double).toStringAsFixed(0)),
                  _cell(entry.value['target'].toString()),
                  _cell(entry.value['achieved'].toString()),
                ],
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget _cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

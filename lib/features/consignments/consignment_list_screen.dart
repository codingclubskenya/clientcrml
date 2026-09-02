import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/consignment_item_model.dart';
import '../../models/consignment_model.dart';
import '../../services/catalog_service.dart';
import '../catalog/catalog_theme.dart';
import 'create_consignment_screen.dart';

class ConsignmentListScreen extends StatefulWidget {
  const ConsignmentListScreen({super.key});

  @override
  State<ConsignmentListScreen> createState() => _ConsignmentListScreenState();
}

class _ConsignmentListScreenState extends State<ConsignmentListScreen> {
  final _service = CatalogService.instance;
  String _search = '';
  String? _baFilter;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  List<Consignment> get _consignments => _service.consignments;

  List<String> get _businessAssociates =>
      _consignments.map((c) => c.businessAssociateName).toSet().toList()..sort();

  List<Consignment> get _filtered {
    return _consignments.where((c) {
      if (_baFilter != null && c.businessAssociateName != _baFilter) {
        return false;
      }
      if (_search.isNotEmpty) {
        final s = _search.toLowerCase();
        final inItems = c.items.any((i) =>
            i.product.name.toLowerCase().contains(s) ||
            c.consignmentId.toLowerCase().contains(s));
        final inBa = c.businessAssociateName.toLowerCase().contains(s);
        if (!inItems && !inBa) return false;
      }
      return true;
    }).toList();
  }

  int get _totalAssignments => _consignments.length;
  int get _totalUnits =>
      _consignments.fold(0, (s, c) => s + c.totalUnitsAssigned);
  int get _totalUnitsSold =>
      _consignments.fold(0, (s, c) => s + c.totalUnitsSold);
  int get _totalUnitsRemaining =>
      _consignments.fold(0, (s, c) => s + c.totalUnitsRemaining);

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<Consignment>(
      MaterialPageRoute(
        builder: (_) => CreateConsignmentScreen(
          businessAssociates: _businessAssociates,
          availableProducts: _service.products,
        ),
      ),
    );
    if (created != null) {
      _service.addConsignment(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CatalogColors.neutralBackground,
      appBar: AppBar(
        title: const Text('Stock Assignments'),
        backgroundColor: CatalogColors.primaryAccent,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: CatalogColors.primaryAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Consignment'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => Future.delayed(const Duration(milliseconds: 400)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _summaryCards(),
            const SizedBox(height: 16),
            _filterToolbar(),
            const SizedBox(height: 12),
            _table(),
          ],
        ),
      ),
    );
  }

  Widget _summaryCards() {
    final cards = [
      _summary(
        'Total Assignments',
        _totalAssignments.toString(),
        Icons.assignment_outlined,
        CatalogColors.primaryAccent,
      ),
      _summary(
        'Cumulative Units',
        _totalUnits.toString(),
        Icons.inventory_2_outlined,
        CatalogColors.secondaryAction,
      ),
      _summary(
        'Units Sold',
        _totalUnitsSold.toString(),
        Icons.sell_outlined,
        CatalogColors.inStockText,
      ),
      _summary(
        'Units Remaining',
        _totalUnitsRemaining.toString(),
        Icons.store_outlined,
        CatalogColors.pendingText,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        if (wide) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == cards.length - 1 ? 0 : 12,
                    ),
                    child: cards[i],
                  ),
                ),
            ],
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((c) => SizedBox(width: 240, child: c)).toList(),
        );
      },
    );
  }

  Widget _summary(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CatalogColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterToolbar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CatalogColors.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final stacked = c.maxWidth < 700;
          final search = TextField(
            decoration: InputDecoration(
              hintText: 'Search by consignment ID, BA or product',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'\n')),
            ],
            onChanged: (v) => setState(() => _search = v),
          );
          final ba = DropdownButtonFormField<String>(
            value: _baFilter,
            isExpanded: true,
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
            hint: const Text('All Business Associates'),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('All')),
              ..._businessAssociates.map((b) =>
                  DropdownMenuItem<String>(value: b, child: Text(b))),
            ],
            onChanged: (v) => setState(() => _baFilter = v),
          );
          if (stacked) {
            return Column(
              children: [
                search,
                const SizedBox(height: 8),
                ba,
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 2, child: search),
              const SizedBox(width: 8),
              Expanded(child: ba),
            ],
          );
        },
      ),
    );
  }

  Widget _table() {
    final list = _filtered;
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 60),
        alignment: Alignment.center,
        child: const Column(
          children: [
            Icon(Icons.assignment_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No consignments found',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    final flat = <_FlatRow>[];
    for (final c in list) {
      for (final i in c.items) {
        flat.add(_FlatRow(consignment: c, item: i));
      }
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: flat
                .map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _mobileRow(r),
                    ))
                .toList(),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CatalogColors.cardBorder),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              headingRowHeight: 44,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 72,
              columns: const [
                DataColumn(label: Text('Consignment ID')),
                DataColumn(label: Text('Product')),
                DataColumn(label: Text('BA')),
                DataColumn(label: Text('Supplier')),
                DataColumn(label: Text('Assigned')),
                DataColumn(label: Text('Sold')),
                DataColumn(label: Text('Price')),
                DataColumn(label: Text('Remaining')),
                DataColumn(label: Text('Progress')),
                DataColumn(label: Text('Status')),
              ],
              rows: flat
                  .map((r) => DataRow(cells: [
                        DataCell(Text(r.consignment.consignmentId)),
                        DataCell(Text(r.item.product.name,
                            overflow: TextOverflow.ellipsis)),
                        DataCell(Text(r.consignment.businessAssociateName,
                            overflow: TextOverflow.ellipsis)),
                        DataCell(Text(r.item.product.supplierName,
                            overflow: TextOverflow.ellipsis)),
                        DataCell(Text('${r.item.unitsToAssign}')),
                        DataCell(Text('${r.item.unitsSold}')),
                        DataCell(Text(
                            'KSh ${r.item.unitPrice.toStringAsFixed(2)}')),
                        DataCell(Text('${r.item.unitsRemaining}')),
                        DataCell(SizedBox(
                          width: 80,
                          child: LinearProgressIndicator(
                            value: r.item.progress,
                            backgroundColor: const Color(0xFFE2E8F0),
                            color: CatalogColors.primaryAccent,
                          ),
                        )),
                        DataCell(_statusBadge(r.consignment.status)),
                      ]))
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _mobileRow(_FlatRow r) {
    final progress = (r.item.progress * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CatalogColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(r.consignment.consignmentId,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              _statusBadge(r.consignment.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(r.item.product.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
              '${r.consignment.businessAssociateName} • ${r.item.product.supplierName}',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _miniStat('Assigned', '${r.item.unitsToAssign}'),
              _miniStat('Sold', '${r.item.unitsSold}'),
              _miniStat('Remaining', '${r.item.unitsRemaining}'),
              _miniStat('Price', 'KSh ${r.item.unitPrice.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: r.item.progress,
            backgroundColor: const Color(0xFFE2E8F0),
            color: CatalogColors.primaryAccent,
          ),
          const SizedBox(height: 4),
          Text('$progress% sold',
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _statusBadge(ConsignmentStatus status) {
    switch (status) {
      case ConsignmentStatus.active:
      case ConsignmentStatus.completed:
        return StatusBadge(
          label: status.label,
          background: CatalogColors.activeBg,
          textColor: CatalogColors.activeText,
          icon: Icons.check_circle,
        );
      case ConsignmentStatus.pending:
        return StatusBadge(
          label: status.label,
          background: CatalogColors.pendingBg,
          textColor: CatalogColors.pendingText,
          icon: Icons.hourglass_top,
        );
      case ConsignmentStatus.cancelled:
        return const StatusBadge(
          label: 'Cancelled',
          background: CatalogColors.lowStockBg,
          textColor: CatalogColors.lowStockText,
          icon: Icons.cancel_outlined,
        );
    }
  }
}

class _FlatRow {
  final Consignment consignment;
  final ConsignmentItem item;
  _FlatRow({required this.consignment, required this.item});
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/consignment_item_model.dart';
import '../../models/consignment_model.dart';
import '../../services/catalog_service.dart';
import '../catalog/catalog_theme.dart';
import 'create_consignment_screen.dart';

class ConsignmentListScreen extends StatefulWidget {
  const ConsignmentListScreen({
    super.key,
    this.businessAssociateId,
    this.businessAssociateName,
  });

  final String? businessAssociateId;
  final String? businessAssociateName;

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

  bool _matchesAssignmentFilter(Consignment c) {
    final targetId = widget.businessAssociateId?.trim().toLowerCase() ?? '';
    final targetName = widget.businessAssociateName?.trim().toLowerCase() ?? '';
    if (targetId.isEmpty && targetName.isEmpty) return true;
    return (targetId.isNotEmpty &&
            c.businessAssociateId.trim().toLowerCase() == targetId) ||
        (targetName.isNotEmpty &&
            c.businessAssociateName.trim().toLowerCase() == targetName);
  }

  List<Consignment> get _visibleConsignments =>
      _consignments.where(_matchesAssignmentFilter).toList();

  List<String> get _businessAssociates =>
      _visibleConsignments.map((c) => c.businessAssociateName).toSet().toList()
        ..sort();

  List<Consignment> get _filtered {
    return _visibleConsignments.where((c) {
      if (_baFilter != null && c.businessAssociateName != _baFilter) {
        return false;
      }
      if (_search.isNotEmpty) {
        final s = _search.toLowerCase();
        final inItems = c.items.any(
          (i) =>
              i.product.name.toLowerCase().contains(s) ||
              c.consignmentId.toLowerCase().contains(s),
        );
        final inBa = c.businessAssociateName.toLowerCase().contains(s);
        if (!inItems && !inBa) return false;
      }
      return true;
    }).toList();
  }

  int get _totalAssignments => _visibleConsignments.length;
  int get _totalUnits =>
      _visibleConsignments.fold(0, (s, c) => s + c.totalUnitsAssigned);
  int get _totalUnitsSold =>
      _visibleConsignments.fold(0, (s, c) => s + c.totalUnitsSold);
  int get _totalUnitsRemaining =>
      _visibleConsignments.fold(0, (s, c) => s + c.totalUnitsRemaining);

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<Consignment>(
      MaterialPageRoute(
        builder:
            (_) => CreateConsignmentScreen(
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
        title: const Text(
          'Stock Assignments',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: CatalogColors.primaryAccent,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: CatalogColors.primaryAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'New Consignment',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh:
            () async => Future.delayed(const Duration(milliseconds: 400)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummarySection(),
                  const SizedBox(height: 16),
                  _buildFilterToolbar(),
                  const SizedBox(height: 16),
                  _buildContentTable(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final cards = [
      _summaryCard(
        'Total Assignments',
        _totalAssignments.toString(),
        Icons.assignment_outlined,
        CatalogColors.primaryAccent,
      ),
      _summaryCard(
        'Cumulative Units',
        _totalUnits.toString(),
        Icons.inventory_2_outlined,
        CatalogColors.secondaryAction,
      ),
      _summaryCard(
        'Units Sold',
        _totalUnitsSold.toString(),
        Icons.sell_outlined,
        CatalogColors.inStockText,
      ),
      _summaryCard(
        'Units Remaining',
        _totalUnitsRemaining.toString(),
        Icons.store_outlined,
        CatalogColors.pendingText,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            children:
                cards
                    .map(
                      (c) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: c,
                        ),
                      ),
                    )
                    .toList(),
          );
        }

        final cardWidth =
            constraints.maxWidth > 500
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
        );
      },
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CatalogColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CatalogColors.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 650;

          final searchField = TextField(
            decoration: InputDecoration(
              hintText: 'Search ID, BA, or product...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon:
                  _search.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _search = ''),
                      )
                      : null,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              isDense: true,
            ),
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\n'))],
            onChanged: (v) => setState(() => _search = v),
          );

          final dropdownField = DropdownButtonFormField<String>(
            value: _baFilter,
            isExpanded: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              isDense: true,
            ),
            hint: const Text('All Business Associates'),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All Associates'),
              ),
              ..._businessAssociates.map(
                (b) => DropdownMenuItem<String>(
                  value: b,
                  child: Text(b, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _baFilter = v),
          );

          if (isCompact) {
            return Column(
              children: [searchField, const SizedBox(height: 8), dropdownField],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: searchField),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: dropdownField),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContentTable() {
    final list = _filtered;
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 60),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CatalogColors.cardBorder),
        ),
        alignment: Alignment.center,
        child: const Column(
          children: [
            Icon(Icons.inventory_outlined, size: 48, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text(
              'No consignments found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    final flatRows = <_FlatRow>[];
    for (final c in list) {
      for (final i in c.items) {
        flatRows.add(_FlatRow(consignment: c, item: i));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 768) {
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: flatRows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _mobileRow(flatRows[index]),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CatalogColors.cardBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columnSpacing: 20,
                  headingRowHeight: 48,
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 64,
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFF8FAFC),
                  ),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Consignment ID',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Product',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Business Associate',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Supplier',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Assigned',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Sold',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Price',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Remaining',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Progress',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows:
                      flatRows.map((r) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                r.consignment.consignmentId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                r.item.product.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DataCell(
                              Text(
                                r.consignment.businessAssociateName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DataCell(
                              Text(
                                r.item.product.supplierName ?? '—',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DataCell(Text('${r.item.unitsToAssign}')),
                            DataCell(Text('${r.item.unitsSold}')),
                            DataCell(
                              Text(
                                'KSh ${r.item.unitPrice.toStringAsFixed(2)}',
                              ),
                            ),
                            DataCell(Text('${r.item.unitsRemaining}')),
                            DataCell(
                              SizedBox(
                                width: 90,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LinearProgressIndicator(
                                      value: r.item.progress,
                                      borderRadius: BorderRadius.circular(4),
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      color: CatalogColors.primaryAccent,
                                      minHeight: 6,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(r.item.progress * 100).toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(_statusBadge(r.consignment.status)),
                          ],
                        );
                      }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _mobileRow(_FlatRow r) {
    final progress = (r.item.progress * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CatalogColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                r.consignment.consignmentId,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              _statusBadge(r.consignment.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            r.item.product.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${r.consignment.businessAssociateName} • ${r.item.product.supplierName ?? '—'}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat('Assigned', '${r.item.unitsToAssign}'),
                _miniStat('Sold', '${r.item.unitsSold}'),
                _miniStat('Remaining', '${r.item.unitsRemaining}'),
                _miniStat(
                  'Price',
                  'KSh ${r.item.unitPrice.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: r.item.progress,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: CatalogColors.primaryAccent,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$progress% sold',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(ConsignmentStatus status) {
    final label = switch (status) {
      ConsignmentStatus.pending => 'Pending',
      ConsignmentStatus.active => 'Active',
      ConsignmentStatus.completed => 'Completed',
      ConsignmentStatus.cancelled => 'Cancelled',
    };

    switch (status) {
      case ConsignmentStatus.active:
      case ConsignmentStatus.completed:
        return StatusBadge(
          label: label,
          background: CatalogColors.activeBg,
          textColor: CatalogColors.activeText,
          icon: Icons.check_circle,
        );
      case ConsignmentStatus.pending:
        return StatusBadge(
          label: label,
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

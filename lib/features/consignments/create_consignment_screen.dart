import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../models/consignment_item_model.dart';
import '../../models/consignment_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/catalog_service.dart';
import '../../features/database/database_service.dart';
import 'product_selection_page.dart';
import '../catalog/catalog_theme.dart';

class CreateConsignmentScreen extends StatefulWidget {
  const CreateConsignmentScreen({
    super.key,
    this.availableProducts,
    this.businessAssociates,
  });

  final List<Product>? availableProducts;
  final List<String>? businessAssociates;

  @override
  State<CreateConsignmentScreen> createState() =>
      _CreateConsignmentScreenState();
}

class _CreateConsignmentScreenState extends State<CreateConsignmentScreen> {
  static const _addNewBaId = '__add_new_ba__';

  final _service = CatalogService.instance;
  final _db = DatabaseService();

  final List<_DraftItem> _items = [];
  final _notesCtrl = TextEditingController();
  final _newBaCtrl = TextEditingController();
  String? _selectedBa;
  UserModel? _selectedUser;
  bool _submitting = false;
  bool _addingNewBa = false;
  late Future<List<UserModel>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _usersFuture = _db.getAllUsers();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    for (final i in _items) {
      i.dispose();
    }
    _notesCtrl.dispose();
    _newBaCtrl.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  List<Product> get _products => widget.availableProducts ?? _service.products;

  /// Dynamic business-associate list — pulled from existing
  /// consignments in the service. An explicit list passed via
  /// [widget.businessAssociates] wins so the caller can pin the list
  /// when needed (e.g. from a test).
  List<String> get _businessAssociates {
    if (widget.businessAssociates != null &&
        widget.businessAssociates!.isNotEmpty) {
      return widget.businessAssociates!;
    }
    return _service.businessAssociates;
  }

  void _addNewBusinessAssociate() {
    final name = _newBaCtrl.text.trim();
    if (name.isEmpty) return;
    _service.addBusinessAssociate(name);
    setState(() {
      _selectedBa = name;
      _selectedUser = UserModel(id: name, email: '', fullName: name, role: 5);
      _addingNewBa = false;
      _newBaCtrl.clear();
    });
  }

  /// Stable, de-duplicated list for the BA dropdown. Synthesized BA
  /// entries are keyed by name so rebuilds can match the selected value.
  List<UserModel> _buildDisplayUsers(List<UserModel> dbUsers) {
    final byId = <String, UserModel>{};
    for (final name in _businessAssociates) {
      if (name.trim().isEmpty) continue;
      byId.putIfAbsent(
        name,
        () => UserModel(id: name, email: '', fullName: name, role: 5),
      );
    }
    for (final user in dbUsers) {
      final label = user.fullName ?? user.email;
      if (_businessAssociates.contains(label)) continue;
      byId.putIfAbsent(user.id, () => user);
    }
    final list =
        byId.values.toList()..sort(
          (a, b) => (a.fullName ?? a.email).toLowerCase().compareTo(
            (b.fullName ?? b.email).toLowerCase(),
          ),
        );
    return list;
  }

  String? _selectedDropdownId(List<UserModel> displayUsers) {
    if (_selectedUser != null) {
      for (final u in displayUsers) {
        if (u.id == _selectedUser!.id) return u.id;
      }
    }
    if (_selectedBa != null) {
      for (final u in displayUsers) {
        if (u.id == _selectedBa || (u.fullName ?? u.email) == _selectedBa) {
          return u.id;
        }
      }
    }
    return null;
  }

  Future<void> _openProductSelection() async {
    final selectedIds = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder:
            (_) => ProductSelectionPage(
              products: _service.products,
              initiallySelectedIds: _items.map((d) => d.product.id).toSet(),
            ),
      ),
    );
    if (selectedIds == null || !mounted) return;

    for (final id in selectedIds) {
      if (!_items.any((d) => d.product.id == id)) {
        final product = _service.products.firstWhere((p) => p.id == id);
        _items.add(_DraftItem(product: product));
      }
    }
    setState(() {});
  }

  void _removeItem(_DraftItem item) {
    setState(() {
      _items.remove(item);
      item.dispose();
    });
  }

  double get _totalValue =>
      _items.fold(0, (s, i) => s + i.unitsToAssign * i.unitPrice);
  int get _totalUnits => _items.fold(0, (s, i) => s + i.unitsToAssign);

  String _generateConsignmentId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'CON-${ts.toString().substring(7)}-${const Uuid().v4().substring(0, 4)}';
  }

  Future<void> _submit() async {
    final selectedBa = _selectedUser?.fullName ?? _selectedBa;
    if (selectedBa == null || selectedBa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Business Associate')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one product')),
      );
      return;
    }
    final invalid = _items.where((i) => !i.isValid).toList();
    if (invalid.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Adjust ${invalid.length} item(s): units between 1 and ${invalid.first.product.currentStock} and price > 0.',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 800));

    final consignmentItems = <ConsignmentItem>[];
    final failed = <String>[];
    for (final draft in _items) {
      final consumed = _service.consumeStock(
        draft.product.id,
        draft.unitsToAssign,
      );
      if (consumed == null) {
        failed.add(draft.product.name);
        continue;
      }
      consignmentItems.add(
        ConsignmentItem(
          product: consumed,
          unitsToAssign: draft.unitsToAssign,
          unitPrice: draft.unitPrice,
        ),
      );
    }

    if (consignmentItems.isEmpty) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Stock changed while submitting. Please retry with available quantities.',
          ),
        ),
      );
      return;
    }

    final consignment = Consignment(
      consignmentId: _generateConsignmentId(),
      businessAssociateId: _selectedUser?.id ?? _selectedBa ?? '',
      businessAssociateName: selectedBa,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: DateTime.now(),
      status: ConsignmentStatus.active,
      items: consignmentItems,
    );

    _service.addConsignment(consignment);

    if (!mounted) return;
    if (failed.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Consignment created, but ${failed.length} item(s) had insufficient stock and were skipped.',
          ),
        ),
      );
    }
    Navigator.of(context).pop(consignment);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CatalogColors.neutralBackground,
      appBar: AppBar(
        title: const Text('Create Consignment'),
        backgroundColor: CatalogColors.primaryAccent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 900;
              final main = ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _productSelectionCard(),
                  const SizedBox(height: 16),
                  if (_items.isNotEmpty) ...[
                    _selectedItemsCard(),
                    const SizedBox(height: 16),
                  ],
                  _assignmentCard(),
                  const SizedBox(height: 16),
                  _submitBar(),
                ],
              );
              final preview = _previewCard();
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: main),
                    const SizedBox(width: 16),
                    SizedBox(width: 340, child: preview),
                  ],
                );
              }
              return main;
            },
          ),
        ),
      ),
    );
  }

  Widget _productSelectionCard() {
    final count = _items.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CatalogColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: const [
              Icon(
                Icons.shopping_basket_outlined,
                color: CatalogColors.primaryAccent,
              ),
              SizedBox(width: 8),
              Text(
                'Select Products',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            count == 0
                ? 'Tap below to choose products by category.'
                : '$count product(s) selected.',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openProductSelection,
            icon: const Icon(Icons.category_outlined),
            label: Text(
              count == 0 ? 'Choose Products' : 'Edit Selection ($count)',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: CatalogColors.primaryAccent,
              side: const BorderSide(color: CatalogColors.cardBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (count > 0) ...[
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: count,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) {
                final p = _items[i].product;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: CatalogColors.primaryAccent.withValues(
                      alpha: 0.1,
                    ),
                    child: Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: CatalogColors.primaryAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    p.name,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${p.category} • KSh ${p.unitPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${p.currentStock} ${p.unit}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _selectedItemsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CatalogColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Item Configuration',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _itemRow(item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(_DraftItem item) {
    final p = item.product;
    final overStock = item.unitsToAssign > p.currentStock;
    final overStockTried = item.unitsToAssignCtrl.text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CatalogColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Available: ${p.currentStock} ${p.unit} • Supplier: ${p.supplierName ?? '—'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _removeItem(item),
                icon: const Icon(Icons.delete_outline),
                color: CatalogColors.lowStockText,
                tooltip: 'Remove',
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              final stacked = c.maxWidth < 480;
              final unitsField = TextField(
                controller: item.unitsToAssignCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Units to Assign',
                  helperText: 'Max ${p.currentStock}',
                  errorText:
                      overStock && overStockTried
                          ? 'Exceeds available stock'
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              );
              final priceField = TextField(
                controller: item.unitPriceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Unit Price (KSh)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              );
              if (stacked) {
                return Column(
                  children: [
                    unitsField,
                    const SizedBox(height: 8),
                    priceField,
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Subtotal: KSh ${item.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: unitsField),
                  const SizedBox(width: 8),
                  Expanded(child: priceField),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Subtotal: KSh ${item.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _assignmentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CatalogColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: const [
              Icon(
                Icons.assignment_ind_outlined,
                color: CatalogColors.primaryAccent,
              ),
              SizedBox(width: 8),
              Text(
                'Assignment Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_addingNewBa)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newBaCtrl,
                    decoration: InputDecoration(
                      labelText: 'New Business Associate *',
                      hintText: 'e.g., Mary Akinyi',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addNewBusinessAssociate(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Add',
                  onPressed: _addNewBusinessAssociate,
                  icon: const Icon(
                    Icons.check_circle,
                    color: CatalogColors.primaryAccent,
                  ),
                ),
                IconButton(
                  tooltip: 'Cancel',
                  onPressed: () => setState(() => _addingNewBa = false),
                  icon: const Icon(Icons.close),
                ),
              ],
            )
          else
            FutureBuilder<List<UserModel>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                final users = snapshot.hasData ? snapshot.data! : <UserModel>[];
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 48,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final displayUsers = _buildDisplayUsers(users);
                final selectedId = _selectedDropdownId(displayUsers);

                return DropdownButtonFormField<String>(
                  value: selectedId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Business Associate (Sales Rep) *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  items: [
                    ...displayUsers.map(
                      (u) => DropdownMenuItem<String>(
                        value: u.id,
                        child: Text(
                          u.fullName ?? u.email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const DropdownMenuItem<String>(
                      value: _addNewBaId,
                      child: Row(
                        children: [
                          Icon(
                            Icons.add,
                            size: 16,
                            color: CatalogColors.primaryAccent,
                          ),
                          SizedBox(width: 6),
                          Text('Add new business associate…'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null || v == _addNewBaId) {
                      setState(() => _addingNewBa = true);
                      return;
                    }
                    final match = displayUsers.firstWhere((u) => u.id == v);
                    setState(() {
                      _selectedUser = match;
                      _selectedBa = match.fullName ?? match.email;
                    });
                  },
                );
              },
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'\n\n\n')),
            ],
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Add any instructions or context',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CatalogColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: const [
              Icon(
                Icons.receipt_long_outlined,
                color: CatalogColors.primaryAccent,
              ),
              SizedBox(width: 8),
              Text(
                'Consignment Preview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _previewRow('Items', '${_items.length}'),
          _previewRow('Total Units', '$_totalUnits'),
          const Divider(height: 24),
          _previewRow(
            'Total Value',
            'KSh ${_totalValue.toStringAsFixed(2)}',
            emphasize: true,
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            const Text(
              'Add products to see the live summary.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            )
          else
            ..._items.map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        i.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'KSh ${(i.unitsToAssign * i.unitPrice).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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

  Widget _previewRow(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasize ? Colors.black : const Color(0xFF64748B),
                fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.bold : FontWeight.w600,
              fontSize: emphasize ? 16 : 14,
              color: emphasize ? CatalogColors.primaryAccent : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitBar() {
    return Row(
      children: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: CatalogColors.primaryAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon:
              _submitting
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : const Icon(Icons.check),
          label: Text(_submitting ? 'Creating...' : 'Create Consignment'),
        ),
      ],
    );
  }
}

class _DraftItem {
  final Product product;
  final TextEditingController unitsToAssignCtrl;
  final TextEditingController unitPriceCtrl;

  _DraftItem({required this.product})
    : unitsToAssignCtrl = TextEditingController(),
      unitPriceCtrl = TextEditingController(
        text: product.unitPrice.toStringAsFixed(2),
      );

  int get unitsToAssign => int.tryParse(unitsToAssignCtrl.text) ?? 0;
  double get unitPrice => double.tryParse(unitPriceCtrl.text) ?? 0;
  double get subtotal => unitsToAssign * unitPrice;

  bool get isValid =>
      unitsToAssign > 0 &&
      unitsToAssign <= product.currentStock &&
      unitPrice > 0;

  void dispose() {
    unitsToAssignCtrl.dispose();
    unitPriceCtrl.dispose();
  }
}

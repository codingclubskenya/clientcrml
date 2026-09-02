import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product_model.dart';
import '../../services/catalog_service.dart';
import 'add_product_screen.dart';
import 'catalog_theme.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _service = CatalogService.instance;
  String _search = '';
  String? _supplierFilter;
  String? _categoryFilter;
  bool _gridView = false;

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

  List<Product> get _products => _service.products;

  List<Product> get _filtered {
    return _products.where((p) {
      if (_supplierFilter != null && p.supplierName != _supplierFilter) {
        return false;
      }
      if (_categoryFilter != null && p.category != _categoryFilter) {
        return false;
      }
      if (_search.isNotEmpty) {
        final s = _search.toLowerCase();
        if (!p.name.toLowerCase().contains(s) &&
            !(p.sku?.toLowerCase().contains(s) ?? false) &&
            !(p.author?.toLowerCase().contains(s) ?? false)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<String> get _suppliers =>
      _products.map((p) => p.supplierName).toSet().toList()..sort();
  List<String> get _categories =>
      _products.map((p) => p.category).toSet().toList()..sort();

  int get _totalCount => _products.length;
  int get _activeCount => _products.where((p) => p.isActive).length;
  int get _lowStockCount => _products.where((p) => p.isLowStock).length;
  int get _outOfStockCount => _products.where((p) => p.isOutOfStock).length;

  Future<void> _openAddProduct() async {
    final created = await Navigator.of(context).push<Product>(
      MaterialPageRoute(builder: (_) => const AddProductScreen()),
    );
    if (created != null) {
      _service.addProduct(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CatalogColors.neutralBackground,
      appBar: AppBar(
        title: const Text('Product Catalog'),
        backgroundColor: CatalogColors.primaryAccent,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddProduct,
        backgroundColor: CatalogColors.primaryAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => Future.delayed(const Duration(milliseconds: 400)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statsHeader(),
            const SizedBox(height: 16),
            _filterToolbar(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                IconButton(
                  tooltip: _gridView ? 'List view' : 'Grid view',
                  icon: Icon(
                    _gridView ? Icons.view_list : Icons.grid_view,
                    color: CatalogColors.primaryAccent,
                  ),
                  onPressed: () => setState(() => _gridView = !_gridView),
                ),
              ],
            ),
            _gridView ? _buildGrid() : _buildList(),
          ],
        ),
      ),
    );
  }

  Widget _statsHeader() {
    final cards = [
      _statCard('Total Products', _totalCount.toString(),
          Icons.inventory_2, CatalogColors.primaryAccent),
      _statCard('Active', _activeCount.toString(), Icons.check_circle,
          CatalogColors.inStockText),
      _statCard('Low Stock', _lowStockCount.toString(), Icons.warning,
          CatalogColors.pendingText),
      _statCard('Out of Stock', _outOfStockCount.toString(),
          Icons.error_outline, CatalogColors.lowStockText),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // 4 cols on tablet/desktop, 2 cols on phone — no hard-coded
        // card widths so there's no sub-pixel overflow on any device.
        if (constraints.maxWidth >= 600) {
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
          children: List.generate(cards.length, (i) {
            return SizedBox(
              width: (constraints.maxWidth - 12) / 2,
              child: cards[i],
            );
          }),
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
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
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 700;
          final search = TextField(
            decoration: InputDecoration(
              hintText: 'Search products by name or SKU',
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
          final supplier = _dropdown(
            hint: 'All Suppliers',
            value: _supplierFilter,
            items: _suppliers,
            onChanged: (v) => setState(() => _supplierFilter = v),
          );
          final category = _dropdown(
            hint: 'All Categories',
            value: _categoryFilter,
            items: _categories,
            onChanged: (v) => setState(() => _categoryFilter = v),
          );
          if (stacked) {
            return Column(
              children: [
                search,
                const SizedBox(height: 8),
                supplier,
                const SizedBox(height: 8),
                category,
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 2, child: search),
              const SizedBox(width: 8),
              Expanded(child: supplier),
              const SizedBox(width: 8),
              Expanded(child: category),
            ],
          );
        },
      ),
    );
  }

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      hint: Text(hint),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All')),
        ...items.map((s) =>
            DropdownMenuItem<String>(value: s, child: Text(s, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildList() {
    final list = _filtered;
    if (list.isEmpty) {
      return _emptyState();
    }
    final width = MediaQuery.of(context).size.width;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(
        list.length,
        (i) => Padding(
          padding: EdgeInsets.only(
            bottom: i < list.length - 1 ? 8 : 0,
          ),
          child: _productRow(list[i], width),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final list = _filtered;
    if (list.isEmpty) return _emptyState();
    final itemWidth = 280.0;
    final spacing = 12.0;
    final runSpacing = 12.0;

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: List.generate(list.length, (i) {
        return SizedBox(
          width: itemWidth,
          child: _productCard(list[i]),
        );
      }),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('No products match your filters',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _productRow(Product p, double maxWidth) {
    if (maxWidth < 560) {
      return _mobileProductRow(p);
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CatalogColors.cardBorder),
      ),
      child: Row(
        children: [
          _productAvatar(p),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${p.category} • ${p.supplierName}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (p.author != null)
                  Text('by ${p.author}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                if (p.gradeLevel != null || p.subject != null)
                  Text(
                    [
                      if (p.gradeLevel != null) p.gradeLevel,
                      if (p.subject != null) p.subject,
                    ].join(' • '),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (p.sku != null)
                  Text('SKU: ${p.sku}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KSh ${p.unitPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${p.currentStock} ${p.unit}',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                _statusBadgeFor(p),
              ],
            ),
          ),
          SizedBox(
            width: 36,
            height: 36,
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              tooltip: 'Actions',
              onSelected: (v) async {
                if (v == 'edit') {
                  final updated = await Navigator.of(context).push<Product>(
                    MaterialPageRoute(
                      builder: (_) => AddProductScreen(initialProduct: p),
                    ),
                  );
                  if (updated != null) {
                    _service.updateProduct(updated);
                  }
                } else if (v == 'delete') {
                  _service.removeProduct(p.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileProductRow(Product p) {
    return Container(
      padding: const EdgeInsets.all(12),
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
            children: [
              _productAvatar(p),
              const SizedBox(width: 12),
              Expanded(
                child: Text(p.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              _actionsMenu(p),
            ],
          ),
          const SizedBox(height: 8),
          Text('${p.category} • ${p.supplierName}',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (p.author != null)
            Text('by ${p.author}',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF94A3B8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          if (p.gradeLevel != null || p.subject != null)
            Text(
              [
                if (p.gradeLevel != null) p.gradeLevel,
                if (p.subject != null) p.subject,
              ].join(' • '),
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (p.sku != null)
            Text('SKU: ${p.sku}',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF94A3B8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('KSh ${p.unitPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Text('${p.currentStock} ${p.unit}',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 12),
              _statusBadgeFor(p),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionsMenu(Product p) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      tooltip: 'Actions',
      onSelected: (v) async {
        if (v == 'edit') {
          final updated = await Navigator.of(context).push<Product>(
            MaterialPageRoute(
              builder: (_) => AddProductScreen(initialProduct: p),
            ),
          );
          if (updated != null) {
            _service.updateProduct(updated);
          }
        } else if (v == 'delete') {
          _service.removeProduct(p.id);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Widget _productCard(Product p) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CatalogColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _productAvatar(p, size: 56),
          const SizedBox(height: 8),
          Text(p.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          Text(p.category,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (p.author != null)
            Text('by ${p.author}',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF94A3B8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          if (p.gradeLevel != null || p.subject != null)
            Text(
              [
                if (p.gradeLevel != null) p.gradeLevel,
                if (p.subject != null) p.subject,
              ].join(' • '),
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),
          Text('KSh ${p.unitPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text('${p.currentStock} ${p.unit}',
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          _statusBadgeFor(p),
        ],
      ),
    );
  }

  Widget _productAvatar(Product p, {double size = 44}) {
    if (p.imageUrl != null && p.imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(p.imageUrl!),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: CatalogColors.primaryAccent.withValues(alpha: 0.1),
      child: Text(
        p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
        style: TextStyle(
            color: CatalogColors.primaryAccent, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _statusBadgeFor(Product p) {
    if (p.isOutOfStock) {
      return const StatusBadge(
        label: 'Out of Stock',
        background: CatalogColors.lowStockBg,
        textColor: CatalogColors.lowStockText,
        icon: Icons.error_outline,
      );
    }
    if (p.isLowStock) {
      return const StatusBadge(
        label: 'Low Stock',
        background: CatalogColors.pendingBg,
        textColor: CatalogColors.pendingText,
        icon: Icons.warning_amber_rounded,
      );
    }
    return const StatusBadge(
      label: 'In Stock',
      background: CatalogColors.inStockBg,
      textColor: CatalogColors.inStockText,
      icon: Icons.check_circle,
    );
  }
}
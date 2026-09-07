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

  List<String> get _suppliers => _products
      .map((p) => p.supplierName)
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
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
        onRefresh:
            () async => Future.delayed(const Duration(milliseconds: 400)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 8),
              _gridView ? _buildGrid() : _buildList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statsHeader() {
    final cards = [
      _statCard(
        'Total Products',
        _totalCount.toString(),
        Icons.inventory_2,
        CatalogColors.primaryAccent,
      ),
      _statCard(
        'Active',
        _activeCount.toString(),
        Icons.check_circle,
        CatalogColors.inStockText,
      ),
      _statCard(
        'Low Stock',
        _lowStockCount.toString(),
        Icons.warning,
        CatalogColors.pendingText,
      ),
      _statCard(
        'Out of Stock',
        _outOfStockCount.toString(),
        Icons.error_outline,
        CatalogColors.lowStockText,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 768) {
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

        final double spacing = 12.0;
        final double itemWidth = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children:
              cards.map((card) {
                return SizedBox(width: itemWidth, child: card);
              }).toList(),
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CatalogColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
          final stacked = constraints.maxWidth < 650;
          final search = TextField(
            decoration: InputDecoration(
              hintText: 'Search products by name or SKU',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\n'))],
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      hint: Text(hint, overflow: TextOverflow.ellipsis),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All')),
        ...items.map(
          (s) => DropdownMenuItem<String>(
            value: s,
            child: Text(s, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildList() {
    final list = _filtered;
    if (list.isEmpty) return _emptyState();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(
            list.length,
            (i) => Padding(
              padding: EdgeInsets.only(bottom: i < list.length - 1 ? 8 : 0),
              child: _productRow(list[i], constraints.maxWidth),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid() {
    final list = _filtered;
    if (list.isEmpty) return _emptyState();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        int crossAxisCount = 1;
        if (width >= 1100) {
          crossAxisCount = 4;
        } else if (width >= 800) {
          crossAxisCount = 3;
        } else if (width >= 500) {
          crossAxisCount = 2;
        }

        final double spacing = 12.0;
        final double itemWidth =
            (width - (spacing * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(list.length, (i) {
            return SizedBox(width: itemWidth, child: _productCard(list[i]));
          }),
        );
      },
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
          Text(
            'No products match your filters',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _productRow(Product p, double availableWidth) {
    if (availableWidth < 560) {
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _productAvatar(p),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  [p.category, p.supplierName]
                      .whereType<String>()
                      .join(' • '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (p.author != null)
                  Text(
                    'by ${p.author}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (p.gradeLevel != null || p.subject != null)
                  Text(
                    [
                      if (p.gradeLevel != null) p.gradeLevel,
                      if (p.subject != null) p.subject,
                    ].join(' • '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (p.sku != null)
                  Text(
                    'SKU: ${p.sku}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'KSh ${p.unitPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${p.currentStock} ${p.unit}',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _statusBadgeFor(p),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _actionsMenu(p),
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
                child: Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _actionsMenu(p),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [p.category, p.supplierName].whereType<String>().join(' • '),
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (p.author != null)
            Text(
              'by ${p.author}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (p.gradeLevel != null || p.subject != null)
            Text(
              [
                if (p.gradeLevel != null) p.gradeLevel,
                if (p.subject != null) p.subject,
              ].join(' • '),
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (p.sku != null)
            Text(
              'SKU: ${p.sku}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'KSh ${p.unitPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${p.currentStock} ${p.unit}',
                style: const TextStyle(fontSize: 12),
              ),
              _statusBadgeFor(p),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionsMenu(Product p) {
    return SizedBox(
      width: 36,
      height: 36,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert, size: 20),
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
        itemBuilder:
            (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
      ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_productAvatar(p, size: 48), _actionsMenu(p)],
          ),
          const SizedBox(height: 8),
          Text(
            p.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            p.category,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (p.author != null)
            Text(
              'by ${p.author}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (p.gradeLevel != null || p.subject != null)
            Text(
              [
                if (p.gradeLevel != null) p.gradeLevel,
                if (p.subject != null) p.subject,
              ].join(' • '),
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),
          Text(
            'KSh ${p.unitPrice.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${p.currentStock} ${p.unit}',
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
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
          color: CatalogColors.primaryAccent,
          fontWeight: FontWeight.bold,
        ),
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

import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../catalog/catalog_theme.dart';

class ProductSelectionPage extends StatefulWidget {
  const ProductSelectionPage({
    super.key,
    required this.products,
    required this.initiallySelectedIds,
  });

  final List<Product> products;
  final Set<String> initiallySelectedIds;

  @override
  State<ProductSelectionPage> createState() => _ProductSelectionPageState();
}

class _ProductSelectionPageState extends State<ProductSelectionPage> {
  final Set<String> _selectedIds = {};
  String? _categoryFilter;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.initiallySelectedIds);
  }

  List<String> get _categories {
    final set = <String>{};
    for (final p in widget.products) {
      if (p.category.trim().isNotEmpty) {
        set.add(p.category);
      }
    }
    return set.toList()..sort();
  }

  List<Product> get _filtered {
    return widget.products.where((p) {
      if (_categoryFilter != null && p.category != _categoryFilter) {
        return false;
      }
      if (_search.isNotEmpty) {
        final s = _search.toLowerCase();
        if (!p.name.toLowerCase().contains(s) &&
            !(p.sku?.toLowerCase().contains(s) ?? false)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _toggle(Product p, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedIds.add(p.id);
      } else {
        _selectedIds.remove(p.id);
      }
    });
  }

  void _done() {
    Navigator.of(context).pop(_selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final selectable = _filtered.where((p) => !p.isOutOfStock).toList();

    return Scaffold(
      backgroundColor: CatalogColors.neutralBackground,
      appBar: AppBar(
        title: const Text('Select Products'),
        backgroundColor: CatalogColors.primaryAccent,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _selectedIds.isEmpty ? null : _done,
            child: const Text(
              'Done',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 560;
                final searchField = TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name or SKU',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                );
                final categoryDropdown = DropdownButtonFormField<String>(
                  value: _categoryFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'All Categories',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null, child: Text('All Categories')),
                    ..._categories.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) => setState(() => _categoryFilter = v),
                );
                final selectedCount = _selectedIds.length;
                if (stacked) {
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 8),
                      categoryDropdown,
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$selectedCount selected',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 2, child: searchField),
                    const SizedBox(width: 8),
                    Expanded(child: categoryDropdown),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 120,
                      child: Text(
                        '$selectedCount selected',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF64748B)),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: selectable.isEmpty
                ? const Center(
                    child: Text(
                      'No products match your filters',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: selectable.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final p = selectable[i];
                      final selected = _selectedIds.contains(p.id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (v) => _toggle(p, v),
                        activeColor: CatalogColors.primaryAccent,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        secondary: CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              CatalogColors.primaryAccent.withValues(alpha: 0.1),
                          child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                              ? CircleAvatar(
                                  radius: 18,
                                  backgroundImage: NetworkImage(p.imageUrl!),
                                )
                              : Text(
                                  p.name.isNotEmpty
                                      ? p.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                      color: CatalogColors.primaryAccent,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                        title: Text(p.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            '${p.category} • KSh ${p.unitPrice.toStringAsFixed(2)} • ${p.currentStock} ${p.unit}',
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedIds.isEmpty ? null : _done,
        backgroundColor: CatalogColors.primaryAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.check),
        label: Text('${_selectedIds.length} selected'),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import '../models/consignment_item_model.dart';
import '../models/consignment_model.dart';
import '../models/product_model.dart';
import '../features/catalog/catalog_seed.dart';

/// In-memory singleton that holds the shared catalog of products and
/// consignments. The product catalog, consignment list and the
/// event orders page all read/write through this service so that:
///
///  * Stock changes in one screen are visible in the others.
///  * Sales recorded from [EventOrdersPage] are validated against
///    the active consignment's [ConsignmentItem.unitsRemaining] and
///    decrement both [ConsignmentItem.unitsSold] and
///    [Product.currentStock].
class CatalogService extends ChangeNotifier {
  CatalogService._() {
    _products.addAll(defaultCatalogProducts());
    _consignments.addAll(_seedConsignments());
  }

  static final CatalogService instance = CatalogService._();

  final List<Product> _products = [];
  final List<Consignment> _consignments = [];

  // --- Products -------------------------------------------------------------

  List<Product> get products => List.unmodifiable(_products);

  Product? productById(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  void addProduct(Product product) {
    _products.add(product);
    notifyListeners();
  }

  /// Replaces the product matching [product.id] with the supplied
  /// [product]. If no matching id exists, the product is appended.
  void updateProduct(Product product) {
    final idx = _products.indexWhere((p) => p.id == product.id);
    if (idx == -1) {
      _products.add(product);
    } else {
      _products[idx] = product;
    }
    notifyListeners();
  }

  void removeProduct(String id) {
    _products.removeWhere((p) => p.id == id);
    for (final c in _consignments) {
      c.items.removeWhere((i) => i.product.id == id);
    }
    notifyListeners();
  }

  /// Decrement [Product.currentStock] by [units] for [productId].
  /// Returns the updated [Product] on success, `null` if not enough stock
  /// or the product is missing.
  Product? consumeStock(String productId, int units) {
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx == -1) return null;
    final p = _products[idx];
    if (units <= 0) return p;
    if (p.currentStock < units) return null;
    _products[idx] = p.copyWith(currentStock: p.currentStock - units);
    notifyListeners();
    return _products[idx];
  }

  // --- Consignments ---------------------------------------------------------

  List<Consignment> get consignments => List.unmodifiable(_consignments);

  Consignment? consignmentById(String id) {
    for (final c in _consignments) {
      if (c.consignmentId == id) return c;
    }
    return null;
  }

  void addConsignment(Consignment c) {
    _consignments.insert(0, c);
    notifyListeners();
  }

  // --- Dynamic lookups (no hard-coded lists) -------------------------------

  /// Distinct list of supplier names found in the current product catalog.
  List<String> get suppliers {
    final set = <String>{};
    for (final p in _products) {
      if (p.supplierName.trim().isNotEmpty) set.add(p.supplierName);
    }
    final list = set.toList()..sort();
    return List.unmodifiable(list);
  }

  /// Distinct list of categories found in the current product catalog.
  List<String> get categories {
    final set = <String>{};
    for (final p in _products) {
      if (p.category.trim().isNotEmpty) set.add(p.category);
    }
    final list = set.toList()..sort();
    return List.unmodifiable(list);
  }

  /// Distinct list of units found in the current product catalog.
  List<String> get units {
    final set = <String>{};
    for (final p in _products) {
      if (p.unit.trim().isNotEmpty) set.add(p.unit);
    }
    final list = set.toList()..sort();
    return List.unmodifiable(list);
  }

  /// Distinct list of business associate names referenced by any
  /// consignment, plus any manually-added ones via
  /// [addBusinessAssociate]. Always returns a non-null list, even when
  /// the catalog has not yet seen a consignment.
  List<String> get businessAssociates {
    final set = <String>{..._extraBusinessAssociates};
    for (final c in _consignments) {
      if (c.businessAssociateName.trim().isNotEmpty) {
        set.add(c.businessAssociateName);
      }
    }
    final list = set.toList()..sort();
    return List.unmodifiable(list);
  }

  final List<String> _extraBusinessAssociates = [];

  /// Adds a business associate name so it appears in dropdowns even
  /// before a consignment is created for them.
  void addBusinessAssociate(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_extraBusinessAssociates.contains(trimmed)) return;
    _extraBusinessAssociates.add(trimmed);
    _extraBusinessAssociates.sort();
    notifyListeners();
  }

  /// Distinct list of book grade levels found on current book products.
  List<String> get gradeLevels {
    final set = <String>{};
    for (final p in _products) {
      if (p.gradeLevel != null && p.gradeLevel!.trim().isNotEmpty) {
        set.add(p.gradeLevel!);
      }
    }
    final list = set.toList()..sort();
    return List.unmodifiable(list);
  }

  /// Distinct list of book subjects found on current book products.
  List<String> get subjects {
    final set = <String>{};
    for (final p in _products) {
      if (p.subject != null && p.subject!.trim().isNotEmpty) {
        set.add(p.subject!);
      }
    }
    final list = set.toList()..sort();
    return List.unmodifiable(list);
  }

  /// Distinct list of book languages found on current book products.
  List<String> get languages {
    final set = <String>{};
    for (final p in _products) {
      if (p.language != null && p.language!.trim().isNotEmpty) {
        set.add(p.language!);
      }
    }
    final list = set.toList()..sort();
    return List.unmodifiable(list);
  }

  /// Returns the latest active or pending consignment for [businessAssociate]
  /// that contains the given [productId], or `null` if none exists.
  ConsignmentItem? activeAllocationFor({
    required String businessAssociate,
    required String productId,
  }) {
    ConsignmentItem? best;
    for (final c in _consignments) {
      if (c.businessAssociateName != businessAssociate) continue;
      if (c.status == ConsignmentStatus.cancelled ||
          c.status == ConsignmentStatus.completed) {
        continue;
      }
      for (final item in c.items) {
        if (item.product.id != productId) continue;
        if (item.unitsRemaining <= 0) continue;
        if (best == null) return item;
        best = item;
      }
    }
    return best;
  }

  /// Records [units] sold from the consignment that allocated [productId]
  /// to [businessAssociate]. Decrements [ConsignmentItem.unitsSold] and
  /// [Product.currentStock]. Returns the updated [ConsignmentItem] on
  /// success or `null` if the consignment has no remaining units for the
  /// product.
  ConsignmentItem? recordSale({
    required String businessAssociate,
    required String productId,
    required int units,
  }) {
    if (units <= 0) return null;
    final allocation = activeAllocationFor(
      businessAssociate: businessAssociate,
      productId: productId,
    );
    if (allocation == null || allocation.unitsRemaining < units) {
      return null;
    }
    final stockResult = consumeStock(productId, units);
    if (stockResult == null) return null;
    allocation.unitsSold += units;
    notifyListeners();
    return allocation;
  }

  /// Returns the total units sold across every active consignment for
  /// [businessAssociate] + [productId]. Used by the event orders page
  /// to display how much of the BA's allocation is consumed.
  int totalUnitsSold({
    required String businessAssociate,
    required String productId,
  }) {
    int total = 0;
    for (final c in _consignments) {
      if (c.businessAssociateName != businessAssociate) continue;
      for (final i in c.items) {
        if (i.product.id == productId) total += i.unitsSold;
      }
    }
    return total;
  }
}

List<Consignment> _seedConsignments() {
  final products = defaultCatalogProducts();
  Product? findById(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  final p1 = findById('p1'); // Understanding Mathematics G5
  final p2 = findById('p2'); // Oxford English G4
  final p4 = findById('p4'); // Moran Kiswahili G6
  final p5 = findById('p5'); // Exercise Books 200pg (pack of 5)
  if (p1 == null || p2 == null || p4 == null || p5 == null) return [];

  final now = DateTime.now();
  return [
    Consignment(
      consignmentId: 'CON-${now.millisecondsSinceEpoch.toString().substring(7)}',
      businessAssociateId: 'ba1',
      businessAssociateName: 'Jane Wanjiku',
      status: ConsignmentStatus.active,
      createdAt: now.subtract(const Duration(days: 3)),
      notes: 'Nairobi region back-to-school drive',
      items: [
        ConsignmentItem(product: p1, unitsToAssign: 80, unitPrice: 700, unitsSold: 12),
        ConsignmentItem(product: p5, unitsToAssign: 40, unitPrice: 380, unitsSold: 6),
      ],
    ),
    Consignment(
      consignmentId: 'CON-${(now.millisecondsSinceEpoch - 86400000).toString().substring(7)}',
      businessAssociateId: 'ba2',
      businessAssociateName: 'Peter Otieno',
      status: ConsignmentStatus.active,
      createdAt: now.subtract(const Duration(days: 1)),
      notes: 'Kisumu schools restock',
      items: [
        ConsignmentItem(product: p2, unitsToAssign: 60, unitPrice: 760, unitsSold: 4),
        ConsignmentItem(product: p4, unitsToAssign: 30, unitPrice: 580),
      ],
    ),
  ];
}
import 'package:uuid/uuid.dart';

class CatalogItemModel {
  final String id;
  final String name;
  final String category;
  final String sku;
  final String itemType;
  final double unitPrice;
  final int stockQty;
  final String? description;
  final bool isActive;
  final bool isSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CatalogItemModel({
    String? id,
    required this.name,
    required this.category,
    required this.sku,
    required this.itemType,
    required this.unitPrice,
    this.stockQty = 0,
    this.description,
    this.isActive = true,
    this.isSynced = false,
    this.createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'category': category,
      'sku': sku,
      'item_type': itemType,
      'unit_price': unitPrice,
      'stock_qty': stockQty,
      'description': description,
      'is_active': isActive,
      'isSynced': isSynced,
    };
    if (createdAt != null) {
      map['created_at'] = createdAt!.toIso8601String();
    }
    if (updatedAt != null) {
      map['updated_at'] = updatedAt!.toIso8601String();
    }
    return map;
  }

  factory CatalogItemModel.fromMap(Map<dynamic, dynamic> map) {
    return CatalogItemModel(
      id: map['id'],
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      sku: map['sku'] ?? '',
      itemType: map['item_type'] ?? map['itemType'] ?? 'sale',
      unitPrice: _parseAmount(map['unit_price'] ?? map['unitPrice']),
      stockQty: _parseInt(map['stock_qty'] ?? map['stockQty']),
      description: map['description'],
      isActive: map['is_active'] == true || map['is_active'] == 1 || map['isActive'] == true || map['isActive'] == 1,
      isSynced: map['isSynced'] == true || map['isSynced'] == 1,
      createdAt: _parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: _parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseAmount(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

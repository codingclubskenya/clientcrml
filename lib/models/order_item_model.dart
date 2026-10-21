import 'package:uuid/uuid.dart';

class OrderItemModel {
  final String id;
  final String orderId;
  final String productName;
  final String? category;
  final String? sku;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? notes;
  final bool isSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OrderItemModel({
    String? id,
    required this.orderId,
    required this.productName,
    this.category,
    this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.notes,
    this.isSynced = false,
    this.createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'order_id': orderId,
      'product_name': productName,
      'category': category,
      'sku': sku,
      'quantity': quantity,
      'unit_price': unitPrice,
      'line_total': lineTotal,
      'notes': notes,
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

  factory OrderItemModel.fromMap(Map<dynamic, dynamic> map) {
    return OrderItemModel(
      id: map['id'],
      orderId: map['order_id'] ?? map['orderId'] ?? '',
      productName: map['product_name'] ?? map['productName'] ?? '',
      category: map['category'],
      sku: map['sku'],
      quantity: _parseInt(map['quantity']),
      unitPrice: _parseAmount(map['unit_price'] ?? map['unitPrice']),
      lineTotal: _parseAmount(map['line_total'] ?? map['lineTotal']),
      notes: map['notes'],
      isSynced: map['isSynced'] == true || map['isSynced'] == 1,
      createdAt: _parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: _parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 1;
    return 1;
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

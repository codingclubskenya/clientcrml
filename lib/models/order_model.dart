import 'package:uuid/uuid.dart';

class OrderModel {
  final String id;
  final String? schoolId;
  final String schoolName;
  final String? schoolPhone;
  final String? agentId;
  final String? regionId;
  final String orderNumber;
  final String paymentMethod;
  final String? paymentReference;
  final double checkoutAmount;
  final String status;
  final String? notes;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final bool isSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OrderModel({
    String? id,
    this.schoolId,
    required this.schoolName,
    this.schoolPhone,
    this.agentId,
    this.regionId,
    String? orderNumber,
    required this.paymentMethod,
    this.paymentReference,
    required this.checkoutAmount,
    this.status = 'pending',
    this.notes,
    this.submittedAt,
    this.approvedAt,
    this.isSynced = false,
    this.createdAt,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4(),
       orderNumber = orderNumber ?? _generateOrderNumber();

  static String _generateOrderNumber() {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final suffix = const Uuid().v4().split('-').first.toUpperCase();
    return 'ORD-$stamp-$suffix';
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'school_id': schoolId,
      'school_name': schoolName,
      'school_phone': schoolPhone,
      'agent_id': agentId,
      'region_id': regionId,
      'order_number': orderNumber,
      'payment_method': paymentMethod,
      'payment_reference': paymentReference,
      'checkout_amount': checkoutAmount,
      'status': status,
      'notes': notes,
      'submitted_at': submittedAt?.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
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

  factory OrderModel.fromMap(Map<dynamic, dynamic> map) {
    return OrderModel(
      id: map['id'],
      schoolId: map['school_id'] ?? map['schoolId'],
      schoolName: map['school_name'] ?? map['schoolName'] ?? '',
      schoolPhone: map['school_phone'] ?? map['schoolPhone'],
      agentId: map['agent_id'] ?? map['agentId'],
      regionId: map['region_id'] ?? map['regionId'],
      orderNumber: map['order_number'] ?? map['orderNumber'],
      paymentMethod: map['payment_method'] ?? map['paymentMethod'] ?? 'cash',
      paymentReference: map['payment_reference'] ?? map['paymentReference'],
      checkoutAmount: _parseAmount(
        map['checkout_amount'] ?? map['checkoutAmount'],
      ),
      status: map['status'] ?? 'pending',
      notes: map['notes'],
      submittedAt: _parseDate(map['submitted_at'] ?? map['submittedAt']),
      approvedAt: _parseDate(map['approved_at'] ?? map['approvedAt']),
      isSynced: map['isSynced'] ?? false,
      createdAt: _parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: _parseDate(map['updated_at'] ?? map['updatedAt']),
    );
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

import 'consignment_item_model.dart';

enum ConsignmentStatus { pending, active, completed, cancelled }

extension ConsignmentStatusLabel on ConsignmentStatus {
  String get label {
    switch (this) {
      case ConsignmentStatus.pending:
        return 'Pending';
      case ConsignmentStatus.active:
        return 'Active';
      case ConsignmentStatus.completed:
        return 'Completed';
      case ConsignmentStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class Consignment {
  final String consignmentId;
  final String businessAssociateId;
  final String businessAssociateName;
  final List<ConsignmentItem> items;
  final String? notes;
  final DateTime createdAt;
  final ConsignmentStatus status;

  Consignment({
    required this.consignmentId,
    required this.businessAssociateId,
    required this.businessAssociateName,
    required this.items,
    this.notes,
    required this.createdAt,
    this.status = ConsignmentStatus.pending,
  });

  double get totalValue => items.fold(0, (sum, item) => sum + item.subtotal);

  int get totalUnitsAssigned =>
      items.fold(0, (sum, item) => sum + item.unitsToAssign);

  int get totalUnitsSold => items.fold(0, (sum, item) => sum + item.unitsSold);

  int get totalUnitsRemaining => totalUnitsAssigned - totalUnitsSold;

  Map<String, dynamic> toMap() => {
    'consignmentId': consignmentId,
    'businessAssociateId': businessAssociateId,
    'businessAssociateName': businessAssociateName,
    'items': items.map((item) => item.toMap()).toList(),
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
  };

  factory Consignment.fromMap(Map<dynamic, dynamic> map) {
    final rawItems = map['items'];
    final rawStatus =
        map['status']?.toString() ?? ConsignmentStatus.pending.name;
    return Consignment(
      consignmentId: (map['consignmentId'] ?? '').toString(),
      businessAssociateId: (map['businessAssociateId'] ?? '').toString(),
      businessAssociateName: (map['businessAssociateName'] ?? '').toString(),
      items:
          rawItems is List
              ? rawItems
                  .map(
                    (e) => ConsignmentItem.fromMap(
                      Map<String, dynamic>.from(
                        e is Map ? e : const <String, dynamic>{},
                      ),
                    ),
                  )
                  .toList()
              : <ConsignmentItem>[],
      notes: map['notes']?.toString(),
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: _parseStatus(rawStatus),
    );
  }

  static ConsignmentStatus _parseStatus(String value) {
    for (final status in ConsignmentStatus.values) {
      if (status.name == value) return status;
    }
    return ConsignmentStatus.pending;
  }
}

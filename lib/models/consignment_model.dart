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

  int get totalUnitsSold =>
      items.fold(0, (sum, item) => sum + item.unitsSold);

  int get totalUnitsRemaining => totalUnitsAssigned - totalUnitsSold;
}
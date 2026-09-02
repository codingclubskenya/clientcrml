import 'product_model.dart';

class ConsignmentItem {
  final Product product;
  int unitsToAssign;
  double unitPrice;
  int unitsSold;

  ConsignmentItem({
    required this.product,
    required this.unitsToAssign,
    required this.unitPrice,
    this.unitsSold = 0,
  });

  double get subtotal => unitsToAssign * unitPrice;

  int get unitsRemaining => unitsToAssign - unitsSold;

  double get progress {
    if (unitsToAssign <= 0) return 0;
    return (unitsSold / unitsToAssign).clamp(0.0, 1.0);
  }
}
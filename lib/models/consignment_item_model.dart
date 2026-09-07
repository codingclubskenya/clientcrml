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

  Map<String, dynamic> toMap() => {
        'product': product.toMap(),
        'unitsToAssign': unitsToAssign,
        'unitPrice': unitPrice,
        'unitsSold': unitsSold,
      };

  factory ConsignmentItem.fromMap(Map<dynamic, dynamic> map) {
    final productMap = map['product'];
    return ConsignmentItem(
      product: Product.fromMap(Map<String, dynamic>.from(
        productMap is Map ? productMap : const <String, dynamic>{},
      )),
      unitsToAssign: _parseInt(map['unitsToAssign']),
      unitPrice: _parseDouble(map['unitPrice']),
      unitsSold: _parseInt(map['unitsSold']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

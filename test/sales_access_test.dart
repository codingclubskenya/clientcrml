import 'package:dehus/core/constants/sales_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin can edit and checkout', () {
    expect(SalesAccess.isAdmin(1), isTrue);
    expect(SalesAccess.canEditSalesFlow(1), isTrue);
    expect(SalesAccess.canCheckout(1), isTrue);
    expect(SalesAccess.isViewOnly(1), isFalse);
  });

  test('sales manager can edit but not checkout', () {
    expect(SalesAccess.canEditSalesFlow(2), isTrue);
    expect(SalesAccess.canCheckout(2), isFalse);
    expect(SalesAccess.isViewOnly(2), isFalse);
  });

  test('bas role can edit and checkout', () {
    expect(SalesAccess.canEditSalesFlow(3), isTrue);
    expect(SalesAccess.canCheckout(3), isTrue);
    expect(SalesAccess.isViewOnly(3), isFalse);
  });

  test('field roles can edit and checkout', () {
    expect(SalesAccess.canEditSalesFlow(4), isTrue);
    expect(SalesAccess.canCheckout(4), isTrue);
    expect(SalesAccess.canEditSalesFlow(5), isTrue);
    expect(SalesAccess.canCheckout(5), isTrue);
  });
}

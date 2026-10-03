import 'package:east_app/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StockReceivableItem item({
    required double invoiceQuantity,
    required double receivedQuantity,
  }) {
    return StockReceivableItem(
      skuId: 'sku-1',
      skuName: 'Cooking Oil',
      invoiceQuantity: invoiceQuantity,
      receivedQuantity: receivedQuantity,
      unit: 'tin',
      note: '',
    );
  }

  test('condition is Matched when quantities are equal', () {
    expect(
      item(invoiceQuantity: 12, receivedQuantity: 12).condition,
      'Matched',
    );
  });

  test('condition is Short when received quantity is lower', () {
    expect(
      item(invoiceQuantity: 12, receivedQuantity: 10).condition,
      'Short',
    );
  });

  test('condition is Excess when received quantity is higher', () {
    expect(
      item(invoiceQuantity: 12, receivedQuantity: 14).condition,
      'Excess',
    );
  });
}

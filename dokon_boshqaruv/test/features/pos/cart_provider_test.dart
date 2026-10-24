import 'package:flutter_test/flutter_test.dart';
import 'package:dokon_boshqaruv/features/pos/providers/cart_provider.dart';
import 'package:dokon_boshqaruv/features/products/models/product.dart';

void main() {
  Product product(
          {String unit = 'dona', String stock = '5', String price = '1.01'}) =>
      Product(
        id: 1,
        name: 'Sinov mahsuloti',
        sku: 'TEST-1',
        barcode: '123456789',
        purchasePrice: '0.50',
        salePrice: price,
        stock: stock,
        unit: unit,
        minStock: '1',
      );

  test('bir xil mahsulot qayta qo‘shilganda qator va miqdor birlashtiriladi',
      () {
    final cart = CartNotifier();
    expect(cart.addProduct(product()), isTrue);
    expect(cart.addProduct(product()), isTrue);
    expect(cart.state, hasLength(1));
    expect(cart.state.single.quantity, 2);
    expect(cart.state.single.lineTotalCents, 202);
  });

  test('miqdor ombor chegarasidan oshmaydi va musbat bo‘lishi kerak', () {
    final cart = CartNotifier();
    cart.addProduct(product(stock: '2'));
    cart.updateQuantity(1, 3);
    expect(cart.state.single.quantity, 1);
    cart.updateQuantity(1, 0);
    expect(cart.state.single.quantity, 1);
  });

  test('kasrli birlik uchun qator summasi sentga yaxlitlanadi', () {
    final cart = CartNotifier();
    cart.addProduct(product(unit: 'kg', price: '2.50', stock: '5'),
        quantity: 1.255);
    expect(cart.state.single.lineTotalCents, 314);
  });
}

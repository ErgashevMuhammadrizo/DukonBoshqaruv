import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item.dart';
import '../../products/models/product.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  bool addProduct(Product product, {double quantity = 1.0}) {
    if (!quantity.isFinite ||
        quantity <= 0 ||
        quantity * 1000 != (quantity * 1000).roundToDouble() ||
        (!{'kg', 'gramm', 'litr', 'ml', 'metr', 'm²', 'm³'}
                .contains(product.unit) &&
            quantity != quantity.truncateToDouble())) {
      return false;
    }
    final existingIndex =
        state.indexWhere((item) => item.productId == product.id);

    if (existingIndex != -1) {
      // Update existing item
      final updatedState = [...state];
      final existingItem = updatedState[existingIndex];
      final currentStock = double.tryParse(product.stock) ?? 0;
      final newQuantity = existingItem.quantity + quantity;

      if (newQuantity <= currentStock) {
        updatedState[existingIndex] = CartItem(
          productId: existingItem.productId,
          name: existingItem.name,
          sku: existingItem.sku,
          salePrice: existingItem.salePrice,
          availableStock: currentStock,
          unit: existingItem.unit,
          quantity: newQuantity,
        );
        state = updatedState;
        return true;
      }
      return false;
    } else {
      // Add new item
      final currentStock = double.tryParse(product.stock) ?? 0;
      if (quantity <= currentStock) {
        state = [
          ...state,
          CartItem(
            productId: product.id,
            name: product.name,
            sku: product.sku,
            salePrice: double.tryParse(product.salePrice) ?? 0,
            availableStock: currentStock,
            unit: product.unit,
            quantity: quantity,
          ),
        ];
        return true;
      }
      return false;
    }
  }

  void updateQuantity(int productId, double newQuantity) {
    if (!newQuantity.isFinite ||
        newQuantity <= 0 ||
        newQuantity * 1000 != (newQuantity * 1000).roundToDouble()) {
      return;
    }
    final selected =
        state.where((item) => item.productId == productId).toList();
    if (selected.isNotEmpty &&
        !{'kg', 'gramm', 'litr', 'ml', 'metr', 'm²', 'm³'}
            .contains(selected.first.unit) &&
        newQuantity != newQuantity.truncateToDouble()) {
      return;
    }
    final updatedState = state.map((item) {
      if (item.productId == productId) {
        if (newQuantity <= item.availableStock) {
          return CartItem(
            productId: item.productId,
            name: item.name,
            sku: item.sku,
            salePrice: item.salePrice,
            availableStock: item.availableStock,
            unit: item.unit,
            quantity: newQuantity,
          );
        }
      }
      return item;
    }).toList();

    state = updatedState;
  }

  void incrementQuantity(int productId) {
    final updatedState = state.map((item) {
      if (item.productId == productId && item.canIncrement()) {
        return CartItem(
          productId: item.productId,
          name: item.name,
          sku: item.sku,
          salePrice: item.salePrice,
          availableStock: item.availableStock,
          unit: item.unit,
          quantity: item.quantity + 1,
        );
      }
      return item;
    }).toList();

    state = updatedState;
  }

  void decrementQuantity(int productId) {
    final item = state.firstWhere((item) => item.productId == productId);
    if (item.quantity <= 1) {
      removeProduct(productId);
    } else {
      updateQuantity(productId, item.quantity - 1);
    }
  }

  void removeProduct(int productId) {
    state = state.where((item) => item.productId != productId).toList();
  }

  void clear() {
    state = [];
  }

  int get subtotalCents =>
      state.fold(0, (sum, item) => sum + item.lineTotalCents);
  double get subtotal => subtotalCents / 100;

  int get itemCount => state.length;

  bool get isEmpty => state.isEmpty;

  bool get isNotEmpty => state.isNotEmpty;
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

final cartSubtotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  final cents = cart.fold(0, (sum, item) => sum + item.lineTotalCents);
  return cents / 100;
});

final cartSubtotalCentsProvider = Provider<int>((ref) {
  return ref
      .watch(cartProvider)
      .fold(0, (sum, item) => sum + item.lineTotalCents);
});

final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).length;
});

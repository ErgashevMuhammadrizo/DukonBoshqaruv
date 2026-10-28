import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../src/api.dart';
import '../../../src/offline.dart';
import '../../../src/app.dart'; // Import for apiProvider and queueProvider
import '../models/product.dart';

final productsStaleProvider = StateProvider<bool>((ref) => false);

// Products list provider
final productsProvider =
    StateNotifierProvider<ProductsNotifier, AsyncValue<List<Product>>>((ref) {
  return ProductsNotifier(
    ref.read(apiProvider),
    ref.read(queueProvider),
    (stale) => ref.read(productsStaleProvider.notifier).state = stale,
  );
});

class ProductsNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  final Api _api;
  final OfflineQueue _queue;
  final void Function(bool) _setStale;

  ProductsNotifier(this._api, this._queue, this._setStale)
      : super(const AsyncValue.loading()) {
    loadProducts();
  }

  Future<void> loadProducts({bool forceRefresh = false}) async {
    if (!forceRefresh && state.hasValue) {
      // Don't reload if already loaded
      return;
    }

    try {
      state = const AsyncValue.loading();
      final data = await _api.products();
      final products = data.map((json) => Product.fromJson(json)).toList();

      // Cache products offline
      await _queue.cacheProducts(data);

      _setStale(false);
      state = AsyncValue.data(products);
    } catch (e, stack) {
      // Try to load from cache
      try {
        final cached = await _queue.cachedProducts();
        if (cached.isNotEmpty) {
          final products =
              cached.map((json) => Product.fromJson(json)).toList();
          _setStale(true);
          state = AsyncValue.data(products);
        } else {
          _setStale(false);
          state = AsyncValue.error(e, stack);
        }
      } catch (_) {
        _setStale(false);
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> refresh() async {
    await loadProducts(forceRefresh: true);
  }

  Future<Product?> addProduct(Map<String, dynamic> data,
      {String? imagePath}) async {
    try {
      final result = await _api.createProduct(data, imagePath: imagePath);
      final newProduct = Product.fromJson(result);

      // Add to local list
      state.whenData((products) {
        state = AsyncValue.data([...products, newProduct]);
      });

      return newProduct;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProduct(int id, Map<String, dynamic> data,
      {String? imagePath}) async {
    try {
      final result = await _api.updateProduct(id, data, imagePath: imagePath);
      final updatedProduct = Product.fromJson(result);

      // Update in local list
      state.whenData((products) {
        final index = products.indexWhere((p) => p.id == id);
        if (index != -1) {
          final newList = [...products];
          newList[index] = updatedProduct;
          state = AsyncValue.data(newList);
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      await _api.deleteProduct(id);

      // Remove from local list
      state.whenData((products) {
        state = AsyncValue.data(products.where((p) => p.id != id).toList());
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> archiveProduct(int id) async {
    try {
      await _api.archiveProduct(id);

      // Update active status in local list
      state.whenData((products) {
        final index = products.indexWhere((p) => p.id == id);
        if (index != -1) {
          final newList = [...products];
          newList[index] = newList[index].copyWith(active: false);
          state = AsyncValue.data(newList);
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Mahsulot miqdorini lokal ravishda yangilaydi (API chaqiruvidan keyin)
  void updateStockLocally(int productId, double newStock) {
    state.whenData((products) {
      final index = products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        final newList = [...products];
        newList[index] = newList[index].copyWith(stock: newStock.toString());
        state = AsyncValue.data(newList);
      }
    });
  }

  /// Delta asosida lokal stock ni yangilaydi
  void adjustStockLocally(int productId, double delta) {
    state.whenData((products) {
      final index = products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        final current = double.tryParse(products[index].stock) ?? 0;
        final newStock = (current + delta).clamp(0.0, double.infinity);
        final newList = [...products];
        newList[index] =
            newList[index].copyWith(stock: newStock.toStringAsFixed(3));
        state = AsyncValue.data(newList);
      }
    });
  }
}

// Filtered products provider
final productFiltersProvider = StateProvider<ProductFilters>((ref) {
  return ProductFilters();
});

final filteredProductsProvider = Provider<List<Product>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final filters = ref.watch(productFiltersProvider);

  return productsAsync.when(
    data: (products) {
      var filtered = products;

      // Search filter
      if (filters.searchQuery != null && filters.searchQuery!.isNotEmpty) {
        final query = filters.searchQuery!.toLowerCase();
        filtered = filtered.where((p) {
          return p.name.toLowerCase().contains(query) ||
              p.sku.toLowerCase().contains(query) ||
              (p.barcode?.toLowerCase().contains(query) ?? false) ||
              (p.categoryName?.toLowerCase().contains(query) ?? false);
        }).toList();
      }

      // Category filter
      if (filters.categoryId != null) {
        filtered =
            filtered.where((p) => p.categoryId == filters.categoryId).toList();
      }

      // Stock status filter
      if (filters.stockStatus != null && filters.stockStatus != 'all') {
        filtered = filtered
            .where((p) => p.stockStatus == filters.stockStatus)
            .toList();
      }

      // Price range filter
      if (filters.minPrice != null) {
        filtered = filtered.where((p) {
          final price = double.tryParse(p.salePrice) ?? 0;
          return price >= filters.minPrice!;
        }).toList();
      }
      if (filters.maxPrice != null) {
        filtered = filtered.where((p) {
          final price = double.tryParse(p.salePrice) ?? 0;
          return price <= filters.maxPrice!;
        }).toList();
      }

      // Sorting
      filtered.sort((a, b) {
        int comparison = 0;

        switch (filters.sortBy) {
          case 'name':
            comparison = a.name.compareTo(b.name);
            break;
          case 'sale_price':
            final priceA = double.tryParse(a.salePrice) ?? 0;
            final priceB = double.tryParse(b.salePrice) ?? 0;
            comparison = priceA.compareTo(priceB);
            break;
          case 'purchase_price':
            final priceA = double.tryParse(a.purchasePrice) ?? 0;
            final priceB = double.tryParse(b.purchasePrice) ?? 0;
            comparison = priceA.compareTo(priceB);
            break;
          case 'stock':
            final stockA = double.tryParse(a.stock) ?? 0;
            final stockB = double.tryParse(b.stock) ?? 0;
            comparison = stockA.compareTo(stockB);
            break;
        }

        return filters.sortAscending ? comparison : -comparison;
      });

      return filtered;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Product summary provider
final productSummaryProvider = Provider<ProductSummary>((ref) {
  final products = ref.watch(filteredProductsProvider);
  return ProductSummary.fromProducts(products);
});

// Categories provider
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final api = ref.read(apiProvider);
  final data = await api.getCategories();
  return data.map((json) => Category.fromJson(json)).toList();
});

// Single product provider
final productProvider = FutureProvider.family<Product?, int>((ref, id) async {
  final api = ref.read(apiProvider);
  final data = await api.getProduct(id);
  return data != null ? Product.fromJson(data) : null;
});

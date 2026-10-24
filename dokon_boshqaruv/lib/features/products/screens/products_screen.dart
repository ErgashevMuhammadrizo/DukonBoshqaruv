import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/products_provider.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import '../widgets/product_summary_cards.dart';
import '../widgets/empty_state.dart';
import 'add_product_screen.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _viewMode = 'list'; // 'list' or 'grid'

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final filteredProducts = ref.watch(filteredProductsProvider);
    final summary = ref.watch(productSummaryProvider);
    final filters = ref.watch(productFiltersProvider);
    final productsStale = ref.watch(productsStaleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mahsulotlar'),
            Text(
              'Mahsulotlarni boshqarish',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          // View mode toggle (only on larger screens)
          if (MediaQuery.of(context).size.width > 600)
            IconButton(
              icon:
                  Icon(_viewMode == 'list' ? Icons.grid_view : Icons.view_list),
              onPressed: () {
                setState(() {
                  _viewMode = _viewMode == 'list' ? 'grid' : 'list';
                });
              },
              tooltip:
                  _viewMode == 'list' ? 'Grid ko\'rinish' : 'List ko\'rinish',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(productsProvider.notifier).refresh();
            },
            tooltip: 'Yangilash',
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (filters.hasActiveFilters)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              _showFiltersSheet(context);
            },
            tooltip: 'Filtrlar',
          ),
        ],
      ),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return EmptyProductsState(
              onAddProduct: () => _navigateToAddProduct(context),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(productsProvider.notifier).refresh(),
            child: CustomScrollView(
              slivers: [
                // Summary cards
                SliverToBoxAdapter(
                  child: ProductSummaryCards(summary: summary),
                ),

                if (productsStale)
                  const SliverToBoxAdapter(child: _StaleInventoryNotice()),

                SliverToBoxAdapter(
                  child: _StockWarnings(
                    products: products
                        .where((p) => p.active && p.stockStatus != 'mavjud')
                        .toList(),
                  ),
                ),

                // Search bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Qidirish (nom, kod, shtrix-kod)...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: filters.searchQuery != null &&
                                filters.searchQuery!.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  ref
                                          .read(productFiltersProvider.notifier)
                                          .state =
                                      filters.copyWith(searchQuery: '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        // Debouncing handled by provider
                        ref.read(productFiltersProvider.notifier).state =
                            filters.copyWith(searchQuery: value);
                      },
                    ),
                  ),
                ),

                // Active filters chip
                if (filters.hasActiveFilters)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (filters.categoryId != null)
                            Chip(
                              label: const Text('Kategoriya'),
                              onDeleted: () {
                                ref
                                    .read(productFiltersProvider.notifier)
                                    .state = filters.copyWith(categoryId: null);
                              },
                            ),
                          if (filters.stockStatus != null &&
                              filters.stockStatus != 'all')
                            Chip(
                              label: Text('Holat: ${filters.stockStatus}'),
                              onDeleted: () {
                                ref
                                        .read(productFiltersProvider.notifier)
                                        .state =
                                    filters.copyWith(stockStatus: 'all');
                              },
                            ),
                          if (filters.minPrice != null ||
                              filters.maxPrice != null)
                            Chip(
                              label: const Text('Narx oralig\'i'),
                              onDeleted: () {
                                ref
                                    .read(productFiltersProvider.notifier)
                                    .state = filters.copyWith(
                                  minPrice: null,
                                  maxPrice: null,
                                );
                              },
                            ),
                          TextButton.icon(
                            onPressed: () {
                              ref.read(productFiltersProvider.notifier).state =
                                  filters.clearFilters();
                            },
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Barchasini tozalash'),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Products list/grid
                if (filteredProducts.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Hech narsa topilmadi',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Filtrlarni o\'zgartiring yoki qidiruvni tozalang',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_viewMode == 'grid' &&
                    MediaQuery.of(context).size.width > 600)
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            MediaQuery.of(context).size.width > 1200 ? 4 : 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = filteredProducts[index];
                          return ProductCard(
                            product: product,
                            onTap: () => _navigateToDetail(context, product.id),
                          );
                        },
                        childCount: filteredProducts.length,
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = filteredProducts[index];
                        return ProductListTile(
                          product: product,
                          onTap: () => _navigateToDetail(context, product.id),
                        );
                      },
                      childCount: filteredProducts.length,
                    ),
                  ),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Xatolik: $error'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(productsProvider.notifier).refresh();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddProduct(context),
        icon: const Icon(Icons.add),
        label: const Text('Mahsulot qo\'shish'),
      ),
    );
  }

  void _navigateToAddProduct(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddProductScreen()),
    );
  }

  void _navigateToDetail(BuildContext context, int productId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: productId),
      ),
    );
  }

  void _showFiltersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ProductFiltersSheet(),
    );
  }
}

class _StockWarnings extends StatelessWidget {
  final List<Product> products;
  const _StockWarnings({required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        color: const Color(0xFFFFF8E1),
        child: Column(
          children: products.map((product) {
            final empty = product.stockStatus == 'tugagan';
            final color = empty ? Colors.red.shade700 : Colors.orange.shade800;
            final stock = product.stock;
            return ListTile(
              dense: true,
              leading: Icon(empty ? Icons.error_outline : Icons.warning_amber,
                  color: color),
              title: Text(
                empty
                    ? '${product.name} tugagan!'
                    : '${product.name} kam qoldi.',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(empty
                  ? 'Omborda mahsulot qolmagan. Ogohlantirish chegarasi: ${product.minStock} ${product.unit}.'
                  : 'Omborda $stock ${product.unit}. Ogohlantirish chegarasi: ${product.minStock} ${product.unit}.'),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _StaleInventoryNotice extends StatelessWidget {
  const _StaleInventoryNotice();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Card(
          color: Color(0xFFFFF3E0),
          child: ListTile(
            dense: true,
            leading: Icon(Icons.cloud_off, color: Colors.deepOrange),
            title:
                Text('Internet yo‘q — qoldiq keshlangan ma’lumotdan olingan.'),
            subtitle:
                Text('Sotuv serverga yuborilganda qoldiq qayta tekshiriladi.'),
          ),
        ),
      );
}

class ProductFiltersSheet extends ConsumerStatefulWidget {
  const ProductFiltersSheet({super.key});

  @override
  ConsumerState<ProductFiltersSheet> createState() =>
      _ProductFiltersSheetState();
}

class _ProductFiltersSheetState extends ConsumerState<ProductFiltersSheet> {
  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(productFiltersProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtrlar',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(productFiltersProvider.notifier).state =
                          filters.clearFilters();
                    },
                    child: const Text('Tozalash'),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Category filter
                    const Text(
                      'Kategoriya',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    categoriesAsync.when(
                      data: (categories) {
                        return Wrap(
                          spacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('Barchasi'),
                              selected: filters.categoryId == null,
                              onSelected: (selected) {
                                if (selected) {
                                  ref
                                          .read(productFiltersProvider.notifier)
                                          .state =
                                      filters.copyWith(categoryId: null);
                                }
                              },
                            ),
                            ...categories.map((category) {
                              return FilterChip(
                                label: Text(category.name),
                                selected: filters.categoryId == category.id,
                                onSelected: (selected) {
                                  ref
                                      .read(productFiltersProvider.notifier)
                                      .state = filters.copyWith(
                                    categoryId: selected ? category.id : null,
                                  );
                                },
                              );
                            }),
                          ],
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Kategoriyalar yuklanmadi'),
                    ),
                    const SizedBox(height: 16),

                    // Stock status filter
                    const Text(
                      'Ombordagi holati',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Barchasi'),
                          selected: filters.stockStatus == null ||
                              filters.stockStatus == 'all',
                          onSelected: (selected) {
                            ref.read(productFiltersProvider.notifier).state =
                                filters.copyWith(stockStatus: 'all');
                          },
                        ),
                        FilterChip(
                          label: const Text('Mavjud'),
                          selected: filters.stockStatus == 'mavjud',
                          onSelected: (selected) {
                            ref.read(productFiltersProvider.notifier).state =
                                filters.copyWith(
                              stockStatus: selected ? 'mavjud' : 'all',
                            );
                          },
                        ),
                        FilterChip(
                          label: const Text('Kam qolgan'),
                          selected: filters.stockStatus == 'kam_qolgan',
                          onSelected: (selected) {
                            ref.read(productFiltersProvider.notifier).state =
                                filters.copyWith(
                              stockStatus: selected ? 'kam_qolgan' : 'all',
                            );
                          },
                        ),
                        FilterChip(
                          label: const Text('Tugagan'),
                          selected: filters.stockStatus == 'tugagan',
                          onSelected: (selected) {
                            ref.read(productFiltersProvider.notifier).state =
                                filters.copyWith(
                              stockStatus: selected ? 'tugagan' : 'all',
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sort by
                    const Text(
                      'Saralash',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Nomi'),
                          selected: filters.sortBy == 'name',
                          onSelected: (selected) {
                            ref.read(productFiltersProvider.notifier).state =
                                filters.copyWith(sortBy: 'name');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Sotuv narxi'),
                          selected: filters.sortBy == 'sale_price',
                          onSelected: (selected) {
                            ref.read(productFiltersProvider.notifier).state =
                                filters.copyWith(sortBy: 'sale_price');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Qoldiq'),
                          selected: filters.sortBy == 'stock',
                          onSelected: (selected) {
                            ref.read(productFiltersProvider.notifier).state =
                                filters.copyWith(sortBy: 'stock');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('O\'sish tartibida'),
                      value: filters.sortAscending,
                      onChanged: (value) {
                        ref.read(productFiltersProvider.notifier).state =
                            filters.copyWith(sortAscending: value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Qo\'llash'),
              ),
            ],
          ),
        );
      },
    );
  }
}

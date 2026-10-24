import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../products/providers/products_provider.dart';
import '../../products/models/product.dart';
import '../providers/cart_provider.dart';
import 'package:intl/intl.dart';

class ProductGrid extends ConsumerWidget {
  final String searchQuery;

  const ProductGrid({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    return productsAsync.when(
      data: (products) {
        // Only show active products with stock > 0 filter option
        final filteredProducts = searchQuery.isEmpty
            ? products.where((p) => p.active).toList()
            : products.where((p) {
                if (!p.active) return false;
                final query = searchQuery.toLowerCase();
                return p.name.toLowerCase().contains(query) ||
                    p.sku.toLowerCase().contains(query) ||
                    (p.barcode?.toLowerCase().contains(query) ?? false);
              }).toList();

        if (filteredProducts.isEmpty) {
          return _buildEmptyState(searchQuery);
        }

        final width = MediaQuery.of(context).size.width;
        final isMobile = width < 600;
        int crossAxisCount;
        if (isMobile) {
          crossAxisCount = 2;
        } else if (width < 900) {
          crossAxisCount = 3;
        } else if (width < 1200) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 4;
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: isMobile ? 0.72 : 0.78,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: filteredProducts.length,
          itemBuilder: (context, index) {
            final product = filteredProducts[index];
            return _ProductCard(product: product);
          },
        );
      },
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 3),
            SizedBox(height: 12),
            Text('Mahsulotlar yuklanmoqda...',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.error_outline_rounded,
                    size: 40, color: Colors.red[400]),
              ),
              const SizedBox(height: 16),
              const Text(
                'Xatolik yuz berdi',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF424242)),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                query.isEmpty
                    ? Icons.inventory_2_outlined
                    : Icons.search_off_rounded,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              query.isEmpty ? 'Mahsulotlar yo\'q' : 'Hech narsa topilmadi',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF616161),
              ),
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '"$query" bo\'yicha natija yo\'q',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerStatefulWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  ConsumerState<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<_ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _addCtrl;
  late Animation<double> _addScale;

  @override
  void initState() {
    super.initState();
    _addCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _addScale = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(parent: _addCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  void _onAddToCart() {
    final product = widget.product;
    final stock = double.tryParse(product.stock) ?? 0;
    if (stock <= 0) return;

    // Bounce animation: shrink then return
    _addCtrl.forward().then((_) => _addCtrl.reverse());

    ref.read(cartProvider.notifier).addProduct(product);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.add_shopping_cart_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${product.name} savatga qo\'shildi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1565C0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final stock = double.tryParse(product.stock) ?? 0;
    final isAvailable = stock > 0;
    final isInCart =
        ref.watch(cartProvider).any((item) => item.productId == product.id);
    final numberFormat = NumberFormat('#,##0', 'uz_UZ');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInCart
              ? const Color(0xFF1565C0).withOpacity(0.6)
              : const Color(0xFFEEEEEE),
          width: isInCart ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isInCart
                ? const Color(0xFF1565C0).withOpacity(0.12)
                : Colors.black.withOpacity(0.05),
            blurRadius: isInCart ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: isAvailable ? _onAddToCart : null,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Image / Icon Area ──
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? const Color(0xFFF3F8FF)
                            : Colors.grey[100],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: product.image != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: Image.network(
                                product.image!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) =>
                                    _buildIconPlaceholder(isAvailable),
                              ),
                            )
                          : _buildIconPlaceholder(isAvailable),
                    ),
                    // Out of stock overlay
                    if (!isAvailable)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'TUGAGAN',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    // In-cart badge
                    if (isInCart)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shopping_cart_rounded,
                                  color: Colors.white, size: 11),
                              SizedBox(width: 3),
                              Text(
                                'Savatda',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Stock badge top-right
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildStockBadge(stock, product.unit),
                    ),
                  ],
                ),
              ),

              // ── Info area ──
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.3,
                          color: isAvailable
                              ? const Color(0xFF212121)
                              : Colors.grey[500],
                        ),
                      ),
                      const Spacer(),
                      // Price row + add button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${numberFormat.format(double.tryParse(product.salePrice) ?? 0)} so\'m',
                                  style: TextStyle(
                                    color: isAvailable
                                        ? const Color(0xFF1565C0)
                                        : Colors.grey[400],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isAvailable)
                            ScaleTransition(
                              scale: _addScale,
                              child: GestureDetector(
                                onTap: _onAddToCart,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF1565C0),
                                        Color(0xFF1E88E5),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(9),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x441565C0),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.add_rounded,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconPlaceholder(bool isAvailable) {
    return Center(
      child: Icon(
        Icons.inventory_2_outlined,
        size: 48,
        color: isAvailable ? const Color(0xFF90CAF9) : Colors.grey[300],
      ),
    );
  }

  Widget _buildStockBadge(double stock, String unit) {
    if (stock <= 0) return const SizedBox.shrink();
    final isLow = stock <= (double.tryParse(widget.product.minStock) ?? 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isLow ? Colors.orange[700] : const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${stock % 1 == 0 ? stock.toInt() : stock.toStringAsFixed(1)} $unit',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

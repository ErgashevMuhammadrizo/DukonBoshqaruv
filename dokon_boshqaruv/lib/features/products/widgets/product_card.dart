import '../../../src/adaptive_colors.dart';
import '../../../src/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import 'quick_stock_adjustment.dart';

class ProductCard extends ConsumerWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppLocaleScope.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder with quick action
            Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        adaptiveColor(context, Colors.grey[100]!),
                        adaptiveColor(context, Colors.grey[200]!)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: product.image == null || product.image!.isEmpty
                      ? Icon(Icons.inventory_2_outlined,
                          size: 56,
                          color: adaptiveColor(context, Colors.grey[400]!))
                      : Image.network(
                          product.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.inventory_2_outlined,
                            size: 56,
                            color: adaptiveColor(context, Colors.grey[400]!),
                          ),
                        ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _StockBadge(product: product),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.qr_code_2,
                            size: 12,
                            color: adaptiveColor(context, Colors.grey[600]!)),
                        SizedBox(width: 4),
                        Text(
                          product.sku,
                          style: TextStyle(
                            fontSize: 11,
                            color: adaptiveColor(context, Colors.grey[600]!,
                                foreground: true),
                          ),
                        ),
                      ],
                    ),
                    Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('m631', [product.salePrice]),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: adaptiveColor(context, Colors.blue,
                                      foreground: true),
                                ),
                              ),
                              Text(
                                '${double.tryParse(product.stock)?.toStringAsFixed(1) ?? product.stock} ${product.unit}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: adaptiveColor(
                                      context, Colors.grey[600]!,
                                      foreground: true),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: adaptiveColor(context, Colors.blue[50]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.add_rounded,
                                size: 18,
                                color: adaptiveColor(context, Colors.blue[700]!,
                                    foreground: true)),
                          ),
                          onPressed: () async {
                            await showDialog<bool>(
                              context: context,
                              builder: (context) =>
                                  QuickStockAdjustmentDialog(product: product),
                            );
                          },
                          tooltip: tr('m519'),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
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
    );
  }
}

class ProductListTile extends ConsumerWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductListTile({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppLocaleScope.of(context);
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minVerticalPadding: 12,
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                adaptiveColor(context, Colors.grey[100]!),
                adaptiveColor(context, Colors.grey[200]!)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.inventory_2_outlined,
              color:
                  adaptiveColor(context, Colors.grey[400]!, foreground: true),
              size: 28),
        ),
        title: Text(
          product.name,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.qr_code_2,
                    size: 12, color: adaptiveColor(context, Colors.grey[600]!)),
                SizedBox(width: 4),
                Expanded(
                    child: Text(product.sku,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: adaptiveColor(context, Colors.grey[600]!,
                                foreground: true)))),
              ],
            ),
            if (product.categoryName != null)
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(Icons.category_outlined,
                        size: 12,
                        color: adaptiveColor(context, Colors.grey[600]!)),
                    SizedBox(width: 4),
                    Text(
                      product.categoryName!,
                      style: TextStyle(
                          fontSize: 12,
                          color: adaptiveColor(context, Colors.grey[600]!,
                              foreground: true)),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: adaptiveColor(context, Colors.blue[50]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${double.tryParse(product.stock)?.toStringAsFixed(1) ?? product.stock} ${product.unit}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: adaptiveColor(context, Colors.blue[700]!,
                          foreground: true),
                    ),
                  ),
                ),
                _StockBadge(product: product),
              ],
            ),
          ],
        ),
        trailing: SizedBox(
          width: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tr('m631', [
                  double.tryParse(product.salePrice)?.toStringAsFixed(0) ??
                      product.salePrice
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: adaptiveColor(context, Colors.blue, foreground: true),
                ),
              ),
              SizedBox(height: 4),
              GestureDetector(
                onTap: () async {
                  await showDialog<bool>(
                    context: context,
                    builder: (context) =>
                        QuickStockAdjustmentDialog(product: product),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: adaptiveColor(context, Colors.blue[700]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded,
                          size: 13,
                          color: adaptiveColor(context, Colors.white)),
                      SizedBox(width: 3),
                      Text(
                        tr('m393'),
                        style: TextStyle(
                            color: adaptiveColor(context, Colors.white,
                                foreground: true),
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final Product product;

  const _StockBadge({required this.product});

  @override
  Widget build(BuildContext context) {
    AppLocaleScope.of(context);
    Color color;
    IconData icon;

    switch (product.stockStatus) {
      case 'tugagan':
        color = Colors.red;
        icon = Icons.error_rounded;
        break;
      case 'kam_qolgan':
        color = Colors.orange;
        icon = Icons.warning_rounded;
        break;
      case 'mavjud':
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(
            product.stockStatusLabel,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

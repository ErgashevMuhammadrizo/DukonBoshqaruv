import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductSummaryCards extends StatelessWidget {
  final ProductSummary summary;

  const ProductSummaryCards({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    if (isSmallScreen) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Jami',
                    value: summary.totalProducts.toString(),
                    icon: Icons.inventory_2,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'Qoldiq',
                    value: summary.totalStock.toStringAsFixed(0),
                    icon: Icons.storage,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Kam qolgan',
                    value: summary.lowStockCount.toString(),
                    icon: Icons.warning_amber,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'Tugagan',
                    value: summary.outOfStockCount.toString(),
                    icon: Icons.error_outline,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Desktop/tablet layout
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              title: 'Jami mahsulotlar',
              value: summary.totalProducts.toString(),
              icon: Icons.inventory_2,
              color: Colors.blue,
              isLarge: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _SummaryCard(
              title: 'Jami qoldiq',
              value: summary.totalStock.toStringAsFixed(0),
              icon: Icons.storage,
              color: Colors.green,
              isLarge: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _SummaryCard(
              title: 'Kam qolgan',
              value: summary.lowStockCount.toString(),
              icon: Icons.warning_amber,
              color: Colors.orange,
              isLarge: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _SummaryCard(
              title: 'Tugagan',
              value: summary.outOfStockCount.toString(),
              icon: Icons.error_outline,
              color: Colors.red,
              isLarge: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLarge;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isLarge ? 20.0 : 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: isLarge ? 32 : 24),
                if (isLarge)
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
              ],
            ),
            SizedBox(height: isLarge ? 12 : 8),
            Text(
              title,
              style: TextStyle(
                fontSize: isLarge ? 14 : 12,
                color: Colors.grey[600],
              ),
            ),
            if (!isLarge)
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

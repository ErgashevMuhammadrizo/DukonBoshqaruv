import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../../../src/app.dart';
import '../providers/products_provider.dart';

class QuickStockAdjustmentDialog extends ConsumerStatefulWidget {
  final Product product;

  const QuickStockAdjustmentDialog({super.key, required this.product});

  @override
  ConsumerState<QuickStockAdjustmentDialog> createState() =>
      _QuickStockAdjustmentDialogState();
}

class _QuickStockAdjustmentDialogState
    extends ConsumerState<QuickStockAdjustmentDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  final List<int> _presets = [10, 20, 50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitAdjustment(bool isAdding) async {
    if (_quantityController.text.isEmpty) {
      setState(() => _error = 'Miqdorni kiriting');
      return;
    }

    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'To\'g\'ri miqdor kiriting');
      return;
    }

    final delta = isAdding ? quantity : -quantity;
    final currentStock = double.tryParse(widget.product.stock) ?? 0;

    // Check if subtraction would result in negative stock
    if (!isAdding && (currentStock + delta) < 0) {
      setState(() => _error = 'Qoldiq manfiy bo\'lishi mumkin emas');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref.read(apiProvider).adjustStock(
            widget.product.id,
            delta.toStringAsFixed(3),
            _reasonController.text.isEmpty
                ? (isAdding ? 'Qo\'shildi' : 'Ayrildi')
                : _reasonController.text,
          );

      // Lokal ravishda darhol yangilaymiz — sahifa qayta yuklanmaydi
      ref
          .read(productsProvider.notifier)
          .adjustStockLocally(widget.product.id, delta);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Qoldiq ${isAdding ? "qo\'shildi" : "ayrildi"}: ${quantity.toStringAsFixed(1)} ${widget.product.unit}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdding = _tabController.index == 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[400]!],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Qoldiqni boshqarish',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.product.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Joriy qoldiq: ${double.tryParse(widget.product.stock)?.toStringAsFixed(1) ?? widget.product.stock} ${widget.product.unit}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.blue[700]!, width: 3),
                  ),
                ),
                labelColor: Colors.blue[700],
                unselectedLabelColor: Colors.grey[600],
                onTap: (_) => setState(() {}),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.add_circle_outline_rounded),
                    text: 'Qo\'shish',
                  ),
                  Tab(
                    icon: Icon(Icons.remove_circle_outline_rounded),
                    text: 'Ayirish',
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Presets
                    const Text(
                      'Tez tanlov',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presets.map((preset) {
                        return ActionChip(
                          label: Text('$preset ${widget.product.unit}'),
                          avatar: Icon(
                            isAdding ? Icons.add_rounded : Icons.remove_rounded,
                            size: 18,
                          ),
                          backgroundColor: Colors.blue[50],
                          labelStyle: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                          side: BorderSide(color: Colors.blue[200]!),
                          onPressed: () {
                            _quantityController.text = preset.toString();
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Quantity Input
                    TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Miqdor *',
                        hintText: '0.0',
                        suffixText: widget.product.unit,
                        prefixIcon: Icon(
                          isAdding
                              ? Icons.add_circle_rounded
                              : Icons.remove_circle_rounded,
                          color: isAdding ? Colors.green : Colors.orange,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      autofocus: true,
                      onChanged: (_) => setState(() => _error = null),
                    ),

                    const SizedBox(height: 16),

                    // Reason Input
                    TextField(
                      controller: _reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Sabab',
                        hintText: isAdding
                            ? 'Masalan: Yangi partiya keldi'
                            : 'Masalan: Singan mahsulotlar',
                        prefixIcon: const Icon(Icons.notes_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  color: Colors.red[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                      color: Colors.red[700], fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Preview
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isAdding
                              ? [Colors.green[50]!, Colors.green[100]!]
                              : [Colors.orange[50]!, Colors.orange[100]!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isAdding
                              ? Colors.green[300]!
                              : Colors.orange[300]!,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Joriy qoldiq:',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${double.tryParse(widget.product.stock)?.toStringAsFixed(1) ?? widget.product.stock} ${widget.product.unit}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Yangi qoldiq:',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _calculateNewStock(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isAdding
                                      ? Colors.green[700]
                                      : Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Bekor qilish'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _submitAdjustment(isAdding),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor:
                            isAdding ? Colors.green : Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(isAdding
                              ? Icons.add_rounded
                              : Icons.remove_rounded),
                      label: Text(
                        _isSubmitting
                            ? 'Saqlanmoqda...'
                            : (isAdding ? 'Qo\'shish' : 'Ayirish'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _calculateNewStock() {
    final quantity = double.tryParse(_quantityController.text);
    final currentStock = double.tryParse(widget.product.stock) ?? 0;

    if (quantity == null) {
      return '${currentStock.toStringAsFixed(1)} ${widget.product.unit}';
    }

    final isAdding = _tabController.index == 0;
    final delta = isAdding ? quantity : -quantity;
    final newStock = currentStock + delta;

    return '${newStock.toStringAsFixed(1)} ${widget.product.unit}';
  }
}

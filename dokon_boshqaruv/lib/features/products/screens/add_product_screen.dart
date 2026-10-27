import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/products_provider.dart';
import '../widgets/barcode_scanner_dialog.dart';
import '../widgets/image_picker_widget.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _imagePath;

  // Controllers
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _minStockController = TextEditingController(text: '0');
  final _descriptionController = TextEditingController();

  String _selectedUnit = 'dona';

  final List<String> _units = [
    'dona',
    'kg',
    'litr',
    'metr',
    'quti',
    'paket',
    'pachka',
    'butilka',
    'gramm',
    'ml',
    'm²',
    'm³',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yangi mahsulot qo\'shish'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Product Image Section
            _SectionHeader(
              title: 'Mahsulot rasmi',
              icon: Icons.image,
            ),
            const SizedBox(height: 16),
            ImagePickerWidget(
              initialImagePath: _imagePath,
              onImageSelected: (path) {
                setState(() {
                  _imagePath = path;
                });
              },
            ),
            const SizedBox(height: 24),

            // Basic Information Section
            _SectionHeader(
              title: 'Asosiy ma\'lumotlar',
              icon: Icons.info_outline,
            ),
            const SizedBox(height: 16),

            if (isSmallScreen) ...[
              // Mobile layout - single column
              _buildNameField(),
              const SizedBox(height: 16),
              _buildSKUField(),
              const SizedBox(height: 16),
              _buildBarcodeField(),
            ] else ...[
              // Desktop layout - two columns
              Row(
                children: [
                  Expanded(child: _buildNameField()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSKUField()),
                ],
              ),
              const SizedBox(height: 16),
              _buildBarcodeField(),
            ],

            const SizedBox(height: 24),

            // Pricing Section
            _SectionHeader(
              title: 'Narxlar',
              icon: Icons.attach_money,
            ),
            const SizedBox(height: 16),

            if (isSmallScreen) ...[
              _buildPurchasePriceField(),
              const SizedBox(height: 16),
              _buildSalePriceField(),
            ] else ...[
              Row(
                children: [
                  Expanded(child: _buildPurchasePriceField()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSalePriceField()),
                ],
              ),
            ],

            // Price warning
            if (_purchasePriceController.text.isNotEmpty &&
                _salePriceController.text.isNotEmpty)
              Builder(
                builder: (context) {
                  final purchase =
                      double.tryParse(_purchasePriceController.text) ?? 0;
                  final sale = double.tryParse(_salePriceController.text) ?? 0;

                  if (sale > 0 && sale < purchase) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Card(
                        color: Colors.orange[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.orange[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Sotuv narxi xarid narxidan past',
                                  style: TextStyle(color: Colors.orange[900]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

            const SizedBox(height: 24),

            // Inventory Section
            _SectionHeader(
              title: 'Ombor',
              icon: Icons.storage,
            ),
            const SizedBox(height: 16),

            if (isSmallScreen) ...[
              _buildStockField(),
              const SizedBox(height: 16),
              _buildMinStockField(),
              const SizedBox(height: 16),
              _buildUnitField(),
            ] else ...[
              Row(
                children: [
                  Expanded(child: _buildStockField()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMinStockField()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildUnitField()),
                ],
              ),
            ],

            const SizedBox(height: 8),
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Boshlang\'ich qoldiq kiritish ixtiyoriy. Keyinchalik ombor harakatlaridan o\'zgartirishingiz mumkin.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
            FilledButton(
              onPressed: _isSaving ? null : _saveProduct,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Mahsulotni saqlash'),
            ),

            const SizedBox(height: 16),

            OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Bekor qilish'),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Mahsulot nomi *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.inventory_2),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Mahsulot nomini kiriting';
        }
        return null;
      },
      textCapitalization: TextCapitalization.words,
    );
  }

  Widget _buildSKUField() {
    return TextFormField(
      controller: _skuController,
      decoration: InputDecoration(
        labelText: 'Mahsulot kodi (SKU) *',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.qr_code),
        suffixIcon: IconButton(
          icon: const Icon(Icons.auto_fix_high),
          onPressed: _generateSKU,
          tooltip: 'Avtomatik generatsiya',
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'SKU kiriting';
        }
        return null;
      },
      textCapitalization: TextCapitalization.characters,
    );
  }

  Widget _buildBarcodeField() {
    return TextFormField(
      controller: _barcodeController,
      decoration: InputDecoration(
        labelText: 'Shtrix-kod',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.barcode_reader),
        helperText: 'Ixtiyoriy',
        suffixIcon: IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: () async {
            final barcode = await showDialog<String>(
              context: context,
              builder: (context) => const BarcodeScannerDialog(),
            );
            if (barcode != null) {
              _barcodeController.text = barcode;
            }
          },
          tooltip: 'Skanerlash',
        ),
      ),
      keyboardType: TextInputType.number,
    );
  }

  Widget _buildPurchasePriceField() {
    return TextFormField(
      controller: _purchasePriceController,
      decoration: const InputDecoration(
        labelText: 'Xarid narxi',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.shopping_cart),
        suffixText: 'UZS',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final price = double.tryParse(value);
          if (price == null || price < 0) {
            return 'To\'g\'ri narx kiriting';
          }
        }
        return null;
      },
    );
  }

  Widget _buildSalePriceField() {
    return TextFormField(
      controller: _salePriceController,
      decoration: const InputDecoration(
        labelText: 'Sotuv narxi *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.sell),
        suffixText: 'UZS',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Sotuv narxini kiriting';
        }
        final price = double.tryParse(value);
        if (price == null || price <= 0) {
          return 'To\'g\'ri narx kiriting';
        }
        return null;
      },
    );
  }

  bool get _fractionalUnit =>
      {'kg', 'gramm', 'litr', 'ml', 'metr', 'm²', 'm³'}.contains(_selectedUnit);

  Widget _buildStockField() {
    return TextFormField(
      controller: _stockController,
      decoration: const InputDecoration(
        labelText: 'Boshlang\'ich qoldiq',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.inventory),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
      ],
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final stock = double.tryParse(value);
          if (stock == null ||
              stock < 0 ||
              (!_fractionalUnit && stock != stock.truncateToDouble())) {
            return 'To\'g\'ri miqdor kiriting';
          }
        }
        return null;
      },
    );
  }

  Widget _buildMinStockField() {
    return TextFormField(
      controller: _minStockController,
      decoration: const InputDecoration(
        labelText: 'Minimal qoldiq',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.warning_amber),
        helperText: 'Ogohlantirish uchun',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
      ],
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final minStock = double.tryParse(value);
          if (minStock == null ||
              minStock < 0 ||
              (!_fractionalUnit && minStock != minStock.truncateToDouble())) {
            return 'To\'g\'ri miqdor kiriting';
          }
        }
        return null;
      },
    );
  }

  Widget _buildUnitField() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'O\'lchov birligi *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.straighten),
      ),
      value: _selectedUnit,
      items: _units.map((unit) {
        return DropdownMenuItem(
          value: unit,
          child: Text(unit),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedUnit = value;
            _formKey.currentState?.validate();
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Birlikni tanlang';
        }
        return null;
      },
    );
  }

  void _generateSKU() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final sku = 'PRD${timestamp.substring(timestamp.length - 8)}';
    _skuController.text = sku;
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final data = {
        'name': _nameController.text.trim(),
        'sku': _skuController.text.trim(),
        'barcode': _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        'purchase_price': _purchasePriceController.text.isEmpty
            ? '0'
            : _purchasePriceController.text,
        'sale_price': _salePriceController.text,
        'initial_stock':
            _stockController.text.isEmpty ? '0' : _stockController.text,
        'min_stock':
            _minStockController.text.isEmpty ? '0' : _minStockController.text,
        'unit': _selectedUnit,
        'active': true,
      };

      await ref
          .read(productsProvider.notifier)
          .addProduct(data, imagePath: _imagePath);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mahsulot muvaffaqiyatli qo\'shildi'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xatolik: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

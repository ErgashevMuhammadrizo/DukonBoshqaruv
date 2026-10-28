import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/cart_provider.dart';
import '../../products/providers/api.dart' hide productsProvider;
import '../../products/providers/products_provider.dart';
import '../../../src/app.dart' show queueProvider;
import '../screens/receipt_screen.dart';

class PaymentDialog extends ConsumerStatefulWidget {
  const PaymentDialog({super.key});

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _cashController = TextEditingController();
  final _cardController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  bool _isProcessing = false;
  String? _pendingOperationId;

  static const _kBlue = Color(0xFF1565C0);
  static const _kGreen = Color(0xFF2E7D32);
  static const _kGreenLight = Color(0xFFE8F5E9);
  static const _kBg = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cashController.dispose();
    _cardController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  double get _cashAmount => double.tryParse(_cashController.text) ?? 0;
  double get _cardAmount => double.tryParse(_cardController.text) ?? 0;
  double get _discount => double.tryParse(_discountController.text) ?? 0;

  void _setExact(double total) {
    if (_tabController.index == 0) {
      _cashController.text = total.toStringAsFixed(0);
    } else if (_tabController.index == 1) {
      _cardController.text = total.toStringAsFixed(0);
    }
    setState(() {});
  }

  Future<void> _processSale() async {
    final cart = ref.read(cartProvider);
    final subtotal = ref.read(cartSubtotalProvider);
    final total = subtotal - _discount;

    if (cart.isEmpty) {
      _snack('Savat bo\'sh', isError: true);
      return;
    }
    if (!_discount.isFinite || _discount < 0 || _discount > subtotal) {
      _snack('Chegirma summadan katta bo\'lishi mumkin emas', isError: true);
      return;
    }

    double cash = 0, card = 0;
    switch (_tabController.index) {
      case 0:
        cash = _cashAmount;
        if (cash < total) {
          _snack('Naqd pul yetarli emas (${_fmt(total - cash)} so\'m kam)',
              isError: true);
          return;
        }
        break;
      case 1:
        card = _cardAmount;
        if (card < total) {
          _snack('Karta summasi yetarli emas', isError: true);
          return;
        }
        break;
      default:
        cash = _cashAmount;
        card = _cardAmount;
        if (cash + card < total) {
          _snack(
              'To\'lov yetarli emas (${_fmt(total - cash - card)} so\'m kam)',
              isError: true);
          return;
        }
    }

    if (!cash.isFinite || !card.isFinite || cash < 0 || card < 0) {
      _snack('To‘lov summasi noto‘g‘ri', isError: true);
      return;
    }
    // Backend faqat to‘lanishi kerak bo‘lgan aniq summani saqlaydi.
    // Mijozdan ortiqcha olingan naqd pul qaytim hisoblanadi.
    if (_tabController.index == 0) cash = total;
    if (_tabController.index == 1) card = total;
    if (_tabController.index == 2 && cash + card > total) {
      cash = total - card;
      if (cash < 0) {
        _snack('Karta summasi jami narxdan katta', isError: true);
        return;
      }
    }
    setState(() => _isProcessing = true);
    try {
      final operationId = _pendingOperationId ??= const Uuid().v4();
      final items = cart.map((item) => item.toJson()).toList();
      final sale = await ref.read(apiProvider).createSalePOS(
            items: items,
            cash: cash,
            card: card,
            discount: _discount,
            operationId: operationId,
          );
      await ref.read(productsProvider.notifier).refresh();
      _pendingOperationId = null;
      ref.read(cartProvider.notifier).clear();
      if (mounted) {
        Navigator.of(context).pop(true);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReceiptScreen(sale: sale)),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final statusCode = e.response?.statusCode;
      final isNetworkError = e.type != DioExceptionType.badResponse;
      final isServerValidation =
          statusCode != null && statusCode >= 400 && statusCode < 500;

      if (isNetworkError) {
        // Tarmoq xatosi — sotuvni offline navbatga saqlaymiz.
        final operationId = _pendingOperationId ??= const Uuid().v4();
        final payload = {
          'items': cart.map((item) => item.toJson()).toList(),
          'cash': cash.toStringAsFixed(2),
          'card': card.toStringAsFixed(2),
          'discount': _discount.toStringAsFixed(2),
        };
        await ref.read(queueProvider).enqueueSale(payload, operationId);
        ref.read(cartProvider.notifier).clear();
        _pendingOperationId = null;
        _snack('Offline saqlandi — tarmoq tiklanganda yuboriladi');
        if (mounted) Navigator.of(context).pop(true);
      } else if (isServerValidation) {
        // Server validatsiya xatosi (ombor yetishmasligi, obuna tugagani va h.k.)
        // Navbatga solmaymiz — foydalanuvchiga aniq xabar ko'rsatamiz.
        final message = (e.response?.data as Map?)?['error']?['message'] ??
            e.message ??
            'Server xatosi';
        _snack(message.toString(), isError: true);
        setState(() => _isProcessing = false);
      } else {
        _snack('Xatolik: ${e.message}', isError: true);
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        _snack('Xatolik: ${e.toString()}', isError: true);
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _createDebtSale() async {
    final cart = ref.read(cartProvider);
    final subtotal = ref.read(cartSubtotalProvider);
    final total = subtotal - _discount;

    if (cart.isEmpty) {
      _snack('Savat bo\'sh', isError: true);
      return;
    }
    if (!_discount.isFinite || _discount < 0 || _discount > subtotal) {
      _snack('Chegirma summadan katta bo\'lishi mumkin emas', isError: true);
      return;
    }

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final noteController = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 14));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Qarzga yozish'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Umumiy summa: ${_fmt(total)} so\'m'),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Mijoz ismi *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefon'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Izoh'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: ctx,
                      initialDate: dueDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (selected != null) {
                      setState(() => dueDate = selected);
                    }
                  },
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text(
                      'Muddat: ${DateFormat('dd.MM.yyyy').format(dueDate)}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Bekor')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final customerName = nameController.text.trim();
    if (customerName.isEmpty) {
      _snack('Mijoz ismini kiriting', isError: true);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final operationId = _pendingOperationId ??= const Uuid().v4();
      final debtPayload = {
        'direction': 'customer',
        'party_name': customerName,
        'phone': phoneController.text.trim(),
        'amount': total.toStringAsFixed(2),
        'reason': 'POS savat',
        'note': noteController.text.trim().isEmpty
            ? 'Qarzga yozilgan savat'
            : noteController.text.trim(),
        'created_on': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
      };
      await ref.read(apiProvider).createDebt(debtPayload);

      final sale = await ref.read(apiProvider).createSalePOS(
            items: cart.map((item) => item.toJson()).toList(),
            cash: total,
            card: 0,
            discount: _discount,
            operationId: operationId,
          );

      await ref.read(productsProvider.notifier).refresh();
      _pendingOperationId = null;
      ref.read(cartProvider.notifier).clear();
      if (mounted) {
        Navigator.of(context).pop(true);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReceiptScreen(sale: sale)),
        );
        _snack('Qarz yozildi va savat yakunlandi');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final message = (e.response?.data as Map?)?['error']?['message'] ??
          e.message ??
          'Qarz saqlanmadi';
      _snack(message.toString(), isError: true);
      setState(() => _isProcessing = false);
    } catch (e) {
      if (mounted) {
        _snack('Xatolik: ${e.toString()}', isError: true);
        setState(() => _isProcessing = false);
      }
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[700] : _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _fmt(double v) => NumberFormat('#,##0', 'uz_UZ').format(v);

  @override
  Widget build(BuildContext context) {
    final subtotal = ref.watch(cartSubtotalProvider);
    final cart = ref.watch(cartProvider);
    final total = subtotal - _discount;
    final numberFormat = NumberFormat('#,##0', 'uz_UZ');

    double change = 0;
    switch (_tabController.index) {
      case 0:
        change = _cashAmount - total;
        break;
      case 1:
        change = _cardAmount - total;
        break;
      default:
        change = (_cashAmount + _cardAmount) - total;
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 720),
        color: _kBg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Header ───
            _buildHeader(context),

            // ─── Summary ───
            _buildSummary(subtotal, total, numberFormat),

            // ─── Payment Tabs ───
            _buildTabBar(),

            // ─── Tab Content ───
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCashTab(total),
                  _buildCardTab(total),
                  _buildSplitTab(total),
                ],
              ),
            ),

            // ─── Change ───
            if (change > 0) _buildChangeBanner(change, numberFormat),

            // ─── Actions ───
            _buildActions(cart.isNotEmpty),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.payment_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To\'lov',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'To\'lov turini tanlang',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!_isProcessing)
            GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(double subtotal, double total, NumberFormat fmt) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      color: Colors.white,
      child: Column(
        children: [
          // Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mahsulotlar jami:',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              Text(
                '${fmt.format(subtotal)} so\'m',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Discount row
          Row(
            children: [
              Text('Chegirma:',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      suffixText: 'so\'m',
                      suffixStyle:
                          TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'To\'lov summasi:',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _kGreenLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${fmt.format(total)} so\'m',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _kGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: _kBlue,
        unselectedLabelColor: Colors.grey[500],
        indicatorColor: _kBlue,
        indicatorWeight: 3,
        tabs: const [
          Tab(
            icon: Icon(Icons.money_rounded, size: 20),
            text: 'Naqd',
            height: 52,
          ),
          Tab(
            icon: Icon(Icons.credit_card_rounded, size: 20),
            text: 'Karta',
            height: 52,
          ),
          Tab(
            icon: Icon(Icons.compare_arrows_rounded, size: 20),
            text: 'Aralash',
            height: 52,
          ),
        ],
      ),
    );
  }

  Widget _buildCashTab(double total) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AmountField(
            controller: _cashController,
            label: 'Naqd pul miqdori',
            icon: Icons.money_rounded,
            iconColor: const Color(0xFF2E7D32),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 16),
          _buildQuickButtons(total),
        ],
      ),
    );
  }

  Widget _buildCardTab(double total) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AmountField(
            controller: _cardController,
            label: 'Karta miqdori',
            icon: Icons.credit_card_rounded,
            iconColor: _kBlue,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 16),
          _buildQuickButtons(total),
        ],
      ),
    );
  }

  Widget _buildSplitTab(double total) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AmountField(
            controller: _cashController,
            label: 'Naqd pul',
            icon: Icons.money_rounded,
            iconColor: const Color(0xFF2E7D32),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
          _AmountField(
            controller: _cardController,
            label: 'Karta',
            icon: Icons.credit_card_rounded,
            iconColor: _kBlue,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(
              children: [
                _SplitRow(
                  label: 'Naqd + Karta:',
                  value: _fmt(_cashAmount + _cardAmount),
                  isHighlight: false,
                ),
                const SizedBox(height: 6),
                _SplitRow(
                  label: 'Kerak:',
                  value: _fmt(total),
                  isHighlight: false,
                ),
                const Divider(height: 16),
                _SplitRow(
                  label: 'Farq:',
                  value:
                      '${_cashAmount + _cardAmount >= total ? "+" : ""}${_fmt((_cashAmount + _cardAmount) - total)}',
                  isHighlight: true,
                  isPositive: _cashAmount + _cardAmount >= total,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickButtons(double total) {
    final fmt = NumberFormat.compact(locale: 'uz');
    final amounts = [
      total,
      10000.0,
      20000.0,
      50000.0,
      100000.0,
      200000.0,
      500000.0
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tez kiritish:',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: amounts.map((a) {
            final isExact = a == total;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _setExact(a),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isExact ? _kGreenLight : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isExact
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE0E0E0),
                    ),
                  ),
                  child: Text(
                    isExact ? 'Aniq (${fmt.format(a)})' : fmt.format(a),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isExact ? _kGreen : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChangeBanner(double change, NumberFormat fmt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFFE8F5E9),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: _kGreen, size: 22),
          const SizedBox(width: 10),
          const Text(
            'Qaytim:',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: _kGreen),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _kGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${fmt.format(change)} so\'m',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool hasCart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      color: Colors.white,
      child: Row(
        children: [
          // Cancel
          Expanded(
            child: OutlinedButton(
              onPressed:
                  _isProcessing ? null : () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(color: Color(0xFFBDBDBD)),
              ),
              child: const Text('Bekor qilish',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : _createDebtSale,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(color: Color(0xFF1565C0)),
              ),
              icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
              label: const Text('Qarz',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 8),
          // Confirm
          Expanded(
            flex: 2,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isProcessing ? null : _processSale,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isProcessing
                          ? [Colors.grey[400]!, Colors.grey[400]!]
                          : const [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _isProcessing
                        ? []
                        : const [
                            BoxShadow(
                              color: Color(0x552E7D32),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isProcessing)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      else
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        _isProcessing ? 'Kutilmoqda...' : 'Tasdiqlash',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Amount Input Field ───
class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onChanged;

  const _AmountField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'so\'m',
        suffixStyle: const TextStyle(
            color: Colors.grey, fontSize: 14, fontWeight: FontWeight.normal),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
        ),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}

// ─── Split Row ───
class _SplitRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;
  final bool isPositive;

  const _SplitRow({
    required this.label,
    required this.value,
    required this.isHighlight,
    this.isPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = isHighlight
        ? (isPositive ? const Color(0xFF2E7D32) : Colors.red[700]!)
        : Colors.grey[700]!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Text(
          '$value so\'m',
          style: TextStyle(
            fontSize: isHighlight ? 15 : 13,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

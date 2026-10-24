import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../src/app.dart';
import '../../pos/models/sale.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

class _DateRange {
  final DateTime start;
  final DateTime end;
  const _DateRange({required this.start, required this.end});
}

final reportRangeProvider = StateProvider<_DateRange>((ref) {
  final now = DateTime.now();
  return _DateRange(
    start: DateTime(now.year, now.month, 1),
    end: DateTime(now.year, now.month, now.day, 23, 59, 59),
  );
});

final reportSummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final range = ref.watch(reportRangeProvider);
  final fmt = DateFormat('yyyy-MM-dd');
  final api = ref.read(apiProvider);
  final r = await api.dio.get(
    'reports/summary/',
    queryParameters: {
      'start': fmt.format(range.start),
      'end': fmt.format(range.end),
    },
  );
  return Map<String, dynamic>.from(r.data as Map);
});

final reportSalesProvider = FutureProvider.autoDispose<List<Sale>>((ref) async {
  final range = ref.watch(reportRangeProvider);
  final fmt = DateFormat('yyyy-MM-dd');
  final api = ref.read(apiProvider);
  final data = await api.posSalesList(
    start: fmt.format(range.start),
    end: fmt.format(range.end),
  );
  return data.map((j) => Sale.fromJson(j as Map<String, dynamic>)).toList();
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  int _period = 4; // Bugun, kecha, 7 kun, 30 kun, oy, sana oralig‘i

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _setPeriod(int idx) {
    if (idx == 5) {
      _pickRange();
      return;
    }
    setState(() => _period = idx);
    final now = DateTime.now();
    late DateTime s, e;
    switch (idx) {
      case 0:
        s = DateTime(now.year, now.month, now.day);
        e = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 1:
        final yesterday = now.subtract(const Duration(days: 1));
        s = DateTime(yesterday.year, yesterday.month, yesterday.day);
        e = DateTime(
            yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case 2:
        s = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        e = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 3:
        s = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 29));
        e = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 4:
        s = DateTime(now.year, now.month, 1);
        e = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      default:
        return;
    }
    ref.read(reportRangeProvider.notifier).state = _DateRange(start: s, end: e);
    ref.invalidate(reportSummaryProvider);
    ref.invalidate(reportSalesProvider);
    _fadeCtrl.forward(from: 0);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (r != null && mounted) {
      setState(() => _period = 5);
      ref.read(reportRangeProvider.notifier).state = _DateRange(
        start: r.start,
        end: DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59),
      );
      ref.invalidate(reportSummaryProvider);
      ref.invalidate(reportSalesProvider);
      _fadeCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(reportSummaryProvider);
    final salesAsync = ref.watch(reportSalesProvider);
    final range = ref.watch(reportRangeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(range),
      body: Column(
        children: [
          _PeriodBar(current: _period, onSelect: _setPeriod),
          Expanded(
            child: FadeTransition(
              opacity: _fadeCtrl,
              child: summaryAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorView(
                    msg: e.toString(),
                    onRetry: () => ref.invalidate(reportSummaryProvider)),
                data: (s) {
                  final revenue = double.tryParse(s['revenue'].toString()) ?? 0;
                  final count = (s['sales_count'] as num?)?.toInt() ?? 0;
                  final cash = double.tryParse(s['cash'].toString()) ?? 0;
                  final card = double.tryParse(s['card'].toString()) ?? 0;

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(reportSummaryProvider);
                      ref.invalidate(reportSalesProvider);
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _RevenueCard(
                            revenue: revenue,
                            count: count,
                            cash: cash,
                            card: card),
                        const SizedBox(height: 14),
                        _OperationalSummary(
                          average:
                              double.tryParse('${s['average_check']}') ?? 0,
                          itemsSold: double.tryParse('${s['items_sold']}') ?? 0,
                          lowStock:
                              (s['low_stock'] as List? ?? const []).cast<Map>(),
                          outOfStock: (s['out_of_stock'] as List? ?? const [])
                              .cast<Map>(),
                        ),
                        const SizedBox(height: 14),
                        if (revenue > 0) ...[
                          _PaymentBar(cash: cash, card: card, total: revenue),
                          const SizedBox(height: 14),
                        ],
                        salesAsync.when(
                          data: (allSales) {
                            final filtered = allSales;
                            if (filtered.isEmpty) {
                              return _EmptyPeriod();
                            }
                            return Column(children: [
                              _BarChartCard(sales: filtered),
                              const SizedBox(height: 14),
                              _TopProductsCard(sales: filtered),
                              const SizedBox(height: 14),
                              _RecentSalesCard(
                                  sales: filtered.take(15).toList()),
                            ]);
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (_, __) => const SizedBox(),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(_DateRange dateRange) {
    final dFmt = DateFormat('dd.MM.yyyy');
    return AppBar(
      backgroundColor: const Color(0xFF0D47A1),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Hisobot',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(
          '${dFmt.format(dateRange.start)} – ${dFmt.format(dateRange.end)}',
          style: const TextStyle(fontSize: 11, color: Colors.white60),
        ),
      ]),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () {
            ref.invalidate(reportSummaryProvider);
            ref.invalidate(reportSalesProvider);
            _fadeCtrl.forward(from: 0);
          },
        ),
      ],
    );
  }
}

// ─── Period bar ──────────────────────────────────────────────────────────────

class _PeriodBar extends StatelessWidget {
  final int current;
  final void Function(int) onSelect;
  const _PeriodBar({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const labels = ['Bugun', 'Kecha', '7 kun', '30 kun', 'Bu oy', 'Sana'];
    return Container(
      color: const Color(0xFF0D47A1),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labels.length, (i) {
            final sel = current == i;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (i == 5)
                        Icon(Icons.calendar_month_rounded,
                            size: 12,
                            color:
                                sel ? const Color(0xFF0D47A1) : Colors.white),
                      if (i == 5) const SizedBox(width: 4),
                      Text(labels[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel ? const Color(0xFF0D47A1) : Colors.white,
                          )),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Revenue card ────────────────────────────────────────────────────────────

class _RevenueCard extends StatelessWidget {
  final double revenue, cash, card;
  final int count;
  const _RevenueCard(
      {required this.revenue,
      required this.count,
      required this.cash,
      required this.card});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'uz_UZ');
    final avg = count > 0 ? revenue / count : 0.0;
    return Column(children: [
      // Main revenue gradient card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D47A1).withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.trending_up_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Umumiy daromad',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
          const SizedBox(height: 14),
          Text(
            '${fmt.format(revenue)} so\'m',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            '$count ta sotuv  •  o\'rtacha ${fmt.format(avg)} so\'m',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _MiniCard(
                icon: Icons.payments_rounded,
                label: 'Naqd pul',
                value: '${fmt.format(cash)} so\'m',
                iconColor: const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9))),
        const SizedBox(width: 12),
        Expanded(
            child: _MiniCard(
                icon: Icons.credit_card_rounded,
                label: 'Plastik karta',
                value: '${fmt.format(card)} so\'m',
                iconColor: const Color(0xFF1565C0),
                bgColor: const Color(0xFFE3F2FD))),
      ]),
    ]);
  }
}

class _MiniCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color iconColor, bgColor;
  const _MiniCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.iconColor,
      required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: iconColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

// ─── Payment breakdown bar ───────────────────────────────────────────────────

class _PaymentBar extends StatelessWidget {
  final double cash, card, total;
  const _PaymentBar(
      {required this.cash, required this.card, required this.total});

  @override
  Widget build(BuildContext context) {
    final cashPct = total > 0 ? cash / total : 0.0;
    final cardPct = total > 0 ? card / total : 0.0;
    final fmt = NumberFormat('0.0');
    return _Card(
      title: 'To\'lov usullari',
      icon: Icons.donut_small_rounded,
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(children: [
              Flexible(
                flex: (cashPct * 1000).round(),
                child: Container(color: const Color(0xFF2E7D32)),
              ),
              Flexible(
                flex: (cardPct * 1000).round(),
                child: Container(color: const Color(0xFF1565C0)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _Dot(color: const Color(0xFF2E7D32)),
          const SizedBox(width: 6),
          Text('Naqd: ${fmt.format(cashPct * 100)}%',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 20),
          _Dot(color: const Color(0xFF1565C0)),
          const SizedBox(width: 6),
          Text('Karta: ${fmt.format(cardPct * 100)}%',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

// ─── Bar chart ───────────────────────────────────────────────────────────────

class _BarChartCard extends StatelessWidget {
  final List<Sale> sales;
  const _BarChartCard({required this.sales});

  @override
  Widget build(BuildContext context) {
    final Map<String, double> byDay = {};
    for (final s in sales) {
      final k = DateFormat('yyyy-MM-dd').format(s.createdAt);
      byDay[k] = (byDay[k] ?? 0) + s.total;
    }
    final sorted = byDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (sorted.isEmpty) return const SizedBox();

    return _Card(
      title: 'Kunlik sotuvlar',
      icon: Icons.bar_chart_rounded,
      child: SizedBox(
        height: 180,
        child: Column(children: [
          Expanded(
            child: CustomPaint(
              painter: _BarPainter(sorted),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _labels(sorted),
          ),
        ]),
      ),
    );
  }

  List<Widget> _labels(List<MapEntry<String, double>> sorted) {
    if (sorted.length <= 7) {
      return sorted
          .map((e) => Text(DateFormat('dd.MM').format(DateTime.parse(e.key)),
              style: const TextStyle(fontSize: 9, color: Color(0xFF90A4AE))))
          .toList();
    }
    final idxs = {0, sorted.length ~/ 2, sorted.length - 1};
    return List.generate(sorted.length, (i) {
      if (idxs.contains(i)) {
        return Text(DateFormat('dd.MM').format(DateTime.parse(sorted[i].key)),
            style: const TextStyle(fontSize: 9, color: Color(0xFF90A4AE)));
      }
      return const SizedBox();
    });
  }
}

class _BarPainter extends CustomPainter {
  final List<MapEntry<String, double>> data;
  _BarPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxV = data.map((e) => e.value).reduce(math.max);
    if (maxV == 0) return;

    final guide = Paint()
      ..color = const Color(0xFFECEFF1)
      ..strokeWidth = 1;
    for (int i = 1; i <= 4; i++) {
      final y = size.height * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guide);
    }

    final barW = (size.width / data.length) * 0.55;
    final gap = size.width / data.length;

    for (int i = 0; i < data.length; i++) {
      final x = gap * i + gap / 2 - barW / 2;
      final h = (data[i].value / maxV) * size.height;
      final paint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(x, size.height - h, barW, h));
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, size.height - h, barW, h),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.data != data;
}

// ─── Top products ─────────────────────────────────────────────────────────────

class _TopProductsCard extends StatelessWidget {
  final List<Sale> sales;
  const _TopProductsCard({required this.sales});

  @override
  Widget build(BuildContext context) {
    final Map<String, double> totals = {};
    final Map<String, double> counts = {};
    final Map<String, String> names = {};
    for (final s in sales) {
      var remainingDiscountCents = (s.discount * 100).round();
      final subtotalCents = (s.subtotal * 100).round();
      final discountCents = remainingDiscountCents;
      for (var index = 0; index < s.items.length; index++) {
        final item = s.items[index];
        final key = item.productId.toString();
        final lineCents = (item.lineTotal * 100).round();
        final proportionalShare = subtotalCents == 0
            ? 0
            : (discountCents * lineCents / subtotalCents).round();
        final share = index == s.items.length - 1
            ? remainingDiscountCents
            : proportionalShare.clamp(
                0,
                math.min(remainingDiscountCents, lineCents),
              ) as int;
        remainingDiscountCents -= share;
        final netLineTotal = (lineCents - share) / 100;
        names[key] = item.name;
        totals[key] = (totals[key] ?? 0) + netLineTotal;
        counts[key] = (counts[key] ?? 0) + item.quantity;
      }
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => (counts[b.key] ?? 0).compareTo(counts[a.key] ?? 0));
    final top = sorted.take(5).toList();
    if (top.isEmpty) return const SizedBox();

    final maxV = counts[top.first.key] ?? 0;
    final fmt = NumberFormat('#,##0', 'uz_UZ');
    final qtyFmt = NumberFormat('#,##0.###', 'uz_UZ');
    final colors = [
      const Color(0xFFFFB300),
      const Color(0xFF78909C),
      const Color(0xFFBF6900),
      const Color(0xFF1E88E5),
      const Color(0xFF43A047),
    ];

    return _Card(
      title: 'Top mahsulotlar',
      icon: Icons.leaderboard_rounded,
      child: Column(
        children: top.asMap().entries.map((en) {
          final i = en.key;
          final e = en.value;
          final soldQuantity = counts[e.key] ?? 0;
          final pct = maxV > 0 ? soldQuantity / maxV : 0.0;
          final c = colors[i % colors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Center(
                    child: Text('${i + 1}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: c)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(names[e.key] ?? 'Mahsulot',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                Text('${fmt.format(e.value)} so\'m',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700])),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const SizedBox(width: 30),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(c),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${qtyFmt.format(soldQuantity)} dona',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Recent sales ─────────────────────────────────────────────────────────────

class _RecentSalesCard extends StatelessWidget {
  final List<Sale> sales;
  const _RecentSalesCard({required this.sales});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'uz_UZ');
    final dFmt = DateFormat('dd.MM  HH:mm');

    return _Card(
      title: 'So\'nggi sotuvlar',
      icon: Icons.receipt_long_rounded,
      child: Column(
        children: sales
            .map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('#${s.receiptNumber}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1565C0))),
                    ),
                    const SizedBox(width: 8),
                    Text(dFmt.format(s.createdAt),
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500])),
                    const Spacer(),
                    if (s.cash > 0)
                      const Icon(Icons.payments_rounded,
                          size: 12, color: Color(0xFF2E7D32)),
                    if (s.card > 0) ...[
                      const SizedBox(width: 2),
                      const Icon(Icons.credit_card_rounded,
                          size: 12, color: Color(0xFF1565C0)),
                    ],
                    const SizedBox(width: 6),
                    Text('${fmt.format(s.total)} so\'m',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0))),
                  ]),
                ))
            .toList(),
      ),
    );
  }
}

// ─── Empty period ─────────────────────────────────────────────────────────────

class _EmptyPeriod extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Bu davrda sotuvlar yo\'q',
              style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ]),
      );
}

class _OperationalSummary extends StatelessWidget {
  final double average;
  final double itemsSold;
  final List<Map> lowStock;
  final List<Map> outOfStock;

  const _OperationalSummary({
    required this.average,
    required this.itemsSold,
    required this.lowStock,
    required this.outOfStock,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat('#,##0', 'uz_UZ');
    final quantity = NumberFormat('#,##0.###', 'uz_UZ');
    return _Card(
      title: 'Savdo va ombor holati',
      icon: Icons.inventory_2_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('O‘rtacha chek: ${money.format(average)} so‘m'),
        const SizedBox(height: 4),
        Text('Sotilgan miqdor: ${quantity.format(itemsSold)}'),
        if (lowStock.isEmpty && outOfStock.isEmpty) ...[
          const SizedBox(height: 8),
          const Text('Kam qolgan mahsulotlar yo‘q.'),
        ],
        for (final product in outOfStock) ...[
          const SizedBox(height: 10),
          _StockWarning(
            title: '${product['name'] ?? 'Mahsulot'} tugagan!',
            detail:
                'Omborda mahsulot qolmagan. Chegara: ${product['min_stock'] ?? 0}',
            color: const Color(0xFFC62828),
          ),
        ],
        for (final product in lowStock) ...[
          const SizedBox(height: 10),
          _StockWarning(
            title: 'Diqqat! ${product['name'] ?? 'Mahsulot'} kam qoldi.',
            detail:
                'Omborda ${product['stock'] ?? 0} dona. Ogohlantirish chegarasi: ${product['min_stock'] ?? 0} dona.',
            color: const Color(0xFFEF6C00),
          ),
        ],
      ]),
    );
  }
}

class _StockWarning extends StatelessWidget {
  final String title;
  final String detail;
  final Color color;
  const _StockWarning(
      {required this.title, required this.detail, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(detail, style: TextStyle(color: color, fontSize: 12)),
        ]),
      );
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorView({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.wifi_off_rounded,
                  size: 40, color: Colors.red.shade400),
            ),
            const SizedBox(height: 16),
            const Text('Ma\'lumot yuklanmadi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              msg.contains('SocketException') || msg.contains('Connection')
                  ? 'Internet aloqasini tekshiring'
                  : 'Server bilan aloqa yo\'q',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Qayta urinish'),
            ),
          ]),
        ),
      );
}

// ─── Card wrapper ─────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Card({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: const Color(0xFF1565C0)),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E))),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

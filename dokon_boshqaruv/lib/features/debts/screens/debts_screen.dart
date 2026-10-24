import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../src/app.dart';

final debtsProvider = FutureProvider.family<List<dynamic>, String>((ref, key) {
  final f = key.split('|');
  return ref.read(apiProvider).debts(
      direction: f[0].isEmpty ? null : f[0],
      search: f[1],
      status: f[2].isEmpty ? null : f[2],
      due: f[3].isEmpty ? null : f[3],
      sort: f[4].isEmpty ? null : f[4],
      start: f[5].isEmpty ? null : f[5],
      end: f[6].isEmpty ? null : f[6]);
});

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});
  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  String? _direction;
  String? _status;
  String? _due;
  String _sort = 'newest';
  DateTime? _start;
  DateTime? _end;
  final _search = TextEditingController();
  bool _busy = false;
  String _money(dynamic raw) =>
      '${NumberFormat('#,##0.##', 'uz_UZ').format(double.tryParse('$raw') ?? 0)} so‘m';
  String get _queryKey =>
      '${_direction ?? ''}|${_search.text.trim()}|${_status ?? ''}|${_due ?? ''}|${_sort == 'newest' ? '' : _sort}|${_start == null ? '' : DateFormat('yyyy-MM-dd').format(_start!)}|${_end == null ? '' : DateFormat('yyyy-MM-dd').format(_end!)}';
  Future<void> _refresh() async => ref.invalidate(debtsProvider(_queryKey));

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(debtsProvider(_queryKey));
    return Scaffold(
      body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(
                  child: Text('Daftar',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold))),
              FilledButton.icon(
                  onPressed: _busy ? null : _newDebt,
                  icon: const Icon(Icons.add),
                  label: const Text('Yangi qarz'))
            ]),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
                initialValue: _direction,
                decoration: const InputDecoration(
                    labelText: 'Qarz turi', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Barcha qarzlar')),
                  DropdownMenuItem(
                      value: 'customer', child: Text('Mijozdan olinadi')),
                  DropdownMenuItem(value: 'store', child: Text('Do‘kon qarzi'))
                ],
                onChanged: (v) => setState(() => _direction = v)),
            const SizedBox(height: 10),
            TextField(
                controller: _search,
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Ism yoki telefon',
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => setState(() {})),
                    border: const OutlineInputBorder()),
                onSubmitted: (_) => setState(() {})),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              SizedBox(
                  width: 165,
                  child: DropdownButtonFormField<String?>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                          labelText: 'Holati', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(
                            value: null, child: Text('Barcha holatlar')),
                        DropdownMenuItem(
                            value: 'open', child: Text('To‘lanmagan')),
                        DropdownMenuItem(
                            value: 'partial', child: Text('Qisman')),
                        DropdownMenuItem(
                            value: 'paid', child: Text('To‘langan')),
                        DropdownMenuItem(
                            value: 'overdue', child: Text('Muddati o‘tgan'))
                      ],
                      onChanged: (v) => setState(() => _status = v))),
              SizedBox(
                  width: 165,
                  child: DropdownButtonFormField<String?>(
                      initialValue: _due,
                      decoration: const InputDecoration(
                          labelText: 'Muddat', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(
                            value: null, child: Text('Barcha muddatlar')),
                        DropdownMenuItem(value: 'today', child: Text('Bugun')),
                        DropdownMenuItem(
                            value: 'overdue', child: Text('O‘tib ketgan'))
                      ],
                      onChanged: (v) => setState(() => _due = v))),
              SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                      initialValue: _sort,
                      decoration: const InputDecoration(
                          labelText: 'Saralash', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(
                            value: 'newest', child: Text('Yangi qarzlar')),
                        DropdownMenuItem(
                            value: 'largest', child: Text('Eng katta qarz')),
                        DropdownMenuItem(
                            value: 'oldest', child: Text('Eng eski qarz')),
                        DropdownMenuItem(
                            value: 'overdue', child: Text('Muddati o‘tganlar'))
                      ],
                      onChanged: (v) => setState(() => _sort = v ?? 'newest'))),
            ]),
            Row(children: [
              Expanded(
                  child: TextButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: _start ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now());
                        if (d != null) setState(() => _start = d);
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: Text(_start == null
                          ? 'Boshlanish sanasi'
                          : DateFormat('dd.MM.yyyy').format(_start!)))),
              Expanded(
                  child: TextButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: _end ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now());
                        if (d != null) setState(() => _end = d);
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: Text(_end == null
                          ? 'Tugash sanasi'
                          : DateFormat('dd.MM.yyyy').format(_end!)))),
              if (_start != null || _end != null)
                IconButton(
                    onPressed: () => setState(() {
                          _start = null;
                          _end = null;
                        }),
                    icon: const Icon(Icons.clear))
            ]),
            const SizedBox(height: 16),
            data.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Column(children: [
                      const Icon(Icons.wifi_off, size: 48),
                      const Text(
                          'Daftarni yuklab bo‘lmadi. Internetni tekshiring.'),
                      TextButton(
                          onPressed: _refresh,
                          child: const Text('Qayta urinish'))
                    ]),
                data: (items) {
                  final visible = items;
                  final receivable = items
                      .where((x) => x['direction'] == 'customer')
                      .fold<double>(
                          0,
                          (s, x) =>
                              s + (double.tryParse('${x['balance']}') ?? 0));
                  final payable = items
                      .where((x) => x['direction'] == 'store')
                      .fold<double>(
                          0,
                          (s, x) =>
                              s + (double.tryParse('${x['balance']}') ?? 0));
                  final overdue =
                      items.where((x) => x['status'] == 'overdue').toList();
                  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                  final dueToday = items
                      .where((x) =>
                          x['due_date'] == today &&
                          (double.tryParse('${x['balance']}') ?? 0) > 0)
                      .toList();
                  final customers = items
                      .where((x) =>
                          x['direction'] == 'customer' &&
                          (double.tryParse('${x['balance']}') ?? 0) > 0)
                      .map((x) => '${x['party_name']}|${x['phone']}')
                      .toSet()
                      .length;
                  final partialCount =
                      items.where((x) => x['status'] == 'partial').length;
                  final paidCount =
                      items.where((x) => x['status'] == 'paid').length;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Expanded(
                              child: _stat('Olinadigan', _money(receivable))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _stat('Do‘kon qarzi', _money(payable)))
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: _stat('Muddati o‘tgan',
                                  '${_money(overdue.fold<double>(0, (s, x) => s + (double.tryParse('${x['balance']}') ?? 0)))} · ${overdue.length} ta')),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _stat('Bugun to‘lanadi',
                                  '${_money(dueToday.fold<double>(0, (s, x) => s + (double.tryParse('${x['balance']}') ?? 0)))} · ${dueToday.length} ta'))
                        ]),
                        const SizedBox(height: 8),
                        _stat('Qarzli mijozlar', '$customers ta'),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: _stat(
                                  'Qisman to‘langan', '$partialCount ta')),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _stat('To‘liq to‘langan', '$paidCount ta'))
                        ]),
                        const SizedBox(height: 12),
                        if (visible.isEmpty)
                          const Padding(
                              padding: EdgeInsets.all(36),
                              child: Column(children: [
                                Icon(Icons.menu_book_outlined,
                                    size: 54, color: Colors.grey),
                                Text('Hozircha qarz yozuvi yo‘q')
                              ]))
                        else
                          ...visible.map((d) => Card(
                              child: ListTile(
                                  leading: CircleAvatar(
                                      child: Icon(d['direction'] == 'customer'
                                          ? Icons.call_received
                                          : Icons.call_made)),
                                  title: Text('${d['party_name']}'),
                                  subtitle: Text(
                                      '${d['phone'] ?? ''}\n${_statusLabel(d['status'])}${d['due_date'] == null ? '' : ' · Muddat: ${DateFormat('dd.MM.yyyy').format(DateTime.parse('${d['due_date']}'))}'}\n${d['reason'] ?? ''}',
                                      maxLines: 2),
                                  isThreeLine: true,
                                  trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(_money(d['balance']),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        if ((double.tryParse(
                                                    '${d['balance']}') ??
                                                0) >
                                            0)
                                          TextButton(
                                              onPressed:
                                                  _busy ? null : () => _pay(d),
                                              child: const Text('To‘lov'))
                                      ]),
                                  onTap: () => _details(d))))
                      ]);
                }),
          ])),
    );
  }

  Widget _stat(String title, String value) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
          ])));

  String _statusLabel(dynamic status) => switch (status) {
        'paid' => 'To‘langan',
        'partial' => 'Qisman to‘langan',
        'overdue' => 'Muddati o‘tgan',
        _ => 'To‘lanmagan',
      };

  Future<void> _newDebt() async {
    final name = TextEditingController(),
        phone = TextEditingController(),
        amount = TextEditingController(),
        reason = TextEditingController(),
        note = TextEditingController();
    String direction = 'customer';
    DateTime createdOn = DateTime.now();
    DateTime? dueDate;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => AlertDialog(
                    title: const Text('Yangi qarz'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField(
                          initialValue: direction,
                          items: const [
                            DropdownMenuItem(
                                value: 'customer',
                                child: Text('Mijozdan olinadi')),
                            DropdownMenuItem(
                                value: 'store', child: Text('Do‘kon qarzi'))
                          ],
                          onChanged: (v) => set(() => direction = v!),
                          decoration:
                              const InputDecoration(labelText: 'Qarz turi')),
                      TextField(
                          controller: name,
                          decoration: const InputDecoration(
                              labelText: 'Ism yoki tashkilot')),
                      TextField(
                          controller: phone,
                          decoration: const InputDecoration(
                              labelText: 'Telefon (ixtiyoriy)')),
                      TextField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Summa')),
                      TextField(
                          controller: reason,
                          decoration: const InputDecoration(
                              labelText: 'Sabab / tavsif')),
                      TextField(
                          controller: note,
                          decoration: const InputDecoration(
                              labelText: 'Izoh (ixtiyoriy)')),
                      Row(children: [
                        Expanded(
                            child: TextButton.icon(
                                onPressed: () async {
                                  final selected = await showDatePicker(
                                      context: ctx,
                                      initialDate: createdOn,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime.now());
                                  if (selected != null) {
                                    set(() => createdOn = selected);
                                  }
                                },
                                icon: const Icon(Icons.event),
                                label: Text(
                                    'Sana: ${DateFormat('dd.MM.yyyy').format(createdOn)}'))),
                        Expanded(
                            child: TextButton.icon(
                                onPressed: () async {
                                  final selected = await showDatePicker(
                                      context: ctx,
                                      initialDate: dueDate ?? DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime(2100));
                                  if (selected != null) {
                                    set(() => dueDate = selected);
                                  }
                                },
                                icon: const Icon(Icons.event_available),
                                label: Text(dueDate == null
                                    ? 'Muddat qo‘shish'
                                    : DateFormat('dd.MM.yyyy')
                                        .format(dueDate!))))
                      ])
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Bekor')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Saqlash'))
                    ])));
    if (ok != true || !mounted) return;
    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    if (name.text.trim().isEmpty || value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ism va musbat summa kiriting')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).createDebt({
        'direction': direction,
        'party_name': name.text.trim(),
        'phone': phone.text.trim(),
        'amount': value.toStringAsFixed(2),
        'reason': reason.text.trim(),
        'note': note.text.trim(),
        'created_on': DateFormat('yyyy-MM-dd').format(createdOn),
        if (dueDate != null)
          'due_date': DateFormat('yyyy-MM-dd').format(dueDate!)
      });
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Qarz saqlanmadi. Internetni tekshirib qayta urinib ko‘ring.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay(Map<String, dynamic> debt) async {
    final amount = TextEditingController();
    String method = 'cash';
    DateTime paidOn = DateTime.now();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => AlertDialog(
                    title: Text('${debt['party_name']} · to‘lov'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Qoldiq: ${_money(debt['balance'])}'),
                      TextField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'To‘lov summasi')),
                      DropdownButtonFormField(
                          initialValue: method,
                          items: const [
                            DropdownMenuItem(
                                value: 'cash', child: Text('Naqd')),
                            DropdownMenuItem(
                                value: 'card', child: Text('Karta')),
                            DropdownMenuItem(
                                value: 'bank', child: Text('Bank o‘tkazmasi'))
                          ],
                          onChanged: (v) => set(() => method = v!)),
                      TextButton.icon(
                          onPressed: () async {
                            final selected = await showDatePicker(
                                context: ctx,
                                initialDate: paidOn,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now());
                            if (selected != null) set(() => paidOn = selected);
                          },
                          icon: const Icon(Icons.event),
                          label: Text(
                              'To‘lov sanasi: ${DateFormat('dd.MM.yyyy').format(paidOn)}'))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Bekor')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Qabul qilish'))
                    ])));
    if (ok != true || !mounted) return;
    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    if (value == null ||
        value <= 0 ||
        value > (double.tryParse('${debt['balance']}') ?? 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('To‘lov musbat bo‘lsin va qoldiqdan oshmasin')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).recordDebtPayment(debt['id'] as int,
          amount: value.toStringAsFixed(2),
          method: method,
          paidOn: DateFormat('yyyy-MM-dd').format(paidOn));
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('To‘lov saqlanmadi. Server javobini tekshiring.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _details(Map<String, dynamic> debt) async {
    try {
      final d = await ref.read(apiProvider).debtDetail(debt['id'] as int);
      if (!mounted) return;
      showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text('${d['party_name']}'),
                  content: SizedBox(
                      width: 360,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Telefon: ${d['phone'] ?? '—'}'),
                            Text('Boshlang‘ich: ${_money(d['amount'])}'),
                            Text('To‘langan: ${_money(d['paid'])}'),
                            Text('Qoldiq: ${_money(d['balance'])}'),
                            Text('Sabab: ${d['reason'] ?? '—'}'),
                            const Divider(),
                            const Text('To‘lovlar',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            ...((d['payments'] as List?) ?? []).map((p) => Text(
                                '${p['paid_on']} · ${_money(p['amount'])} · ${p['method']}'))
                          ])),
                  actions: [
                    TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _editDetails(d);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Tahrirlash')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Yopish'))
                  ]));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tafsilotlarni yuklab bo‘lmadi')));
      }
    }
  }

  Future<void> _editDetails(Map<String, dynamic> debt) async {
    final note = TextEditingController(text: '${debt['note'] ?? ''}');
    DateTime? due = debt['due_date'] == null
        ? null
        : DateTime.tryParse('${debt['due_date']}');
    final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => AlertDialog(
                  title: const Text('Qarz ma’lumotlarini tahrirlash'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: note,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Izoh')),
                    TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                              context: ctx,
                              initialDate: due ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100));
                          if (picked != null) set(() => due = picked);
                        },
                        icon: const Icon(Icons.event),
                        label: Text(due == null
                            ? 'To‘lov muddatini tanlash'
                            : DateFormat('dd.MM.yyyy').format(due!))),
                    if (due != null)
                      TextButton(
                          onPressed: () => set(() => due = null),
                          child: const Text('Muddatni olib tashlash'))
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Bekor')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Saqlash'))
                  ],
                )));
    if (saved != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).updateDebt(debt['id'] as int,
          note: note.text,
          dueDate: due == null ? null : DateFormat('yyyy-MM-dd').format(due!),
          clearDueDate: due == null);
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('O‘zgarishlarni saqlab bo‘lmadi')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

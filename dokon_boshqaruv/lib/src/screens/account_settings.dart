import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import 'change_password.dart';

class AccountSettings extends ConsumerStatefulWidget {
  const AccountSettings({super.key});

  @override
  ConsumerState<AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends ConsumerState<AccountSettings> {
  Map<String, dynamic>? profile;
  List<dynamic> plans = const [];
  List<dynamic> payments = const [];
  List<dynamic> subscriptions = const [];
  bool loading = true;
  bool _purchasing = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = ref.read(apiProvider);
      final values = await Future.wait([
        api.me(),
        api.plans(),
        api.payments(),
        api.subscriptionHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        profile = values[0] as Map<String, dynamic>;
        plans = values[1] as List<dynamic>;
        payments = values[2] as List<dynamic>;
        subscriptions = values[3] as List<dynamic>;
        loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        error = _message(e);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Ma’lumotlarni yuklab bo‘lmadi. Qayta urinib ko‘ring.';
        loading = false;
      });
    }
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      return '${data['error']['message'] ?? 'So‘rov bajarilmadi'}';
    }
    return 'Serverga ulanib bo‘lmadi. Internetni tekshirib qayta urinib ko‘ring.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hisob sozlamalari')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Qayta yuklash'),
                    ),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _profileCard(),
                      const SizedBox(height: 16),
                      _subscriptionCard(),
                      const SizedBox(height: 16),
                      _plansSection(),
                      const SizedBox(height: 16),
                      _historySection(
                          'To‘lovlar tarixi',
                          payments,
                          (x) =>
                              '${x['plan_name'] ?? 'Tarif'} · ${x['amount']} ${x['currency']} · ${x['status']}'),
                      const SizedBox(height: 16),
                      _historySection(
                          'Obunalar tarixi',
                          subscriptions,
                          (x) =>
                              '${x['plan_name'] ?? 'Tarif'} · ${x['status']} · ${x['ends_at'] ?? '—'}'),
                    ],
                  ),
                ),
    );
  }

  Widget _profileCard() {
    final p = profile!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Profil', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _row('Username', p['username']),
          _row('Ism familiya',
              '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim()),
          _row('Email', p['email']),
          _row('Do‘kon', p['store']),
          _row('Do‘kon telefoni', p['store_phone']),
          _row('Rol',
              p['is_superadmin'] == true ? 'Superadmin' : 'Foydalanuvchi'),
          _row(
              'Akkaunt holati', p['is_active'] == true ? 'Faol' : 'Bloklangan'),
          _row('Yaratilgan', _date(p['date_joined'])),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.person_outline),
              label: const Text('Profilni tahrirlash'),
            ),
            OutlinedButton.icon(
              onPressed: _changeUsername,
              icon: const Icon(Icons.edit),
              label: const Text('Username'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChangePassword())),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Parolni o‘zgartirish'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _subscriptionCard() {
    final sub = profile?['subscription'] as Map? ?? const {};
    return Card(
      child: ListTile(
        leading:
            Icon(sub['active'] == true ? Icons.verified : Icons.warning_amber),
        title: Text('Obuna: ${sub['status'] ?? 'noma’lum'}'),
        subtitle: Text(
            'Tarif: ${sub['plan'] ?? '—'} · Tugash sanasi: ${_date(sub['expires_at'])}'),
      ),
    );
  }

  Future<void> _purchase(Map<String, dynamic> plan) async {
    if (_purchasing) return;
    final controller = TextEditingController();
    final reference = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${plan['name']} · ${plan['price']} ${plan['currency']}'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Bu tugma kartadan pul yechmaydi. To‘lov rekvizitlarini administrator bilan kelishing. To‘lovdan keyin izoh yoki tranzaksiya raqamini kiriting.'),
          const SizedBox(height: 16),
          TextField(controller: controller, maxLength: 160,
            decoration: const InputDecoration(labelText: 'To‘lov izohi / tranzaksiya raqami')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
          FilledButton(onPressed: () {
            if (controller.text.trim().isNotEmpty) Navigator.pop(ctx, controller.text.trim());
          }, child: const Text('Ariza yuborish')),
        ],
      ),
    );
    if (!mounted || reference == null) return;
    setState(() => _purchasing = true);
    try {
      await ref.read(apiProvider).dio.post('payments/', data: {'plan_id': plan['id'], 'reference': reference});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ariza yuborildi. Administrator tasdiqlashini kuting.')));
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ariza yuborilmadi. Internetni tekshirib qayta urining.')));
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Widget _plansSection() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tariflar', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
                'Tarifni tanlang va to‘lov arizasini yuboring. Obuna administrator to‘lovni tasdiqlagach faollashadi.'),
            ...plans.map((raw) {
              final plan = Map<String, dynamic>.from(raw as Map);
              final features =
                  (plan['features'] as List? ?? const []).join(' · ');
              final current = plan['name'] == profile?['subscription']?['plan'];
              return Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: current ? const Color(0xFFF0F8F6) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: current ? const Color(0xFF126B63) : const Color(0xFFDCE3E8)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Icon(Icons.workspace_premium_outlined, color: Color(0xFF126B63)),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${plan['name']}', style: Theme.of(context).textTheme.titleLarge)),
                    if (current) const Chip(label: Text('Joriy tarif')),
                  ]),
                  const SizedBox(height: 16),
                  Text('${plan['price']} ${plan['currency']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  const Text('Tarifning bir to‘lov davri uchun'),
                  const Divider(height: 28),
                  Text('${plan['user_limit']} foydalanuvchi · ${plan['product_limit']} mahsulot'),
                  if (features.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(features)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _purchasing ? null : () => _purchase(plan),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(_purchasing ? 'Yuborilmoqda...' : current ? 'Tarifni uzaytirish' : 'Tarifni tanlash'),
                  ),
                ]),
              );
            }),
          ]),
        ),
      );

  Widget _historySection(String title, List<dynamic> rows,
          String Function(Map<String, dynamic>) label) =>
      Card(
        child: ExpansionTile(
          title: Text('$title (${rows.length})'),
          children: rows.isEmpty
              ? const [ListTile(title: Text('Hozircha yozuv yo‘q'))]
              : rows
                  .map((raw) => ListTile(
                      title:
                          Text(label(Map<String, dynamic>.from(raw as Map)))))
                  .toList(),
        ),
      );

  Widget _row(String label, Object? value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
              width: 125,
              child:
                  Text(label, style: const TextStyle(color: Colors.blueGrey))),
          Expanded(
              child: Text(value?.toString().isNotEmpty == true
                  ? value.toString()
                  : '—')),
        ]),
      );

  String _date(Object? value) {
    if (value == null) return '—';
    final parsed = DateTime.tryParse(value.toString());
    return parsed == null
        ? value.toString()
        : '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  Future<void> _changeUsername() async {
    final controller =
        TextEditingController(text: '${profile?['username'] ?? ''}');
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Username’ni o‘zgartirish'),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Yangi username')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Bekor qilish')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Saqlash')),
        ],
      ),
    );
    if (next == null || next.isEmpty) return;
    try {
      await ref.read(apiProvider).changeUsername(next);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username o‘zgartirildi')));
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(e))));
      }
    }
  }

  Future<void> _editProfile() async {
    final p = profile ?? const <String, dynamic>{};
    final first = TextEditingController(text: '${p['first_name'] ?? ''}');
    final last = TextEditingController(text: '${p['last_name'] ?? ''}');
    final email = TextEditingController(text: '${p['email'] ?? ''}');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profil ma’lumotlari'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: first,
              decoration: const InputDecoration(labelText: 'Ism')),
          TextField(
              controller: last,
              decoration: const InputDecoration(labelText: 'Familiya')),
          TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Bekor qilish')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Saqlash')),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await ref.read(apiProvider).updateProfile({
        'first_name': first.text.trim(),
        'last_name': last.text.trim(),
        'email': email.text.trim(),
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profil yangilandi')));
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(e))));
      }
    }
  }
}

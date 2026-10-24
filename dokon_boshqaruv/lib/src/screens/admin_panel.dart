import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../app.dart';

class AdminPanel extends ConsumerStatefulWidget {
  const AdminPanel({super.key});

  @override
  ConsumerState<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends ConsumerState<AdminPanel>
    with SingleTickerProviderStateMixin {
  int selectedTab = 0;
  List<dynamic> users = [];
  List<dynamic> sectionRows = [];
  Map<String, dynamic> dashboard = {};
  Map<String, dynamic> systemStatus = {};
  int page = 1;
  int pages = 1;
  String search = '';
  bool sectionLoading = false;
  bool dashboardLoading = false;
  String? dashboardError;
  DateTime? dashboardStart;
  DateTime? dashboardEnd;
  bool? activeFilter;
  String? paymentStatus;
  String? subscriptionStatus;
  DateTime? paymentStart;
  DateTime? paymentEnd;
  bool loading = true;
  String? error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    loadDashboard();
    loadUsers();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> loadUsers() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await ref
          .read(apiProvider)
          .adminUsers(page: page, q: search, active: activeFilter);
      if (mounted) {
        setState(() {
          users = result['results'] as List<dynamic>;
          pages = result['pages'] as int;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Foydalanuvchilarni yuklashda xatolik: $e';
          loading = false;
        });
      }
    }
  }

  Future<void> loadDashboard() async {
    if (mounted)
      setState(() {
        dashboardLoading = true;
        dashboardError = null;
      });
    try {
      final data = await ref.read(apiProvider).adminDashboard(
          start: dashboardStart == null
              ? null
              : DateFormat('yyyy-MM-dd').format(dashboardStart!),
          end: dashboardEnd == null
              ? null
              : DateFormat('yyyy-MM-dd').format(dashboardEnd!));
      if (mounted)
        setState(() {
          dashboard = data;
          dashboardLoading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          dashboardError = 'Dashboardni yuklab bo‘lmadi';
          dashboardLoading = false;
        });
    }
  }

  Future<void> loadSection(int tab) async {
    if (tab == 0 || tab == 1) return;
    setState(() {
      sectionLoading = true;
      error = null;
    });
    try {
      final api = ref.read(apiProvider);
      dynamic result;
      if (tab == 2)
        result =
            await api.adminStores(page: page, q: search, active: activeFilter);
      if (tab == 3) result = await api.adminPlans();
      if (tab == 4)
        result =
            await api.adminSubscriptions(status: subscriptionStatus, q: search);
      if (tab == 5)
        result = await api.adminPayments(
            page: page,
            status: paymentStatus,
            start: paymentStart == null
                ? null
                : DateFormat('yyyy-MM-dd').format(paymentStart!),
            end: paymentEnd == null
                ? null
                : DateFormat('yyyy-MM-dd').format(paymentEnd!));
      if (tab == 6) result = await api.adminAudit(page: page, q: search);
      if (tab == 7) result = await api.adminSystemStatus();
      if (!mounted) return;
      setState(() {
        if (tab == 7)
          systemStatus = result as Map<String, dynamic>;
        else if (result is Map<String, dynamic>) {
          sectionRows = result['results'] as List<dynamic>;
          pages = result['pages'] as int;
        } else
          sectionRows = result as List<dynamic>;
        sectionLoading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          error = 'Bo‘lim ma’lumotlari yuklanmadi: $e';
          sectionLoading = false;
        });
    }
  }

  void selectTab(int index) {
    setState(() {
      selectedTab = index;
      page = 1;
      search = '';
    });
    if (index == 0) loadDashboard();
    if (index == 1) loadUsers();
    if (index > 1) loadSection(index);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Panel',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              isMobile ? 'Boshqaruv paneli' : 'Tizim boshqaruvi',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (!isMobile)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Chip(
                  avatar: const Icon(Icons.admin_panel_settings,
                      size: 18, color: Colors.white),
                  label: const Text(
                    'Superadmin',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: Colors.orange[700],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              if (selectedTab == 0)
                loadDashboard();
              else if (selectedTab == 1)
                loadUsers();
              else
                loadSection(selectedTab);
            },
            tooltip: 'Yangilash',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Chiqish'),
                  content: const Text('Admindan chiqmoqchimisiz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Yo\'q'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Ha, chiqish'),
                    ),
                  ],
                ),
              );

              if (shouldLogout == true) {
                await ref.read(apiProvider).logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const Login()),
                    (route) => false,
                  );
                }
              }
            },
            tooltip: 'Chiqish',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
      ),
      floatingActionButton: selectedTab == 1 || selectedTab == 3
          ? FloatingActionButton.extended(
              onPressed: selectedTab == 1
                  ? _showCreateUserDialog
                  : () => _showPlanDialog(),
              icon: Icon(
                  selectedTab == 1 ? Icons.person_add_rounded : Icons.add_card),
              label: Text(selectedTab == 1
                  ? (isMobile ? 'Yangi user' : 'Yangi foydalanuvchi')
                  : 'Yangi tarif'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            )
          : null,
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          height: 60,
          child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                  children: List.generate(8, (i) {
                const labels = [
                  'Dashboard',
                  'Userlar',
                  'Do‘konlar',
                  'Tariflar',
                  'Obunalar',
                  'To‘lovlar',
                  'Audit',
                  'Tizim'
                ];
                const icons = [
                  Icons.dashboard_outlined,
                  Icons.people_outline,
                  Icons.store_outlined,
                  Icons.sell_outlined,
                  Icons.card_membership_outlined,
                  Icons.payments_outlined,
                  Icons.history,
                  Icons.monitor_heart_outlined
                ];
                return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                        avatar: Icon(icons[i], size: 18),
                        label: Text(labels[i]),
                        selected: selectedTab == i,
                        onSelected: (_) => selectTab(i)));
              }))),
        ),
        Expanded(
          child: _buildSelectedTab(),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: selectedTab,
          onDestinationSelected: selectTab,
          extended: MediaQuery.of(context).size.width > 800,
          backgroundColor: Colors.white,
          indicatorColor: Theme.of(context).colorScheme.primaryContainer,
          labelType: NavigationRailLabelType.none,
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: Text('Bosh sahifa'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded),
              label: Text('Userlar'),
            ),
            NavigationRailDestination(
                icon: Icon(Icons.store_outlined),
                selectedIcon: Icon(Icons.store),
                label: Text('Do‘konlar')),
            NavigationRailDestination(
                icon: Icon(Icons.sell_outlined),
                selectedIcon: Icon(Icons.sell),
                label: Text('Tariflar')),
            NavigationRailDestination(
                icon: Icon(Icons.card_membership_outlined),
                selectedIcon: Icon(Icons.card_membership),
                label: Text('Obunalar')),
            NavigationRailDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments),
                label: Text('To‘lovlar')),
            NavigationRailDestination(
                icon: Icon(Icons.history),
                selectedIcon: Icon(Icons.history),
                label: Text('Audit log')),
            NavigationRailDestination(
                icon: Icon(Icons.monitor_heart_outlined),
                selectedIcon: Icon(Icons.monitor_heart),
                label: Text('Tizim holati')),
          ],
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(
          child: _buildSelectedTab(),
        ),
      ],
    );
  }

  Widget _buildDashboard() {
    if (dashboardLoading && dashboard.isEmpty)
      return const Center(child: CircularProgressIndicator());
    if (dashboardError != null && dashboard.isEmpty)
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(dashboardError!),
        FilledButton.icon(
            onPressed: loadDashboard,
            icon: const Icon(Icons.refresh),
            label: const Text('Qayta urinish'))
      ]));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                          context: context,
                          initialDate: dashboardStart ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now());
                      if (d != null) setState(() => dashboardStart = d);
                      loadDashboard();
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: Text(dashboardStart == null
                        ? 'Boshlanish sanasi'
                        : DateFormat('dd.MM.yyyy').format(dashboardStart!)))),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                          context: context,
                          initialDate: dashboardEnd ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now());
                      if (d != null) setState(() => dashboardEnd = d);
                      loadDashboard();
                    },
                    icon: const Icon(Icons.event),
                    label: Text(dashboardEnd == null
                        ? 'Tugash sanasi'
                        : DateFormat('dd.MM.yyyy').format(dashboardEnd!)))),
            IconButton(
                onPressed: () {
                  setState(() {
                    dashboardStart = null;
                    dashboardEnd = null;
                  });
                  loadDashboard();
                },
                icon: const Icon(Icons.clear))
          ]),
          _DashboardCard(
            gradient: LinearGradient(
              colors: [Colors.blue[600]!, Colors.blue[400]!],
            ),
            icon: Icons.admin_panel_settings_rounded,
            title: 'Admin Panelga xush kelibsiz',
            subtitle: 'Tizimni boshqarish va nazorat qilish',
          ),
          const SizedBox(height: 16),

          // Statistics Cards
          const Text(
            'Statistika',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: isSmall
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                    child: _StatCard(
                      icon: Icons.people_rounded,
                      title: 'Foydalanuvchilar',
                      value: '${dashboard['users']?['total'] ?? '—'}',
                      color: Colors.purple,
                    ),
                  ),
                  SizedBox(
                    width: isSmall
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                    child: _StatCard(
                      icon: Icons.store_rounded,
                      title: 'Do\'konlar',
                      value: '${dashboard['stores']?['total'] ?? '—'}',
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(
                    width: isSmall
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                    child: _StatCard(
                      icon: Icons.verified_user_rounded,
                      title: 'Faol obunalar',
                      value: '${dashboard['subscriptions']?['active'] ?? '—'}',
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(
                    width: isSmall
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                    child: _StatCard(
                      icon: Icons.person_rounded,
                      title: 'Faol userlar',
                      value: '${dashboard['users']?['active'] ?? '—'}',
                      color: Colors.blue,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Quick Actions
          const Text(
            'Tez amallar',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _QuickActionCard(
            icon: Icons.person_add_rounded,
            title: 'Yangi foydalanuvchi',
            subtitle: 'Tizimga yangi user qo\'shish',
            onTap: () => _showCreateUserDialog(),
          ),
          const SizedBox(height: 8),
          _StatCard(
              icon: Icons.block,
              title: 'Bloklangan userlar',
              value: '${dashboard['users']?['blocked'] ?? '—'}',
              color: Colors.red),
          const SizedBox(height: 8),
          _StatCard(
              icon: Icons.store_mall_directory,
              title: 'Faol / bloklangan do‘konlar',
              value:
                  '${dashboard['stores']?['active'] ?? '—'} / ${dashboard['stores']?['blocked'] ?? '—'}',
              color: Colors.indigo),
          const SizedBox(height: 8),
          _StatCard(
              icon: Icons.hourglass_bottom,
              title: 'Trial / muddati tugagan',
              value:
                  '${dashboard['subscriptions']?['trial'] ?? '—'} / ${dashboard['subscriptions']?['expired'] ?? '—'}',
              color: Colors.deepOrange),
          const SizedBox(height: 8),
          _StatCard(
              icon: Icons.payments,
              title: 'Tasdiqlangan to‘lovlar',
              value:
                  '${dashboard['payments']?['approved_count'] ?? '—'} · ${dashboard['payments']?['approved_total'] ?? '—'} so‘m',
              color: Colors.teal),
          const SizedBox(height: 8),
          _QuickActionCard(
            icon: Icons.people_rounded,
            title: 'Foydalanuvchilarni ko\'rish',
            subtitle: 'Barcha userlar ro\'yxati',
            onTap: () => selectTab(1),
          ),
          const SizedBox(height: 20),
          const Text('So‘nggi muhim amallar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ...((dashboard['recent_actions'] as List? ?? []).map((a) => ListTile(
              dense: true,
              leading: const Icon(Icons.history),
              title: Text('${a['action']} · ${a['target']}'),
              subtitle: Text('${a['actor']} · ${a['timestamp']}')))),
        ],
      ),
    );
  }

  Widget _buildSelectedTab() {
    if (selectedTab == 0) return _buildDashboard();
    if (selectedTab == 1) return _buildUsersTab();
    return _buildAdminSection();
  }

  Widget _buildAdminSection() {
    if (sectionLoading) return const Center(child: CircularProgressIndicator());
    if (error != null)
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(error!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: () => loadSection(selectedTab),
            icon: const Icon(Icons.refresh),
            label: const Text('Qayta urinish'))
      ]));
    if (selectedTab == 7)
      return ListView(padding: const EdgeInsets.all(20), children: [
        Text('Tizim holati', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        _statusTile('Backend/API', systemStatus['api']),
        _statusTile('Ma’lumotlar bazasi', systemStatus['database']),
        _statusTile(
            'Backup monitoring',
            systemStatus['backup']?['available'] == true
                ? 'mavjud'
                : systemStatus['backup']?['message'] ?? 'mavjud emas'),
        ListTile(
            title: const Text('Tekshirilgan vaqt'),
            subtitle: Text('${systemStatus['checked_at'] ?? '—'}'))
      ]);
    if (selectedTab == 3) return _buildPlans();
    if (selectedTab == 4) return _buildSubscriptions();
    return _buildAdminRows();
  }

  Widget _statusTile(String label, dynamic value) => Card(
      child: ListTile(
          leading: Icon(value == 'ok' ? Icons.check_circle : Icons.info_outline,
              color: value == 'ok' ? Colors.green : Colors.orange),
          title: Text(label),
          subtitle: Text('$value')));

  Widget _buildAdminRows() {
    final title = const [
      '',
      '',
      'Do‘konlar',
      '',
      '',
      'To‘lovlar',
      'Audit log'
    ][selectedTab];
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (selectedTab == 2 || selectedTab == 6)
                  SizedBox(
                      width: 200,
                      child: TextField(
                          decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Qidirish',
                              border: OutlineInputBorder()),
                          onSubmitted: (v) {
                            search = v;
                            page = 1;
                            loadSection(selectedTab);
                          })),
                if (selectedTab == 2)
                  SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<bool?>(
                          initialValue: activeFilter,
                          decoration: const InputDecoration(labelText: 'Holat'),
                          items: const [
                            DropdownMenuItem(
                                value: null, child: Text('Barchasi')),
                            DropdownMenuItem(value: true, child: Text('Faol')),
                            DropdownMenuItem(
                                value: false, child: Text('Bloklangan'))
                          ],
                          onChanged: (v) {
                            activeFilter = v;
                            page = 1;
                            loadSection(2);
                          })),
                if (selectedTab == 5)
                  SizedBox(
                      width: 170,
                      child: DropdownButtonFormField<String?>(
                          initialValue: paymentStatus,
                          decoration:
                              const InputDecoration(labelText: 'To‘lov holati'),
                          items: const [
                            DropdownMenuItem(
                                value: null, child: Text('Barchasi')),
                            DropdownMenuItem(
                                value: 'pending', child: Text('Kutilmoqda')),
                            DropdownMenuItem(
                                value: 'approved', child: Text('Tasdiqlangan')),
                            DropdownMenuItem(
                                value: 'failed', child: Text('Muvaffaqiyatsiz'))
                          ],
                          onChanged: (v) {
                            paymentStatus = v;
                            page = 1;
                            loadSection(5);
                          })),
                if (selectedTab == 5)
                  IconButton(
                      tooltip: 'Boshlanish sanasi',
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: paymentStart ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now());
                        if (d != null) {
                          paymentStart = d;
                          page = 1;
                          loadSection(5);
                        }
                      },
                      icon: Icon(paymentStart == null
                          ? Icons.calendar_month
                          : Icons.event_available)),
                if (selectedTab == 5)
                  IconButton(
                      tooltip: 'Tugash sanasi',
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: paymentEnd ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now());
                        if (d != null) {
                          paymentEnd = d;
                          page = 1;
                          loadSection(5);
                        }
                      },
                      icon: Icon(paymentEnd == null
                          ? Icons.event
                          : Icons.event_available))
              ])),
      Expanded(
          child: sectionRows.isEmpty
              ? const Center(child: Text('Ma’lumot topilmadi'))
              : ListView.builder(
                  itemCount: sectionRows.length,
                  itemBuilder: (context, i) {
                    final row =
                        Map<String, dynamic>.from(sectionRows[i] as Map);
                    if (selectedTab == 2)
                      return Card(
                          child: ListTile(
                              leading: const Icon(Icons.store),
                              title: Text('${row['name']}'),
                              subtitle: Text(
                                  'Egasi: ${row['owner']} · ${row['subscription_status']}\nID: ${row['id']} · ${row['created_at']}'),
                              isThreeLine: true,
                              onTap: () => _showStoreDetails(row),
                              trailing: Switch(
                                  value: row['is_active'] == true,
                                  onChanged: (v) => _toggleStore(row, v))));
                    if (selectedTab == 5)
                      return Card(
                          child: ListTile(
                              leading: const Icon(Icons.payments),
                              title: Text(
                                  '${row['store']} · ${row['amount']} ${row['currency'] ?? ''}'),
                              subtitle: Text(
                                  '${row['provider'] ?? 'manual'} · ${row['plan']} · ${row['billing_period'] ?? 'month'} · ${row['status']}\nTransaction: ${row['provider_transaction_id'] ?? '—'} · ${row['submitted_at']}'),
                              isThreeLine: true,
                              trailing: row['status'] == 'pending'
                                  ? IconButton(
                                      tooltip: 'Tasdiqlash',
                                      icon: const Icon(Icons.check_circle,
                                          color: Colors.green),
                                      onPressed: () => _approvePayment(row))
                                  : null));
                    return Card(
                        child: ListTile(
                            leading: const Icon(Icons.history),
                            title: Text('${row['action']} · ${row['target']}'),
                            subtitle:
                                Text('${row['actor']} · ${row['timestamp']}'),
                            onTap: () => showDialog<void>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                        title: const Text('Audit yozuvi'),
                                        content: SelectableText(
                                            '${row['metadata']}'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('Yopish'))
                                        ]))));
                  })),
      if (pages > 1) _pagination()
    ]);
  }

  Widget _buildPlans() =>
      ListView(padding: const EdgeInsets.all(12), children: [
        if (sectionRows.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24), child: Text('Tariflar mavjud emas')),
        ...sectionRows.map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          return Card(
              child: ListTile(
                  leading: const Icon(Icons.sell),
                  title: Text('${row['name']}'),
                  subtitle: Text(
                      '${row['price']} ${row['currency'] ?? 'UZS'}/oy · ${row['annual_price'] ?? '—'} ${row['currency'] ?? 'UZS'}/yil\nUser ${row['user_limit']} ta · mahsulot ${row['product_limit']} ta · trial ${row['trial_days'] ?? 0} kun'),
                  isThreeLine: true,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Switch(
                        value: row['active'] == true,
                        onChanged: (v) async {
                          try {
                            await ref.read(apiProvider).saveAdminPlan(
                                {...row, 'active': v},
                                id: row['id']);
                            await loadSection(3);
                          } catch (e) {
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                      'Tarif holatini saqlab bo‘lmadi: $e')));
                          }
                        }),
                    IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showPlanDialog(plan: row))
                  ])));
        })
      ]);

  Widget _buildSubscriptions() =>
      ListView(padding: const EdgeInsets.all(12), children: [
        DropdownButtonFormField<String?>(
          initialValue: subscriptionStatus,
          decoration: const InputDecoration(labelText: 'Obuna holati'),
          items: const [
            DropdownMenuItem(value: null, child: Text('Barchasi')),
            DropdownMenuItem(value: 'active', child: Text('Faol')),
            DropdownMenuItem(value: 'trial', child: Text('Trial')),
            DropdownMenuItem(value: 'expired', child: Text('Tugagan')),
            DropdownMenuItem(value: 'cancelled', child: Text('Bekor qilingan')),
          ],
          onChanged: (value) {
            subscriptionStatus = value;
            loadSection(4);
          },
        ),
        if (sectionRows.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Obuna yozuvlari mavjud emas')),
        ...sectionRows.map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          return Card(
              child: ListTile(
                  leading: const Icon(Icons.card_membership),
                  title: Text('${row['store']} · ${row['status']}'),
                  subtitle: Text(
                      'Egasi: ${row['owner']} · Tarif: ${row['plan'] ?? '—'} · ${row['billing_period'] ?? ''}\nTrial: ${row['trial_end'] ?? '—'} · To‘langan: ${row['paid_until'] ?? '—'}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                      onSelected: (v) => _subscriptionAction(row, v),
                      itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'extend',
                                child: Text('1 oyga uzaytirish')),
                            PopupMenuItem(
                                value: 'cancel',
                                child: Text('Obunani bekor qilish'))
                          ])));
        })
      ]);

  Widget _pagination() => Padding(
      padding: const EdgeInsets.all(12),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
            onPressed: page > 1
                ? () {
                    page--;
                    if (selectedTab == 1)
                      loadUsers();
                    else
                      loadSection(selectedTab);
                  }
                : null,
            icon: const Icon(Icons.chevron_left)),
        Text('$page / $pages'),
        IconButton(
            onPressed: page < pages
                ? () {
                    page++;
                    if (selectedTab == 1)
                      loadUsers();
                    else
                      loadSection(selectedTab);
                  }
                : null,
            icon: const Icon(Icons.chevron_right))
      ]));

  Future<void> _subscriptionAction(
      Map<String, dynamic> row, String action) async {
    final reason = TextEditingController();
    final accepted = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(action == 'cancel'
                    ? 'Obunani bekor qilish'
                    : 'Obunani uzaytirish'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(action == 'cancel'
                      ? '${row['store']} do‘koni obunasi darhol tugatiladi.'
                      : '${row['store']} obunasi bir oyga uzaytiriladi.'),
                  const SizedBox(height: 12),
                  TextField(
                      controller: reason,
                      decoration:
                          const InputDecoration(labelText: 'Sabab (majburiy)')),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Ortga')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, reason.text.trim()),
                      child: const Text('Tasdiqlash'))
                ]));
    if (accepted == null || accepted.isEmpty) return;
    try {
      await ref.read(apiProvider).adminSubscriptionAction(
          row['store_id'] as int, action,
          reason: accepted);
      await loadSection(4);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Amal bajarilmadi: $e')));
    }
  }

  Future<void> _approvePayment(Map<String, dynamic> payment) async {
    final reason = TextEditingController();
    final accepted = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('To‘lovni tasdiqlash'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                      '${payment['store']} do‘koni uchun ${payment['amount']} ${payment['currency'] ?? ''} to‘lov obunani ${payment['billing_period'] ?? ''} muddatiga uzaytiradi.'),
                  const SizedBox(height: 12),
                  TextField(
                      controller: reason,
                      decoration: const InputDecoration(
                          labelText: 'Tekshiruv sababi (majburiy)')),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Bekor')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, reason.text.trim()),
                      child: const Text('Tasdiqlash'))
                ]));
    if (accepted == null || accepted.isEmpty) return;
    try {
      await ref
          .read(apiProvider)
          .adminApprovePayment(payment['id'] as int, accepted);
      await loadSection(5);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('To‘lovni tasdiqlab bo‘lmadi: $e')));
    }
  }

  Future<void> _toggleStore(Map<String, dynamic> row, bool active) async {
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(
                    active ? 'Do‘konni faollashtirish' : 'Do‘konni bloklash'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${row['name']} do‘koni holati o‘zgaradi.'),
                  if (!active)
                    TextField(
                        controller: reason,
                        decoration:
                            const InputDecoration(labelText: 'Bloklash sababi'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Bekor')),
                  FilledButton(
                      onPressed: () {
                        if (!active && reason.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Bloklash sababini kiriting')));
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Tasdiqlash'))
                ]));
    if (accepted != true) return;
    try {
      await ref
          .read(apiProvider)
          .adminStore(row['id'] as int, active, reason.text);
      await loadSection(2);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Do‘kon holatini o‘zgartirib bo‘lmadi: $e')));
    }
  }

  void _showStoreDetails(Map<String, dynamic> store) {
    showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text('${store['name']}'),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(
                          icon: Icons.tag,
                          label: 'ID',
                          value: '${store['id']}'),
                      _DetailRow(
                          icon: Icons.person,
                          label: 'Egasi',
                          value: '${store['owner']}'),
                      _DetailRow(
                          icon: Icons.calendar_month,
                          label: 'Ro‘yxatdan o‘tgan',
                          value: '${store['created_at']}'),
                      _DetailRow(
                          icon: Icons.verified_user,
                          label: 'Holat',
                          value: store['is_active'] == true
                              ? 'Faol'
                              : 'Bloklangan'),
                      _DetailRow(
                          icon: Icons.card_membership,
                          label: 'Obuna',
                          value: '${store['subscription_status']}'),
                      _DetailRow(
                          icon: Icons.event,
                          label: 'To‘lov muddati',
                          value: '${store['paid_until'] ?? '—'}'),
                      _DetailRow(
                          icon: Icons.people,
                          label: 'Bog‘langan userlar',
                          value: '${store['staff_count']}')
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Yopish'))
                ]));
  }

  Future<void> _showPlanDialog({Map<String, dynamic>? plan}) async {
    final name = TextEditingController(text: '${plan?['name'] ?? ''}');
    final months = TextEditingController(text: '${plan?['months'] ?? 1}');
    final price = TextEditingController(text: '${plan?['price'] ?? ''}');
    final annualPrice =
        TextEditingController(text: '${plan?['annual_price'] ?? ''}');
    final userLimit =
        TextEditingController(text: '${plan?['user_limit'] ?? 2}');
    final productLimit =
        TextEditingController(text: '${plan?['product_limit'] ?? 500}');
    final trialDays =
        TextEditingController(text: '${plan?['trial_days'] ?? 0}');
    final description =
        TextEditingController(text: '${plan?['description'] ?? ''}');
    final features = TextEditingController(
        text: ((plan?['features'] as List?) ?? const []).join('\n'));
    final discount =
        TextEditingController(text: '${plan?['discount_percent'] ?? 0}');
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title:
                    Text(plan == null ? 'Yangi tarif' : 'Tarifni tahrirlash'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      decoration:
                          const InputDecoration(labelText: 'Tarif nomi')),
                  TextField(
                      controller: months,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Muddat (oy)')),
                  TextField(
                      controller: price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Narx (so‘m)')),
                  TextField(
                      controller: annualPrice,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Yillik narx (so‘m)')),
                  TextField(
                      controller: userLimit,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'User limiti')),
                  TextField(
                      controller: productLimit,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Faol mahsulot limiti')),
                  TextField(
                      controller: trialDays,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Trial kunlari')),
                  TextField(
                      controller: description,
                      decoration: const InputDecoration(labelText: 'Tavsif')),
                  TextField(
                      controller: features,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Imkoniyatlar (har satrga bittadan)')),
                  TextField(
                      controller: discount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Chegirma foizi'))
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Bekor')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Saqlash'))
                ]));
    if (ok != true) return;
    final m = int.tryParse(months.text),
        users = int.tryParse(userLimit.text),
        products = int.tryParse(productLimit.text),
        trial = int.tryParse(trialDays.text),
        p = double.tryParse(price.text.replaceAll(',', '.')),
        ap = double.tryParse(annualPrice.text.replaceAll(',', '.')),
        d = double.tryParse(discount.text.replaceAll(',', '.'));
    if (name.text.trim().isEmpty ||
        m == null ||
        m < 1 ||
        p == null ||
        p < 0 ||
        ap == null ||
        ap < 0 ||
        users == null ||
        users < 1 ||
        products == null ||
        products < 1 ||
        trial == null ||
        trial < 0 ||
        d == null ||
        d < 0 ||
        d > 100) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Tarif ma’lumotlarini to‘g‘ri kiriting')));
      return;
    }
    try {
      await ref.read(apiProvider).saveAdminPlan({
        'name': name.text.trim(),
        'months': m,
        'price': p.toStringAsFixed(2),
        'annual_price': ap.toStringAsFixed(2),
        'user_limit': users,
        'product_limit': products,
        'trial_days': trial,
        'description': description.text.trim(),
        'features': features.text
            .split('\n')
            .map((x) => x.trim())
            .where((x) => x.isNotEmpty)
            .toList(),
        if (plan?['code'] != null) 'code': plan!['code'],
        'currency': plan?['currency'] ?? 'UZS',
        'discount_percent': d.toStringAsFixed(2),
        'active': plan?['active'] ?? true
      }, id: plan?['id'] as int?);
      await loadSection(3);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Tarif saqlanmadi: $e')));
    }
  }

  Widget _buildUsersTab() {
    if (loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Yuklanmoqda...'),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: loadUsers,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
              child: TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Username yoki do‘kon',
                border: OutlineInputBorder()),
            onSubmitted: (v) {
              search = v;
              page = 1;
              loadUsers();
            },
          )),
          const SizedBox(width: 8),
          SizedBox(
              width: 145,
              child: DropdownButtonFormField<bool?>(
                initialValue: activeFilter,
                decoration: const InputDecoration(labelText: 'Holat'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Barchasi')),
                  DropdownMenuItem(value: true, child: Text('Faol')),
                  DropdownMenuItem(value: false, child: Text('Bloklangan'))
                ],
                onChanged: (v) {
                  activeFilter = v;
                  page = 1;
                  loadUsers();
                },
              )),
        ]),
      ),
      if (users.isEmpty)
        const Expanded(
            child: Center(child: Text('Qidiruv bo‘yicha user topilmadi')))
      else
        Expanded(
            child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = Map<String, dynamic>.from(users[index] as Map);
            final isSuperuser = user['is_superuser'] == true;

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showUserDetailsDialog(user),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'user_${user['id']}',
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isSuperuser
                                  ? [Colors.orange[400]!, Colors.orange[600]!]
                                  : [Colors.blue[400]!, Colors.blue[600]!],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isSuperuser ? Colors.orange : Colors.blue)
                                        .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              user['username'][0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user['username'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSuperuser) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.star_rounded,
                                            size: 12,
                                            color: Colors.orange[700]),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Admin',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.store_rounded,
                                    size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    user['store_name'] ?? 'Do\'kon mavjud emas',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Holat: ${user['is_active'] == true ? 'Faol' : (user['has_password'] == true ? 'Bloklangan' : 'Aktivatsiya kutilmoqda')}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: user['is_active'] == true
                                      ? Colors.green[700]
                                      : Colors.orange[800]),
                            ),
                          ],
                        ),
                      ),
                      if (!isSuperuser &&
                          (user['is_active'] == true ||
                              user['has_password'] == true))
                        IconButton(
                            icon: Icon(user['is_active'] == true
                                ? Icons.block
                                : Icons.check_circle_outline),
                            onPressed: () =>
                                _toggleUser(user, user['is_active'] != true),
                            tooltip: user['is_active'] == true
                                ? 'Bloklash'
                                : 'Faollashtirish'),
                      IconButton(
                          icon: const Icon(Icons.vpn_key_rounded),
                          onPressed: () => _issueActivationCode(user),
                          tooltip: 'Aktivatsiya kodi',
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.blue[50],
                              foregroundColor: Colors.blue[700])),
                    ],
                  ),
                ),
              ),
            );
          },
        )),
      if (pages > 1) _pagination()
    ]);
  }

  Future<void> _toggleUser(Map<String, dynamic> user, bool active) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title:
                    Text(active ? 'Userni faollashtirish' : 'Userni bloklash'),
                content: Text(
                    '${user['username']} hisobi ${active ? 'faollashtiriladi' : 'bloklanadi'}.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Bekor')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Tasdiqlash'))
                ]));
    if (ok != true) return;
    try {
      await ref.read(apiProvider).adminUser(user['id'] as int, active);
      await loadUsers();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User holatini o‘zgartirib bo‘lmadi: $e')));
    }
  }

  void _showUserDetailsDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: user['is_superuser'] == true
                      ? [Colors.orange[400]!, Colors.orange[600]!]
                      : [Colors.blue[400]!, Colors.blue[600]!],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  user['username'][0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user['username'],
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(
              icon: Icons.badge_rounded,
              label: 'ID',
              value: user['id'].toString(),
            ),
            _DetailRow(
                icon: Icons.calendar_today,
                label: 'Ro‘yxatdan o‘tgan',
                value: '${user['date_joined']}'),
            _DetailRow(
              icon: Icons.store_rounded,
              label: 'Do\'kon',
              value: user['store_name'] ?? 'Mavjud emas',
            ),
            _DetailRow(
              icon: Icons.admin_panel_settings_rounded,
              label: 'Rol',
              value:
                  user['is_superuser'] == true ? 'Superadmin' : 'Foydalanuvchi',
            ),
            _DetailRow(
                icon: Icons.verified_user_outlined,
                label: 'Holat',
                value: user['is_active'] == true
                    ? 'Faol'
                    : 'Bloklangan / aktivatsiya kutilmoqda'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Yopish'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _issueActivationCode(user);
            },
            icon: const Icon(Icons.vpn_key_rounded),
            label: const Text('Kod berish'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateUserDialog() async {
    final usernameController = TextEditingController();
    final storeNameController = TextEditingController();
    bool busy = false;
    String? dialogError;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(Icons.person_add_rounded, color: Colors.blue[700]),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Yangi foydalanuvchi',
                        style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: usernameController,
                        decoration: InputDecoration(
                          labelText: 'Foydalanuvchi nomi *',
                          hintText: 'user123',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: storeNameController,
                        decoration: InputDecoration(
                          labelText: 'Do\'kon nomi',
                          hintText: 'Ixtiyoriy',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.store_outlined),
                        ),
                      ),
                      if (dialogError != null)
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
                                    dialogError!,
                                    style: TextStyle(
                                        color: Colors.red[700], fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: const Text('Bekor qilish'),
                ),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          if (usernameController.text.trim().isEmpty) {
                            setDialogState(() {
                              dialogError = 'Username majburiy';
                            });
                            return;
                          }

                          setDialogState(() {
                            busy = true;
                            dialogError = null;
                          });

                          try {
                            final result =
                                await ref.read(apiProvider).createAdminUser(
                                      usernameController.text.trim(),
                                      storeNameController.text.trim(),
                                    );

                            if (context.mounted) {
                              Navigator.pop(context);
                              await loadUsers();

                              // Show success dialog
                              if (context.mounted) {
                                _showSuccessDialog(result);
                              }
                            }
                          } catch (e) {
                            setDialogState(() {
                              busy = false;
                              dialogError = e.toString();
                            });
                          }
                        },
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(busy ? 'Yaratilmoqda...' : 'Yaratish'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.check_circle_rounded,
                  color: Colors.green[700], size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Muvaffaqiyatli!', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(
              icon: Icons.person_rounded,
              label: 'Username',
              value: result['username'],
            ),
            _DetailRow(
              icon: Icons.store_rounded,
              label: 'Do\'kon',
              value: result['store_name'],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Foydalanuvchiga aktivatsiya kodini bering',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keyinroq'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Find the user in the list and issue activation code
              final newUser = users.firstWhere(
                (u) => u['username'] == result['username'],
                orElse: () => result,
              );
              _issueActivationCode(newUser);
            },
            icon: const Icon(Icons.vpn_key_rounded),
            label: const Text('Kod berish'),
          ),
        ],
      ),
    );
  }

  Future<void> _issueActivationCode(Map<String, dynamic> user) async {
    try {
      final result = await ref.read(apiProvider).issueCredential(
            user['id'],
            'activation',
          );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.vpn_key_rounded, color: Colors.orange[700]),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child:
                      Text('Aktivatsiya kodi', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DetailRow(
                  icon: Icons.person_rounded,
                  label: 'Foydalanuvchi',
                  value: user['username'],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bir martalik kod:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey[100]!, Colors.grey[200]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          result['one_time_code'],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: result['one_time_code']),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: Colors.white),
                                  const SizedBox(width: 8),
                                  const Text('Kod nusxalandi'),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                        ),
                        tooltip: 'Nusxalash',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result['warning'] ??
                              'Kodni xavfsiz kanal orqali bir marta yuboring',
                          style: TextStyle(
                            color: Colors.orange[900],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Tushunarli'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Xatolik: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// Helper Widgets

class _DashboardCard extends StatelessWidget {
  final Gradient gradient;
  final IconData icon;
  final String title;
  final String subtitle;

  const _DashboardCard({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 40, color: Colors.white),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.blue[700]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 18, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

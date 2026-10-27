import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../screens/account_settings.dart';
import '../screens/admin_panel.dart';
import '../screens/change_password.dart';

import '../../features/products/screens/products_screen.dart';
import '../../features/products/providers/products_provider.dart' as products;
import '../../features/pos/screens/pos_screen.dart';
import '../../features/pos/providers/cart_provider.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/debts/screens/debts_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isAdmin = false;
  String? _username;

  int _pendingCount = 0;
  bool _syncing = false;
  bool _leaving = false;
  bool _networkUnavailable = false;
  String? _syncMessage;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;

  static const _labels = [
    'Mahsulotlar',
    'Savdo',
    'Hisobot',
    'Daftar',
  ];

  static const _icons = [
    Icons.inventory_2_outlined,
    Icons.point_of_sale_outlined,
    Icons.assessment_outlined,
    Icons.menu_book_outlined,
  ];

  static const _selectedIcons = [
    Icons.inventory_2_rounded,
    Icons.point_of_sale_rounded,
    Icons.assessment_rounded,
    Icons.menu_book_rounded,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    unawaited(_loadProfile());
    unawaited(_updatePendingCount());

    _connectivity = Connectivity().onConnectivityChanged.listen(
      (results) {
        if (!mounted || _leaving) return;

        final disconnected = results.every((r) => r == ConnectivityResult.none);

        setState(() {
          _networkUnavailable = disconnected;
        });

        if (!disconnected) {
          unawaited(_syncNow());
        }
      },
      onError: (Object error) {
        // Ulanish kuzatuvi xatosi sotuvlarni o‘chirmaydi.
      },
    );

    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_syncNow()),
    );

    unawaited(_syncNow());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_leaving) {
      unawaited(_syncNow());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopBackgroundTasks();
    super.dispose();
  }

  void _stopBackgroundTasks() {
    _timer?.cancel();
    _timer = null;

    final subscription = _connectivity;
    _connectivity = null;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref.read(apiProvider).me();

      if (!mounted || _leaving) return;

      setState(() {
        _isAdmin =
            profile['is_superadmin'] == true || profile['superadmin'] == true;
        _username = profile['username']?.toString();
      });
    } catch (_) {
      // Offline profilga ruxsat bo‘lsa Api.me() uni qaytaradi.
      // Bu yerda yangi sessiya yaratilmaydi.
    }
  }

  Future<void> _updatePendingCount() async {
    try {
      final count = await ref.read(queueProvider).pendingCount();

      if (!mounted || _leaving) return;

      setState(() {
        _pendingCount = count;
      });
    } catch (_) {
      // Akkaunt almashishi vaqtida eski ekran yangilanmaydi.
    }
  }

  Future<void> _syncNow({bool manual = false}) async {
    if (!mounted || _leaving || _syncing) return;

    final api = ref.read(apiProvider);
    final owner = api.sessionKey;

    if (owner == null) return;

    setState(() => _syncing = true);

    try {
      final queue = ref.read(queueProvider);
      final result = await queue.syncOnce(api);

      if (!mounted || _leaving || api.sessionKey != owner) {
        return;
      }

      final remaining = await queue.pendingCount();
      String message;

      if (result.networkError) {
        message = 'Serverga ulanish yo‘q. Sotuvlar qurilmada saqlangan.';
      } else if (result.conflicts > 0) {
        message = '${result.conflicts} ta sotuv tekshirishni talab qiladi.';
      } else if (result.acked > 0) {
        message = '${result.acked} ta sotuv serverda tasdiqlandi.';
      } else if (remaining > 0) {
        message = '$remaining ta sotuv hali tasdiqlanmagan.';
      } else {
        message = 'Yuborilmagan sotuvlar yo‘q.';
      }

      // Barcha lokal sotuvlar tasdiqlangandan keyin
      // serverdagi yangi mahsulot qoldiqlarini olamiz.
      if (result.acked > 0 && remaining == 0) {
        try {
          await ref.read(products.productsProvider.notifier).refresh();
        } catch (_) {
          // Mahsulot yangilanmasligi tasdiqlangan sotuvni
          // qayta yuborishga sabab bo‘lmaydi.
          message += ' Mahsulotlarni keyinroq yangilang.';
        }
      }

      if (!mounted || _leaving || api.sessionKey != owner) {
        return;
      }

      setState(() {
        _pendingCount = remaining;
        _syncMessage = message;

        if (result.networkError) {
          _networkUnavailable = true;
        } else if (result.acked > 0) {
          _networkUnavailable = false;
        }
      });

      if (manual) {
        _showMessage(message);
      }
    } catch (_) {
      if (mounted && !_leaving) {
        setState(() {
          _syncMessage = 'Sinxronlash bajarilmadi. Sotuvlar o‘chirilmagan.';
        });

        if (manual) {
          _showMessage(_syncMessage!);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _logout() async {
    if (_leaving) return;

    if (_syncing) {
      _showMessage('Sinxronlash tugashini kuting.');
      return;
    }

    await _updatePendingCount();
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Akkauntdan chiqish'),
        content: Text(
          _pendingCount > 0
              ? '$_pendingCount ta tasdiqlanmagan sotuv bor. '
                  'Ular shu akkaunt uchun qurilmada qoladi. '
                  'Qayta kirish uchun internet kerak bo‘ladi. '
                  'Chiqasizmi?'
              : 'Akkauntdan chiqasizmi? '
                  'Qayta kirish uchun internet kerak bo‘ladi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Ortga'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _leaving = true);
    _stopBackgroundTasks();

    final api = ref.read(apiProvider);
    await api.logout();

    if (!mounted) return;

    // Oldingi akkaunt savati yangi akkauntga o‘tmasin.
    ref.read(cartProvider.notifier).clear();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const Login(),
      ),
      (_) => false,
    );
  }

  Future<void> _openAccount() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AccountSettings(),
      ),
    );

    if (mounted && !_leaving) {
      unawaited(_loadProfile());
    }
  }

  void _openPassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ChangePassword(),
      ),
    );
  }

  void _handleMenu(String value) {
    switch (value) {
      case 'profile':
        unawaited(_openAccount());
        break;
      case 'password':
        _openPassword();
        break;
      case 'logout':
        unawaited(_logout());
        break;
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 1:
        return const POSScreen();
      case 2:
        return const ReportsScreen();
      case 3:
        return const DebtsScreen();
      default:
        return const ProductsScreen();
    }
  }

  Widget _buildStatusBar() {
    final message = _networkUnavailable
        ? 'Serverga ulanish yo‘q'
        : _syncMessage ?? 'Sotuvlarni sinxronlash';

    return Material(
      color: _networkUnavailable ? Colors.orange.shade50 : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        child: Row(
          children: [
            Icon(
              _networkUnavailable ? Icons.cloud_off : Icons.cloud_sync_outlined,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$message\nNavbatda: $_pendingCount ta',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: 'Sinxronlash',
              onPressed:
                  _syncing || _leaving ? null : () => _syncNow(manual: true),
              icon: _syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.sync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(_username ?? 'Akkaunt'),
              subtitle: Text(
                _isAdmin ? 'Administrator' : 'Foydalanuvchi',
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profil'),
              onTap: () {
                Navigator.of(context).pop();
                unawaited(_openAccount());
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Parolni o‘zgartirish'),
              onTap: () {
                Navigator.of(context).pop();
                _openPassword();
              },
            ),
            if (_isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Admin panel'),
                onTap: () {
                  Navigator.of(context).pop();

                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminPanel(),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sinxronlash'),
              onTap: () {
                Navigator.of(context).pop();
                unawaited(_syncNow(manual: true));
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.logout,
                color: Colors.red,
              ),
              title: const Text(
                'Chiqish',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.of(context).pop();
                unawaited(_logout());
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dokon Boshqaruv'),
            if (_username != null)
              Text(
                _username!,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'profile',
                child: Text('Profil'),
              ),
              PopupMenuItem(
                value: 'password',
                child: Text('Parolni o‘zgartirish'),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Text('Chiqish'),
              ),
            ],
          ),
        ],
      ),
      drawer: mobile ? _buildDrawer() : null,
      body: Column(
        children: [
          _buildStatusBar(),
          Expanded(
            child: mobile
                ? _buildBody()
                : Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: (index) {
                          setState(() => _selectedIndex = index);
                          unawaited(_updatePendingCount());
                        },
                        labelType: NavigationRailLabelType.all,
                        destinations: List.generate(
                          _labels.length,
                          (index) => NavigationRailDestination(
                            icon: Icon(_icons[index]),
                            selectedIcon: Icon(_selectedIcons[index]),
                            label: Text(_labels[index]),
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildBody()),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: mobile
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
                unawaited(_updatePendingCount());
              },
              destinations: List.generate(
                _labels.length,
                (index) => NavigationDestination(
                  icon: Icon(_icons[index]),
                  selectedIcon: Icon(_selectedIcons[index]),
                  label: _labels[index],
                ),
              ),
            )
          : null,
    );
  }
}

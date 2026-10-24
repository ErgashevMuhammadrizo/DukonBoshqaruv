import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'api.dart';
import 'offline.dart';
import 'screens/admin_panel.dart';
import 'screens/activate_account.dart';
import 'screens/change_password.dart';
import 'screens/home_screen.dart';
import '../features/products/screens/products_screen.dart';

final apiProvider = Provider<Api>((ref) => Api());
final queueProvider = Provider<OfflineQueue>((ref) => OfflineQueue());

class DokonApp extends StatelessWidget {
  const DokonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dokon Boshqaruv',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff165cdb)),
        useMaterial3: true,
      ),
      home: const Startup(),
    );
  }
}

class Startup extends ConsumerWidget {
  const Startup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: Future.microtask(() async {
        final restored = await ref.read(apiProvider).restore();
        if (!restored) return null;

        try {
          final profile = await ref.read(apiProvider).me();
          return profile;
        } catch (_) {
          return null;
        }
      }).timeout(const Duration(seconds: 6), onTimeout: () => null),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  SizedBox(height: 16),
                  Text('Yuklanmoqda...'),
                ],
              ),
            ),
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          return const Login();
        }

        // Check if user is superadmin
        final isSuperAdmin =
            profile['is_superadmin'] == true || profile['superadmin'] == true;

        // Check if user needs to change password
        final needsPasswordChange = profile['needs_password_change'] == true ||
            profile['force_password_change'] == true;

        if (needsPasswordChange) {
          return const ChangePassword(isFirstTime: true);
        }

        return isSuperAdmin ? const AdminPanel() : const HomeScreen();
      },
    );
  }
}

class Login extends ConsumerStatefulWidget {
  const Login({super.key});

  @override
  ConsumerState<Login> createState() => _LoginState();
}

class _LoginState extends ConsumerState<Login> {
  final user = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.storefront, size: 54, color: Colors.blue),
                const SizedBox(height: 12),
                const Text(
                  'Dokon Boshqaruv',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 26),
                TextField(
                  controller: user,
                  decoration: const InputDecoration(
                    labelText: 'Foydalanuvchi nomi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: pass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Parol',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final navigator = Navigator.of(context);
                          setState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await ref.read(apiProvider).login(
                                  user.text,
                                  pass.text,
                                );

                            // Check user role after successful login
                            final profile = await ref.read(apiProvider).me();
                            final isSuperAdmin =
                                profile['is_superadmin'] == true ||
                                    profile['superadmin'] == true;

                            final needsPasswordChange =
                                profile['needs_password_change'] == true ||
                                    profile['force_password_change'] == true;

                            if (!mounted) return;

                            // Navigate based on role and password status
                            if (needsPasswordChange) {
                              navigator.pushReplacement(
                                MaterialPageRoute(
                                    builder: (_) => const ChangePassword(
                                        isFirstTime: true)),
                              );
                            } else if (isSuperAdmin) {
                              navigator.pushReplacement(
                                MaterialPageRoute(
                                    builder: (_) => const AdminPanel()),
                              );
                            } else {
                              navigator.pushReplacement(
                                MaterialPageRoute(
                                    builder: (_) => const HomeScreen()),
                              );
                            }
                          } on DioException catch (e) {
                            if (!mounted) return;
                            final status = e.response?.statusCode;
                            final message = switch (status) {
                              401 =>
                                'Login yoki parol noto‘g‘ri, yoxud hisob hali faollashtirilmagan.',
                              429 =>
                                'Juda ko‘p urinish bo‘ldi. Biroz kutib qayta urinib ko‘ring.',
                              null =>
                                'Backendga ulanish yo‘q. Backend ishga tushganini va API manzilini tekshiring.',
                              _ =>
                                'Backend xatosi (HTTP $status). Keyinroq qayta urinib ko‘ring.',
                            };
                            setState(() => error = message);
                          } catch (_) {
                            if (!mounted) return;
                            setState(() => error =
                                'Kirish amalga oshmadi. Qayta urinib ko‘ring.');
                          } finally {
                            if (mounted) {
                              setState(() => busy = false);
                            }
                          }
                        },
                  child: Text(busy ? 'Tekshirilmoqda...' : 'Kirish'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ActivateAccount()),
                    );
                  },
                  child: const Text('Hisobni aktivatsiya qilish'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Home extends ConsumerStatefulWidget {
  const Home({super.key});

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> {
  int tab = 0;
  List<dynamic> products = [];
  bool loading = true;
  bool isAdmin = false;
  String? error;
  final Map<int, int> cart = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final profile = await ref.read(apiProvider).me();
      isAdmin =
          profile['superadmin'] == true || profile['is_superadmin'] == true;

      // Try to fetch products
      try {
        final fetchedProducts = await ref.read(apiProvider).products();
        await ref.read(queueProvider).cacheProducts(fetchedProducts);
        products = fetchedProducts;
      } catch (e) {
        // If products fetch fails, try to load from cache
        print('Products fetch error: $e');
        products = await ref.read(queueProvider).cachedProducts();
        if (products.isEmpty) {
          error = 'Mahsulotlar yuklanmadi. Internet yo\'q yoki do\'kon bo\'sh.';
        } else {
          error = 'Internet yo\'q. Saqlangan ma\'lumotlar ko\'rsatildi.';
        }
      }
    } catch (e) {
      print('Profile or products load error: $e');
      // If even profile fails, try to load cached products
      products = await ref.read(queueProvider).cachedProducts();
      error = 'Internet yo\'q. Saqlangan ma\'lumotlar ko\'rsatildi.';
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = cart.entries.fold<double>(0, (value, entry) {
      final product = products.firstWhere(
        (p) => p['id'] == entry.key,
        orElse: () => {'sale_price': 0},
      );
      final price = double.tryParse('${product['sale_price']}') ?? 0.0;
      return value + price * entry.value;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokon Boshqaruv'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Admin panel',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminPanel()),
                );
              },
              icon: const Icon(Icons.admin_panel_settings),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) async {
              if (value == 'change_password') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChangePassword()),
                );
              } else if (value == 'logout') {
                final navigator = Navigator.of(context);
                await ref.read(apiProvider).logout();
                if (!mounted) return;
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const Login()),
                  (route) => false,
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'change_password',
                child: Row(
                  children: [
                    Icon(Icons.password),
                    SizedBox(width: 12),
                    Text('Parolni o\'zgartirish'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 12),
                    Text('Chiqish'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Sinxronlash',
            onPressed: () async {
              await ref.read(queueProvider).sync(ref.read(apiProvider));
              await load();
            },
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (error != null)
                  MaterialBanner(
                    content: Text(error!),
                    actions: [
                      TextButton(
                          onPressed: load, child: const Text('Qayta urinish'))
                    ],
                  ),
                Expanded(
                  child: tab == 0
                      ? const ProductsScreen()
                      : tab == 2
                          ? const Center(
                              child:
                                  Text('Hisobotlar uchun internetga ulaning'))
                          : ListView.builder(
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                final product = products[index];
                                return ListTile(
                                  title:
                                      Text(product['name']?.toString() ?? ''),
                                  subtitle: Text(
                                    '${product['stock']} ${product['unit']} · ${product['sale_price']} UZS',
                                  ),
                                  trailing: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        cart[product['id']] =
                                            (cart[product['id']] ?? 0) + 1;
                                      });
                                    },
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                );
                              },
                            ),
                ),
                if (tab == 1)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: cart.isEmpty
                          ? null
                          : () async {
                              final queue = ref.read(queueProvider);
                              final scaffoldMessenger =
                                  ScaffoldMessenger.maybeOf(context);
                              await queue.enqueueSale(
                                {
                                  'items': cart.entries
                                      .map((entry) => {
                                            'product_id': entry.key,
                                            'quantity': entry.value,
                                          })
                                      .toList(),
                                  'cash': total.toStringAsFixed(2),
                                  'card': '0',
                                },
                                const Uuid().v4(),
                              );
                              if (!mounted) return;
                              cart.clear();
                              setState(() {});
                              scaffoldMessenger?.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Savdo qurilmada saqlandi. Sinxronlash talab etiladi.'),
                                ),
                              );
                            },
                      child: Text(
                          'Savdoni saqlash · ${total.toStringAsFixed(2)} UZS'),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Mahsulotlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Kassa',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment),
            label: 'Hisobot',
          ),
        ],
      ),
    );
  }
}

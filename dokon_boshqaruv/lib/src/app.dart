import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'offline.dart';
import 'screens/activate_account.dart';
import 'screens/admin_panel.dart';
import 'screens/change_password.dart';
import 'screens/home_screen.dart';

import '../features/products/providers/products_provider.dart'
    as products;

final appNavigatorKey = GlobalKey<NavigatorState>();

final apiProvider = Provider<Api>((ref) {
  final api = Api();

  api.onLogout = () {
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const Login(),
      ),
      (_) => false,
    );
  };

  ref.onDispose(() {
    api.onLogout = null;
  });

  return api;
});

final queueProvider = Provider<OfflineQueue>((ref) {
  final api = ref.watch(apiProvider);
  final owner = api.sessionKey;

  if (owner == null) {
    throw StateError(
      'Offline bazani ochish uchun akkauntga kirish kerak.',
    );
  }

  return OfflineQueue(
    dbName: 'dokon_queue_$owner.db',
    ownerKey: owner,
    currentOwner: () => api.sessionKey,
  );
});

void _resetAccountProviders(WidgetRef ref) {
  ref.invalidate(products.productsProvider);
  ref.invalidate(products.categoriesProvider);
  ref.invalidate(products.productProvider);
  ref.invalidate(products.productFiltersProvider);
  ref.invalidate(products.productsStaleProvider);
  ref.invalidate(queueProvider);
}

Widget _screenForProfile(Map<String, dynamic> profile) {
  final changePassword =
      profile['needs_password_change'] == true ||
      profile['force_password_change'] == true;

  if (changePassword) {
    return const ChangePassword(isFirstTime: true);
  }

  final isAdmin = profile['is_superadmin'] == true ||
      profile['superadmin'] == true;

  return isAdmin ? const AdminPanel() : const HomeScreen();
}

class DokonApp extends StatelessWidget {
  const DokonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Dokon Boshqaruv',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF126B63)),
        scaffoldBackgroundColor: const Color(0xFFF5F7F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white, foregroundColor: Color(0xFF152D3B),
          elevation: 0, centerTitle: false,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF152D3B)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDCE3E8))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDCE3E8))),
        ),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        )),
        outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        )),
        dividerTheme: const DividerThemeData(color: Color(0xFFE2E8ED), thickness: 1),
        navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white, elevation: 0),
      ),
      home: const Startup(),
    );
  }
}

class Startup extends ConsumerStatefulWidget {
  const Startup({super.key});

  @override
  ConsumerState<Startup> createState() => _StartupState();
}

class _StartupState extends ConsumerState<Startup> {
  late final Future<Map<String, dynamic>?> _startup;

  @override
  void initState() {
    super.initState();
    _startup = _restore();
  }

  Future<Map<String, dynamic>?> _restore() async {
    try {
      final api = ref.read(apiProvider);

      if (!await api.restore()) return null;

      final profile = await api.me();

      if (!mounted) return null;

      _resetAccountProviders(ref);
      return profile;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.connectionState !=
            ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Akkaunt tekshirilmoqda...'),
                ],
              ),
            ),
          );
        }

        final profile = snapshot.data;

        if (profile == null) {
          return const Login();
        }

        return _screenForProfile(profile);
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
  void dispose() {
    user.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (busy) return;

    if (user.text.trim().isEmpty || pass.text.isEmpty) {
      setState(() {
        error = 'Login va parolni kiriting.';
      });
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    try {
      final api = ref.read(apiProvider);

      await api.login(user.text, pass.text);
      final profile = await api.me();

      if (!mounted) return;

      _resetAccountProviders(ref);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => _screenForProfile(profile),
        ),
        (_) => false,
      );
    } on DioException catch (e) {
      if (!mounted) return;

      final status = e.response?.statusCode;

      setState(() {
        error = switch (status) {
          400 => 'Kiritilgan ma’lumotlarni tekshiring.',
          401 => 'Login yoki parol noto‘g‘ri.',
          403 => 'Akkauntga kirish cheklangan.',
          429 => 'Ko‘p urinish bo‘ldi. Biroz kuting.',
          null => 'Serverga ulanish yo‘q. Internetni tekshiring.',
          _ => 'Server xatosi: HTTP $status.',
        };
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        error = 'Kirish amalga oshmadi. Qayta urinib ko‘ring.';
      });
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.storefront,
                      size: 64,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Dokon Boshqaruv',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: user,
                      enabled: !busy,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.username,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Foydalanuvchi nomi',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: pass,
                      enabled: !busy,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [
                        AutofillHints.password,
                      ],
                      onSubmitted: (_) => _login(),
                      decoration: const InputDecoration(
                        labelText: 'Parol',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.red,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: busy ? null : _login,
                      child: Text(
                        busy ? 'Tekshirilmoqda...' : 'Kirish',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const ActivateAccount(),
                                ),
                              );
                            },
                      child: const Text(
                        'Hisobni aktivatsiya qilish',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Birinchi kirish uchun internet kerak. '
                      'Offline ishlash oldindan tasdiqlangan '
                      'akkaunt uchun mavjud.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Eski koddagi Home() chaqiruvlari bilan moslik.
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
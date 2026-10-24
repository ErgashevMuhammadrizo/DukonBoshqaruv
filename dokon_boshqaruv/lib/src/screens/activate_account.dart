
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';

class ActivateAccount extends ConsumerStatefulWidget {
  const ActivateAccount({super.key});

  @override
  ConsumerState<ActivateAccount> createState() =>
      _ActivateAccountState();
}

class _ActivateAccountState extends ConsumerState<ActivateAccount> {
  final codeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool busy = false;
  String? error;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.lock_open,
                  size: 64,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Hisobni aktivatsiya qilish',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Admin tomonidan berilgan kodni kiriting va parolingizni o‘rnating',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueGrey),
                ),
                const SizedBox(height: 32),

                // Aktivatsiya kodi
                TextField(
                  controller: codeController,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Aktivatsiya kodi',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.vpn_key),
                  ),
                ),
                const SizedBox(height: 16),

                // Yangi parol
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Yangi parol',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Parolni tasdiqlash
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Parolni tasdiqlang',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureConfirm = !obscureConfirm;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Parol talablari
                const Card(
                  color: Color(0xFFF3F4F6),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parol talablari:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text('• Kamida 10 ta belgi'),
                        Text(
                          '• Faqat raqamlardan iborat bo‘lmasligi kerak',
                        ),
                        Text('• Umumiy parollardan foydalanmang'),
                      ],
                    ),
                  ),
                ),

                // Xatolik xabari
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Card(
                      color: Colors.red[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Aktivatsiya tugmasi
                FilledButton(
                  onPressed: busy ? null : _activate,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    busy
                        ? 'Aktivatsiya qilinmoqda...'
                        : 'Hisobni aktivatsiya qilish',
                  ),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const Login(),
                            ),
                          );
                        },
                  child: const Text('Kirish sahifasiga qaytish'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _activate() async {
    if (busy) return;

    final code = codeController.text.trim();
    final password = passwordController.text;
    final confirmation = confirmPasswordController.text;

    // Mahalliy tekshiruvlar
    if (code.isEmpty) {
      setState(() => error = 'Aktivatsiya kodini kiriting');
      return;
    }

    if (password.isEmpty) {
      setState(() => error = 'Parolni kiriting');
      return;
    }

    if (password != confirmation) {
      setState(() => error = 'Parollar mos kelmadi');
      return;
    }

    if (password.length < 10) {
      setState(() {
        error = 'Parol kamida 10 ta belgidan iborat bo‘lishi kerak';
      });
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    try {
      final result = await ref.read(apiProvider).activateAccount(
            code,
            password,
          );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Muvaffaqiyatli!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                result['message']?.toString() ??
                    'Hisobingiz aktivatsiya qilindi',
              ),
              const SizedBox(height: 8),
              Text('Username: ${result['username'] ?? ''}'),
              const SizedBox(height: 16),
              const Text(
                'Endi username va yangi parolingiz bilan kirishingiz mumkin.',
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const Login(),
                  ),
                );
              },
              child: const Text('Kirish sahifasiga o‘tish'),
            ),
          ],
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;

      final data = e.response?.data;
      var message = 'Aktivatsiya amalga oshmadi.';

      if (data is Map) {
        final errorData = data['error'];

        if (errorData is Map && errorData['message'] != null) {
          message = errorData['message'].toString();
        } else if (data['detail'] != null) {
          message = data['detail'].toString();
        } else if (data['message'] != null) {
          message = data['message'].toString();
        } else {
          message = 'Server javobi: ${data.toString()}';
        }
      } else if (e.response == null) {
        message = 'Serverga ulanib bo‘lmadi. Internetni tekshiring.';
      } else if (data != null) {
        message = data.toString();
      } else {
        message = 'HTTP ${e.response?.statusCode}: server xatosi';
      }

      setState(() {
        error = 'Aktivatsiya xatosi: $message';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = 'Kutilmagan xatolik: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}

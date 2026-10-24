import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app.dart';

class ActivateAccount extends ConsumerStatefulWidget {
  const ActivateAccount({super.key});

  @override
  ConsumerState<ActivateAccount> createState() => _ActivateAccountState();
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
                const Icon(Icons.lock_open, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'Hisobni aktivatsiya qilish',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Admin tomonidan berilgan kodni kiriting va parolingizni o\'rnating',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueGrey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Aktivatsiya kodi',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.vpn_key),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
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
                        setState(() => obscurePassword = !obscurePassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
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
                        setState(() => obscureConfirm = !obscureConfirm);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Card(
                  color: Color(0xFFF3F4F6),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parol talablari:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text('• Kamida 10 ta belgi'),
                        Text('• Faqat raqamlardan iborat bo\'lmasligi kerak'),
                        Text('• Umumiy parollardan foydalanmang'),
                      ],
                    ),
                  ),
                ),
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
                FilledButton(
                  onPressed: busy ? null : _activate,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(busy
                      ? 'Aktivatsiya qilinmoqda...'
                      : 'Hisobni aktivatsiya qilish'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const Login()),
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
    setState(() {
      busy = true;
      error = null;
    });

    // Validation
    if (codeController.text.trim().isEmpty) {
      setState(() {
        error = 'Aktivatsiya kodini kiriting';
        busy = false;
      });
      return;
    }

    if (passwordController.text.isEmpty) {
      setState(() {
        error = 'Parolni kiriting';
        busy = false;
      });
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      setState(() {
        error = 'Parollar mos kelmadi';
        busy = false;
      });
      return;
    }

    if (passwordController.text.length < 10) {
      setState(() {
        error = 'Parol kamida 10 ta belgidan iborat bo\'lishi kerak';
        busy = false;
      });
      return;
    }

    try {
      final result = await ref.read(apiProvider).activateAccount(
            codeController.text.trim(),
            passwordController.text,
          );

      if (!mounted) return;

      // Show success dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Muvaffaqiyatli!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 16),
              Text(result['message'] ?? 'Hisobingiz aktivatsiya qilindi'),
              const SizedBox(height: 8),
              Text('Username: ${result['username']}'),
              const SizedBox(height: 16),
              const Text(
                  'Endi o\'zingizning username va parolingiz bilan kirishingiz mumkin'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const Login()),
                );
              },
              child: const Text('Kirish sahifasiga o\'tish'),
            ),
          ],
        ),
      );
} on DioException catch (e) {
  if (!mounted) return;

  final data = e.response?.data;
  String message = 'Aktivatsiya amalga oshmadi.';

  if (data is Map) {
    final errorData = data['error'];

    if (errorData is Map && errorData['message'] != null) {
      message = errorData['message'].toString();
    } else if (data['detail'] != null) {
      message = data['detail'].toString();
    } else if (data['message'] != null) {
      message = data['message'].toString();
    }
  } else if (e.response == null) {
    message = 'Serverga ulanib bo‘lmadi. Internet aloqasini tekshiring.';
  }

  setState(() {
    error = 'Aktivatsiya xatosi: $message';
    busy = false;
  });
} catch (e) {
  if (!mounted) return;

  setState(() {
    error = 'Kutilmagan xatolik: $e';
    busy = false;
  });
}

  @override
  void dispose() {
    codeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}

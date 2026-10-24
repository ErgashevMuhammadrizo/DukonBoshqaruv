import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app.dart';
import 'home_screen.dart';

class ChangePassword extends ConsumerStatefulWidget {
  final bool isFirstTime;

  const ChangePassword({super.key, this.isFirstTime = false});

  @override
  ConsumerState<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends ConsumerState<ChangePassword> {
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool busy = false;
  String? error;
  bool obscureOld = true;
  bool obscureNew = true;
  bool obscureConfirm = true;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isFirstTime,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isFirstTime
              ? 'Parolni yangilash'
              : 'Parolni o\'zgartirish'),
          automaticallyImplyLeading: !widget.isFirstTime,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    widget.isFirstTime ? Icons.security : Icons.password,
                    size: 64,
                    color: widget.isFirstTime ? Colors.orange : Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isFirstTime
                        ? 'Parolingizni yangilang'
                        : 'Parolni o\'zgartirish',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isFirstTime
                        ? 'Xavfsizlik uchun parolingizni o\'zgartirish shart'
                        : 'Xavfsizlik uchun parolingizni muntazam yangilang',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.blueGrey),
                  ),
                  if (widget.isFirstTime)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Card(
                        color: Colors.orange[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.orange[700]),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Bu birinchi kirish. Yangi parol o\'rnating.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: oldPasswordController,
                    obscureText: obscureOld,
                    decoration: InputDecoration(
                      labelText: 'Joriy parol',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOld ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => obscureOld = !obscureOld);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Yangi parol',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => obscureNew = !obscureNew);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Yangi parolni tasdiqlang',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_clock),
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
                          Text('• Eski paroldan farqli bo\'lishi kerak'),
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
                    onPressed: busy ? null : _changePassword,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(busy
                        ? 'O\'zgartirilmoqda...'
                        : 'Parolni o\'zgartirish'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: widget.isFirstTime
                        ? null
                        : () => Navigator.pop(context),
                    child: Text(widget.isFirstTime
                        ? 'Parol o\'zgartirish majburiy'
                        : 'Bekor qilish'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    setState(() {
      busy = true;
      error = null;
    });

    // Validation
    if (oldPasswordController.text.isEmpty) {
      setState(() {
        error = 'Joriy parolni kiriting';
        busy = false;
      });
      return;
    }

    if (newPasswordController.text.isEmpty) {
      setState(() {
        error = 'Yangi parolni kiriting';
        busy = false;
      });
      return;
    }

    if (newPasswordController.text != confirmPasswordController.text) {
      setState(() {
        error = 'Yangi parollar mos kelmadi';
        busy = false;
      });
      return;
    }

    if (newPasswordController.text.length < 10) {
      setState(() {
        error = 'Yangi parol kamida 10 ta belgidan iborat bo\'lishi kerak';
        busy = false;
      });
      return;
    }

    if (oldPasswordController.text == newPasswordController.text) {
      setState(() {
        error = 'Yangi parol eski paroldan farqli bo\'lishi kerak';
        busy = false;
      });
      return;
    }

    try {
      final result = await ref.read(apiProvider).changePassword(
            oldPasswordController.text,
            newPasswordController.text,
            confirmPasswordController.text,
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
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 16),
              Text(result['message'] ?? 'Parolingiz o\'zgartirildi'),
              const SizedBox(height: 16),
              Text(
                widget.isFirstTime
                    ? 'Endi tizimga kirish mumkin'
                    : 'Xavfsizlik uchun qayta kirish kerak bo\'ladi',
                textAlign: TextAlign.center,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                if (widget.isFirstTime) {
                  // For first-time change, go to Home screen directly
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  }
                } else {
                  // For regular password change, logout and go to login
                  await ref.read(apiProvider).logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const Login()),
                      (route) => false,
                    );
                  }
                }
              },
              child: Text(widget.isFirstTime
                  ? 'Davom etish'
                  : 'Kirish sahifasiga o\'tish'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Xatolik: ${e.toString()}';
        busy = false;
      });
    }
  }

  @override
  void dispose() {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}

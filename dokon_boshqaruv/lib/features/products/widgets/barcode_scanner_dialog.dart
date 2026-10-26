import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class BarcodeScannerDialog extends StatefulWidget {
  const BarcodeScannerDialog({super.key});

  @override
  State<BarcodeScannerDialog> createState() =>
      _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState
    extends State<BarcodeScannerDialog>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _completed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_ensureCameraReady());
  }

  Future<void> _ensureCameraReady() async {
    if (!mounted || _completed) return;

    try {
      final status = await Permission.camera.request();
      if (!mounted) return;

      if (status != PermissionStatus.granted &&
          status != PermissionStatus.limited) {
        return;
      }

      if (!_controller.value.isInitialized) {
        await _controller.start();
      }
    } catch (_) {
      // Kamera xatosi MobileScanner.errorBuilder orqali ko‘rsatiladi.
    }
  }

  Future<void> _startCamera() async {
    if (!mounted || _completed) return;

    try {
      final status = await Permission.camera.request();
      if (!mounted) return;
      if (status != PermissionStatus.granted &&
          status != PermissionStatus.limited) {
        return;
      }
      if (!_controller.value.isInitialized) {
        await _controller.start();
      }
    } catch (_) {
      // Kamera xatosi MobileScanner.errorBuilder orqali ko‘rsatiladi.
    }
  }

  Future<void> _stopCamera() async {
    try {
      await _controller.stop();
    } catch (_) {
      // Yopilayotgan kameraning xatosi oynani buzmasligi kerak.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_completed) return;

    if (state == AppLifecycleState.resumed) {
      unawaited(_startCamera());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_stopCamera());
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_completed || !mounted) return;

    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();

      if (code == null || code.isEmpty) continue;

      _completed = true;
      Navigator.of(context).pop(code);
      return;
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu kamerada chiroqni yoqib bo‘lmadi.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 500,
        height: screen.height * 0.75,
        child: Column(
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Shtrix-kodni skanerlash'),
              actions: [
                IconButton(
                  tooltip: 'Yopish',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error, child) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.no_photography_outlined,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Kamera ochilmadi. Telefon sozlamalarida '
                          'Dokon Boshqaruv uchun kamera ruxsatini '
                          'tekshiring.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Xato: ${error.errorCode.name}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () async {
                            await openAppSettings();
                          },
                          child: const Text('Sozlamalarni ochish'),
                        ),
                        TextButton(
                          onPressed: _startCamera,
                          child: const Text('Qayta urinish'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Mahsulotdagi shtrix-kodni kameraga ko‘rsating. '
                'Kod to‘liq ko‘rinsin va tasvir tiniqlashishini kuting.',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: 'Chiroq',
              onPressed: _toggleTorch,
              icon: const Icon(Icons.flash_on),
            ),
          ],
        ),
      ),
    );
  }
}
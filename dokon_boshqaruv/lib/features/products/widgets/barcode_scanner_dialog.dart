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
      final status = await Permission.camera.status;
      if (!mounted) return;

      if (status != PermissionStatus.granted &&
          status != PermissionStatus.limited) {
        final requested = await Permission.camera.request();
        if (!mounted) return;

        if (requested != PermissionStatus.granted &&
            requested != PermissionStatus.limited) {
          return;
        }
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
      final status = await Permission.camera.status;
      if (!mounted) return;

      if (status != PermissionStatus.granted &&
          status != PermissionStatus.limited) {
        final requested = await Permission.camera.request();
        if (!mounted) return;
        if (requested != PermissionStatus.granted &&
            requested != PermissionStatus.limited) {
          return;
        }
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
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.phonelink_lock_rounded,
                            size: 56,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Kamera ruxsati kerak',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Shtrix-kodni skanerlash uchun telefoningizning '
                            'sozlamalarida Dokon Boshqaruvga kamera ruxsatini '
                            'bering.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () async {
                              await openAppSettings();
                              if (!mounted) return;
                              await _startCamera();
                            },
                            icon: const Icon(Icons.settings_outlined),
                            label: const Text('Sozlamalarni ochish'),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _startCamera,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Qayta urinish'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Xato: ${error.errorCode.name}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
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
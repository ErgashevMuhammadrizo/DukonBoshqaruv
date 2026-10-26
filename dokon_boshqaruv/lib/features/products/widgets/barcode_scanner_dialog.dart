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
  final MobileScannerController _controller =
      MobileScannerController(
    autoStart: false,
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  Future<void> _jobs = Future<void>.value();

  bool _disposed = false;
  bool _completed = false;
  bool _active = true;
  bool _busy = true;
  bool _permissionDenied = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null ||
        state == AppLifecycleState.resumed;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _schedule(_startCamera);
      }
    });
  }

  // Start/stop bir vaqtning o‘zida bajarilmaydi.
  void _schedule(Future<void> Function() action) {
    _jobs = _jobs.then((_) async {
      if (_disposed || _completed) return;

      try {
        await action();
      } catch (error) {
        _showError(error.toString());
      }
    });
  }

  void _showError(String message) {
    if (!mounted || _disposed || _completed) return;

    setState(() {
      _busy = false;
      _error = message;
    });
  }

  Future<void> _startCamera() async {
    if (!_active || _disposed || _completed) return;

    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
        _permissionDenied = false;
      });
    }

    var permission = await Permission.camera.status;

    if (permission.isDenied) {
      permission = await Permission.camera.request();
    }

    if (_disposed || _completed || !mounted) return;

    if (!permission.isGranted) {
      setState(() {
        _busy = false;
        _permissionDenied = true;
      });
      return;
    }

    // Ruxsat oynasi ilovani vaqtincha inactive qilishi mumkin.
    if (!_active) {
      setState(() => _busy = false);
      return;
    }

    try {
      // Oldingi kamera sessiyasi ochiq qolgan bo‘lsa to‘xtatamiz.
      if (_controller.value.isInitialized) {
        await _controller.stop();
      }

      if (_disposed || _completed || !_active) return;

      await _controller.start();

      if (!mounted || _disposed || _completed) return;

      setState(() {
        _busy = false;
        _error = null;
        _permissionDenied = false;
      });
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _stopCamera() async {
    try {
      if (_controller.value.isInitialized) {
        await _controller.stop();
      }
    } catch (_) {
      // Kamera allaqachon yopilgan bo‘lishi mumkin.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;

    if (_disposed || _completed) return;

    if (_active) {
      _schedule(_startCamera);
    } else {
      _schedule(_stopCamera);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_disposed || _completed || !mounted) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();

      if (value == null || value.isEmpty) continue;

      _completed = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  void _toggleTorch() {
    _schedule(() async {
      if (!_controller.value.isInitialized) return;

      try {
        await _controller.toggleTorch();
      } catch (_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kamera chirog‘ini yoqib bo‘lmadi.'),
          ),
        );
      }
    });
  }

  Future<void> _disposeCamera() async {
    await _jobs;

    try {
      await _controller.dispose();
    } catch (_) {
      // Ekran yopilganidan keyin UI yangilanmaydi.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeCamera());
    super.dispose();
  }

  Widget _errorPanel(
    String message, {
    required bool permissionProblem,
  }) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                permissionProblem
                    ? Icons.no_photography_outlined
                    : Icons.camera_alt_outlined,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                permissionProblem
                    ? 'Kamera ruxsati berilmagan'
                    : 'Kamerani ishga tushirib bo‘lmadi',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                permissionProblem
                    ? 'Telefon sozlamalarida ushbu ilova '
                        'uchun kamera ruxsatini yoqing.'
                    : 'Boshqa kamera ilovalarini yoping. '
                        'Telefonning umumiy kamera maxfiylik '
                        'tugmasi o‘chirilmaganini tekshiring.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SelectableText(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _schedule(_startCamera),
                icon: const Icon(Icons.refresh),
                label: const Text('Qayta urinish'),
              ),
              if (permissionProblem)
                TextButton(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  child: const Text('Sozlamalarni ochish'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 500,
        height: size.height * 0.8,
        child: Column(
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Shtrix-kodni skanerlash'),
              actions: [
                IconButton(
                  onPressed: () =>
                      Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    errorBuilder: (context, error, child) {
                      return _errorPanel(
                        error.toString(),
                        permissionProblem: false,
                      );
                    },
                  ),
                  if (_permissionDenied)
                    _errorPanel(
                      'Android kamera ruxsatini bermadi.',
                      permissionProblem: true,
                    )
                  else if (_error != null)
                    _errorPanel(
                      _error!,
                      permissionProblem: false,
                    )
                  else if (_busy)
                    const ColoredBox(
                      color: Colors.black87,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Mahsulot shtrix-kodini kameraga ko‘rsating. '
                'Kod to‘liq ko‘rinsin.',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              onPressed: _busy ||
                      _permissionDenied ||
                      _error != null
                  ? null
                  : _toggleTorch,
              tooltip: 'Chiroq',
              icon: const Icon(Icons.flash_on),
            ),
          ],
        ),
      ),
    );
  }
}
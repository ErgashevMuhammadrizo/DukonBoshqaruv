import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../src/diagnostics/app_diagnostics.dart';
import '../../../src/diagnostics/camera_session.dart';
import '../../../src/diagnostics/diagnostics_view.dart';

class BarcodeScannerDialog extends StatefulWidget {
  const BarcodeScannerDialog({super.key});

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _PermissionFailure implements Exception {
  const _PermissionFailure(this.status);
  final String status;
  @override
  String toString() => 'Camera permission: $status';
}

class _CameraPort implements CameraSessionPort {
  _CameraPort({
    required this.running,
    required this.startCamera,
    required this.stopCamera,
    required this.disposeCamera,
  });
  final bool Function() running;
  final Future<void> Function() startCamera, stopCamera, disposeCamera;
  @override
  bool get isRunning => running();
  @override
  Future<void> start() => startCamera();
  @override
  Future<void> stop() => stopCamera();
  @override
  Future<void> dispose() => disposeCamera();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog>
    with WidgetsBindingObserver {
  static const _native = MethodChannel('dokon_boshqaruv/camera_diagnostics');
  final _diagnostics = AppDiagnostics.instance;
  final _controller = MobileScannerController(
    autoStart: false,
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.normal,
    cameraResolution: const Size(1280, 720),
    returnImage: false,
  );
  late final CameraSession _session;
  bool _busy = true;
  bool _closing = false;
  bool _disposed = false;
  bool _permissionDenied = false;
  bool _slow = false;
  String? _lastError;
  String? _lastState;
  CameraFacing _facing = CameraFacing.back;
  Timer? _watchdog;

  @override
  void initState() {
    super.initState();
    _diagnostics.record('scanner.open', message: 'Camera diagnostic patch v1');
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onState);
    _session = CameraSession(
      _CameraPort(
        running: () => _controller.value.isRunning,
        startCamera: _start,
        stopCamera: _stop,
        disposeCamera: () async {
          _diagnostics.record('camera.dispose.begin');
          await _controller.dispose();
          _diagnostics.record('camera.dispose.complete');
        },
      ),
      onError: _onFailure,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _closing) return;
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == null || state == AppLifecycleState.resumed) {
        unawaited(_session.resume());
      } else {
        _busy = false;
        _update();
      }
    });
  }

  void _update() {
    if (!mounted || _disposed) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_disposed) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  void _recordScannerError(MobileScannerException error) {
    _diagnostics.record(
      'camera.plugin.error',
      error: error,
      details: {
        'scanner_code': error.errorCode.name,
        'native_code': error.errorDetails?.code,
        'native_message': error.errorDetails?.message,
        'native_details': error.errorDetails?.details,
      },
    );
  }

  void _onState() {
    if (_disposed || _closing) return;
    final state = _controller.value;
    final fingerprint = '${state.isInitialized}/${state.isRunning}/'
        '${state.isStarting}/${state.error}';
    if (fingerprint == _lastState) return;
    _lastState = fingerprint;
    _diagnostics.record(
      'camera.controller.state',
      details: {
        'initialized': state.isInitialized,
        'running': state.isRunning,
        'starting': state.isStarting,
        'facing': state.cameraDirection.name,
        'preview_size': state.size,
      },
    );
    if (state.error != null) {
      _recordScannerError(state.error!);
      _lastError = state.error.toString();
    }
    _update();
  }

  Future<void> _probe() async {
    try {
      final result = await _native
          .invokeMapMethod<String, dynamic>('probe')
          .timeout(const Duration(seconds: 4));
      _diagnostics.record('android.camera2.probe', details: result);
    } catch (error, stack) {
      _diagnostics.record(
        'android.camera2.probe.error',
        error: error,
        stack: stack,
      );
      // Probe failure must not prevent the actual scanner from being tried.
    }
  }

  Future<void> _openReport() async {
    _diagnostics.record('diagnostics.request');
    await _probe();
    try {
      const scannerChannel = MethodChannel(
        'dev.steenbakker.mobile_scanner/scanner/method',
      );
      final stats = await scannerChannel
          .invokeMapMethod<String, dynamic>('diagnostics')
          .timeout(const Duration(seconds: 3));
      _diagnostics.record('android.analysis.counters', details: stats);
    } catch (error, stack) {
      _diagnostics.record('android.analysis.counters.error',
          error: error, stack: stack);
    }
    if (mounted) await showDiagnosticsDialog(context);
  }

  Future<void> _start() async {
    if (_closing || _disposed || !_session.wantsRunning) return;
    _busy = true;
    _slow = false;
    _lastError = null;
    _permissionDenied = false;
    _update();
    try {
      _diagnostics.record('permission.check');
      var permission = await Permission.camera.status;
      _diagnostics.record('permission.status', message: permission.name);
      if (permission.isDenied) {
        _diagnostics.record('permission.request');
        permission = await Permission.camera.request();
        _diagnostics.record('permission.result', message: permission.name);
      }
      if (!permission.isGranted) throw _PermissionFailure(permission.name);
      if (_closing || _disposed || !_session.wantsRunning) return;
      await _probe();
      if (_closing || _disposed || !_session.wantsRunning) return;
      _diagnostics.record(
        'camera.start.begin',
        details: {'requested_facing': _facing.name},
      );
      _watchdog?.cancel();
      _watchdog = Timer(const Duration(seconds: 12), () {
        _diagnostics.record(
          'camera.start.pending',
          message:
              'Native start has not replied after 12 seconds; no parallel retry was started.',
        );
        _slow = true;
        _update();
      });
      await _controller.start(cameraDirection: _facing);
      // start() stores many native errors in controller.value, rather than throwing.
      verifyCameraStarted(
        running: _controller.value.isRunning,
        error: _controller.value.error,
      );
      _diagnostics.record('camera.start.complete');
      _lastError = null;
    } finally {
      _watchdog?.cancel();
      _busy = false;
      _update();
    }
  }

  Future<void> _stop() async {
    _diagnostics.record('camera.stop.begin');
    await _controller.stop();
    _diagnostics.record('camera.stop.complete');
  }

  void _onFailure(Object error, StackTrace stack) {
    _diagnostics.record('camera.session.error', error: error, stack: stack);
    if (error is MobileScannerException) _recordScannerError(error);
    _permissionDenied = error is _PermissionFailure ||
        (error is MobileScannerException &&
            error.errorCode == MobileScannerErrorCode.permissionDenied);
    _lastError = error.toString();
    _busy = false;
    _update();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _diagnostics.record('lifecycle', message: state.name);
    if (_closing || _disposed) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_session.resume());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_session.pause());
    }
  }

  Future<void> _finish([String? code]) async {
    if (_closing || !mounted) return;
    _closing = true;
    _update();
    _diagnostics.record(
      'scanner.close.begin',
      message: code == null ? 'cancel' : 'barcode detected; value omitted',
    );
    final timer = Timer(const Duration(seconds: 12), () {
      _diagnostics.record(
        'camera.close.pending',
        message: 'Waiting for the pending native operation.',
      );
      _slow = true;
      _update();
    });
    await _session.close();
    timer.cancel();
    if (mounted) Navigator.of(context).pop(code);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_closing || _disposed || !mounted) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        // Do not write barcode contents or images to diagnostics.
        unawaited(_finish(code));
        return;
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_busy || _closing) return;
    await _session.pause();
    if (_closing || !mounted) return;
    _facing =
        _facing == CameraFacing.back ? CameraFacing.front : CameraFacing.back;
    _diagnostics.record('camera.switch', message: _facing.name);
    await _session.resume();
  }

  @override
  void dispose() {
    _disposed = true;
    _watchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onState);
    unawaited(_session.close());
    super.dispose();
  }

  Widget _failure(String message) => ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _permissionDenied
                      ? Icons.no_photography_outlined
                      : Icons.camera_alt_outlined,
                  size: 48,
                  color: Colors.orange,
                ),
                const SizedBox(height: 12),
                Text(
                  _permissionDenied
                      ? 'Kamera ruxsati berilmagan'
                      : 'Kamera ochilishida xato',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SelectableText(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const Text(
                  'Hisobotda xatoning bosqichi va Android qaytargan asl sabab ko‘rsatiladi.',
                  textAlign: TextAlign.center,
                ),
                FilledButton.icon(
                  onPressed: _busy || _closing ? null : () => _session.retry(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Qayta urinish'),
                ),
                if (_permissionDenied)
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

  @override
  Widget build(BuildContext context) {
    final stateError = _controller.value.error;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_finish());
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(12),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 520,
          height: MediaQuery.sizeOf(context).height * .85,
          child: Column(
            children: [
              AppBar(
                automaticallyImplyLeading: false,
                title: const Text('Shtrix-kod'),
                actions: [
                  IconButton(
                    tooltip: 'Yopish',
                    onPressed: _closing ? null : () => _finish(),
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
                      tapToFocus: true,
                      useAppLifecycleState: false,
                      onDetectError: (error, stack) {
                        _diagnostics.record(
                          'barcode.analysis.error',
                          error: error,
                          stack: stack,
                        );
                        _onFailure(error, stack);
                      },
                      errorBuilder: (context, error) =>
                          _failure(error.toString()),
                    ),
                    if (_lastError != null || stateError != null)
                      _failure(_lastError ?? stateError.toString()),
                    if (_busy || _closing)
                      ColoredBox(
                        color: Colors.black87,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                _slow
                                    ? 'Android javobi kutilmoqda. Hisobotni ochishingiz mumkin.'
                                    : (_closing
                                        ? 'Kamera yopilmoqda...'
                                        : 'Kamera ochilmoqda...'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'Kodni kameraga ko‘rsating. Fokus uchun tasvirga teging.',
                  textAlign: TextAlign.center,
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Chiroq',
                    onPressed: _busy || _closing
                        ? null
                        : () => _session.action(_controller.toggleTorch),
                    icon: const Icon(Icons.flash_on),
                  ),
                  TextButton.icon(
                    onPressed: _busy || _closing ? null : _switchCamera,
                    icon: const Icon(Icons.cameraswitch),
                    label: const Text('Boshqa kamera'),
                  ),
                  TextButton.icon(
                    onPressed: _openReport,
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('Xato hisoboti'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

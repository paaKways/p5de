import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:p5de/app/telemetry/app_telemetry.dart';
import 'package:p5de/contexts/runtime_preview/domain/runtime_console_entry.dart';
import 'package:p5de/contexts/runtime_preview/domain/runtime_physical_viewport.dart';
import 'package:p5de/contexts/runtime_preview/presentation/fullscreen_runtime_preview_view.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';

class FullscreenRuntimePreviewPage extends StatefulWidget {
  const FullscreenRuntimePreviewPage({
    required this.sketch,
    required this.initialCode,
    this.telemetry = const NoopAppTelemetry(),
    super.key,
  });

  final Sketch sketch;
  final String initialCode;
  final AppTelemetry telemetry;

  @override
  State<FullscreenRuntimePreviewPage> createState() =>
      _FullscreenRuntimePreviewPageState();
}

class _FullscreenRuntimePreviewPageState
    extends State<FullscreenRuntimePreviewPage> {
  final GlobalKey<FullscreenRuntimePreviewViewState> _runtimeKey =
      GlobalKey<FullscreenRuntimePreviewViewState>();

  bool _hasAutoRun = false;
  bool _hasFirstFrame = false;
  bool _isClosing = false;
  bool _canPopAfterRuntimeStop = false;
  Timer? _runtimeWatchdogTimer;
  Stopwatch? _runStopwatch;
  String? _lastErrorMessage;

  static const _runtimeWatchdogTimeout = Duration(seconds: 60);

  bool get _supportsProcessingJava =>
      widget.sketch.language == SketchLanguage.processingJava;

  @override
  void initState() {
    super.initState();
    unawaited(widget.telemetry.setCurrentScreen('runtime_preview_fullscreen'));
    unawaited(
      widget.telemetry.setCustomKey('current_sketch_id', widget.sketch.id),
    );
    unawaited(
      widget.telemetry.setCustomKey(
        'current_language',
        widget.sketch.language.storageValue,
      ),
    );
    unawaited(
      widget.telemetry.setCustomKey(
        'runtime_preview_implementation',
        'fullscreen_physical',
      ),
    );
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
  }

  @override
  void dispose() {
    _runtimeWatchdogTimer?.cancel();
    unawaited(SystemChrome.setPreferredOrientations(const []));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  void _handleRuntimeReady() {
    if (_hasAutoRun) {
      return;
    }
    _hasAutoRun = true;
    unawaited(_runCurrentCode());
  }

  Future<void> _runCurrentCode() async {
    if (!_supportsProcessingJava) {
      await _closePreview(
        'Processing Java runtime is required for full-screen preview.',
      );
      return;
    }

    _runStopwatch = Stopwatch()..start();
    _startRuntimeWatchdog();
    unawaited(widget.telemetry.setCustomKey('runtime_status', 'starting'));
    unawaited(
      widget.telemetry.logEvent(
        'runtime_run',
        parameters: {
          'trigger': 'fullscreen_physical_auto',
          'sketch_id': widget.sketch.id,
          'language': widget.sketch.language.storageValue,
          'code_length': widget.initialCode.length,
        },
      ),
    );

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _isClosing) {
      return;
    }

    await _runtimeKey.currentState?.runProcessingJava(
      widget.initialCode,
      viewport: _physicalViewport(),
    );
  }

  RuntimePhysicalViewport _physicalViewport() {
    final view = View.of(context);
    final physicalSize = view.physicalSize;
    final devicePixelRatio = view.devicePixelRatio;
    return RuntimePhysicalViewport(
      width: math.max(1, physicalSize.width.round()),
      height: math.max(1, physicalSize.height.round()),
      devicePixelRatio: devicePixelRatio,
    );
  }

  void _startRuntimeWatchdog() {
    _runtimeWatchdogTimer?.cancel();
    _runtimeWatchdogTimer = Timer(_runtimeWatchdogTimeout, () {
      if (!mounted || _isClosing || _hasFirstFrame) {
        return;
      }
      const message =
          'Processing Java runtime did not reach first frame within 60 seconds.';
      unawaited(widget.telemetry.setCustomKey('runtime_status', 'watchdog'));
      unawaited(
        widget.telemetry.logEvent(
          'runtime_watchdog_timeout',
          parameters: {'sketch_id': widget.sketch.id},
        ),
      );
      unawaited(_closePreview(message));
    });
  }

  void _cancelRuntimeWatchdog() {
    _runtimeWatchdogTimer?.cancel();
    _runtimeWatchdogTimer = null;
  }

  void _handleRuntimeStatusChanged(String status) {
    if (_isClosing) {
      return;
    }
    unawaited(widget.telemetry.setCustomKey('runtime_status', status));
    if (status == 'running') {
      _cancelRuntimeWatchdog();
      return;
    }
    if (status == 'failure') {
      unawaited(
        _closePreview(_lastErrorMessage ?? 'Processing Java runtime failed.'),
      );
    }
  }

  void _handleRuntimeFirstFrame() {
    if (_isClosing) {
      return;
    }
    _cancelRuntimeWatchdog();
    _hasFirstFrame = true;
    final elapsedMs = _runStopwatch?.elapsedMilliseconds;
    _runStopwatch?.stop();
    _runStopwatch = null;
    final parameters = <String, Object?>{'sketch_id': widget.sketch.id};
    if (elapsedMs != null) {
      parameters['elapsed_ms'] = elapsedMs;
    }
    unawaited(widget.telemetry.setCustomKey('runtime_status', 'running'));
    unawaited(
      widget.telemetry.logEvent('runtime_first_frame', parameters: parameters),
    );
  }

  void _handleRuntimeError(Map<String, Object?> payload) {
    if (_isClosing) {
      return;
    }
    final message = _messageFromRuntimeError(payload);
    _lastErrorMessage = message;
    unawaited(widget.telemetry.setCustomKey('runtime_status', 'failure'));
    unawaited(
      widget.telemetry.logEvent(
        'runtime_error',
        parameters: {'sketch_id': widget.sketch.id},
      ),
    );
    unawaited(_closePreview(message));
  }

  String _messageFromRuntimeError(Map<String, Object?> payload) {
    final diagnostics = _diagnosticsFromPayload(payload['diagnostics']);
    if (diagnostics.isNotEmpty) {
      return diagnostics
          .map((diagnostic) {
            return '${diagnostic.displayLocation} - ${diagnostic.message}';
          })
          .join('\n');
    }

    final message =
        (payload['message'] as String?) ??
        (payload['log'] as String?) ??
        'Processing Java runtime error.';
    return _stripPhaseLog(message).trim().isEmpty
        ? 'Processing Java runtime error.'
        : _stripPhaseLog(message);
  }

  List<RuntimeDiagnostic> _diagnosticsFromPayload(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map((item) => RuntimeDiagnostic.fromPayload(item.cast()))
        .toList(growable: false);
  }

  String _stripPhaseLog(String message) {
    return message
        .replaceAll(
          RegExp(r'(^|\n)Phase log:\n(?:- .*(?:\n|$))+', multiLine: true),
          '\n',
        )
        .trim();
  }

  Future<void> _closePreview([String? result]) async {
    if (_isClosing) {
      return;
    }
    _isClosing = true;
    _cancelRuntimeWatchdog();
    try {
      await (_runtimeKey.currentState?.stop() ?? Future<void>.value()).timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {
      // Route closure should continue even if the WebView is already gone.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _canPopAfterRuntimeStop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<String?>(
      canPop: _canPopAfterRuntimeStop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(_closePreview());
      },
      child: ColoredBox(
        color: const Color(0xFF0F172A),
        child: SizedBox.expand(
          child: FullscreenRuntimePreviewView(
            key: _runtimeKey,
            onReady: _handleRuntimeReady,
            onStatusChanged: _handleRuntimeStatusChanged,
            onLog: (_, _) {},
            onError: _handleRuntimeError,
            onFirstFrame: _handleRuntimeFirstFrame,
          ),
        ),
      ),
    );
  }
}

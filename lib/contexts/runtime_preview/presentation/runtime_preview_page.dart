import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:p5de/app/telemetry/app_telemetry.dart';
import 'package:p5de/contexts/runtime_preview/domain/runtime_console_entry.dart';
import 'package:p5de/contexts/runtime_preview/presentation/runtime_preview_bloc.dart';
import 'package:p5de/contexts/runtime_preview/presentation/runtime_preview_view.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';

class RuntimePreviewPage extends StatefulWidget {
  const RuntimePreviewPage({
    required this.sketch,
    required this.initialCode,
    this.telemetry = const NoopAppTelemetry(),
    super.key,
  });

  final Sketch sketch;
  final String initialCode;
  final AppTelemetry telemetry;

  @override
  State<RuntimePreviewPage> createState() => _RuntimePreviewPageState();
}

class _RuntimePreviewPageState extends State<RuntimePreviewPage> {
  final GlobalKey<RuntimePreviewViewState> _runtimeKey =
      GlobalKey<RuntimePreviewViewState>();
  late final RuntimePreviewBloc _bloc;
  bool _hasAutoRun = false;
  bool _isConsoleExpanded = false;
  bool _isClosing = false;
  bool _canPopAfterRuntimeStop = false;
  bool _watchdogTimedOut = false;
  Stopwatch? _runStopwatch;
  Timer? _runtimeWatchdogTimer;

  static const _runtimeWatchdogTimeout = Duration(seconds: 60);

  bool get _supportsProcessingJava =>
      widget.sketch.language == SketchLanguage.processingJava;

  @override
  void initState() {
    super.initState();
    _bloc = RuntimePreviewBloc();
    unawaited(widget.telemetry.setCurrentScreen('runtime_preview'));
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
    _bloc.close();
    super.dispose();
  }

  Future<void> _runCurrentCode({String trigger = 'run'}) async {
    if (!_supportsProcessingJava) {
      return;
    }
    _runStopwatch = Stopwatch()..start();
    unawaited(widget.telemetry.setCustomKey('runtime_status', 'starting'));
    unawaited(
      widget.telemetry.logEvent(
        'runtime_run',
        parameters: {
          'trigger': trigger,
          'sketch_id': widget.sketch.id,
          'language': widget.sketch.language.storageValue,
          'code_length': widget.initialCode.length,
        },
      ),
    );
    _startRuntimeWatchdog();
    _bloc.add(const RuntimePreviewRunStarted());
    await _runtimeKey.currentState?.runProcessingJava(widget.initialCode);
  }

  Future<void> _stopRuntime() async {
    _cancelRuntimeWatchdog();
    _watchdogTimedOut = false;
    await _runtimeKey.currentState?.stop();
    unawaited(widget.telemetry.setCustomKey('runtime_status', 'stopped'));
    unawaited(
      widget.telemetry.logEvent(
        'runtime_stop',
        parameters: {'sketch_id': widget.sketch.id},
      ),
    );
    _bloc.add(const RuntimePreviewStopped());
  }

  Future<void> _restartRuntime() async {
    unawaited(
      widget.telemetry.logEvent(
        'runtime_restart',
        parameters: {'sketch_id': widget.sketch.id},
      ),
    );
    await _runCurrentCode(trigger: 'restart');
  }

  Future<void> _shutdownRuntimeForExit() async {
    _cancelRuntimeWatchdog();
    if (!_supportsProcessingJava) {
      return;
    }
    try {
      await (_runtimeKey.currentState?.stop() ?? Future<void>.value()).timeout(
        const Duration(seconds: 2),
      );
      unawaited(
        widget.telemetry.logEvent(
          'runtime_stop',
          parameters: {'trigger': 'route_exit', 'sketch_id': widget.sketch.id},
        ),
      );
      unawaited(widget.telemetry.setCustomKey('runtime_status', 'stopped'));
    } catch (_) {
      // The route is closing either way; a missing or already-disposed WebView
      // should not trap the user on the preview screen.
    }
    if (mounted) {
      _bloc.add(const RuntimePreviewStopped());
    }
  }

  Future<void> _closePreview() async {
    if (_isClosing) {
      return;
    }
    _isClosing = true;
    await _shutdownRuntimeForExit();
    if (!mounted) {
      return;
    }
    setState(() {
      _canPopAfterRuntimeStop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  void _handleRuntimeReady() {
    if (_hasAutoRun) {
      return;
    }
    _hasAutoRun = true;
    _runCurrentCode(trigger: 'auto');
  }

  void _startRuntimeWatchdog() {
    _runtimeWatchdogTimer?.cancel();
    _watchdogTimedOut = false;
    _runtimeWatchdogTimer = Timer(_runtimeWatchdogTimeout, () {
      if (!mounted) {
        return;
      }
      _watchdogTimedOut = true;
      setState(() {
        _isConsoleExpanded = true;
      });
      unawaited(_stopRuntimeAfterWatchdog());
    });
  }

  void _cancelRuntimeWatchdog() {
    _runtimeWatchdogTimer?.cancel();
    _runtimeWatchdogTimer = null;
  }

  Future<void> _stopRuntimeAfterWatchdog() async {
    try {
      await _runtimeKey.currentState?.stop();
    } catch (_) {
      // The watchdog recovery path should still surface a failure if the
      // WebView controller is already unavailable.
    }
    if (mounted) {
      unawaited(widget.telemetry.setCustomKey('runtime_status', 'watchdog'));
      unawaited(
        widget.telemetry.logEvent(
          'runtime_watchdog_timeout',
          parameters: {'sketch_id': widget.sketch.id},
        ),
      );
      unawaited(
        widget.telemetry.recordError(
          StateError('Processing Java runtime watchdog timed out.'),
          StackTrace.current,
          reason: 'runtime_watchdog_timeout',
          parameters: {'sketch_id': widget.sketch.id},
        ),
      );
      _bloc.add(const RuntimePreviewWatchdogTimedOut());
    }
  }

  void _handleRuntimeStatusChanged(String status) {
    if (_watchdogTimedOut && status == 'stopped') {
      return;
    }
    if (status == 'running' || status == 'stopped' || status == 'failure') {
      _cancelRuntimeWatchdog();
    }
    unawaited(widget.telemetry.setCustomKey('runtime_status', status));
    _bloc.add(RuntimePreviewStatusChanged(status));
  }

  void _handleRuntimeFirstFrame() {
    _cancelRuntimeWatchdog();
    _watchdogTimedOut = false;
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
    _bloc.add(const RuntimePreviewFirstFrameReceived());
  }

  void _handleRuntimeError(Map<String, Object?> payload) {
    _cancelRuntimeWatchdog();
    _watchdogTimedOut = false;
    final diagnostics = _diagnosticsFromPayload(payload['diagnostics']);
    final message =
        (payload['message'] as String?) ??
        (payload['log'] as String?) ??
        'Processing Java runtime error.';
    if (!_isConsoleExpanded && mounted) {
      setState(() {
        _isConsoleExpanded = true;
      });
    }
    unawaited(widget.telemetry.setCustomKey('runtime_status', 'failure'));
    unawaited(
      widget.telemetry.logEvent(
        'runtime_error',
        parameters: {
          'sketch_id': widget.sketch.id,
          'diagnostic_count': diagnostics.length,
        },
      ),
    );
    unawaited(
      widget.telemetry.recordError(
        StateError(message),
        StackTrace.current,
        reason: 'runtime_error',
        parameters: {
          'sketch_id': widget.sketch.id,
          'diagnostic_count': diagnostics.length,
        },
      ),
    );
    _bloc.add(
      RuntimePreviewErrorReceived(
        message: message,
        stack: payload['stack'] as String?,
        diagnostics: diagnostics,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: PopScope<void>(
        canPop: _canPopAfterRuntimeStop,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            return;
          }
          unawaited(_closePreview());
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F6F8),
          body: Column(
            children: [
              BlocBuilder<RuntimePreviewBloc, RuntimePreviewState>(
                builder: (context, state) => _RuntimeControlBar(
                  status: _supportsProcessingJava
                      ? state.status
                      : RuntimePreviewStatus.failure,
                  onBack: () => unawaited(_closePreview()),
                  onRestart: _supportsProcessingJava
                      ? () => unawaited(_restartRuntime())
                      : null,
                  onStop: _supportsProcessingJava ? _stopRuntime : null,
                ),
              ),
              Expanded(
                child: _supportsProcessingJava
                    ? RuntimePreviewView(
                        key: _runtimeKey,
                        onReady: _handleRuntimeReady,
                        onStatusChanged: _handleRuntimeStatusChanged,
                        onLog: (level, message) => _bloc.add(
                          RuntimePreviewLogReceived(
                            level: level,
                            message: message,
                          ),
                        ),
                        onError: _handleRuntimeError,
                        onFirstFrame: _handleRuntimeFirstFrame,
                      )
                    : const _UnsupportedRuntime(),
              ),
              BlocBuilder<RuntimePreviewBloc, RuntimePreviewState>(
                builder: (context, state) => _RuntimeConsole(
                  expanded: _isConsoleExpanded,
                  onToggle: () {
                    setState(() {
                      _isConsoleExpanded = !_isConsoleExpanded;
                    });
                  },
                  entries: _supportsProcessingJava
                      ? state.consoleEntries
                      : const [
                          RuntimeConsoleEntry(
                            level: RuntimeConsoleLevel.error,
                            message:
                                'Only Processing Java is wired to the bundled TeaVM runtime in this slice.',
                          ),
                        ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuntimeControlBar extends StatelessWidget {
  const _RuntimeControlBar({
    required this.status,
    required this.onBack,
    required this.onRestart,
    required this.onStop,
  });

  final RuntimePreviewStatus status;
  final VoidCallback onBack;
  final VoidCallback? onRestart;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Material(
      color: Colors.white,
      child: Container(
        height: 44,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            _RuntimeBarButton(
              tooltip: 'Back',
              icon: Icons.arrow_back,
              onPressed: onBack,
            ),
            const SizedBox(width: 4),
            Icon(Icons.circle, size: 9, color: color),
            const SizedBox(width: 8),
            Text(
              _statusLabel(status),
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            _RuntimeBarButton(
              tooltip: 'Restart',
              icon: Icons.replay,
              onPressed: onRestart,
            ),
            _RuntimeBarButton(
              tooltip: 'Stop',
              icon: Icons.stop,
              onPressed: onStop,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  String _statusLabel(RuntimePreviewStatus status) {
    return switch (status) {
      RuntimePreviewStatus.idle => 'Idle',
      RuntimePreviewStatus.starting => 'Starting',
      RuntimePreviewStatus.compiling => 'Compiling',
      RuntimePreviewStatus.loading => 'Loading',
      RuntimePreviewStatus.running => 'Running',
      RuntimePreviewStatus.stopped => 'Stopped',
      RuntimePreviewStatus.failure => 'Error',
    };
  }

  Color _statusColor(RuntimePreviewStatus status) {
    return switch (status) {
      RuntimePreviewStatus.running => const Color(0xFF166534),
      RuntimePreviewStatus.failure => const Color(0xFFB91C1C),
      RuntimePreviewStatus.stopped => const Color(0xFF475569),
      RuntimePreviewStatus.idle => const Color(0xFF475569),
      _ => const Color(0xFFB45309),
    };
  }
}

class _RuntimeBarButton extends StatelessWidget {
  const _RuntimeBarButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 21),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
    );
  }
}

class _RuntimeConsole extends StatelessWidget {
  const _RuntimeConsole({
    required this.entries,
    required this.expanded,
    required this.onToggle,
  });

  final List<RuntimeConsoleEntry> entries;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: expanded ? 190 : 48,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
                child: Row(
                  children: [
                    const Text(
                      'Console',
                      style: TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entries.isEmpty ? 'No output' : '${entries.length}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: const Color(0xFFCBD5E1),
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Expanded(
                child: entries.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: Text(
                          'No runtime output.',
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              entry.message,
                              style: TextStyle(
                                color: _entryColor(entry.level),
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Color _entryColor(RuntimeConsoleLevel level) {
    return switch (level) {
      RuntimeConsoleLevel.error => const Color(0xFFFCA5A5),
      RuntimeConsoleLevel.warning => const Color(0xFFFDE68A),
      RuntimeConsoleLevel.info => const Color(0xFFCBD5E1),
    };
  }
}

class _UnsupportedRuntime extends StatelessWidget {
  const _UnsupportedRuntime();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0F172A),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Processing Java runtime is available. p5.js runtime execution is on hold indefinitely.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

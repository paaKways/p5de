import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:p5de/contexts/runtime_preview/domain/runtime_console_entry.dart';
import 'package:p5de/contexts/runtime_preview/presentation/runtime_preview_bloc.dart';
import 'package:p5de/contexts/runtime_preview/presentation/runtime_preview_view.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';

class RuntimePreviewPage extends StatefulWidget {
  const RuntimePreviewPage({
    required this.sketch,
    required this.initialCode,
    super.key,
  });

  final Sketch sketch;
  final String initialCode;

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

  bool get _supportsProcessingJava =>
      widget.sketch.language == SketchLanguage.processingJava;

  @override
  void initState() {
    super.initState();
    _bloc = RuntimePreviewBloc();
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
    unawaited(SystemChrome.setPreferredOrientations(const []));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    _bloc.close();
    super.dispose();
  }

  Future<void> _runCurrentCode() async {
    if (!_supportsProcessingJava) {
      return;
    }
    _bloc.add(const RuntimePreviewRunStarted());
    await _runtimeKey.currentState?.runProcessingJava(widget.initialCode);
  }

  Future<void> _stopRuntime() async {
    await _runtimeKey.currentState?.stop();
    _bloc.add(const RuntimePreviewStopped());
  }

  Future<void> _shutdownRuntimeForExit() async {
    if (!_supportsProcessingJava) {
      return;
    }
    try {
      await (_runtimeKey.currentState?.stop() ?? Future<void>.value()).timeout(
        const Duration(seconds: 2),
      );
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
    _runCurrentCode();
  }

  void _handleRuntimeError(Map<String, Object?> payload) {
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
                  onRestart: _supportsProcessingJava ? _runCurrentCode : null,
                  onStop: _supportsProcessingJava ? _stopRuntime : null,
                ),
              ),
              Expanded(
                child: _supportsProcessingJava
                    ? RuntimePreviewView(
                        key: _runtimeKey,
                        onReady: _handleRuntimeReady,
                        onStatusChanged: (status) =>
                            _bloc.add(RuntimePreviewStatusChanged(status)),
                        onLog: (level, message) => _bloc.add(
                          RuntimePreviewLogReceived(
                            level: level,
                            message: message,
                          ),
                        ),
                        onError: _handleRuntimeError,
                        onFirstFrame: () =>
                            _bloc.add(const RuntimePreviewFirstFrameReceived()),
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
            'Processing Java runtime is available. p5.js runtime wiring is still separate work.',
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

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:p5de/contexts/runtime_preview/domain/runtime_console_entry.dart';
import 'package:p5de/contexts/runtime_preview/domain/runtime_physical_viewport.dart';

class FullscreenRuntimePreviewView extends StatefulWidget {
  const FullscreenRuntimePreviewView({
    required this.onReady,
    required this.onStatusChanged,
    required this.onLog,
    required this.onError,
    required this.onFirstFrame,
    super.key,
  });

  final VoidCallback onReady;
  final ValueChanged<String> onStatusChanged;
  final void Function(RuntimeConsoleLevel level, String message) onLog;
  final ValueChanged<Map<String, Object?>> onError;
  final VoidCallback onFirstFrame;

  @override
  State<FullscreenRuntimePreviewView> createState() =>
      FullscreenRuntimePreviewViewState();
}

class FullscreenRuntimePreviewViewState
    extends State<FullscreenRuntimePreviewView> {
  static int _nextViewId = 0;

  late final String _viewType;
  late final html.IFrameElement _iframe;
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  Timer? _runtimeReadyRetryTimer;
  int _runtimeReadyAttempts = 0;
  bool _ready = false;
  _PendingFullscreenRun? _pendingRun;

  static const _runtimeReadyRetryDelay = Duration(milliseconds: 150);
  static const _maxRuntimeReadyAttempts = 80;

  @override
  void initState() {
    super.initState();
    _viewType = 'p5de-processing-fullscreen-runtime-${_nextViewId++}';
    _iframe = html.IFrameElement()
      ..src = 'assets/assets/runtime/processing_java/runtime.html'
      ..style.border = '0'
      ..style.height = '100%'
      ..style.overflow = 'hidden'
      ..style.width = '100%';
    _iframe.setAttribute('sandbox', 'allow-scripts allow-same-origin');
    _iframe.setAttribute('allow', 'fullscreen');
    _iframe.setAttribute('scrolling', 'no');
    _iframe.onLoad.listen((_) => _startRuntimeReadyHandshake());
    _messageSubscription = html.window.onMessage.listen(_handleMessage);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _iframe);
  }

  @override
  void dispose() {
    _runtimeReadyRetryTimer?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> runProcessingJava(
    String code, {
    required RuntimePhysicalViewport viewport,
  }) async {
    final pendingRun = _PendingFullscreenRun(code: code, viewport: viewport);
    if (!_ready) {
      _pendingRun = pendingRun;
      return;
    }
    _postCommand('runProcessingJava', {
      'code': pendingRun.code,
      'viewport': pendingRun.viewport.toPayload(),
    });
  }

  Future<void> stop() async {
    _pendingRun = null;
    _postCommand('stop', const {});
  }

  Future<void> showError(String message) async {
    _postCommand('showError', {'message': message});
  }

  void _startRuntimeReadyHandshake() {
    _ready = false;
    _runtimeReadyAttempts = 0;
    _runtimeReadyRetryTimer?.cancel();
    _tryRequestRuntimeReady();
  }

  void _tryRequestRuntimeReady() {
    if (!mounted || _ready) {
      return;
    }
    _postCommand('ping', const {});
    _runtimeReadyAttempts += 1;
    if (_runtimeReadyAttempts >= _maxRuntimeReadyAttempts) {
      return;
    }
    _runtimeReadyRetryTimer = Timer(
      _runtimeReadyRetryDelay,
      _tryRequestRuntimeReady,
    );
  }

  void _postCommand(String command, Map<String, Object?> payload) {
    _iframe.contentWindow?.postMessage(
      jsonEncode({
        'source': 'p5de-flutter-runtime',
        'command': command,
        'payload': payload,
      }),
      '*',
    );
  }

  void _handleMessage(html.MessageEvent event) {
    final data = _normalizePayload(event.data);
    if (data['source'] != 'p5de-processing-runtime') {
      return;
    }
    final name = data['name'];
    final payload = _normalizePayload(data['payload']);
    if (name == 'runtimeReady') {
      _ready = true;
      _runtimeReadyRetryTimer?.cancel();
      _runtimeReadyRetryTimer = null;
      widget.onReady();
      final pendingRun = _pendingRun;
      if (pendingRun != null) {
        _pendingRun = null;
        _postCommand('runProcessingJava', {
          'code': pendingRun.code,
          'viewport': pendingRun.viewport.toPayload(),
        });
      }
      return;
    }
    if (!_ready) {
      return;
    }
    if (name == 'runtimeStatusChanged') {
      final status = payload['status'];
      if (status is String) {
        widget.onStatusChanged(status);
      }
    }
    if (name == 'runtimeLog') {
      final message = payload['message'];
      if (message is String) {
        widget.onLog(_levelFromPayload(payload['level']), message);
      }
    }
    if (name == 'runtimeError') {
      widget.onError(payload);
    }
    if (name == 'runtimeFirstFrame') {
      widget.onFirstFrame();
    }
  }

  RuntimeConsoleLevel _levelFromPayload(Object? raw) {
    return switch (raw) {
      'warning' => RuntimeConsoleLevel.warning,
      'error' => RuntimeConsoleLevel.error,
      _ => RuntimeConsoleLevel.info,
    };
  }

  Map<String, Object?> _normalizePayload(Object? raw) {
    if (raw is Map) {
      return raw.cast<String, Object?>();
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.cast<String, Object?>();
        }
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      key: const Key('runtime_processing_java_fullscreen_webview'),
      viewType: _viewType,
    );
  }
}

class _PendingFullscreenRun {
  const _PendingFullscreenRun({required this.code, required this.viewport});

  final String code;
  final RuntimePhysicalViewport viewport;
}

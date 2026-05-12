// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:p5de/contexts/runtime_preview/domain/runtime_console_entry.dart';

class RuntimePreviewView extends StatefulWidget {
  const RuntimePreviewView({
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
  State<RuntimePreviewView> createState() => RuntimePreviewViewState();
}

class RuntimePreviewViewState extends State<RuntimePreviewView> {
  static int _nextViewId = 0;

  late final String _viewType;
  late final html.IFrameElement _iframe;
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  Timer? _runtimeReadyRetryTimer;
  int _runtimeReadyAttempts = 0;
  bool _ready = false;
  String? _pendingCode;

  static const _runtimeReadyRetryDelay = Duration(milliseconds: 150);
  static const _maxRuntimeReadyAttempts = 80;

  @override
  void initState() {
    super.initState();
    _viewType = 'p5de-processing-runtime-${_nextViewId++}';
    _iframe = html.IFrameElement()
      ..src = 'assets/assets/runtime/processing_java/runtime.html'
      ..style.border = '0'
      ..style.height = '100%'
      ..style.width = '100%';
    _iframe.setAttribute('sandbox', 'allow-scripts allow-same-origin');
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

  Future<void> runProcessingJava(String code) async {
    if (!_ready) {
      _pendingCode = code;
      return;
    }
    _postCommand('runProcessingJava', {'code': code});
  }

  Future<void> stop() async {
    _pendingCode = null;
    _postCommand('stop', const {});
  }

  Future<void> restart() async {
    _postCommand('restart', const {});
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
      final pendingCode = _pendingCode;
      if (pendingCode != null) {
        _pendingCode = null;
        _postCommand('runProcessingJava', {'code': pendingCode});
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
      key: const Key('runtime_processing_java_webview'),
      viewType: _viewType,
    );
  }
}

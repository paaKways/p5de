import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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
  static const String _runtimeAssetUrlText =
      'https://appassets.androidplatform.net/assets/flutter_assets/assets/runtime/processing_java/runtime.html';
  static final WebUri _runtimeAssetUrl = WebUri(_runtimeAssetUrlText);

  InAppWebViewController? _controller;
  bool _ready = false;
  String? _pendingCode;

  Future<void> runProcessingJava(String code) async {
    if (!_ready) {
      _pendingCode = code;
      return;
    }
    await _runProcessingJavaNow(code);
  }

  Future<void> stop() async {
    _pendingCode = null;
    await _controller?.evaluateJavascript(
      source: 'window.P5deProcessingRuntime.stop();',
    );
  }

  Future<void> restart() async {
    await _controller?.evaluateJavascript(
      source: 'window.P5deProcessingRuntime.restart();',
    );
  }

  void _registerBridgeHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'runtimeReady',
      callback: (_) {
        _ready = true;
        widget.onReady();
        final pendingCode = _pendingCode;
        if (pendingCode != null) {
          _pendingCode = null;
          _runProcessingJavaNow(pendingCode);
        }
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'runtimeStatusChanged',
      callback: (args) {
        final payload = _decodeBridgePayload(args);
        final status = payload['status'];
        if (status is String) {
          widget.onStatusChanged(status);
        }
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'runtimeLog',
      callback: (args) {
        final payload = _decodeBridgePayload(args);
        final message = payload['message'];
        if (message is String) {
          widget.onLog(_levelFromPayload(payload['level']), message);
        }
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'runtimeError',
      callback: (args) => widget.onError(_decodeBridgePayload(args)),
    );
    controller.addJavaScriptHandler(
      handlerName: 'runtimeFirstFrame',
      callback: (_) => widget.onFirstFrame(),
    );
  }

  Future<void> _runProcessingJavaNow(String code) async {
    final payload = jsonEncode({'code': code});
    await _controller?.evaluateJavascript(
      source: 'window.P5deProcessingRuntime.runProcessingJava($payload);',
    );
  }

  RuntimeConsoleLevel _levelFromPayload(Object? raw) {
    return switch (raw) {
      'warning' => RuntimeConsoleLevel.warning,
      'error' => RuntimeConsoleLevel.error,
      _ => RuntimeConsoleLevel.info,
    };
  }

  Map<String, Object?> _decodeBridgePayload(List<dynamic> args) {
    if (args.isEmpty) {
      return const {};
    }
    final raw = args.first;
    if (raw is Map) {
      return raw.cast<String, Object?>();
    }
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.cast<String, Object?>();
      }
    }
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      key: const Key('runtime_processing_java_webview'),
      initialUrlRequest: URLRequest(url: _runtimeAssetUrl),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: false,
        supportZoom: false,
        disableContextMenu: true,
        allowFileAccess: false,
        allowContentAccess: false,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        iframeAllow: 'fullscreen',
        iframeAllowFullscreen: true,
        webViewAssetLoader: WebViewAssetLoader(
          pathHandlers: [AssetsPathHandler(path: '/assets/')],
        ),
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        _registerBridgeHandlers(controller);
      },
      onLoadStart: (controller, url) {
        _ready = false;
      },
    );
  }
}

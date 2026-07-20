import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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
  static const String _runtimeAssetUrlText =
      'https://appassets.androidplatform.net/assets/flutter_assets/assets/runtime/processing_java/runtime.html';
  static final WebUri _runtimeAssetUrl = WebUri(_runtimeAssetUrlText);

  InAppWebViewController? _controller;
  bool _ready = false;
  _PendingFullscreenRun? _pendingRun;

  Future<void> runProcessingJava(
    String code, {
    required RuntimePhysicalViewport viewport,
  }) async {
    final pendingRun = _PendingFullscreenRun(code: code, viewport: viewport);
    if (!_ready) {
      _pendingRun = pendingRun;
      return;
    }
    await _runProcessingJavaNow(pendingRun);
  }

  Future<void> stop() async {
    _pendingRun = null;
    await _controller?.evaluateJavascript(
      source: 'window.P5deProcessingRuntime.stop();',
    );
  }

  void _registerBridgeHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'runtimeReady',
      callback: (_) {
        _ready = true;
        widget.onReady();
        final pendingRun = _pendingRun;
        if (pendingRun != null) {
          _pendingRun = null;
          _runProcessingJavaNow(pendingRun);
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

  Future<void> _runProcessingJavaNow(_PendingFullscreenRun run) async {
    final payload = jsonEncode({
      'code': run.code,
      'viewport': run.viewport.toPayload(),
    });
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
      key: const Key('runtime_processing_java_fullscreen_webview'),
      initialUrlRequest: URLRequest(url: _runtimeAssetUrl),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: false,
        supportZoom: false,
        disableContextMenu: true,
        disableVerticalScroll: true,
        disableHorizontalScroll: true,
        verticalScrollBarEnabled: false,
        horizontalScrollBarEnabled: false,
        disallowOverScroll: true,
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

class _PendingFullscreenRun {
  const _PendingFullscreenRun({required this.code, required this.viewport});

  final String code;
  final RuntimePhysicalViewport viewport;
}

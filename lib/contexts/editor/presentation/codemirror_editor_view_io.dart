import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class CodeMirrorEditorView extends StatefulWidget {
  const CodeMirrorEditorView({
    required this.code,
    required this.language,
    required this.onChanged,
    required this.onCursorChanged,
    required this.onReady,
    super.key,
  });

  final String code;
  final String language;
  final ValueChanged<String> onChanged;
  final void Function(int line, int column) onCursorChanged;
  final VoidCallback onReady;

  @override
  State<CodeMirrorEditorView> createState() => CodeMirrorEditorViewState();
}

class CodeMirrorEditorViewState extends State<CodeMirrorEditorView> {
  InAppWebViewController? _controller;
  bool _ready = false;

  Future<void> setCode(String code) async {
    if (!_ready) {
      return;
    }
    await _controller?.evaluateJavascript(
      source: 'window.P5deEditor.setCode(${jsonEncode(code)});',
    );
  }

  Future<void> insertText(String text, {int? cursorOffset}) async {
    if (!_ready) {
      return;
    }
    final offsetArgument = cursorOffset == null ? '' : ', $cursorOffset';
    await _controller?.evaluateJavascript(
      source:
          'window.P5deEditor.insertText(${jsonEncode(text)}$offsetArgument);',
    );
  }

  Future<void> runCommand(String command) async {
    if (!_ready) {
      return;
    }
    await _controller?.evaluateJavascript(
      source: 'window.P5deEditor.runCommand(${jsonEncode(command)});',
    );
  }

  Future<void> focusEditor() async {
    if (!_ready) {
      return;
    }
    await _controller?.evaluateJavascript(source: 'window.P5deEditor.focus();');
  }

  void _registerBridgeHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'editorReady',
      callback: (_) {
        _ready = true;
        widget.onReady();
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'editorCodeChanged',
      callback: (args) {
        final payload = _decodeBridgePayload(args);
        final code = payload['code'];
        if (code is String) {
          widget.onChanged(code);
        }
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'editorCursorChanged',
      callback: (args) {
        final payload = _decodeBridgePayload(args);
        final line = payload['line'];
        final column = payload['column'];
        if (line is num && column is num) {
          widget.onCursorChanged(line.toInt(), column.toInt());
        }
      },
    );
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

  Future<void> _initializeCodeMirror() async {
    final options = jsonEncode({
      'code': widget.code,
      'language': widget.language,
    });
    await _controller?.evaluateJavascript(
      source: 'window.P5deEditor.createEditor($options);',
    );
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      key: const Key('editor_codemirror_webview'),
      initialFile: 'assets/editor/codemirror/editor.html',
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
        supportZoom: false,
        disableContextMenu: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        _registerBridgeHandlers(controller);
      },
      onLoadStop: (controller, url) => _initializeCodeMirror(),
    );
  }
}

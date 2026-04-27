// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

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
  static int _nextViewId = 0;

  late final String _viewType;
  late final html.IFrameElement _iframe;
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'p5de-codemirror-editor-${_nextViewId++}';
    _iframe = html.IFrameElement()
      ..src = 'assets/assets/editor/codemirror/editor.html'
      ..style.border = '0'
      ..style.height = '100%'
      ..style.width = '100%';
    _iframe.onLoad.listen((_) => _createEditor());
    _messageSubscription = html.window.onMessage.listen(_handleMessage);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _iframe);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> setCode(String code) async {
    _postCommand('setCode', {'code': code});
  }

  Future<void> insertText(String text) async {
    _postCommand('insertText', {'text': text});
  }

  void _createEditor() {
    _postCommand('createEditor', {
      'code': widget.code,
      'language': widget.language,
    });
  }

  void _postCommand(String command, Map<String, Object?> payload) {
    _iframe.contentWindow?.postMessage({
      'source': 'p5de-flutter',
      'command': command,
      'payload': payload,
    }, '*');
  }

  void _handleMessage(html.MessageEvent event) {
    if (event.source != _iframe.contentWindow) {
      return;
    }
    final data = event.data;
    if (data is! Map) {
      return;
    }
    final name = data['name'];
    final payload = _normalizePayload(data['payload']);
    if (name == 'editorReady') {
      _ready = true;
      widget.onReady();
      return;
    }
    if (!_ready) {
      return;
    }
    if (name == 'editorCodeChanged') {
      final code = payload['code'];
      if (code is String) {
        widget.onChanged(code);
      }
    }
    if (name == 'editorCursorChanged') {
      final line = payload['line'];
      final column = payload['column'];
      if (line is num && column is num) {
        widget.onCursorChanged(line.toInt(), column.toInt());
      }
    }
  }

  Map<String, Object?> _normalizePayload(Object? raw) {
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
    return HtmlElementView(
      key: const Key('editor_codemirror_webview'),
      viewType: _viewType,
    );
  }
}

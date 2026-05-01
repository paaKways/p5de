import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

class WebCodeEditor extends StatefulWidget {
  const WebCodeEditor({
    required this.initialCode,
    required this.onCodeChanged,
    super.key,
  });

  final String initialCode;
  final ValueChanged<String> onCodeChanged;

  @override
  State<WebCodeEditor> createState() => _WebCodeEditorState();
}

class _WebCodeEditorState extends State<WebCodeEditor> {
  static int _nextId = 0;

  late final String _viewType;
  late final html.IFrameElement _iframe;
  StreamSubscription<html.MessageEvent>? _messageSubscription;

  String _latestCode = '';

  @override
  void initState() {
    super.initState();
    _latestCode = widget.initialCode;

    _viewType = 'p5de-web-code-editor-${_nextId++}';
    _iframe = html.IFrameElement()
      ..src = 'assets/assets/editor/codemirror_host.html?v=20260316_2'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
      return _iframe;
    });

    _iframe.onLoad.listen((_) {
      _postCommand('editor.setCode', code: _latestCode);
      _postCommand('editor.focus');
    });

    _messageSubscription = html.window.onMessage.listen(_onMessage);
  }

  @override
  void didUpdateWidget(covariant WebCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCode != oldWidget.initialCode &&
        widget.initialCode != _latestCode) {
      _latestCode = widget.initialCode;
      _postCommand('editor.setCode', code: _latestCode);
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }

  void _onMessage(html.MessageEvent event) {
    final data = event.data;
    if (data is! String) {
      return;
    }

    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map) {
        return;
      }
      payload = decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      // Ignore messages that are not part of the editor bridge protocol.
      return;
    }

    final kind = payload['kind']?.toString();
    if (kind == null || !kind.startsWith('editor.')) {
      return;
    }

    // ignore: avoid_print
    print('WebCodeEditor message kind=$kind');

    if (kind == 'editor.error') {
      // ignore: avoid_print
      print('Web editor host error: ${payload['message']}');
      return;
    }

    if (kind == 'editor.debug') {
      // ignore: avoid_print
      print('Web editor host debug: ${payload['message']}');
      return;
    }

    if (kind == 'editor.ready') {
      // Re-sync current draft after host/backend switch (loading -> codemirror/textarea).
      _postCommand('editor.setCode', code: _latestCode);
      _postCommand('editor.focus');
      return;
    }

    if (kind != 'editor.codeChanged') {
      return;
    }

    final code = payload['code']?.toString() ?? '';
    _latestCode = code;
    widget.onCodeChanged(code);
  }

  void _postCommand(String kind, {String? code}) {
    final payload = <String, String>{'kind': kind};
    if (code != null) {
      payload['code'] = code;
    }

    _iframe.contentWindow?.postMessage(jsonEncode(payload), '*');
  }
}

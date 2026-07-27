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
    required this.fontSize,
    required this.onChanged,
    required this.onCursorChanged,
    required this.onReady,
    super.key,
  });

  final String code;
  final String language;
  final int fontSize;
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
  Timer? _createEditorRetryTimer;
  int _createEditorAttempts = 0;
  bool _ready = false;

  static const _createEditorRetryDelay = Duration(milliseconds: 150);
  static const _maxCreateEditorAttempts = 80;

  @override
  void initState() {
    super.initState();
    _viewType = 'p5de-codemirror-editor-${_nextViewId++}';
    _iframe = html.IFrameElement()
      ..src = 'assets/assets/editor/codemirror/editor.html'
      ..style.border = '0'
      ..style.height = '100%'
      ..style.width = '100%';
    _iframe.onLoad.listen((_) => _startCreateEditorHandshake());
    _messageSubscription = html.window.onMessage.listen(_handleMessage);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _iframe);
  }

  @override
  void dispose() {
    _createEditorRetryTimer?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> setCode(String code) async {
    _postCommand('setCode', {'code': code});
  }

  Future<void> insertText(String text, {int? cursorOffset}) async {
    final payload = <String, Object?>{'text': text};
    if (cursorOffset != null) {
      payload['cursorOffset'] = cursorOffset;
    }
    _postCommand('insertText', payload);
  }

  Future<void> runCommand(String command) async {
    _postCommand('runCommand', {'command': command});
  }

  Future<void> focusEditor() async {
    _postCommand('focus', const {});
  }

  Future<void> setFontSize(int fontSize) async {
    _postCommand('setFontSize', {'fontSize': fontSize});
  }

  Future<void> setPointerEventsEnabled(bool enabled) async {
    _iframe.style.pointerEvents = enabled ? 'auto' : 'none';
  }

  void _createEditor() {
    _postCommand('createEditor', {
      'code': widget.code,
      'language': widget.language,
      'fontSize': widget.fontSize,
    });
  }

  void _startCreateEditorHandshake() {
    _ready = false;
    _createEditorAttempts = 0;
    _createEditorRetryTimer?.cancel();
    _tryCreateEditor();
  }

  void _tryCreateEditor() {
    if (!mounted || _ready) {
      return;
    }
    _createEditor();
    _createEditorAttempts += 1;
    if (_createEditorAttempts >= _maxCreateEditorAttempts) {
      return;
    }
    _createEditorRetryTimer = Timer(_createEditorRetryDelay, _tryCreateEditor);
  }

  void _postCommand(String command, Map<String, Object?> payload) {
    _iframe.contentWindow?.postMessage(
      jsonEncode({
        'source': 'p5de-flutter',
        'command': command,
        'payload': payload,
      }),
      '*',
    );
  }

  void _handleMessage(html.MessageEvent event) {
    final data = _normalizePayload(event.data);
    if (data['source'] != 'p5de-codemirror') {
      return;
    }
    final name = data['name'];
    final payload = _normalizePayload(data['payload']);
    if (name == 'editorReady') {
      _ready = true;
      _createEditorRetryTimer?.cancel();
      _createEditorRetryTimer = null;
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
  void didUpdateWidget(CodeMirrorEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontSize != widget.fontSize) {
      setFontSize(widget.fontSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      key: const Key('editor_codemirror_webview'),
      viewType: _viewType,
    );
  }
}

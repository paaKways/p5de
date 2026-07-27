import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
  static const String _editorAssetUrlText =
      'https://appassets.androidplatform.net/assets/flutter_assets/assets/editor/codemirror/editor.html';
  static const String _editorBundleAssetUrlText =
      'https://appassets.androidplatform.net/assets/flutter_assets/assets/editor/codemirror/editor.bundle.js';
  static final WebUri _editorAssetUrl = WebUri(_editorAssetUrlText);

  InAppWebViewController? _controller;
  bool _ready = false;
  bool _initializing = false;
  bool _pointerEventsEnabled = true;
  int _loadGeneration = 0;

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

  Future<void> setFontSize(int fontSize) async {
    if (!_ready) {
      return;
    }
    await _controller?.evaluateJavascript(
      source: 'window.P5deEditor.setFontSize($fontSize);',
    );
  }

  Future<void> setPointerEventsEnabled(bool enabled) async {
    if (_pointerEventsEnabled == enabled) {
      return;
    }
    setState(() => _pointerEventsEnabled = enabled);
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
    if (_ready || _initializing) {
      return;
    }
    _initializing = true;
    final generation = ++_loadGeneration;
    final options = jsonEncode({
      'code': widget.code,
      'language': widget.language,
      'fontSize': widget.fontSize,
    });
    final bundleUrl = jsonEncode(_editorBundleAssetUrlText);
    try {
      for (var attempt = 0; attempt < 150; attempt += 1) {
        if (!mounted || generation != _loadGeneration) {
          return;
        }
        await _loadBundledCodeMirror(options, bundleUrl);
        if (await _isCodeMirrorMounted()) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      _initializing = false;
    }
  }

  Future<bool> _isCodeMirrorMounted() async {
    final isMounted = await _controller?.evaluateJavascript(
      source: 'Boolean(document.querySelector(".cm-editor"))',
    );
    return isMounted == true || isMounted == 'true';
  }

  Future<void> _loadBundledCodeMirror(String options, String bundleUrl) async {
    await _controller?.evaluateJavascript(
      source:
          '''
window.__p5dePendingEditorOptions = $options;
async function loadP5deEditorBundle() {
  function mountEditor() {
    if (!window.P5deEditor?.createEditor) {
      return false;
    }
    window.__p5deEditorBundleLoaded = true;
    window.__p5deEditorBundleLoading = false;
    window.__p5deEditorBundleError = null;
    if (!document.querySelector('.cm-editor')) {
      window.P5deEditor.createEditor(window.__p5dePendingEditorOptions);
    }
    return true;
  }

  function fail(error) {
    window.__p5deEditorBundleLoading = false;
    window.__p5deEditorBundleError = error.message;
    console.error(error);
    var editor = document.getElementById('editor');
    if (editor) {
      editor.textContent = 'Editor failed to load: ' + error.message;
    }
  }

  if (mountEditor() || window.__p5deEditorBundleLoading) {
    return;
  }

  window.__p5deEditorBundleLoading = true;
  window.__p5deEditorBundleError = null;

  try {
    await import($bundleUrl);
    if (!mountEditor()) {
      fail(new Error('Editor bundle loaded without API'));
    }
  } catch (error) {
    fail(error);
  }
}
loadP5deEditorBundle();
''',
    );
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
    return IgnorePointer(
      ignoring: !_pointerEventsEnabled,
      child: InAppWebView(
        key: const Key('editor_codemirror_webview'),
        initialUrlRequest: URLRequest(url: _editorAssetUrl),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          transparentBackground: true,
          supportZoom: false,
          disableContextMenu: false,
          allowFileAccess: false,
          allowContentAccess: false,
          allowFileAccessFromFileURLs: false,
          allowUniversalAccessFromFileURLs: false,
          webViewAssetLoader: WebViewAssetLoader(
            pathHandlers: [AssetsPathHandler(path: '/assets/')],
          ),
        ),
        onWebViewCreated: (controller) {
          _controller = controller;
          _registerBridgeHandlers(controller);
          Future<void>.delayed(
            const Duration(milliseconds: 600),
            _initializeCodeMirror,
          );
        },
        onLoadStart: (controller, url) {
          _ready = false;
          _loadGeneration += 1;
        },
        onProgressChanged: (controller, progress) {
          if (progress == 100) {
            _initializeCodeMirror();
          }
        },
        onLoadStop: (controller, url) => _initializeCodeMirror(),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class InAppWebViewCodeEditor extends StatefulWidget {
  const InAppWebViewCodeEditor({
    required this.initialCode,
    required this.onCodeChanged,
    super.key,
  });

  final String initialCode;
  final ValueChanged<String> onCodeChanged;

  @override
  State<InAppWebViewCodeEditor> createState() => _InAppWebViewCodeEditorState();
}

class _InAppWebViewCodeEditorState extends State<InAppWebViewCodeEditor> {
  InAppWebViewController? _controller;
  String _latestCode = '';
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _latestCode = widget.initialCode;
  }

  @override
  void didUpdateWidget(covariant InAppWebViewCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCode != widget.initialCode &&
        widget.initialCode != _latestCode) {
      _latestCode = widget.initialCode;
      _setCode(widget.initialCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
        isInspectable: true,
      ),
      initialFile: 'assets/editor/codemirror_host.html',
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: 'onEditorCodeChanged',
          callback: (args) {
            final value = (args.isNotEmpty ? args.first : '')?.toString() ?? '';
            _latestCode = value;
            widget.onCodeChanged(value);
            return null;
          },
        );
      },
      onLoadStop: (controller, url) async {
        _isReady = true;
        await _setCode(_latestCode);
      },
    );
  }

  Future<void> _setCode(String code) async {
    if (!_isReady || _controller == null) {
      return;
    }
    final escaped = _escapeJsString(code);
    await _controller!.evaluateJavascript(
      source: "window.editorBridge && window.editorBridge.setCode('$escaped');",
    );
  }

  String _escapeJsString(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
  }
}

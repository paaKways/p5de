import 'package:flutter/widgets.dart';

class WebCodeEditor extends StatelessWidget {
  const WebCodeEditor({
    required this.initialCode,
    required this.onCodeChanged,
    super.key,
  });

  final String initialCode;
  final ValueChanged<String> onCodeChanged;

  @override
  Widget build(BuildContext context) {
    // Non-web platforms should never instantiate this widget.
    return const SizedBox.shrink();
  }
}

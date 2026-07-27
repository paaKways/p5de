import 'dart:async';

class EditorAutosaveDebouncer {
  EditorAutosaveDebouncer({
    required void Function() onSave,
    this.delay = const Duration(seconds: 1),
  }) : _onSave = onSave;

  final void Function() _onSave;
  final Duration delay;
  Timer? _timer;

  bool get isPending => _timer?.isActive ?? false;

  void schedule() {
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      _onSave();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void flush() {
    final hadPendingSave = isPending;
    cancel();
    if (hadPendingSave) {
      _onSave();
    }
  }

  void dispose() => cancel();
}

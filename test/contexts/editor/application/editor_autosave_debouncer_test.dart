import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/editor/application/editor_autosave_debouncer.dart';

void main() {
  testWidgets('restarts the delay and saves only after typing stops', (
    tester,
  ) async {
    var saveCount = 0;
    final debouncer = EditorAutosaveDebouncer(
      onSave: () => saveCount += 1,
      delay: const Duration(seconds: 1),
    );
    addTearDown(debouncer.dispose);

    debouncer.schedule();
    await tester.pump(const Duration(milliseconds: 700));
    debouncer.schedule();
    await tester.pump(const Duration(milliseconds: 999));

    expect(saveCount, 0);
    expect(debouncer.isPending, isTrue);

    await tester.pump(const Duration(milliseconds: 1));

    expect(saveCount, 1);
    expect(debouncer.isPending, isFalse);
  });

  testWidgets('flushes one pending save immediately', (tester) async {
    var saveCount = 0;
    final debouncer = EditorAutosaveDebouncer(onSave: () => saveCount += 1);
    addTearDown(debouncer.dispose);

    debouncer.schedule();
    debouncer.flush();
    debouncer.flush();

    expect(saveCount, 1);
    expect(debouncer.isPending, isFalse);
  });
}

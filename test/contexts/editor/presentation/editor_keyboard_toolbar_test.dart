import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/editor/presentation/editor_page.dart';

void main() {
  test('character toolbar matches APDE order without digits', () {
    expect(editorKeyboardShortcutValues, const [
      '\t',
      ';',
      ',',
      '{',
      '}',
      '(',
      ')',
      '=',
      '*',
      '/',
      '+',
      '-',
      '&',
      '|',
      '!',
      '[',
      ']',
      '<',
      '>',
      '"',
      "'",
      r'\',
      '_',
      '.',
      '?',
      ':',
      '%',
      '@',
      '#',
    ]);
    expect(editorKeyboardShortcutValues, isNot(contains('0')));
    expect(editorKeyboardShortcutValues, isNot(contains('1')));
  });
}

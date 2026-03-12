import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';

void main() {
  group('SketchName', () {
    test('trims and normalizes value', () {
      final name = SketchName('  My Sketch  ');

      expect(name.value, 'My Sketch');
      expect(name.normalized, 'my sketch');
    });

    test('throws on empty value', () {
      expect(
        () => SketchName('   '),
        throwsA(isA<InvalidSketchNameException>()),
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';

void main() {
  group('SketchLanguage', () {
    test('derives a Processing Java file name from the sketch name', () {
      expect(
        SketchLanguage.processingJava.fileNameForSketchName(
          'Pong Runtime Test',
        ),
        'Pong Runtime Test.pde',
      );
    });

    test('does not duplicate an existing Processing Java file extension', () {
      expect(
        SketchLanguage.processingJava.fileNameForSketchName(
          'screen_grapher.pde',
        ),
        'screen_grapher.pde',
      );
    });

    test('derives a p5.js file name from the sketch name', () {
      expect(
        SketchLanguage.p5js.fileNameForSketchName('Particles'),
        'Particles.js',
      );
    });

    test('exposes runtime file extensions', () {
      expect(SketchLanguage.processingJava.fileExtension, 'pde');
      expect(SketchLanguage.p5js.fileExtension, 'js');
    });
  });
}

import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';

const String kDefaultP5jsSketchTemplate = '''
function setup() {
  createCanvas(windowWidth, windowHeight);
}

function draw() {
  background(240);
}
''';

const String kDefaultProcessingJavaSketchTemplate = '''
void setup() {
  size(400, 400);
}

void draw() {
  background(240);
}
''';

String defaultSketchTemplateFor(SketchLanguage language) {
  return switch (language) {
    SketchLanguage.processingJava => kDefaultProcessingJavaSketchTemplate,
    SketchLanguage.p5js => kDefaultP5jsSketchTemplate,
  };
}

@Deprecated('Use kDefaultP5jsSketchTemplate or defaultSketchTemplateFor.')
const String kDefaultSketchTemplate = kDefaultP5jsSketchTemplate;

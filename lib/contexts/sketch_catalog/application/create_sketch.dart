import 'package:p5de/contexts/sketch_catalog/application/sketch_templates.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';

class CreateSketch {
  CreateSketch({
    required SketchRepository repository,
    required IdGenerator idGenerator,
    required Clock clock,
  }) : _repository = repository,
       _idGenerator = idGenerator,
       _clock = clock;

  final SketchRepository _repository;
  final IdGenerator _idGenerator;
  final Clock _clock;

  Future<Sketch> call({
    required String name,
    SketchLanguage language = SketchLanguage.p5js,
    String? code,
  }) async {
    final sketchName = SketchName(name);
    final isDuplicate = await _repository.existsByNormalizedName(
      sketchName.normalized,
    );
    if (isDuplicate) {
      throw DuplicateSketchNameException();
    }

    final now = _clock.now().millisecondsSinceEpoch;
    final sketch = Sketch(
      id: _idGenerator.newId(),
      name: sketchName,
      language: language,
      code: code ?? defaultSketchTemplateFor(language),
      createdAt: now,
      updatedAt: now,
    );

    await _repository.create(sketch);
    return sketch;
  }
}

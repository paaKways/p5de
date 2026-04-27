import 'package:p5de/contexts/editor/domain/editor_draft.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/shared/clock.dart';

class SaveSketch {
  const SaveSketch({required SketchRepository repository, required Clock clock})
    : _repository = repository,
      _clock = clock;

  final SketchRepository _repository;
  final Clock _clock;

  Future<Sketch> call(EditorDraft draft) async {
    final sketch = await _repository.findById(draft.sketchId);
    if (sketch == null) {
      throw SketchNotFoundException();
    }

    final updated = sketch.copyWith(
      code: draft.currentCode,
      updatedAt: _clock.now().millisecondsSinceEpoch,
    );
    await _repository.update(updated);
    return updated;
  }
}

import 'package:p5de/contexts/editor/domain/editor_draft.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';

class LoadSketchForEdit {
  LoadSketchForEdit(this._repository);

  final SketchRepository _repository;

  Future<EditorDraft> call(String sketchId) async {
    final sketch = await _repository.findById(sketchId);
    if (sketch == null) {
      throw SketchNotFoundException();
    }

    return EditorDraft(
      sketchId: sketch.id,
      sketchName: sketch.name.value,
      code: sketch.code,
      lastSavedAt: sketch.updatedAt,
      isDirty: false,
    );
  }
}

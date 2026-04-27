import 'package:p5de/contexts/editor/domain/editor_draft.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';

class LoadSketchForEdit {
  const LoadSketchForEdit(this._repository);

  final SketchRepository _repository;

  Future<EditorDraft> call(String sketchId) async {
    final sketch = await _repository.findById(sketchId);
    if (sketch == null) {
      throw SketchNotFoundException();
    }
    return EditorDraft.fromSketch(sketch);
  }
}

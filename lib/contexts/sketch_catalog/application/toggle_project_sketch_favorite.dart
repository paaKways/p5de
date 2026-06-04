import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';

class ToggleProjectSketchFavorite {
  const ToggleProjectSketchFavorite(this._repository);

  final ProjectRepository _repository;

  Future<void> call({
    required String projectId,
    required String sketchId,
  }) async {
    final sketch = await _repository.findSketchById(projectId, sketchId);
    if (sketch == null) {
      throw SketchNotFoundException();
    }
    await _repository.updateSketch(
      projectId,
      sketch.copyWith(isFavorite: !sketch.isFavorite),
    );
  }
}

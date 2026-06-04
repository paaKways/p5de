import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';

class ToggleSketchFavorite {
  const ToggleSketchFavorite(this._repository);

  final SketchRepository _repository;

  Future<void> call(String sketchId) async {
    final sketch = await _repository.findById(sketchId);
    if (sketch == null) {
      throw SketchNotFoundException();
    }
    await _repository.update(sketch.copyWith(isFavorite: !sketch.isFavorite));
  }
}

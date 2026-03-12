import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';

class DeleteSketch {
  DeleteSketch(this._repository);

  final SketchRepository _repository;

  Future<void> call(String sketchId) async {
    await _repository.deleteById(sketchId);
  }
}

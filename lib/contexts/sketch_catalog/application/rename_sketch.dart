import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/shared/clock.dart';

class RenameSketch {
  RenameSketch({required SketchRepository repository, required Clock clock})
    : _repository = repository,
      _clock = clock;

  final SketchRepository _repository;
  final Clock _clock;

  Future<void> call({required String sketchId, required String newName}) async {
    final existing = await _repository.findById(sketchId);
    if (existing == null) {
      throw SketchNotFoundException();
    }

    final sketchName = SketchName(newName);
    final isDuplicate = await _repository.existsByNormalizedName(
      sketchName.normalized,
      excludingSketchId: sketchId,
    );
    if (isDuplicate) {
      throw DuplicateSketchNameException();
    }

    final updated = existing.copyWith(
      name: sketchName,
      updatedAt: _clock.now().millisecondsSinceEpoch,
    );
    await _repository.update(updated);
  }
}

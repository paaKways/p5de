import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';

class DuplicateSketchNameException implements Exception {}

class SketchNotFoundException implements Exception {}

abstract class SketchRepository {
  Future<void> create(Sketch sketch);

  Future<void> update(Sketch sketch);

  Future<void> deleteById(String sketchId);

  Future<Sketch?> findById(String sketchId);

  Future<List<Sketch>> list({String? query});

  Future<bool> existsByNormalizedName(
    String normalizedName, {
    String? excludingSketchId,
  });
}

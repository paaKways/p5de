import 'package:p5de/contexts/sketch_catalog/domain/project.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';

class DuplicateProjectNameException implements Exception {}

class ProjectNotFoundException implements Exception {}

abstract class ProjectRepository {
  Future<Project> create({required String name});

  Future<void> rename({required String projectId, required String newName});

  Future<void> deleteById(String projectId);

  Future<Project?> findById(String projectId);

  Future<List<Project>> list({String? query});

  Future<List<Sketch>> listSketches(String projectId, {String? query});

  Future<List<ProjectSketchMatch>> listFavoriteSketches({String? query});

  Future<List<ProjectSketchMatch>> searchSketches(String query);

  Future<void> createSketch(String projectId, Sketch sketch);

  Future<void> createSketches(String projectId, Iterable<Sketch> sketches);

  Future<void> updateSketch(String projectId, Sketch sketch);

  Future<void> deleteSketchById(String projectId, String sketchId);

  Future<Sketch?> findSketchById(String projectId, String sketchId);

  Future<bool> existsSketchByNormalizedName(
    String projectId,
    String normalizedName, {
    String? excludingSketchId,
  });
}

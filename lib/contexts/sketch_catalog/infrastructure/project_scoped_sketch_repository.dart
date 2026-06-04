import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';

class ProjectScopedSketchRepository implements SketchRepository {
  const ProjectScopedSketchRepository({
    required ProjectRepository projectRepository,
    required String projectId,
  }) : _projectRepository = projectRepository,
       _projectId = projectId;

  final ProjectRepository _projectRepository;
  final String _projectId;

  @override
  Future<void> create(Sketch sketch) {
    return _projectRepository.createSketch(_projectId, sketch);
  }

  @override
  Future<void> update(Sketch sketch) {
    return _projectRepository.updateSketch(_projectId, sketch);
  }

  @override
  Future<void> deleteById(String sketchId) {
    return _projectRepository.deleteSketchById(_projectId, sketchId);
  }

  @override
  Future<Sketch?> findById(String sketchId) {
    return _projectRepository.findSketchById(_projectId, sketchId);
  }

  @override
  Future<List<Sketch>> list({String? query}) {
    return _projectRepository.listSketches(_projectId, query: query);
  }

  @override
  Future<List<Sketch>> listFavorites({String? query}) async {
    final sketches = await list(query: query);
    return sketches
        .where((sketch) => sketch.isFavorite)
        .toList(growable: false);
  }

  @override
  Future<bool> existsByNormalizedName(
    String normalizedName, {
    String? excludingSketchId,
  }) {
    return _projectRepository.existsSketchByNormalizedName(
      _projectId,
      normalizedName,
      excludingSketchId: excludingSketchId,
    );
  }
}

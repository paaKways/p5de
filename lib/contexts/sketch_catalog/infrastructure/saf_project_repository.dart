import 'package:p5de/contexts/sketch_catalog/domain/project.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/saf_catalog_store.dart';

class SafProjectRepository implements ProjectRepository {
  const SafProjectRepository(this._store);

  final SafCatalogStore _store;

  @override
  Future<Project> create({required String name}) => _store.createProject(name);

  @override
  Future<void> rename({required String projectId, required String newName}) =>
      _store.renameProject(projectId, newName);

  @override
  Future<void> deleteById(String projectId) => _store.deleteProject(projectId);

  @override
  Future<Project?> findById(String projectId) => _store.findProject(projectId);

  @override
  Future<List<Project>> list({String? query}) =>
      _store.listProjects(query: query);

  @override
  Future<List<Sketch>> listSketches(String projectId, {String? query}) =>
      _store.listProjectSketches(projectId, query: query);

  @override
  Future<List<ProjectSketchMatch>> listFavoriteSketches({String? query}) =>
      _store.listFavoriteProjectSketches(query: query);

  @override
  Future<List<ProjectSketchMatch>> searchSketches(String query) =>
      _store.searchProjectSketches(query);

  @override
  Future<void> createSketch(String projectId, Sketch sketch) =>
      _store.createProjectSketch(projectId, sketch);

  @override
  Future<void> createSketches(String projectId, Iterable<Sketch> sketches) =>
      _store.createProjectSketches(projectId, sketches);

  @override
  Future<void> updateSketch(String projectId, Sketch sketch) =>
      _store.updateProjectSketch(projectId, sketch);

  @override
  Future<void> deleteSketchById(String projectId, String sketchId) =>
      _store.deleteProjectSketch(projectId, sketchId);

  @override
  Future<Sketch?> findSketchById(String projectId, String sketchId) =>
      _store.findProjectSketch(projectId, sketchId);

  @override
  Future<bool> existsSketchByNormalizedName(
    String projectId,
    String normalizedName, {
    String? excludingSketchId,
  }) {
    return _store.projectSketchNameExists(
      projectId,
      normalizedName,
      excludingSketchId: excludingSketchId,
    );
  }
}

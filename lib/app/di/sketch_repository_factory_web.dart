import 'package:p5de/contexts/sketch_catalog/application/sketch_catalog_exporter.dart';
import 'package:p5de/app/di/sketch_storage_backend.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/web_local_storage_project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/web_local_storage_sketch_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<bool> hasPersistedSketchCatalogStorage({
  required SketchStorageBackend storageBackend,
}) async {
  final preferences = await SharedPreferences.getInstance();
  return preferences.containsKey(kSketchCatalogWebStorageKey) ||
      preferences.containsKey(kProjectCatalogWebStorageKey);
}

SketchRepository createSketchRepository({
  required SketchStorageBackend storageBackend,
}) {
  return WebLocalStorageSketchRepository();
}

ProjectRepository createProjectRepository({
  required SketchStorageBackend storageBackend,
}) {
  return WebLocalStorageProjectRepository();
}

SketchCatalogExporter? createSketchCatalogExporter({
  required SketchRepository sketchRepository,
  required ProjectRepository projectRepository,
}) {
  return null;
}

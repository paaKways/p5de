import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:p5de/contexts/sketch_catalog/application/sketch_catalog_exporter.dart';
import 'package:p5de/app/di/sketch_storage_backend.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/drift_project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/drift_sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/filesystem_project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/filesystem_sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/saf_catalog_store.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/saf_project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/saf_sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/sketch_catalog_database.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/user_visible_sketch_catalog_exporter.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/user_visible_sketch_mirror.dart';

final _database = SketchCatalogDatabase();
final _safCatalogStore = SafCatalogStore();
final _userVisibleSketchMirror = CoalescingUserVisibleSketchMirror(
  const MethodChannelUserVisibleSketchMirror(),
);

SketchStorageBackend defaultSketchStorageBackend() => SketchStorageBackend.saf;

Future<bool> hasPersistedSketchCatalogStorage({
  required SketchStorageBackend storageBackend,
}) async {
  final documents = await getApplicationDocumentsDirectory();
  final sketchRoot = Directory(
    '${documents.path}${Platform.pathSeparator}sketches',
  );
  if (await sketchRoot.exists()) {
    return true;
  }

  final databaseFile = File(
    '${documents.path}${Platform.pathSeparator}p5de.sqlite',
  );
  return databaseFile.exists();
}

SketchRepository createSketchRepository({
  required SketchStorageBackend storageBackend,
}) {
  switch (storageBackend) {
    case SketchStorageBackend.drift:
      return DriftSketchRepository(
        _database,
        legacyRepository: FilesystemSketchRepository(),
      );
    case SketchStorageBackend.filesystem:
      return FilesystemSketchRepository(
        userVisibleMirror: _userVisibleSketchMirror,
      );
    case SketchStorageBackend.saf:
      return SafSketchRepository(_safCatalogStore);
  }
}

ProjectRepository createProjectRepository({
  required SketchStorageBackend storageBackend,
}) {
  switch (storageBackend) {
    case SketchStorageBackend.drift:
      return DriftProjectRepository(
        _database,
        legacyRepository: FilesystemProjectRepository(),
      );
    case SketchStorageBackend.filesystem:
      return FilesystemProjectRepository(
        userVisibleMirror: _userVisibleSketchMirror,
      );
    case SketchStorageBackend.saf:
      return SafProjectRepository(_safCatalogStore);
  }
}

SketchCatalogExporter? createSketchCatalogExporter({
  required SketchRepository sketchRepository,
  required ProjectRepository projectRepository,
}) {
  if (sketchRepository is SafSketchRepository) {
    return null;
  }
  return UserVisibleSketchCatalogExporter(
    sketchRepository: sketchRepository,
    projectRepository: projectRepository,
  );
}

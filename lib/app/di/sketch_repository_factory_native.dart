import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/drift_sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/filesystem_sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/sketch_catalog_database.dart';

SketchRepository createSketchRepository() {
  return FilesystemSketchRepository(
    legacyRepository: DriftSketchRepository(SketchCatalogDatabase()),
  );
}

import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/web_local_storage_sketch_repository.dart';

SketchRepository createSketchRepository() {
  return WebLocalStorageSketchRepository();
}

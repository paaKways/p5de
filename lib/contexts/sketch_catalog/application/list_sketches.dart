import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';

class ListSketches {
  ListSketches(this._repository);

  final SketchRepository _repository;

  Future<List<Sketch>> call() async {
    return _repository.list();
  }
}

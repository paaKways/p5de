import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';

class SearchSketches {
  SearchSketches(this._repository);

  final SketchRepository _repository;

  Future<List<Sketch>> call(String query) async {
    return _repository.list(query: query);
  }
}

import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';

class ListFavoriteSketches {
  const ListFavoriteSketches(this._repository);

  final SketchRepository _repository;

  Future<List<Sketch>> call({String? query}) {
    return _repository.listFavorites(query: query);
  }
}

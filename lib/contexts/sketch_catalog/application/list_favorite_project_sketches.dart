import 'package:p5de/contexts/sketch_catalog/domain/project.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';

class ListFavoriteProjectSketches {
  const ListFavoriteProjectSketches(this._repository);

  final ProjectRepository _repository;

  Future<List<ProjectSketchMatch>> call({String? query}) {
    return _repository.listFavoriteSketches(query: query);
  }
}

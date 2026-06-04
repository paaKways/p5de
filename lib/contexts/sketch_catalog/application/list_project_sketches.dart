import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';

class ListProjectSketches {
  const ListProjectSketches(this._repository);

  final ProjectRepository _repository;

  Future<List<Sketch>> call(String projectId, {String? query}) {
    return _repository.listSketches(projectId, query: query);
  }
}

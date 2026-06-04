import 'package:p5de/contexts/sketch_catalog/domain/project.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';

class ListProjects {
  const ListProjects(this._repository);

  final ProjectRepository _repository;

  Future<List<Project>> call({String? query}) {
    return _repository.list(query: query);
  }
}

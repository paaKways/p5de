import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';

class DeleteProject {
  const DeleteProject(this._repository);

  final ProjectRepository _repository;

  Future<void> call(String projectId) {
    return _repository.deleteById(projectId);
  }
}

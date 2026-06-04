import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';

class RenameProject {
  const RenameProject(this._repository);

  final ProjectRepository _repository;

  Future<void> call({required String projectId, required String newName}) {
    return _repository.rename(projectId: projectId, newName: newName);
  }
}

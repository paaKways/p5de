import 'package:p5de/contexts/sketch_catalog/application/create_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/project_templates.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';

abstract class DefaultProjectSeedStore {
  Future<bool> isDefaultProjectSeedHandled(String seedKey);

  Future<void> markDefaultProjectSeedHandled(String seedKey);
}

class SeedDefaultProjects {
  const SeedDefaultProjects({
    required CreateProject createProject,
    required ProjectRepository projectRepository,
    required SketchRepository sketchRepository,
    required DefaultProjectSeedStore seedStore,
  }) : _createProject = createProject,
       _projectRepository = projectRepository,
       _sketchRepository = sketchRepository,
       _seedStore = seedStore;

  static const ProjectTemplate _defaultTemplate = ProjectTemplate.suacodeAfrica;

  final CreateProject _createProject;
  final ProjectRepository _projectRepository;
  final SketchRepository _sketchRepository;
  final DefaultProjectSeedStore _seedStore;

  Future<void> call({required bool hasExistingInstallEvidence}) async {
    final seedKey = _defaultTemplate.seedKey;
    if (seedKey == null ||
        await _seedStore.isDefaultProjectSeedHandled(seedKey)) {
      return;
    }

    if (hasExistingInstallEvidence || await _hasCatalogContent()) {
      await _seedStore.markDefaultProjectSeedHandled(seedKey);
      return;
    }

    try {
      await _createProject(
        name: _defaultTemplate.defaultProjectName ?? _defaultTemplate.label,
        template: _defaultTemplate,
      );
    } on DuplicateProjectNameException {
      // Treat a matching existing project as an already-handled seed.
    }

    await _seedStore.markDefaultProjectSeedHandled(seedKey);
  }

  Future<bool> _hasCatalogContent() async {
    if ((await _sketchRepository.list()).isNotEmpty) {
      return true;
    }
    return (await _projectRepository.list()).isNotEmpty;
  }
}

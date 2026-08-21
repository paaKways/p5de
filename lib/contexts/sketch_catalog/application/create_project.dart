import 'package:p5de/contexts/sketch_catalog/domain/project.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/application/project_templates.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:flutter/services.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';

enum ProjectCreationStage {
  creatingProject,
  loadingTemplate,
  preparingSketches,
  savingSketches,
  complete,
}

class ProjectCreationProgress {
  const ProjectCreationProgress({
    required this.stage,
    this.completed = 0,
    this.total = 0,
  });

  final ProjectCreationStage stage;
  final int completed;
  final int total;

  double? get value {
    if (stage != ProjectCreationStage.preparingSketches || total <= 0) {
      return null;
    }
    return completed / total;
  }

  String get label {
    switch (stage) {
      case ProjectCreationStage.creatingProject:
        return 'Creating folder...';
      case ProjectCreationStage.loadingTemplate:
        return 'Loading folder content...';
      case ProjectCreationStage.preparingSketches:
        return 'Loading sketch $completed of $total...';
      case ProjectCreationStage.savingSketches:
        return 'Adding $total sketches to folder...';
      case ProjectCreationStage.complete:
        return 'Folder ready.';
    }
  }
}

typedef ProjectCreationProgressCallback =
    void Function(ProjectCreationProgress progress);

class CreateProject {
  CreateProject(
    this._repository, {
    required Clock clock,
    required IdGenerator idGenerator,
    AssetBundle? bundle,
  }) : _clock = clock,
       _idGenerator = idGenerator,
       _bundle = bundle ?? rootBundle;

  final ProjectRepository _repository;
  final Clock _clock;
  final IdGenerator _idGenerator;
  final AssetBundle _bundle;

  Future<Project> call({
    required String name,
    ProjectTemplate template = ProjectTemplate.empty,
    ProjectCreationProgressCallback? onProgress,
  }) async {
    onProgress?.call(
      const ProjectCreationProgress(
        stage: ProjectCreationStage.creatingProject,
      ),
    );
    final project = await _repository.create(name: name);
    try {
      onProgress?.call(
        const ProjectCreationProgress(
          stage: ProjectCreationStage.loadingTemplate,
        ),
      );
      final bundledTemplate = await BundledProjectTemplate.load(
        template,
        bundle: _bundle,
      );
      if (bundledTemplate == null) {
        onProgress?.call(
          const ProjectCreationProgress(stage: ProjectCreationStage.complete),
        );
        return project;
      }

      final sketches = <Sketch>[];
      for (var index = 0; index < bundledTemplate.sketches.length; index++) {
        final sketchSeed = bundledTemplate.sketches[index];
        sketches.add(
          await sketchSeed.toSketch(
            bundle: _bundle,
            idGenerator: _idGenerator,
            clock: _clock,
            language: bundledTemplate.language,
            offset: index,
          ),
        );
        onProgress?.call(
          ProjectCreationProgress(
            stage: ProjectCreationStage.preparingSketches,
            completed: index + 1,
            total: bundledTemplate.sketches.length,
          ),
        );
      }

      onProgress?.call(
        ProjectCreationProgress(
          stage: ProjectCreationStage.savingSketches,
          completed: sketches.length,
          total: sketches.length,
        ),
      );
      await _repository.createSketches(project.id, sketches);
      onProgress?.call(
        ProjectCreationProgress(
          stage: ProjectCreationStage.complete,
          completed: sketches.length,
          total: sketches.length,
        ),
      );

      return project;
    } catch (_) {
      try {
        await _repository.deleteById(project.id);
      } catch (_) {
        // Preserve the original creation error. A cleanup failure is secondary.
      }
      rethrow;
    }
  }
}

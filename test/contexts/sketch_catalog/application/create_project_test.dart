import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/project_templates.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/in_memory_project_repository.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';

void main() {
  test('creation progress describes the folder work being performed', () {
    expect(
      const ProjectCreationProgress(
        stage: ProjectCreationStage.creatingProject,
      ).label,
      'Creating folder...',
    );
    expect(
      const ProjectCreationProgress(
        stage: ProjectCreationStage.loadingTemplate,
      ).label,
      'Loading folder content...',
    );
    expect(
      const ProjectCreationProgress(
        stage: ProjectCreationStage.preparingSketches,
        completed: 4,
        total: 29,
      ).label,
      'Loading sketch 4 of 29...',
    );
    expect(
      const ProjectCreationProgress(
        stage: ProjectCreationStage.savingSketches,
        completed: 29,
        total: 29,
      ).label,
      'Adding 29 sketches to folder...',
    );
    expect(
      const ProjectCreationProgress(stage: ProjectCreationStage.complete).label,
      'Folder ready.',
    );
  });

  test(
    'removes a partially created template folder when population fails',
    () async {
      final repository = _FailingProjectRepository();
      final createProject = CreateProject(
        repository,
        clock: _FixedClock(),
        idGenerator: _FixedIdGenerator(),
        bundle: _FakeAssetBundle({
          'assets/default_projects/suacode_africa/manifest.json': jsonEncode({
            'language': 'processing_java',
            'sketches': [
              {
                'name': 'intro',
                'asset':
                    'assets/default_projects/suacode_africa/sketches/Intro.pde',
              },
            ],
          }),
          'assets/default_projects/suacode_africa/sketches/Intro.pde':
              'void setup() {}',
        }),
      );

      await expectLater(
        createProject(
          name: 'SuaCode (Intro to Prog)',
          template: ProjectTemplate.suacodeAfrica,
        ),
        throwsStateError,
      );

      expect(await repository.list(), isEmpty);
    },
  );
}

class _FailingProjectRepository extends InMemoryProjectRepository {
  @override
  Future<void> createSketches(
    String projectId,
    Iterable<Sketch> newSketches,
  ) async {
    throw StateError('simulated SAF write failure');
  }
}

class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime.fromMillisecondsSinceEpoch(1000);
}

class _FixedIdGenerator implements IdGenerator {
  @override
  String newId() => 'sketch-id';
}

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) {
      throw StateError('Missing fake asset: $key');
    }
    final bytes = Uint8List.fromList(value.codeUnits);
    return ByteData.sublistView(bytes);
  }
}

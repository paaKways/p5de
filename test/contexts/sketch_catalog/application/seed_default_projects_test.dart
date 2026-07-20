import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/project_templates.dart';
import 'package:p5de/contexts/sketch_catalog/application/seed_default_projects.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/in_memory_project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/in_memory_sketch_repository.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';

void main() {
  group('SeedDefaultProjects', () {
    test('creates SuaCode Intro to Prog folder on first install', () async {
      final projectRepository = InMemoryProjectRepository();
      final seedStore = _MemoryDefaultProjectSeedStore();
      final seeder = _seeder(
        projectRepository: projectRepository,
        seedStore: seedStore,
      );

      await seeder(hasExistingInstallEvidence: false);

      final projects = await projectRepository.list();
      expect(projects, hasLength(1));
      expect(projects.single.name.value, 'SuaCode (Intro to Prog)');
      expect(projects.single.sketchCount, 2);
      expect(
        await seedStore.isDefaultProjectSeedHandled(
          ProjectTemplate.suacodeAfrica.seedKey!,
        ),
        isTrue,
      );
    });

    test('skips seeding when the seed was already handled', () async {
      final projectRepository = InMemoryProjectRepository();
      final seedStore = _MemoryDefaultProjectSeedStore();
      await seedStore.markDefaultProjectSeedHandled(
        ProjectTemplate.suacodeAfrica.seedKey!,
      );
      final seeder = _seeder(
        projectRepository: projectRepository,
        seedStore: seedStore,
      );

      await seeder(hasExistingInstallEvidence: false);

      expect(await projectRepository.list(), isEmpty);
    });

    test(
      'skips and marks handled when existing install storage is found',
      () async {
        final projectRepository = InMemoryProjectRepository();
        final seedStore = _MemoryDefaultProjectSeedStore();
        final seeder = _seeder(
          projectRepository: projectRepository,
          seedStore: seedStore,
        );

        await seeder(hasExistingInstallEvidence: true);

        expect(await projectRepository.list(), isEmpty);
        expect(
          await seedStore.isDefaultProjectSeedHandled(
            ProjectTemplate.suacodeAfrica.seedKey!,
          ),
          isTrue,
        );
      },
    );

    test('skips and marks handled when existing projects are found', () async {
      final projectRepository = InMemoryProjectRepository();
      await projectRepository.create(name: 'Existing Project');
      final seedStore = _MemoryDefaultProjectSeedStore();
      final seeder = _seeder(
        projectRepository: projectRepository,
        seedStore: seedStore,
      );

      await seeder(hasExistingInstallEvidence: false);

      final projects = await projectRepository.list();
      expect(projects, hasLength(1));
      expect(projects.single.name.value, 'Existing Project');
      expect(
        await seedStore.isDefaultProjectSeedHandled(
          ProjectTemplate.suacodeAfrica.seedKey!,
        ),
        isTrue,
      );
    });

    test(
      'skips and marks handled when standalone sketches are found',
      () async {
        final projectRepository = InMemoryProjectRepository();
        final sketchRepository = InMemorySketchRepository();
        await sketchRepository.create(
          Sketch(
            id: 'sketch-1',
            name: SketchName('Existing Sketch'),
            language: SketchLanguage.processingJava,
            code: 'void setup() {}',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
        final seedStore = _MemoryDefaultProjectSeedStore();
        final seeder = _seeder(
          projectRepository: projectRepository,
          sketchRepository: sketchRepository,
          seedStore: seedStore,
        );

        await seeder(hasExistingInstallEvidence: false);

        expect(await projectRepository.list(), isEmpty);
        expect(
          await seedStore.isDefaultProjectSeedHandled(
            ProjectTemplate.suacodeAfrica.seedKey!,
          ),
          isTrue,
        );
      },
    );
  });
}

SeedDefaultProjects _seeder({
  required InMemoryProjectRepository projectRepository,
  required _MemoryDefaultProjectSeedStore seedStore,
  InMemorySketchRepository? sketchRepository,
}) {
  return SeedDefaultProjects(
    createProject: CreateProject(
      projectRepository,
      clock: _FixedClock(),
      idGenerator: _IncrementalIdGenerator(),
      bundle: _FakeAssetBundle({
        'assets/default_projects/suacode_africa/manifest.json': jsonEncode({
          'language': 'processing_java',
          'sketches': [
            {
              'name': 'intro',
              'asset':
                  'assets/default_projects/suacode_africa/sketches/Intro.pde',
            },
            {
              'name': 'circle',
              'asset':
                  'assets/default_projects/suacode_africa/sketches/circle.pde',
            },
          ],
        }),
        'assets/default_projects/suacode_africa/sketches/Intro.pde':
            'void setup() {}',
        'assets/default_projects/suacode_africa/sketches/circle.pde':
            'void draw() {}',
      }),
    ),
    projectRepository: projectRepository,
    sketchRepository: sketchRepository ?? InMemorySketchRepository(),
    seedStore: seedStore,
  );
}

class _MemoryDefaultProjectSeedStore implements DefaultProjectSeedStore {
  final Set<String> _handledSeeds = {};

  @override
  Future<bool> isDefaultProjectSeedHandled(String seedKey) async {
    return _handledSeeds.contains(seedKey);
  }

  @override
  Future<void> markDefaultProjectSeedHandled(String seedKey) async {
    _handledSeeds.add(seedKey);
  }
}

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final value = _assets[key];
    if (value == null) {
      throw StateError('Missing test asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}

class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime.fromMillisecondsSinceEpoch(1000);
}

class _IncrementalIdGenerator implements IdGenerator {
  int _count = 0;

  @override
  String newId() {
    _count++;
    return 'id-$_count';
  }
}

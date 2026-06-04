import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/delete_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/delete_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_projects.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/rename_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/rename_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/search_project_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/search_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/filesystem_project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/filesystem_sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/project_scoped_sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/user_visible_sketch_mirror.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';

void main() {
  test('uses sketch folders as the native source of truth', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'p5de_filesystem_repo_test_',
    );

    try {
      final firstSessionRepository = FilesystemSketchRepository(
        rootDirectory: tempDir,
      );
      final createSketch = CreateSketch(
        repository: firstSessionRepository,
        idGenerator: _FixedIdGenerator('pong-id-1'),
        clock: _FixedClock(1700000000000),
      );
      final renameSketch = RenameSketch(
        repository: firstSessionRepository,
        clock: _FixedClock(1700000005000),
      );

      final created = await createSketch(
        name: 'Pong',
        language: SketchLanguage.processingJava,
        code: 'void setup() {}',
      );

      final createdFile = File('${tempDir.path}/Pong/Pong.pde');
      final metadataFile = File('${tempDir.path}/Pong/.p5de.json');
      expect(await createdFile.exists(), isTrue);
      expect(await createdFile.readAsString(), 'void setup() {}');
      expect(await metadataFile.exists(), isTrue);

      await renameSketch(sketchId: created.id, newName: 'Arcade Pong');

      expect(await Directory('${tempDir.path}/Pong').exists(), isFalse);
      expect(
        await File('${tempDir.path}/Arcade Pong/Arcade Pong.pde').exists(),
        isTrue,
      );
      expect(
        await File('${tempDir.path}/Arcade Pong/Pong.pde').exists(),
        isFalse,
      );

      final secondSessionRepository = FilesystemSketchRepository(
        rootDirectory: tempDir,
      );
      final listSketches = ListSketches(secondSessionRepository);
      final searchSketches = SearchSketches(secondSessionRepository);
      final deleteSketch = DeleteSketch(secondSessionRepository);

      final reopenedItems = await listSketches();
      expect(reopenedItems, hasLength(1));
      expect(reopenedItems.first.id, 'pong-id-1');
      expect(reopenedItems.first.name.value, 'Arcade Pong');
      expect(reopenedItems.first.language, SketchLanguage.processingJava);
      expect(reopenedItems.first.updatedAt, 1700000005000);

      final searchResults = await searchSketches('arcade');
      expect(searchResults, hasLength(1));
      expect(searchResults.first.id, 'pong-id-1');

      await deleteSketch('pong-id-1');
      expect(await listSketches(), isEmpty);
      expect(await Directory('${tempDir.path}/Arcade Pong').exists(), isFalse);
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  test('imports legacy mirrored Processing Java sketch folders', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'p5de_legacy_filesystem_repo_test_',
    );

    try {
      final legacyDir = Directory('${tempDir.path}/Legacy Pong');
      await legacyDir.create(recursive: true);
      await File(
        '${legacyDir.path}/Sketch.pde',
      ).writeAsString('void setup() { size(200, 200); }');

      final repository = FilesystemSketchRepository(rootDirectory: tempDir);
      final items = await ListSketches(repository)();

      expect(items, hasLength(1));
      expect(items.first.name.value, 'Legacy Pong');
      expect(items.first.language, SketchLanguage.processingJava);
      expect(items.first.code, 'void setup() { size(200, 200); }');
      expect(await File('${legacyDir.path}/.p5de.json').exists(), isTrue);
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  test('imports metadata-free p5.js sketch folders', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'p5de_missing_metadata_p5js_repo_test_',
    );

    try {
      final sketchDir = Directory('${tempDir.path}/Particles');
      await sketchDir.create(recursive: true);
      await File(
        '${sketchDir.path}/sketch.js',
      ).writeAsString('function setup() {}');

      final repository = FilesystemSketchRepository(rootDirectory: tempDir);
      final items = await ListSketches(repository)();

      expect(items, hasLength(1));
      expect(items.first.name.value, 'Particles');
      expect(items.first.language, SketchLanguage.p5js);
      expect(items.first.code, 'function setup() {}');
      expect(items.first.id, startsWith('fs_'));
      expect(await File('${sketchDir.path}/.p5de.json').exists(), isTrue);
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  test('writes created p5.js sketches with js extension', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'p5de_p5js_extension_repo_test_',
    );

    try {
      final repository = FilesystemSketchRepository(rootDirectory: tempDir);
      final createSketch = CreateSketch(
        repository: repository,
        idGenerator: _FixedIdGenerator('particles-id-1'),
        clock: _FixedClock(1700000000000),
      );

      await createSketch(
        name: 'Particles',
        language: SketchLanguage.p5js,
        code: 'function setup() {}',
      );

      final createdFile = File('${tempDir.path}/Particles/Particles.js');
      expect(await createdFile.exists(), isTrue);
      expect(await createdFile.readAsString(), 'function setup() {}');
      expect(
        await File('${tempDir.path}/Particles/sketch.js').exists(),
        isFalse,
      );
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  test(
    'imports metadata-free sketches with custom source file names',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'p5de_custom_source_name_repo_test_',
      );

      try {
        final sketchDir = Directory('${tempDir.path}/Screen Grapher');
        await sketchDir.create(recursive: true);
        await File(
          '${sketchDir.path}/screen_grapher.pde',
        ).writeAsString('void setup() { fullScreen(); }');

        final repository = FilesystemSketchRepository(rootDirectory: tempDir);
        final items = await ListSketches(repository)();

        expect(items, hasLength(1));
        expect(items.first.name.value, 'screen_grapher.pde');
        expect(items.first.language, SketchLanguage.processingJava);
        expect(items.first.code, 'void setup() { fullScreen(); }');
        expect(await File('${sketchDir.path}/.p5de.json').exists(), isTrue);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    },
  );

  test('recovers from invalid sketch metadata', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'p5de_invalid_metadata_repo_test_',
    );

    try {
      final sketchDir = Directory('${tempDir.path}/Recovered Pong');
      await sketchDir.create(recursive: true);
      await File(
        '${sketchDir.path}/Sketch.pde',
      ).writeAsString('void draw() { background(0); }');
      await File('${sketchDir.path}/.p5de.json').writeAsString('{bad json');

      final repository = FilesystemSketchRepository(rootDirectory: tempDir);
      final items = await ListSketches(repository)();

      expect(items, hasLength(1));
      expect(items.first.name.value, 'Recovered Pong');
      expect(items.first.language, SketchLanguage.processingJava);
      expect(items.first.code, 'void draw() { background(0); }');
      expect(items.first.id, startsWith('fs_'));
      expect(
        await File('${sketchDir.path}/.p5de.json').readAsString(),
        contains('"name":"Recovered Pong"'),
      );
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  test('migrates legacy sqlite sketches into folders once', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'p5de_filesystem_migration_test_',
    );

    try {
      final legacyRepository = _LegacySketchRepository([
        Sketch(
          id: 'legacy-id-1',
          name: SketchName('Migrated Pong'),
          language: SketchLanguage.processingJava,
          code: 'void draw() { background(0); }',
          createdAt: 10,
          updatedAt: 20,
        ),
      ]);
      final repository = FilesystemSketchRepository(
        rootDirectory: tempDir,
        legacyRepository: legacyRepository,
      );

      final migrated = await ListSketches(repository)();
      expect(migrated, hasLength(1));
      expect(migrated.first.id, 'legacy-id-1');
      expect(
        await File(
          '${tempDir.path}/Migrated Pong/Migrated Pong.pde',
        ).readAsString(),
        'void draw() { background(0); }',
      );
      expect(
        await File('${tempDir.path}/.p5de_sqlite_migrated').exists(),
        isTrue,
      );

      legacyRepository.sketches.clear();
      final afterLegacyCleared = await ListSketches(repository)();
      expect(afterLegacyCleared, hasLength(1));
      expect(afterLegacyCleared.first.name.value, 'Migrated Pong');
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  test('manages project folders and top-level project sketches', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'p5de_project_folder_repo_test_',
    );

    try {
      final projectRepository = FilesystemProjectRepository(
        rootDirectory: tempDir,
      );
      final createProject = CreateProject(
        projectRepository,
        clock: _FixedClock(1700000000000),
        idGenerator: _FixedIdGenerator('project-template-id'),
      );
      final renameProject = RenameProject(projectRepository);
      final deleteProject = DeleteProject(projectRepository);
      final listProjects = ListProjects(projectRepository);
      final searchProjectSketches = SearchProjectSketches(projectRepository);

      final project = await createProject(name: 'Arcade');
      expect(await Directory('${tempDir.path}/Arcade').exists(), isTrue);
      expect(
        () => createProject(name: 'arcade'),
        throwsA(isA<DuplicateProjectNameException>()),
      );

      final scopedSketchRepository = ProjectScopedSketchRepository(
        projectRepository: projectRepository,
        projectId: project.id,
      );
      final createSketch = CreateSketch(
        repository: scopedSketchRepository,
        idGenerator: _FixedIdGenerator('project-sketch-id-1'),
        clock: _FixedClock(1700000000000),
      );

      await createSketch(
        name: 'Pong',
        language: SketchLanguage.processingJava,
        code: 'void setup() {}',
      );
      await Directory(
        '${tempDir.path}/Arcade/Assets/Nested',
      ).create(recursive: true);
      await File(
        '${tempDir.path}/Arcade/Assets/Nested/Ignored.pde',
      ).writeAsString('void draw() {}');

      final sketches = await ListSketches(scopedSketchRepository)();
      expect(sketches, hasLength(1));
      expect(sketches.first.name.value, 'Pong');
      expect(
        await File('${tempDir.path}/Arcade/Pong/Pong.pde').readAsString(),
        'void setup() {}',
      );

      final projects = await listProjects();
      expect(projects, hasLength(1));
      expect(projects.first.name.value, 'Arcade');
      expect(projects.first.sketchCount, 1);

      final matches = await searchProjectSketches('pong');
      expect(matches, hasLength(1));
      expect(matches.first.project.name.value, 'Arcade');
      expect(matches.first.sketch.name.value, 'Pong');

      await renameProject(projectId: project.id, newName: 'Arcade Pack');
      expect(await Directory('${tempDir.path}/Arcade').exists(), isFalse);
      expect(await Directory('${tempDir.path}/Arcade Pack').exists(), isTrue);

      final renamedProject = (await listProjects()).single;
      await deleteProject(renamedProject.id);
      expect(await Directory('${tempDir.path}/Arcade Pack').exists(), isFalse);
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  test(
    'batch creates project sketches with one user-visible mirror sync',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'p5de_project_batch_repo_test_',
      );

      try {
        final mirror = _CountingUserVisibleSketchMirror();
        final projectRepository = FilesystemProjectRepository(
          rootDirectory: tempDir,
          userVisibleMirror: mirror,
        );
        final project = await projectRepository.create(name: 'Arcade');
        expect(mirror.syncCount, 1);

        await projectRepository.createSketches(project.id, [
          Sketch(
            id: 'project-sketch-id-1',
            name: SketchName('Project One'),
            language: SketchLanguage.processingJava,
            code: 'void setup() {}',
            createdAt: 1,
            updatedAt: 2,
          ),
          Sketch(
            id: 'project-sketch-id-2',
            name: SketchName('Project Two'),
            language: SketchLanguage.processingJava,
            code: 'void draw() {}',
            createdAt: 1,
            updatedAt: 3,
          ),
        ]);

        expect(mirror.syncCount, 2);
        expect(await projectRepository.listSketches(project.id), hasLength(2));
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    },
  );

  test('lists favourite standalone and project sketches directly', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'p5de_favourite_filesystem_repo_test_',
    );

    try {
      final sketchRepository = FilesystemSketchRepository(
        rootDirectory: tempDir,
      );
      await sketchRepository.create(
        Sketch(
          id: 'standalone-star',
          name: SketchName('Standalone Star'),
          language: SketchLanguage.processingJava,
          code: 'void setup() {}',
          createdAt: 1,
          updatedAt: 3,
          isFavorite: true,
        ),
      );
      await sketchRepository.create(
        Sketch(
          id: 'standalone-plain',
          name: SketchName('Standalone Plain'),
          language: SketchLanguage.processingJava,
          code: 'void draw() {}',
          createdAt: 1,
          updatedAt: 4,
        ),
      );

      final projectRepository = FilesystemProjectRepository(
        rootDirectory: tempDir,
      );
      final project = await projectRepository.create(name: 'Arcade');
      await projectRepository.createSketch(
        project.id,
        Sketch(
          id: 'project-star',
          name: SketchName('Project Star'),
          language: SketchLanguage.processingJava,
          code: 'void setup() {}',
          createdAt: 1,
          updatedAt: 5,
          isFavorite: true,
        ),
      );
      await projectRepository.createSketch(
        project.id,
        Sketch(
          id: 'project-plain',
          name: SketchName('Project Plain'),
          language: SketchLanguage.processingJava,
          code: 'void draw() {}',
          createdAt: 1,
          updatedAt: 6,
        ),
      );

      final standaloneFavorites = await sketchRepository.listFavorites();
      expect(standaloneFavorites, hasLength(1));
      expect(standaloneFavorites.single.name.value, 'Standalone Star');

      final projectFavorites = await projectRepository.listFavoriteSketches();
      expect(projectFavorites, hasLength(1));
      expect(projectFavorites.single.project.name.value, 'Arcade');
      expect(projectFavorites.single.sketch.name.value, 'Project Star');

      final queriedProjectFavorites = await projectRepository
          .listFavoriteSketches(query: 'star');
      expect(queriedProjectFavorites, hasLength(1));
      expect(
        await projectRepository.listFavoriteSketches(query: 'plain'),
        isEmpty,
      );
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}

class _FixedClock implements Clock {
  _FixedClock(this._epochMs);

  final int _epochMs;

  @override
  DateTime now() => DateTime.fromMillisecondsSinceEpoch(_epochMs);
}

class _FixedIdGenerator implements IdGenerator {
  _FixedIdGenerator(this._id);

  final String _id;

  @override
  String newId() => _id;
}

class _CountingUserVisibleSketchMirror implements UserVisibleSketchMirror {
  int syncCount = 0;

  @override
  Future<void> syncFrom(Directory sourceDirectory) async {
    syncCount += 1;
  }
}

class _LegacySketchRepository implements SketchRepository {
  _LegacySketchRepository(this.sketches);

  final List<Sketch> sketches;

  @override
  Future<void> create(Sketch sketch) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteById(String sketchId) {
    throw UnimplementedError();
  }

  @override
  Future<bool> existsByNormalizedName(
    String normalizedName, {
    String? excludingSketchId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Sketch?> findById(String sketchId) {
    throw UnimplementedError();
  }

  @override
  Future<List<Sketch>> list({String? query}) async {
    return sketches;
  }

  @override
  Future<List<Sketch>> listFavorites({String? query}) async {
    return sketches
        .where((sketch) => sketch.isFavorite)
        .toList(growable: false);
  }

  @override
  Future<void> update(Sketch sketch) {
    throw UnimplementedError();
  }
}

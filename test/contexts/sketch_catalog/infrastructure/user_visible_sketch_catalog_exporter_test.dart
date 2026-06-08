import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/sketch_catalog/application/sketch_catalog_exporter.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/in_memory_project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/in_memory_sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/user_visible_sketch_catalog_exporter.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/user_visible_sketch_mirror.dart';

void main() {
  test('exports sketches to staging and invokes user-visible mirror', () async {
    final tempDir = await Directory.systemTemp.createTemp('p5de_export_test_');
    final stagingRoot = Directory('${tempDir.path}/staging/sketches');
    final mirror = _RecordingSketchMirror();
    final sketchRepository = InMemorySketchRepository();
    final projectRepository = InMemoryProjectRepository();

    try {
      await sketchRepository.create(
        Sketch(
          id: 'standalone-1',
          name: SketchName('Standalone Sketch'),
          language: SketchLanguage.processingJava,
          code: 'void setup() {}',
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
        ),
      );
      final project = await projectRepository.create(name: 'SuaCode Africa');
      await projectRepository.createSketch(
        project.id,
        Sketch(
          id: 'project-sketch-1',
          name: SketchName('Map View'),
          language: SketchLanguage.p5js,
          code: 'function setup() {}',
          createdAt: 1700000001000,
          updatedAt: 1700000001000,
        ),
      );

      final exporter = UserVisibleSketchCatalogExporter(
        sketchRepository: sketchRepository,
        projectRepository: projectRepository,
        mirror: mirror,
        stagingRoot: stagingRoot,
      );

      final exportedPath = await exporter.exportAll();

      expect(exportedPath, 'Download/SuaCode IDE/sketches');
      expect(mirror.syncedSource?.path, stagingRoot.path);
      await expectLater(
        File(
          '${stagingRoot.path}/SuaCode Africa/Map View/Map View.js',
        ).readAsString(),
        completion('function setup() {}'),
      );
      await expectLater(
        File(
          '${stagingRoot.path}/Standalone Sketch/Standalone Sketch.pde',
        ).readAsString(),
        completion('void setup() {}'),
      );
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  test('exports only selected sketches to staging', () async {
    final tempDir = await Directory.systemTemp.createTemp('p5de_export_test_');
    final stagingRoot = Directory('${tempDir.path}/staging/sketches');
    final mirror = _RecordingSketchMirror();
    final sketchRepository = InMemorySketchRepository();
    final projectRepository = InMemoryProjectRepository();

    try {
      final standalone = Sketch(
        id: 'standalone-1',
        name: SketchName('Standalone Sketch'),
        language: SketchLanguage.processingJava,
        code: 'void setup() {}',
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
      );
      await sketchRepository.create(standalone);
      final project = await projectRepository.create(name: 'SuaCode Africa');
      final selectedProjectSketch = Sketch(
        id: 'project-sketch-1',
        name: SketchName('Map View'),
        language: SketchLanguage.p5js,
        code: 'function setup() {}',
        createdAt: 1700000001000,
        updatedAt: 1700000001000,
      );
      final unselectedProjectSketch = Sketch(
        id: 'project-sketch-2',
        name: SketchName('Hidden View'),
        language: SketchLanguage.p5js,
        code: 'function draw() {}',
        createdAt: 1700000002000,
        updatedAt: 1700000002000,
      );
      await projectRepository.createSketches(project.id, [
        selectedProjectSketch,
        unselectedProjectSketch,
      ]);

      final exporter = UserVisibleSketchCatalogExporter(
        sketchRepository: sketchRepository,
        projectRepository: projectRepository,
        mirror: mirror,
        stagingRoot: stagingRoot,
      );

      final exportedPath = await exporter.exportItems([
        SketchCatalogExportItem.standalone(standalone),
        SketchCatalogExportItem.project(
          project: project,
          sketch: selectedProjectSketch,
        ),
      ]);

      expect(exportedPath, 'Download/SuaCode IDE/sketches');
      expect(mirror.syncedSource?.path, stagingRoot.path);
      expect(
        await File(
          '${stagingRoot.path}/Standalone Sketch/Standalone Sketch.pde',
        ).exists(),
        isTrue,
      );
      expect(
        await File(
          '${stagingRoot.path}/SuaCode Africa/Map View/Map View.js',
        ).exists(),
        isTrue,
      );
      expect(
        await File(
          '${stagingRoot.path}/SuaCode Africa/Hidden View/Hidden View.js',
        ).exists(),
        isFalse,
      );
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}

class _RecordingSketchMirror implements UserVisibleSketchMirror {
  Directory? syncedSource;

  @override
  Future<void> syncFrom(Directory sourceDirectory) async {
    syncedSource = sourceDirectory;
  }
}

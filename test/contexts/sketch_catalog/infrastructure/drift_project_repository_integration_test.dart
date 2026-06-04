import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/drift_project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/sketch_catalog_database.dart';

void main() {
  test(
    'persists projects and project sketches across database reopen',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'p5de_drift_project_test_',
      );
      final dbFile = File('${tempDir.path}/catalog.sqlite');

      try {
        final firstSessionDb = SketchCatalogDatabase(
          executor: NativeDatabase.createInBackground(dbFile),
        );
        final firstSessionRepository = DriftProjectRepository(firstSessionDb);

      final project = await firstSessionRepository.create(
        name: 'SuaCode Africa',
      );
      await firstSessionRepository.createSketch(
        project.id,
        Sketch(
          id: 'project-sketch-1',
          name: SketchName('Map View'),
          language: SketchLanguage.p5js,
            code: 'function setup() {}',
            createdAt: 1700000000000,
            updatedAt: 1700000000000,
          ),
        );

        await firstSessionDb.close();

        final secondSessionDb = SketchCatalogDatabase(
          executor: NativeDatabase.createInBackground(dbFile),
        );
        final secondSessionRepository = DriftProjectRepository(secondSessionDb);

        final reopenedProject = await secondSessionRepository.findById(
          project.id,
        );
        expect(reopenedProject, isNotNull);
        expect(reopenedProject!.name.value, 'SuaCode Africa');
        expect(reopenedProject.sketchCount, 1);

        final sketches = await secondSessionRepository.listSketches(project.id);
        expect(sketches, hasLength(1));
        expect(sketches.first.name.value, 'Map View');
        expect(sketches.first.language, SketchLanguage.p5js);

        await secondSessionRepository.rename(
          projectId: project.id,
          newName: 'Renamed Africa',
        );
        final renamedProject = await secondSessionRepository.findById(
          project.id,
        );
        expect(renamedProject, isNotNull);
        expect(renamedProject!.name.value, 'Renamed Africa');

        final favoriteSketch = sketches.first.copyWith(isFavorite: true);
        await secondSessionRepository.updateSketch(project.id, favoriteSketch);
        final favorites = await secondSessionRepository.listFavoriteSketches();
        expect(favorites, hasLength(1));
        expect(favorites.first.project.id, project.id);
        expect(favorites.first.sketch.id, favoriteSketch.id);

      await expectLater(
        secondSessionRepository.create(name: 'Renamed Africa'),
        throwsA(isA<DuplicateProjectNameException>()),
      );

        await secondSessionDb.close();
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    },
  );
}

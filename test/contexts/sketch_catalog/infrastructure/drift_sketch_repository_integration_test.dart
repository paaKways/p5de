import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/delete_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/rename_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/search_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/drift_sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/native_sketch_file_store.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/sketch_catalog_database.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';

void main() {
  test('persists sketches across database reopen', () async {
    final tempDir = await Directory.systemTemp.createTemp('p5de_drift_test_');
    final dbFile = File('${tempDir.path}/catalog.sqlite');

    try {
      final firstSessionDb = SketchCatalogDatabase(
        executor: NativeDatabase.createInBackground(dbFile),
      );
      final firstSessionRepository = DriftSketchRepository(firstSessionDb);
      final createSketch = CreateSketch(
        repository: firstSessionRepository,
        idGenerator: _FixedIdGenerator('persist-id-1'),
        clock: _FixedClock(1700000000000),
      );
      final renameSketch = RenameSketch(
        repository: firstSessionRepository,
        clock: _FixedClock(1700000005000),
      );

      final created = await createSketch(
        name: 'Persistent Sketch',
        language: SketchLanguage.processingJava,
      );
      await renameSketch(sketchId: created.id, newName: 'Renamed Sketch');

      final listSketchesSession1 = ListSketches(firstSessionRepository);
      final session1Items = await listSketchesSession1();
      expect(session1Items, hasLength(1));
      expect(session1Items.first.name.value, 'Renamed Sketch');

      await firstSessionDb.close();

      // Re-open the same file to verify persisted state survives app restart.
      final secondSessionDb = SketchCatalogDatabase(
        executor: NativeDatabase.createInBackground(dbFile),
      );
      final secondSessionRepository = DriftSketchRepository(secondSessionDb);

      final listSketchesSession2 = ListSketches(secondSessionRepository);
      final searchSketchesSession2 = SearchSketches(secondSessionRepository);
      final deleteSketchSession2 = DeleteSketch(secondSessionRepository);

      final reopenedItems = await listSketchesSession2();
      expect(reopenedItems, hasLength(1));
      expect(reopenedItems.first.id, created.id);
      expect(reopenedItems.first.name.value, 'Renamed Sketch');
      expect(reopenedItems.first.language, SketchLanguage.processingJava);

      final searchResults = await searchSketchesSession2('renamed');
      expect(searchResults, hasLength(1));
      expect(searchResults.first.id, created.id);

      await deleteSketchSession2(created.id);
      final emptyAfterDelete = await listSketchesSession2();
      expect(emptyAfterDelete, isEmpty);

      await secondSessionDb.close();
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  test('mirrors native sketches to disk files', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'p5de_file_store_test_',
    );
    final dbFile = File('${tempDir.path}/catalog.sqlite');
    final sketchesDir = Directory('${tempDir.path}/sketches');

    try {
      final database = SketchCatalogDatabase(
        executor: NativeDatabase.createInBackground(dbFile),
      );
      final repository = DriftSketchRepository(
        database,
        fileStore: NativeSketchFileStore(rootDirectory: sketchesDir),
      );
      final createSketch = CreateSketch(
        repository: repository,
        idGenerator: _FixedIdGenerator('file-id-1'),
        clock: _FixedClock(1700000000000),
      );
      final renameSketch = RenameSketch(
        repository: repository,
        clock: _FixedClock(1700000005000),
      );
      final deleteSketch = DeleteSketch(repository);

      final created = await createSketch(
        name: 'Disk Sketch',
        language: SketchLanguage.processingJava,
        code: 'void setup() {}',
      );

      final createdFile = File('${sketchesDir.path}/Disk Sketch/Sketch.pde');
      expect(await createdFile.exists(), isTrue);
      expect(await createdFile.readAsString(), 'void setup() {}');

      await renameSketch(sketchId: created.id, newName: 'Renamed Disk Sketch');

      final oldDirectory = Directory('${sketchesDir.path}/Disk Sketch');
      final renamedFile = File(
        '${sketchesDir.path}/Renamed Disk Sketch/Sketch.pde',
      );
      expect(await oldDirectory.exists(), isFalse);
      expect(await renamedFile.exists(), isTrue);
      expect(await renamedFile.readAsString(), 'void setup() {}');

      await deleteSketch(created.id);
      expect(
        await Directory('${sketchesDir.path}/Renamed Disk Sketch').exists(),
        isFalse,
      );

      await database.close();
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

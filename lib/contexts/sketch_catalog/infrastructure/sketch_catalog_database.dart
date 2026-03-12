import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

part 'sketch_catalog_database.g.dart';

@DataClassName('SketchEntry')
class SketchEntries extends Table {
  @override
  String get tableName => 'sketches';

  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get nameNormalized => text().named('name_normalized')();

  TextColumn get code => text()();

  IntColumn get createdAt => integer().named('created_at')();

  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {nameNormalized},
      ];
}

@DriftAccessor(tables: [SketchEntries])
class SketchDao extends DatabaseAccessor<SketchCatalogDatabase>
    with _$SketchDaoMixin {
  SketchDao(super.db);

  Future<void> insertSketch(SketchEntriesCompanion companion) {
    return into(sketchEntries).insert(companion);
  }

  Future<void> updateSketch(SketchEntriesCompanion companion) {
    return update(sketchEntries).replace(companion);
  }

  Future<void> deleteSketchById(String sketchId) {
    return (delete(
      sketchEntries,
    )..where((tbl) => tbl.id.equals(sketchId))).go();
  }

  Future<SketchEntry?> findById(String sketchId) {
    return (select(
      sketchEntries,
    )..where((tbl) => tbl.id.equals(sketchId))).getSingleOrNull();
  }

  Future<SketchEntry?> findByNormalizedName(String normalizedName) {
    return (select(sketchEntries)
          ..where((tbl) => tbl.nameNormalized.equals(normalizedName)))
        .getSingleOrNull();
  }

  Future<List<SketchEntry>> list({String? query}) {
    final statement = select(sketchEntries)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);
    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim().toLowerCase()}%';
      statement.where((tbl) => tbl.nameNormalized.like(q));
    }
    return statement.get();
  }
}

@DriftDatabase(tables: [SketchEntries], daos: [SketchDao])
class SketchCatalogDatabase extends _$SketchCatalogDatabase {
  SketchCatalogDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) async => m.createAll());
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/p5de.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}

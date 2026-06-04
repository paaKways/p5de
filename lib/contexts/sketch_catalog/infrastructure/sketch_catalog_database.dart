import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

part 'sketch_catalog_database.g.dart';

// Drift table that persists the sketch aggregate in local SQLite.
@DataClassName('SketchEntry')
class SketchEntries extends Table {
  @override
  String get tableName => 'sketches';

  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get nameNormalized => text().named('name_normalized')();

  TextColumn get language => text().withDefault(const Constant('p5js'))();

  TextColumn get code => text()();

  IntColumn get createdAt => integer().named('created_at')();

  IntColumn get updatedAt => integer().named('updated_at')();

  BoolColumn get isFavorite =>
      boolean().named('is_favorite').withDefault(const Constant(false))();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  @override
  // Enforce case-insensitive uniqueness via pre-normalized value.
  List<Set<Column>> get uniqueKeys => [
    {nameNormalized},
  ];
}

@DataClassName('ProjectEntry')
class ProjectEntries extends Table {
  @override
  String get tableName => 'projects';

  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get nameNormalized => text().named('name_normalized')();

  IntColumn get createdAt => integer().named('created_at')();

  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {nameNormalized},
  ];
}

@DataClassName('ProjectSketchEntry')
class ProjectSketchEntries extends Table {
  @override
  String get tableName => 'project_sketches';

  TextColumn get id => text()();

  TextColumn get projectId =>
      text().named('project_id').references(ProjectEntries, #id)();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get nameNormalized => text().named('name_normalized')();

  TextColumn get language => text().withDefault(const Constant('p5js'))();

  TextColumn get code => text()();

  IntColumn get createdAt => integer().named('created_at')();

  IntColumn get updatedAt => integer().named('updated_at')();

  BoolColumn get isFavorite =>
      boolean().named('is_favorite').withDefault(const Constant(false))();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {projectId, nameNormalized},
  ];
}

// DAO encapsulates SQL queries so repository code stays mapping-focused.
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
    // Most recently updated sketches first for catalog UX.
    final statement = select(sketchEntries)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);
    if (query != null && query.trim().isNotEmpty) {
      // Query runs on normalized name for case-insensitive matching.
      final q = '%${query.trim().toLowerCase()}%';
      statement.where((tbl) => tbl.nameNormalized.like(q));
    }
    return statement.get();
  }

  Future<List<SketchEntry>> listFavorites({String? query}) {
    final statement = select(sketchEntries)
      ..where((tbl) => tbl.isFavorite.equals(true))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);
    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim().toLowerCase()}%';
      statement.where((tbl) => tbl.nameNormalized.like(q));
    }
    return statement.get();
  }
}

@DriftAccessor(tables: [ProjectEntries, ProjectSketchEntries])
class ProjectDao extends DatabaseAccessor<SketchCatalogDatabase>
    with _$ProjectDaoMixin {
  ProjectDao(super.db);

  Future<void> insertProject(ProjectEntriesCompanion companion) {
    return into(projectEntries).insert(companion);
  }

  Future<void> updateProject(ProjectEntriesCompanion companion) {
    return update(projectEntries).replace(companion);
  }

  Future<void> deleteProjectById(String projectId) {
    return transaction(() async {
      await (delete(
        projectSketchEntries,
      )..where((tbl) => tbl.projectId.equals(projectId))).go();
      await (delete(
        projectEntries,
      )..where((tbl) => tbl.id.equals(projectId))).go();
    });
  }

  Future<ProjectEntry?> findProjectById(String projectId) {
    return (select(
      projectEntries,
    )..where((tbl) => tbl.id.equals(projectId))).getSingleOrNull();
  }

  Future<ProjectEntry?> findProjectByNormalizedName(String normalizedName) {
    return (select(projectEntries)
          ..where((tbl) => tbl.nameNormalized.equals(normalizedName)))
        .getSingleOrNull();
  }

  Future<List<ProjectEntry>> listProjects({String? query}) {
    final statement = select(projectEntries)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);
    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim().toLowerCase()}%';
      statement.where((tbl) => tbl.nameNormalized.like(q));
    }
    return statement.get();
  }

  Future<int> countSketches(String projectId) async {
    final countExpression = projectSketchEntries.id.count();
    final row =
        await (selectOnly(projectSketchEntries)
              ..addColumns([countExpression])
              ..where(projectSketchEntries.projectId.equals(projectId)))
            .getSingle();
    return row.read(countExpression) ?? 0;
  }

  Future<void> insertProjectSketch(ProjectSketchEntriesCompanion companion) {
    return into(projectSketchEntries).insert(companion);
  }

  Future<void> insertProjectSketches(
    Iterable<ProjectSketchEntriesCompanion> companions,
  ) {
    return batch((batch) {
      batch.insertAll(projectSketchEntries, companions);
    });
  }

  Future<void> updateProjectSketch(ProjectSketchEntriesCompanion companion) {
    return update(projectSketchEntries).replace(companion);
  }

  Future<void> deleteProjectSketchById(String projectId, String sketchId) {
    return (delete(projectSketchEntries)..where(
          (tbl) => tbl.projectId.equals(projectId) & tbl.id.equals(sketchId),
        ))
        .go();
  }

  Future<ProjectSketchEntry?> findProjectSketchById(
    String projectId,
    String sketchId,
  ) {
    return (select(projectSketchEntries)..where(
          (tbl) => tbl.projectId.equals(projectId) & tbl.id.equals(sketchId),
        ))
        .getSingleOrNull();
  }

  Future<ProjectSketchEntry?> findProjectSketchByNormalizedName(
    String projectId,
    String normalizedName,
  ) {
    return (select(projectSketchEntries)..where(
          (tbl) =>
              tbl.projectId.equals(projectId) &
              tbl.nameNormalized.equals(normalizedName),
        ))
        .getSingleOrNull();
  }

  Future<List<ProjectSketchEntry>> listProjectSketches(
    String projectId, {
    String? query,
  }) {
    final statement = select(projectSketchEntries)
      ..where((tbl) => tbl.projectId.equals(projectId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);
    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim().toLowerCase()}%';
      statement.where((tbl) => tbl.nameNormalized.like(q));
    }
    return statement.get();
  }

  Future<List<ProjectSketchEntry>> listFavoriteProjectSketches({
    String? query,
  }) {
    final statement = select(projectSketchEntries)
      ..where((tbl) => tbl.isFavorite.equals(true))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);
    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim().toLowerCase()}%';
      statement.where((tbl) => tbl.nameNormalized.like(q));
    }
    return statement.get();
  }

  Future<List<ProjectSketchEntry>> searchProjectSketches(String query) {
    final q = '%${query.trim().toLowerCase()}%';
    return (select(projectSketchEntries)
          ..where((tbl) => tbl.nameNormalized.like(q))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .get();
  }
}

@DriftDatabase(
  tables: [SketchEntries, ProjectEntries, ProjectSketchEntries],
  daos: [SketchDao, ProjectDao],
)
class SketchCatalogDatabase extends _$SketchCatalogDatabase {
  SketchCatalogDatabase({QueryExecutor? executor})
    : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(sketchEntries, sketchEntries.language);
      }
      if (from < 3) {
        await m.addColumn(sketchEntries, sketchEntries.isFavorite);
      }
      if (from < 4) {
        await m.createTable(projectEntries);
        await m.createTable(projectSketchEntries);
      }
    },
  );
}

LazyDatabase _openConnection() {
  // Lazy init avoids touching file system until first DB operation.
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/p5de.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}

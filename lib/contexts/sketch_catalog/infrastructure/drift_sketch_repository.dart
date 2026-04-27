import 'package:drift/drift.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/sketch_catalog_database.dart';

// Repository adapter between domain contracts and Drift persistence.
class DriftSketchRepository implements SketchRepository {
  DriftSketchRepository(this._database);

  final SketchCatalogDatabase _database;

  SketchDao get _dao => _database.sketchDao;

  @override
  Future<void> create(Sketch sketch) async {
    await _dao.insertSketch(_toCompanion(sketch));
  }

  @override
  Future<void> update(Sketch sketch) async {
    await _dao.updateSketch(_toCompanion(sketch));
  }

  @override
  Future<void> deleteById(String sketchId) async {
    await _dao.deleteSketchById(sketchId);
  }

  @override
  Future<Sketch?> findById(String sketchId) async {
    final row = await _dao.findById(sketchId);
    if (row == null) {
      return null;
    }
    return _toDomain(row);
  }

  @override
  Future<List<Sketch>> list({String? query}) async {
    final rows = await _dao.list(query: query);
    // Keep domain layer independent from generated Drift row types.
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<bool> existsByNormalizedName(
    String normalizedName, {
    String? excludingSketchId,
  }) async {
    // Exclusion is used during rename to ignore the current sketch row.
    final row = await _dao.findByNormalizedName(normalizedName);
    if (row == null) {
      return false;
    }
    if (excludingSketchId == null) {
      return true;
    }
    return row.id != excludingSketchId;
  }

  SketchEntriesCompanion _toCompanion(Sketch sketch) {
    // Persist normalized name to support case-insensitive uniqueness/search.
    return SketchEntriesCompanion(
      id: Value(sketch.id),
      name: Value(sketch.name.value),
      nameNormalized: Value(sketch.name.normalized),
      language: Value(sketch.language.storageValue),
      code: Value(sketch.code),
      createdAt: Value(sketch.createdAt),
      updatedAt: Value(sketch.updatedAt),
    );
  }

  Sketch _toDomain(SketchEntry row) {
    return Sketch(
      id: row.id,
      name: SketchName(row.name),
      language: SketchLanguage.fromStorageValue(row.language),
      code: row.code,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

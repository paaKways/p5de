import 'package:drift/drift.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/sketch_catalog_database.dart';

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
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<bool> existsByNormalizedName(
    String normalizedName, {
    String? excludingSketchId,
  }) async {
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
    return SketchEntriesCompanion(
      id: Value(sketch.id),
      name: Value(sketch.name.value),
      nameNormalized: Value(sketch.name.normalized),
      code: Value(sketch.code),
      createdAt: Value(sketch.createdAt),
      updatedAt: Value(sketch.updatedAt),
    );
  }

  Sketch _toDomain(SketchEntry row) {
    return Sketch(
      id: row.id,
      name: SketchName(row.name),
      code: row.code,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

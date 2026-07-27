import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/saf_catalog_store.dart';

class SafSketchRepository implements SketchRepository {
  const SafSketchRepository(this._store);

  final SafCatalogStore _store;

  @override
  Future<void> create(Sketch sketch) => _store.createStandaloneSketch(sketch);

  @override
  Future<void> update(Sketch sketch) => _store.updateStandaloneSketch(sketch);

  @override
  Future<void> deleteById(String sketchId) =>
      _store.deleteStandaloneSketch(sketchId);

  @override
  Future<Sketch?> findById(String sketchId) =>
      _store.findStandaloneSketch(sketchId);

  @override
  Future<List<Sketch>> list({String? query}) =>
      _store.listStandaloneSketches(query: query);

  @override
  Future<List<Sketch>> listFavorites({String? query}) async {
    return (await list(
      query: query,
    )).where((sketch) => sketch.isFavorite).toList(growable: false);
  }

  @override
  Future<bool> existsByNormalizedName(
    String normalizedName, {
    String? excludingSketchId,
  }) {
    return _store.standaloneNameExists(
      normalizedName,
      excludingSketchId: excludingSketchId,
    );
  }
}

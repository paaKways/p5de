import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';

// Web/dev repository backed by process memory only.
class InMemorySketchRepository implements SketchRepository {
  final List<Sketch> _items = [];

  @override
  Future<void> create(Sketch sketch) async {
    _items.add(sketch);
  }

  @override
  Future<void> update(Sketch sketch) async {
    final index = _items.indexWhere((item) => item.id == sketch.id);
    if (index < 0) {
      throw SketchNotFoundException();
    }
    _items[index] = sketch;
  }

  @override
  Future<void> deleteById(String sketchId) async {
    _items.removeWhere((item) => item.id == sketchId);
  }

  @override
  Future<Sketch?> findById(String sketchId) async {
    for (final item in _items) {
      if (item.id == sketchId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<Sketch>> list({String? query}) async {
    var output = List<Sketch>.from(_items);
    if (query != null && query.trim().isNotEmpty) {
      final normalized = query.trim().toLowerCase();
      output = output
          .where((item) => item.name.normalized.contains(normalized))
          .toList(growable: false);
    }
    output.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return output;
  }

  @override
  Future<List<Sketch>> listFavorites({String? query}) async {
    final normalized = query?.trim().toLowerCase();
    final output = _items
        .where((item) {
          if (!item.isFavorite) {
            return false;
          }
          return normalized == null ||
              normalized.isEmpty ||
              item.name.normalized.contains(normalized);
        })
        .toList(growable: false);
    output.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return output;
  }

  @override
  Future<bool> existsByNormalizedName(
    String normalizedName, {
    String? excludingSketchId,
  }) async {
    return _items.any((item) {
      if (excludingSketchId != null && item.id == excludingSketchId) {
        return false;
      }
      return item.name.normalized == normalizedName;
    });
  }
}

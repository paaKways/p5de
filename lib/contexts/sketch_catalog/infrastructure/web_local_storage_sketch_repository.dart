import 'dart:convert';

import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/web_local_storage_project_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kSketchCatalogWebStorageKey = 'p5de.sketch_catalog.v1';

int _webStorageVersion = 0;

Future<void> clearSketchCatalogWebStorage() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kSketchCatalogWebStorageKey);
  await prefs.remove(kProjectCatalogWebStorageKey);
  _webStorageVersion++;
  markProjectCatalogWebStorageCleared();
}

// Web repository backed by browser storage via shared_preferences.
class WebLocalStorageSketchRepository implements SketchRepository {
  WebLocalStorageSketchRepository();

  static const String _storageKey = kSketchCatalogWebStorageKey;
  final List<Sketch> _items = [];
  int _loadedVersion = -1;

  @override
  Future<void> create(Sketch sketch) async {
    await _ensureLoaded();
    _items.add(sketch);
    await _persist();
  }

  @override
  Future<void> update(Sketch sketch) async {
    await _ensureLoaded();
    final index = _items.indexWhere((item) => item.id == sketch.id);
    if (index < 0) {
      throw SketchNotFoundException();
    }
    _items[index] = sketch;
    await _persist();
  }

  @override
  Future<void> deleteById(String sketchId) async {
    await _ensureLoaded();
    _items.removeWhere((item) => item.id == sketchId);
    await _persist();
  }

  @override
  Future<Sketch?> findById(String sketchId) async {
    await _ensureLoaded();
    for (final item in _items) {
      if (item.id == sketchId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<Sketch>> list({String? query}) async {
    await _ensureLoaded();
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
    await _ensureLoaded();
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
    await _ensureLoaded();
    return _items.any((item) {
      if (excludingSketchId != null && item.id == excludingSketchId) {
        return false;
      }
      return item.name.normalized == normalizedName;
    });
  }

  Future<void> _ensureLoaded() async {
    // Reload when storage was cleared externally through debug action.
    if (_loadedVersion == _webStorageVersion) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _items.clear();

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items.addAll(
            decoded.whereType<Map>().map((entry) {
              final map = entry.cast<String, Object?>();
              return Sketch(
                id: map['id'] as String,
                name: SketchName(map['name'] as String),
                language: SketchLanguage.fromStorageValue(
                  map['language'] as String? ??
                      SketchLanguage.p5js.storageValue,
                ),
                code: map['code'] as String,
                createdAt: map['createdAt'] as int,
                updatedAt: map['updatedAt'] as int,
                isFavorite: map['isFavorite'] as bool? ?? false,
              );
            }),
          );
        }
      } catch (_) {
        // Ignore corrupted storage and keep empty in-memory state.
        _items.clear();
      }
    }

    _loadedVersion = _webStorageVersion;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _items
        .map(
          (item) => <String, Object>{
            'id': item.id,
            'name': item.name.value,
            'language': item.language.storageValue,
            'code': item.code,
            'createdAt': item.createdAt,
            'updatedAt': item.updatedAt,
            'isFavorite': item.isFavorite,
          },
        )
        .toList(growable: false);
    await prefs.setString(_storageKey, jsonEncode(payload));
    _loadedVersion = _webStorageVersion;
  }
}

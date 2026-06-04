import 'dart:convert';

import 'package:p5de/contexts/sketch_catalog/domain/project.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kProjectCatalogWebStorageKey = 'p5de.project_catalog.v1';

int _projectWebStorageVersion = 0;

void markProjectCatalogWebStorageCleared() {
  _projectWebStorageVersion++;
}

class WebLocalStorageProjectRepository implements ProjectRepository {
  static const String _storageKey = kProjectCatalogWebStorageKey;

  final Map<String, Project> _projects = {};
  final Map<String, List<Sketch>> _sketchesByProjectId = {};
  int _loadedVersion = -1;

  @override
  Future<Project> create({required String name}) async {
    await _ensureLoaded();
    final projectName = SketchName(name);
    if (_existsByNormalizedName(projectName.normalized)) {
      throw DuplicateProjectNameException();
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final project = Project(
      id: _projectIdFor(projectName),
      name: projectName,
      createdAt: now,
      updatedAt: now,
      sketchCount: 0,
    );
    _projects[project.id] = project;
    _sketchesByProjectId[project.id] = [];
    await _persist();
    return project;
  }

  @override
  Future<void> rename({
    required String projectId,
    required String newName,
  }) async {
    await _ensureLoaded();
    final existing = _projects[projectId];
    if (existing == null) {
      throw ProjectNotFoundException();
    }
    final projectName = SketchName(newName);
    if (_existsByNormalizedName(
      projectName.normalized,
      excludingProjectId: projectId,
    )) {
      throw DuplicateProjectNameException();
    }

    final updated = Project(
      id: _projectIdFor(projectName),
      name: projectName,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      sketchCount: existing.sketchCount,
    );
    _projects.remove(projectId);
    _projects[updated.id] = updated;
    _sketchesByProjectId[updated.id] =
        _sketchesByProjectId.remove(projectId) ?? [];
    await _persist();
  }

  @override
  Future<void> deleteById(String projectId) async {
    await _ensureLoaded();
    final removed = _projects.remove(projectId);
    if (removed == null) {
      throw ProjectNotFoundException();
    }
    _sketchesByProjectId.remove(projectId);
    await _persist();
  }

  @override
  Future<Project?> findById(String projectId) async {
    await _ensureLoaded();
    return _projectWithCount(_projects[projectId]);
  }

  @override
  Future<List<Project>> list({String? query}) async {
    await _ensureLoaded();
    final normalized = query?.trim().toLowerCase();
    final projects = _projects.values
        .map(_projectWithCount)
        .whereType<Project>()
        .where((project) {
          if (normalized == null || normalized.isEmpty) {
            return true;
          }
          return project.name.normalized.contains(normalized);
        })
        .toList(growable: false);
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  @override
  Future<List<Sketch>> listSketches(String projectId, {String? query}) async {
    await _ensureLoaded();
    final sketches = _sketchesFor(projectId);
    final normalized = query?.trim().toLowerCase();
    var output = List<Sketch>.from(sketches);
    if (normalized != null && normalized.isNotEmpty) {
      output = output
          .where((sketch) => sketch.name.normalized.contains(normalized))
          .toList(growable: false);
    }
    output.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return output;
  }

  @override
  Future<List<ProjectSketchMatch>> listFavoriteSketches({String? query}) async {
    await _ensureLoaded();
    final normalized = query?.trim().toLowerCase();
    final matches = <ProjectSketchMatch>[];
    for (final project in await list()) {
      final sketches = _sketchesByProjectId[project.id] ?? const <Sketch>[];
      for (final sketch in sketches) {
        if (!sketch.isFavorite) {
          continue;
        }
        if (normalized != null &&
            normalized.isNotEmpty &&
            !sketch.name.normalized.contains(normalized)) {
          continue;
        }
        matches.add(ProjectSketchMatch(project: project, sketch: sketch));
      }
    }
    matches.sort((a, b) => b.sketch.updatedAt.compareTo(a.sketch.updatedAt));
    return matches;
  }

  @override
  Future<List<ProjectSketchMatch>> searchSketches(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }
    final matches = <ProjectSketchMatch>[];
    for (final project in await list()) {
      final sketches = await listSketches(project.id, query: query);
      for (final sketch in sketches) {
        matches.add(ProjectSketchMatch(project: project, sketch: sketch));
      }
    }
    matches.sort((a, b) => b.sketch.updatedAt.compareTo(a.sketch.updatedAt));
    return matches;
  }

  @override
  Future<void> createSketch(String projectId, Sketch sketch) async {
    await createSketches(projectId, [sketch]);
  }

  @override
  Future<void> createSketches(
    String projectId,
    Iterable<Sketch> newSketches,
  ) async {
    await _ensureLoaded();
    final existingSketches = _sketchesFor(projectId);
    final normalizedNames = existingSketches
        .map((sketch) => sketch.name.normalized)
        .toSet();
    for (final sketch in newSketches) {
      if (!normalizedNames.add(sketch.name.normalized)) {
        throw DuplicateSketchNameException();
      }
    }
    existingSketches.addAll(newSketches);
    _touchProject(projectId);
    await _persist();
  }

  @override
  Future<void> updateSketch(String projectId, Sketch sketch) async {
    await _ensureLoaded();
    final sketches = _sketchesFor(projectId);
    final index = sketches.indexWhere((item) => item.id == sketch.id);
    if (index < 0) {
      throw SketchNotFoundException();
    }
    sketches[index] = sketch;
    _touchProject(projectId);
    await _persist();
  }

  @override
  Future<void> deleteSketchById(String projectId, String sketchId) async {
    await _ensureLoaded();
    final sketches = _sketchesFor(projectId);
    final before = sketches.length;
    sketches.removeWhere((item) => item.id == sketchId);
    if (sketches.length == before) {
      throw SketchNotFoundException();
    }
    _touchProject(projectId);
    await _persist();
  }

  @override
  Future<Sketch?> findSketchById(String projectId, String sketchId) async {
    await _ensureLoaded();
    final sketches = _sketchesFor(projectId);
    for (final sketch in sketches) {
      if (sketch.id == sketchId) {
        return sketch;
      }
    }
    return null;
  }

  @override
  Future<bool> existsSketchByNormalizedName(
    String projectId,
    String normalizedName, {
    String? excludingSketchId,
  }) async {
    await _ensureLoaded();
    final sketches = _sketchesFor(projectId);
    return sketches.any((item) {
      if (excludingSketchId != null && item.id == excludingSketchId) {
        return false;
      }
      return item.name.normalized == normalizedName;
    });
  }

  Future<void> _ensureLoaded() async {
    if (_loadedVersion == _projectWebStorageVersion) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _projects.clear();
    _sketchesByProjectId.clear();

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = decoded.cast<String, Object?>();
          final projects = map['projects'];
          if (projects is List) {
            for (final entry in projects.whereType<Map>()) {
              final project = _projectFromJson(entry.cast<String, Object?>());
              _projects[project.id] = project;
              _sketchesByProjectId[project.id] = [];
            }
          }
          final sketches = map['sketchesByProjectId'];
          if (sketches is Map) {
            for (final entry in sketches.entries) {
              final projectId = entry.key.toString();
              final rawSketches = entry.value;
              if (rawSketches is List) {
                _sketchesByProjectId[projectId] = rawSketches
                    .whereType<Map>()
                    .map(
                      (item) => _sketchFromJson(item.cast<String, Object?>()),
                    )
                    .toList(growable: false);
              }
            }
          }
        }
      } catch (_) {
        _projects.clear();
        _sketchesByProjectId.clear();
      }
    }

    _loadedVersion = _projectWebStorageVersion;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, Object>{
      'projects': _projects.values.map(_projectToJson).toList(growable: false),
      'sketchesByProjectId': _sketchesByProjectId.map(
        (projectId, sketches) => MapEntry(
          projectId,
          sketches.map(_sketchToJson).toList(growable: false),
        ),
      ),
    };
    await prefs.setString(_storageKey, jsonEncode(payload));
    _loadedVersion = _projectWebStorageVersion;
  }

  List<Sketch> _sketchesFor(String projectId) {
    if (!_projects.containsKey(projectId)) {
      throw ProjectNotFoundException();
    }
    return _sketchesByProjectId.putIfAbsent(projectId, () => []);
  }

  bool _existsByNormalizedName(
    String normalizedName, {
    String? excludingProjectId,
  }) {
    return _projects.values.any((project) {
      if (excludingProjectId != null && project.id == excludingProjectId) {
        return false;
      }
      return project.name.normalized == normalizedName;
    });
  }

  Project? _projectWithCount(Project? project) {
    if (project == null) {
      return null;
    }
    return Project(
      id: project.id,
      name: project.name,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
      sketchCount: _sketchesByProjectId[project.id]?.length ?? 0,
    );
  }

  void _touchProject(String projectId) {
    final project = _projects[projectId];
    if (project == null) {
      return;
    }
    _projects[projectId] = Project(
      id: project.id,
      name: project.name,
      createdAt: project.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      sketchCount: project.sketchCount,
    );
  }

  String _projectIdFor(SketchName name) {
    final encoded = base64UrlEncode(
      utf8.encode(name.normalized),
    ).replaceAll('=', '');
    return 'project_$encoded';
  }

  Project _projectFromJson(Map<String, Object?> map) {
    return Project(
      id: map['id'] as String,
      name: SketchName(map['name'] as String),
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
      sketchCount: 0,
    );
  }

  Map<String, Object> _projectToJson(Project project) {
    return {
      'id': project.id,
      'name': project.name.value,
      'createdAt': project.createdAt,
      'updatedAt': project.updatedAt,
    };
  }

  Sketch _sketchFromJson(Map<String, Object?> map) {
    return Sketch(
      id: map['id'] as String,
      name: SketchName(map['name'] as String),
      language: SketchLanguage.fromStorageValue(
        map['language'] as String? ??
            SketchLanguage.processingJava.storageValue,
      ),
      code: map['code'] as String,
      createdAt: map['createdAt'] as int,
      updatedAt: map['updatedAt'] as int,
      isFavorite: map['isFavorite'] as bool? ?? false,
    );
  }

  Map<String, Object> _sketchToJson(Sketch sketch) {
    return {
      'id': sketch.id,
      'name': sketch.name.value,
      'language': sketch.language.storageValue,
      'code': sketch.code,
      'createdAt': sketch.createdAt,
      'updatedAt': sketch.updatedAt,
      'isFavorite': sketch.isFavorite,
    };
  }
}

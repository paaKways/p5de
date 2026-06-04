import 'dart:convert';

import 'package:p5de/contexts/sketch_catalog/domain/project.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';

class InMemoryProjectRepository implements ProjectRepository {
  final Map<String, _ProjectRecord> _projects = {};
  final Map<String, List<Sketch>> _sketchesByProjectId = {};

  @override
  Future<Project> create({required String name}) async {
    final projectName = SketchName(name);
    if (await _existsByNormalizedName(projectName.normalized)) {
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
    _projects[project.id] = _ProjectRecord(project);
    _sketchesByProjectId[project.id] = [];
    return project;
  }

  @override
  Future<void> rename({
    required String projectId,
    required String newName,
  }) async {
    final record = _projects[projectId];
    if (record == null) {
      throw ProjectNotFoundException();
    }
    final projectName = SketchName(newName);
    if (await _existsByNormalizedName(
      projectName.normalized,
      excludingProjectId: projectId,
    )) {
      throw DuplicateProjectNameException();
    }

    final updated = Project(
      id: record.project.id,
      name: projectName,
      createdAt: record.project.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      sketchCount: record.project.sketchCount,
    );
    _projects[projectId] = _ProjectRecord(updated);
  }

  @override
  Future<void> deleteById(String projectId) async {
    final removed = _projects.remove(projectId);
    if (removed == null) {
      throw ProjectNotFoundException();
    }
    _sketchesByProjectId.remove(projectId);
  }

  @override
  Future<Project?> findById(String projectId) async {
    return _projectWithCount(_projects[projectId]?.project);
  }

  @override
  Future<List<Project>> list({String? query}) async {
    final normalized = query?.trim().toLowerCase();
    final projects = _projects.values
        .map((record) => _projectWithCount(record.project))
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
    if (!_projects.containsKey(projectId)) {
      throw ProjectNotFoundException();
    }
    var sketches = List<Sketch>.from(_sketchesByProjectId[projectId] ?? []);
    final normalized = query?.trim().toLowerCase();
    if (normalized != null && normalized.isNotEmpty) {
      sketches = sketches
          .where((sketch) => sketch.name.normalized.contains(normalized))
          .toList(growable: false);
    }
    sketches.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sketches;
  }

  @override
  Future<List<ProjectSketchMatch>> listFavoriteSketches({String? query}) async {
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
  }

  @override
  Future<void> updateSketch(String projectId, Sketch sketch) async {
    final sketches = _sketchesFor(projectId);
    final index = sketches.indexWhere((item) => item.id == sketch.id);
    if (index < 0) {
      throw SketchNotFoundException();
    }
    sketches[index] = sketch;
  }

  @override
  Future<void> deleteSketchById(String projectId, String sketchId) async {
    final sketches = _sketchesFor(projectId);
    final before = sketches.length;
    sketches.removeWhere((item) => item.id == sketchId);
    if (sketches.length == before) {
      throw SketchNotFoundException();
    }
  }

  @override
  Future<Sketch?> findSketchById(String projectId, String sketchId) async {
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
    final sketches = _sketchesFor(projectId);
    return sketches.any((item) {
      if (excludingSketchId != null && item.id == excludingSketchId) {
        return false;
      }
      return item.name.normalized == normalizedName;
    });
  }

  List<Sketch> _sketchesFor(String projectId) {
    if (!_projects.containsKey(projectId)) {
      throw ProjectNotFoundException();
    }
    return _sketchesByProjectId.putIfAbsent(projectId, () => []);
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

  Future<bool> _existsByNormalizedName(
    String normalizedName, {
    String? excludingProjectId,
  }) async {
    return _projects.values.any((record) {
      if (excludingProjectId != null &&
          record.project.id == excludingProjectId) {
        return false;
      }
      return record.project.name.normalized == normalizedName;
    });
  }

  String _projectIdFor(SketchName name) {
    final encoded = base64UrlEncode(
      utf8.encode(name.normalized),
    ).replaceAll('=', '');
    return 'project_$encoded';
  }
}

class _ProjectRecord {
  const _ProjectRecord(this.project);

  final Project project;
}

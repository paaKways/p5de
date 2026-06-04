import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/sketch_catalog_database.dart';

class DriftProjectRepository implements ProjectRepository {
  DriftProjectRepository(this._database, {ProjectRepository? legacyRepository})
    : _legacyRepository = legacyRepository;

  final SketchCatalogDatabase _database;
  final ProjectRepository? _legacyRepository;
  bool _legacyImported = false;

  ProjectDao get _dao => _database.projectDao;

  @override
  Future<Project> create({required String name}) async {
    await _importLegacyIfNeeded();
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
    await _dao.insertProject(_projectToCompanion(project));
    return project;
  }

  @override
  Future<void> rename({
    required String projectId,
    required String newName,
  }) async {
    await _importLegacyIfNeeded();
    final existing = await _dao.findProjectById(projectId);
    if (existing == null) {
      throw ProjectNotFoundException();
    }

    final name = SketchName(newName);
    if (await _existsByNormalizedName(
      name.normalized,
      excludingProjectId: projectId,
    )) {
      throw DuplicateProjectNameException();
    }

    await _dao.updateProject(
      ProjectEntriesCompanion(
        id: Value(existing.id),
        name: Value(name.value),
        nameNormalized: Value(name.normalized),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<void> deleteById(String projectId) async {
    await _importLegacyIfNeeded();
    if (await _dao.findProjectById(projectId) == null) {
      throw ProjectNotFoundException();
    }
    await _dao.deleteProjectById(projectId);
  }

  @override
  Future<Project?> findById(String projectId) async {
    await _importLegacyIfNeeded();
    final row = await _dao.findProjectById(projectId);
    if (row == null) {
      return null;
    }
    return _projectFromRow(row);
  }

  @override
  Future<List<Project>> list({String? query}) async {
    await _importLegacyIfNeeded();
    final rows = await _dao.listProjects(query: query);
    final projects = <Project>[];
    for (final row in rows) {
      projects.add(await _projectFromRow(row));
    }
    return projects;
  }

  @override
  Future<List<Sketch>> listSketches(String projectId, {String? query}) async {
    await _importLegacyIfNeeded();
    if (await _dao.findProjectById(projectId) == null) {
      throw ProjectNotFoundException();
    }
    final rows = await _dao.listProjectSketches(projectId, query: query);
    return rows.map(_sketchFromRow).toList(growable: false);
  }

  @override
  Future<List<ProjectSketchMatch>> listFavoriteSketches({String? query}) async {
    await _importLegacyIfNeeded();
    final rows = await _dao.listFavoriteProjectSketches(query: query);
    return _matchesFromRows(rows);
  }

  @override
  Future<List<ProjectSketchMatch>> searchSketches(String query) async {
    await _importLegacyIfNeeded();
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const [];
    }
    final rows = await _dao.searchProjectSketches(trimmedQuery);
    return _matchesFromRows(rows);
  }

  @override
  Future<void> createSketch(String projectId, Sketch sketch) async {
    await createSketches(projectId, [sketch]);
  }

  @override
  Future<void> createSketches(
    String projectId,
    Iterable<Sketch> sketches,
  ) async {
    await _importLegacyIfNeeded();
    if (await _dao.findProjectById(projectId) == null) {
      throw ProjectNotFoundException();
    }

    final normalizedNames = (await _dao.listProjectSketches(
      projectId,
    )).map((sketch) => sketch.nameNormalized).toSet();
    final companions = <ProjectSketchEntriesCompanion>[];
    var newestUpdate = 0;
    for (final sketch in sketches) {
      if (!normalizedNames.add(sketch.name.normalized)) {
        throw DuplicateSketchNameException();
      }
      if (sketch.updatedAt > newestUpdate) {
        newestUpdate = sketch.updatedAt;
      }
      companions.add(_sketchToCompanion(projectId, sketch));
    }
    if (companions.isEmpty) {
      return;
    }
    await _dao.insertProjectSketches(companions);
    await _touchProject(projectId, updatedAt: newestUpdate);
  }

  @override
  Future<void> updateSketch(String projectId, Sketch sketch) async {
    await _importLegacyIfNeeded();
    final previous = await _dao.findProjectSketchById(projectId, sketch.id);
    if (previous == null) {
      throw SketchNotFoundException();
    }
    final duplicate = await _dao.findProjectSketchByNormalizedName(
      projectId,
      sketch.name.normalized,
    );
    if (duplicate != null && duplicate.id != sketch.id) {
      throw DuplicateSketchNameException();
    }
    await _dao.updateProjectSketch(_sketchToCompanion(projectId, sketch));
    await _touchProject(projectId, updatedAt: sketch.updatedAt);
  }

  @override
  Future<void> deleteSketchById(String projectId, String sketchId) async {
    await _importLegacyIfNeeded();
    if (await _dao.findProjectSketchById(projectId, sketchId) == null) {
      throw SketchNotFoundException();
    }
    await _dao.deleteProjectSketchById(projectId, sketchId);
    await _touchProject(projectId);
  }

  @override
  Future<Sketch?> findSketchById(String projectId, String sketchId) async {
    await _importLegacyIfNeeded();
    final row = await _dao.findProjectSketchById(projectId, sketchId);
    return row == null ? null : _sketchFromRow(row);
  }

  @override
  Future<bool> existsSketchByNormalizedName(
    String projectId,
    String normalizedName, {
    String? excludingSketchId,
  }) async {
    await _importLegacyIfNeeded();
    final row = await _dao.findProjectSketchByNormalizedName(
      projectId,
      normalizedName,
    );
    if (row == null) {
      return false;
    }
    return excludingSketchId == null || row.id != excludingSketchId;
  }

  Future<bool> _existsByNormalizedName(
    String normalizedName, {
    String? excludingProjectId,
  }) async {
    final row = await _dao.findProjectByNormalizedName(normalizedName);
    if (row == null) {
      return false;
    }
    return excludingProjectId == null || row.id != excludingProjectId;
  }

  Future<List<ProjectSketchMatch>> _matchesFromRows(
    List<ProjectSketchEntry> rows,
  ) async {
    final matches = <ProjectSketchMatch>[];
    for (final row in rows) {
      final projectRow = await _dao.findProjectById(row.projectId);
      if (projectRow == null) {
        continue;
      }
      matches.add(
        ProjectSketchMatch(
          project: await _projectFromRow(projectRow),
          sketch: _sketchFromRow(row),
        ),
      );
    }
    return matches;
  }

  Future<Project> _projectFromRow(ProjectEntry row) async {
    return Project(
      id: row.id,
      name: SketchName(row.name),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      sketchCount: await _dao.countSketches(row.id),
    );
  }

  ProjectEntriesCompanion _projectToCompanion(Project project) {
    return ProjectEntriesCompanion(
      id: Value(project.id),
      name: Value(project.name.value),
      nameNormalized: Value(project.name.normalized),
      createdAt: Value(project.createdAt),
      updatedAt: Value(project.updatedAt),
    );
  }

  Sketch _sketchFromRow(ProjectSketchEntry row) {
    return Sketch(
      id: row.id,
      name: SketchName(row.name),
      language: SketchLanguage.fromStorageValue(row.language),
      code: row.code,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isFavorite: row.isFavorite,
    );
  }

  ProjectSketchEntriesCompanion _sketchToCompanion(
    String projectId,
    Sketch sketch,
  ) {
    return ProjectSketchEntriesCompanion(
      id: Value(sketch.id),
      projectId: Value(projectId),
      name: Value(sketch.name.value),
      nameNormalized: Value(sketch.name.normalized),
      language: Value(sketch.language.storageValue),
      code: Value(sketch.code),
      createdAt: Value(sketch.createdAt),
      updatedAt: Value(sketch.updatedAt),
      isFavorite: Value(sketch.isFavorite),
    );
  }

  Future<void> _touchProject(String projectId, {int? updatedAt}) async {
    final project = await _dao.findProjectById(projectId);
    if (project == null) {
      throw ProjectNotFoundException();
    }
    await _dao.updateProject(
      ProjectEntriesCompanion(
        id: Value(project.id),
        name: Value(project.name),
        nameNormalized: Value(project.nameNormalized),
        createdAt: Value(project.createdAt),
        updatedAt: Value(updatedAt ?? DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> _importLegacyIfNeeded() async {
    if (_legacyImported) {
      return;
    }
    _legacyImported = true;

    final legacyRepository = _legacyRepository;
    if (legacyRepository == null) {
      return;
    }

    final existingNames = (await _dao.listProjects())
        .map((project) => project.nameNormalized)
        .toSet();
    final legacyProjects = await legacyRepository.list();
    for (final legacyProject in legacyProjects) {
      if (existingNames.contains(legacyProject.name.normalized)) {
        continue;
      }
      await _dao.insertProject(
        ProjectEntriesCompanion(
          id: Value(legacyProject.id),
          name: Value(legacyProject.name.value),
          nameNormalized: Value(legacyProject.name.normalized),
          createdAt: Value(legacyProject.createdAt),
          updatedAt: Value(legacyProject.updatedAt),
        ),
      );
      existingNames.add(legacyProject.name.normalized);

      final sketches = await legacyRepository.listSketches(legacyProject.id);
      await _dao.insertProjectSketches(
        sketches.map((sketch) => _sketchToCompanion(legacyProject.id, sketch)),
      );
    }
  }

  String _projectIdFor(SketchName name) {
    final encoded = base64UrlEncode(
      utf8.encode(name.normalized),
    ).replaceAll('=', '');
    return 'project_$encoded';
  }
}

import 'dart:convert';

import 'package:p5de/contexts/sketch_catalog/domain/project.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/saf_directory_bridge.dart';

class SafCatalogStore {
  SafCatalogStore({SafDirectoryBridge bridge = const SafDirectoryBridge()})
    : _bridge = bridge;

  static const _metadataFileName = '.p5de.json';

  final SafDirectoryBridge _bridge;

  Future<List<Sketch>> listStandaloneSketches({String? query}) async {
    final sketches = <Sketch>[];
    for (final entry in await _topLevelDirectories()) {
      final sketch = await _readSketch(entry.path);
      if (sketch != null) {
        sketches.add(sketch);
      }
    }
    return _filterAndSortSketches(sketches, query);
  }

  Future<void> createStandaloneSketch(Sketch sketch) async {
    if (await _topLevelNameExists(sketch.name.normalized)) {
      throw DuplicateSketchNameException();
    }
    await _writeSketch(sketch, previousPath: null, parentPath: '');
  }

  Future<void> updateStandaloneSketch(Sketch sketch) async {
    final previousPath = await _standalonePathForId(sketch.id);
    if (previousPath == null) {
      throw SketchNotFoundException();
    }
    await _writeSketch(sketch, previousPath: previousPath, parentPath: '');
  }

  Future<void> deleteStandaloneSketch(String sketchId) async {
    final path = await _standalonePathForId(sketchId);
    if (path == null) {
      throw SketchNotFoundException();
    }
    await _bridge.delete(path);
  }

  Future<Sketch?> findStandaloneSketch(String sketchId) async {
    final path = await _standalonePathForId(sketchId);
    return path == null ? null : _readSketch(path);
  }

  Future<bool> standaloneNameExists(
    String normalizedName, {
    String? excludingSketchId,
  }) async {
    final sketches = await listStandaloneSketches();
    return sketches.any(
      (sketch) =>
          sketch.name.normalized == normalizedName &&
          sketch.id != excludingSketchId,
    );
  }

  Future<List<Project>> listProjects({String? query}) async {
    final normalizedQuery = query?.trim().toLowerCase();
    final projects = <Project>[];
    for (final entry in await _topLevelDirectories()) {
      if (await _hasSketchSource(entry.path)) {
        continue;
      }
      final project = await _projectFromEntry(entry);
      if (normalizedQuery == null ||
          normalizedQuery.isEmpty ||
          project.name.normalized.contains(normalizedQuery)) {
        projects.add(project);
      }
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Future<Project> createProject(String rawName) async {
    final name = SketchName(rawName);
    if (await _topLevelNameExists(name.normalized)) {
      throw DuplicateProjectNameException();
    }
    final path = _folderNameFor(name);
    await _bridge.createDirectory(path);
    final entry = await _entryAtPath(path);
    return _projectFromEntry(entry);
  }

  Future<void> renameProject(String projectId, String rawName) async {
    final path = await _projectPathForId(projectId);
    if (path == null) {
      throw ProjectNotFoundException();
    }
    final name = SketchName(rawName);
    if (await _topLevelNameExists(name.normalized, excludingPath: path)) {
      throw DuplicateProjectNameException();
    }
    final folderName = _folderNameFor(name);
    if (_nameFromPath(path) != folderName) {
      await _bridge.rename(path, folderName);
    }
  }

  Future<void> deleteProject(String projectId) async {
    final path = await _projectPathForId(projectId);
    if (path == null) {
      throw ProjectNotFoundException();
    }
    await _bridge.delete(path);
  }

  Future<Project?> findProject(String projectId) async {
    final path = await _projectPathForId(projectId);
    if (path == null) {
      return null;
    }
    return _projectFromEntry(await _entryAtPath(path));
  }

  Future<List<Sketch>> listProjectSketches(
    String projectId, {
    String? query,
  }) async {
    final projectPath = await _projectPathForId(projectId);
    if (projectPath == null) {
      throw ProjectNotFoundException();
    }
    return _listSketchesIn(projectPath, query: query);
  }

  Future<void> createProjectSketch(String projectId, Sketch sketch) async {
    await createProjectSketches(projectId, [sketch]);
  }

  Future<void> createProjectSketches(
    String projectId,
    Iterable<Sketch> sketches,
  ) async {
    final projectPath = await _projectPathForId(projectId);
    if (projectPath == null) {
      throw ProjectNotFoundException();
    }
    final normalizedNames = (await _listSketchesIn(
      projectPath,
    )).map((sketch) => sketch.name.normalized).toSet();
    for (final sketch in sketches) {
      if (!normalizedNames.add(sketch.name.normalized)) {
        throw DuplicateSketchNameException();
      }
    }
    for (final sketch in sketches) {
      await _writeSketch(sketch, previousPath: null, parentPath: projectPath);
    }
  }

  Future<void> updateProjectSketch(String projectId, Sketch sketch) async {
    final projectPath = await _projectPathForId(projectId);
    if (projectPath == null) {
      throw ProjectNotFoundException();
    }
    final previousPath = await _sketchPathForId(projectPath, sketch.id);
    if (previousPath == null) {
      throw SketchNotFoundException();
    }
    await _writeSketch(
      sketch,
      previousPath: previousPath,
      parentPath: projectPath,
    );
  }

  Future<void> deleteProjectSketch(String projectId, String sketchId) async {
    final projectPath = await _projectPathForId(projectId);
    if (projectPath == null) {
      throw ProjectNotFoundException();
    }
    final path = await _sketchPathForId(projectPath, sketchId);
    if (path == null) {
      throw SketchNotFoundException();
    }
    await _bridge.delete(path);
  }

  Future<Sketch?> findProjectSketch(String projectId, String sketchId) async {
    final projectPath = await _projectPathForId(projectId);
    if (projectPath == null) {
      throw ProjectNotFoundException();
    }
    final path = await _sketchPathForId(projectPath, sketchId);
    return path == null ? null : _readSketch(path);
  }

  Future<bool> projectSketchNameExists(
    String projectId,
    String normalizedName, {
    String? excludingSketchId,
  }) async {
    final sketches = await listProjectSketches(projectId);
    return sketches.any(
      (sketch) =>
          sketch.name.normalized == normalizedName &&
          sketch.id != excludingSketchId,
    );
  }

  Future<List<ProjectSketchMatch>> listFavoriteProjectSketches({
    String? query,
  }) async {
    final matches = <ProjectSketchMatch>[];
    for (final project in await listProjects()) {
      for (final sketch in await listProjectSketches(
        project.id,
        query: query,
      )) {
        if (sketch.isFavorite) {
          matches.add(ProjectSketchMatch(project: project, sketch: sketch));
        }
      }
    }
    matches.sort((a, b) => b.sketch.updatedAt.compareTo(a.sketch.updatedAt));
    return matches;
  }

  Future<List<ProjectSketchMatch>> searchProjectSketches(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const [];
    }
    final matches = <ProjectSketchMatch>[];
    for (final project in await listProjects()) {
      for (final sketch in await listProjectSketches(
        project.id,
        query: query,
      )) {
        matches.add(ProjectSketchMatch(project: project, sketch: sketch));
      }
    }
    matches.sort((a, b) => b.sketch.updatedAt.compareTo(a.sketch.updatedAt));
    return matches;
  }

  Future<void> _writeSketch(
    Sketch sketch, {
    required String? previousPath,
    required String parentPath,
  }) async {
    String? previousSourceFileName;
    if (previousPath != null) {
      final previousEntries = await _bridge.list(previousPath);
      previousSourceFileName = _sourceEntry(
        previousPath,
        previousEntries,
        await _readMetadata(previousPath, previousEntries),
      )?.name;
    }

    final folderName = _folderNameFor(sketch.name);
    var targetPath = _join(parentPath, folderName);
    if (previousPath == null) {
      if (await _bridge.exists(targetPath)) {
        throw DuplicateSketchNameException();
      }
      await _bridge.createDirectory(targetPath);
    } else if (previousPath != targetPath) {
      if (await _bridge.exists(targetPath)) {
        throw DuplicateSketchNameException();
      }
      targetPath = await _bridge.rename(previousPath, folderName);
    }

    final sourceFileName = sketch.language.fileNameForSketchName(
      sketch.name.value,
    );
    if (previousSourceFileName != null &&
        previousSourceFileName != sourceFileName) {
      final previousSourcePath = _join(targetPath, previousSourceFileName);
      if (await _bridge.exists(previousSourcePath)) {
        await _bridge.delete(previousSourcePath);
      }
    }
    await _bridge.writeText(
      _join(targetPath, sourceFileName),
      sketch.code,
      mimeType: 'text/plain',
    );
    await _bridge.writeText(
      _join(targetPath, _metadataFileName),
      jsonEncode(_metadataFor(sketch)),
      mimeType: 'application/json',
    );
  }

  Future<List<Sketch>> _listSketchesIn(
    String parentPath, {
    String? query,
  }) async {
    final sketches = <Sketch>[];
    for (final entry in await _bridge.list(parentPath)) {
      if (!entry.isDirectory || entry.name.startsWith('.')) {
        continue;
      }
      final sketch = await _readSketch(entry.path);
      if (sketch != null) {
        sketches.add(sketch);
      }
    }
    return _filterAndSortSketches(sketches, query);
  }

  Future<Sketch?> _readSketch(String directoryPath) async {
    final entries = await _bridge.list(directoryPath);
    final metadata = await _readMetadata(directoryPath, entries);
    final source = _sourceEntry(directoryPath, entries, metadata);
    if (source == null) {
      return null;
    }
    final language = _languageForFileName(source.name)!;
    final folderName = _nameFromPath(directoryPath);
    final name = SketchName(folderName);
    final modified = source.lastModified > 0
        ? source.lastModified
        : DateTime.now().millisecondsSinceEpoch;
    final sketch = Sketch(
      id: _stringMetadata(metadata, 'id') ?? _legacyIdFor(name),
      name: name,
      language: language,
      code: await _bridge.readText(source.path),
      createdAt: _intMetadata(metadata, 'createdAt') ?? modified,
      updatedAt: _intMetadata(metadata, 'updatedAt') ?? modified,
      isFavorite: _boolMetadata(metadata, 'isFavorite') ?? false,
    );
    if (metadata == null) {
      await _bridge.writeText(
        _join(directoryPath, _metadataFileName),
        jsonEncode(_metadataFor(sketch)),
        mimeType: 'application/json',
      );
    }
    return sketch;
  }

  Future<Map<String, Object?>?> _readMetadata(
    String directoryPath,
    List<SafDocumentEntry> entries,
  ) async {
    final metadataEntry = _firstWhereOrNull(
      entries,
      (entry) => !entry.isDirectory && entry.name == _metadataFileName,
    );
    if (metadataEntry == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(await _bridge.readText(metadataEntry.path));
      return decoded is Map ? decoded.cast<String, Object?>() : null;
    } catch (_) {
      return null;
    }
  }

  SafDocumentEntry? _sourceEntry(
    String directoryPath,
    List<SafDocumentEntry> entries,
    Map<String, Object?>? metadata,
  ) {
    final folderName = _nameFromPath(directoryPath);
    for (final language in SketchLanguage.values) {
      final canonicalName = language.fileNameForSketchName(folderName);
      final canonicalEntry = _firstWhereOrNull(
        entries,
        (candidate) =>
            !candidate.isDirectory && candidate.name == canonicalName,
      );
      if (canonicalEntry != null) {
        return canonicalEntry;
      }
    }
    final sourceFileName = _stringMetadata(metadata, 'sourceFileName');
    if (sourceFileName != null) {
      final entry = _firstWhereOrNull(
        entries,
        (candidate) =>
            !candidate.isDirectory && candidate.name == sourceFileName,
      );
      if (entry != null && _languageForFileName(entry.name) != null) {
        return entry;
      }
    }
    for (final language in SketchLanguage.values) {
      final entry = _firstWhereOrNull(
        entries,
        (candidate) =>
            !candidate.isDirectory && candidate.name == language.fileName,
      );
      if (entry != null) {
        return entry;
      }
    }
    final sourceEntries =
        entries
            .where(
              (entry) =>
                  !entry.isDirectory &&
                  _languageForFileName(entry.name) != null,
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return sourceEntries.isEmpty ? null : sourceEntries.first;
  }

  Future<Project> _projectFromEntry(SafDocumentEntry entry) async {
    final sketchDirectories = (await _bridge.list(entry.path))
        .where((child) => child.isDirectory && !child.name.startsWith('.'))
        .toList(growable: false);
    final name = SketchName(entry.name);
    final fallbackTime = entry.lastModified > 0
        ? entry.lastModified
        : DateTime.now().millisecondsSinceEpoch;
    final updatedAt = sketchDirectories.fold<int>(
      fallbackTime,
      (latest, child) =>
          child.lastModified > latest ? child.lastModified : latest,
    );
    return Project(
      id: _projectIdForName(name.value),
      name: name,
      createdAt: fallbackTime,
      updatedAt: updatedAt,
      sketchCount: sketchDirectories.length,
    );
  }

  Future<List<SafDocumentEntry>> _topLevelDirectories() async {
    return (await _bridge.list(''))
        .where((entry) => entry.isDirectory && !entry.name.startsWith('.'))
        .toList(growable: false);
  }

  Future<String?> _standalonePathForId(String sketchId) async {
    for (final entry in await _topLevelDirectories()) {
      if (await _sketchIdAt(entry.path) == sketchId) {
        return entry.path;
      }
    }
    return null;
  }

  Future<String?> _projectPathForId(String projectId) async {
    for (final entry in await _topLevelDirectories()) {
      if (!await _hasSketchSource(entry.path) &&
          _projectIdForName(entry.name) == projectId) {
        return entry.path;
      }
    }
    return null;
  }

  Future<bool> _hasSketchSource(String directoryPath) async {
    final entries = await _bridge.list(directoryPath);
    return entries.any(
      (entry) => !entry.isDirectory && _languageForFileName(entry.name) != null,
    );
  }

  Future<String?> _sketchPathForId(String parentPath, String sketchId) async {
    for (final entry in await _bridge.list(parentPath)) {
      if (!entry.isDirectory || entry.name.startsWith('.')) {
        continue;
      }
      if (await _sketchIdAt(entry.path) == sketchId) {
        return entry.path;
      }
    }
    return null;
  }

  Future<String?> _sketchIdAt(String directoryPath) async {
    final entries = await _bridge.list(directoryPath);
    final metadata = await _readMetadata(directoryPath, entries);
    final metadataId = _stringMetadata(metadata, 'id');
    if (metadataId != null) {
      return metadataId;
    }
    return (await _readSketch(directoryPath))?.id;
  }

  Future<bool> _topLevelNameExists(
    String normalizedName, {
    String? excludingPath,
  }) async {
    for (final entry in await _topLevelDirectories()) {
      if (entry.path != excludingPath &&
          entry.name.trim().toLowerCase() == normalizedName) {
        return true;
      }
    }
    return false;
  }

  Future<SafDocumentEntry> _entryAtPath(String path) async {
    final parentPath = _parentPath(path);
    final entry = _firstWhereOrNull(
      await _bridge.list(parentPath),
      (candidate) => candidate.path == path,
    );
    if (entry == null) {
      throw StateError('Unable to find $path');
    }
    return entry;
  }

  List<Sketch> _filterAndSortSketches(List<Sketch> sketches, String? query) {
    final normalizedQuery = query?.trim().toLowerCase();
    final filtered = normalizedQuery == null || normalizedQuery.isEmpty
        ? sketches
        : sketches
              .where(
                (sketch) => sketch.name.normalized.contains(normalizedQuery),
              )
              .toList(growable: false);
    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return filtered;
  }

  Map<String, Object?> _metadataFor(Sketch sketch) {
    return {
      'id': sketch.id,
      'name': sketch.name.value,
      'language': sketch.language.storageValue,
      'sourceFileName': sketch.language.fileNameForSketchName(
        sketch.name.value,
      ),
      'createdAt': sketch.createdAt,
      'updatedAt': sketch.updatedAt,
      'isFavorite': sketch.isFavorite,
    };
  }

  SketchLanguage? _languageForFileName(String fileName) {
    final normalized = fileName.toLowerCase();
    for (final language in SketchLanguage.values) {
      if (normalized.endsWith('.${language.fileExtension.toLowerCase()}')) {
        return language;
      }
    }
    return null;
  }

  String _folderNameFor(SketchName name) {
    final sanitized = name.value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    return sanitized.isEmpty ? 'Untitled' : sanitized;
  }

  String _projectIdForName(String name) {
    final normalized = name.trim().toLowerCase();
    return 'project_${base64UrlEncode(utf8.encode(normalized)).replaceAll('=', '')}';
  }

  String _legacyIdFor(SketchName name) {
    return 'fs_${base64UrlEncode(utf8.encode(name.normalized)).replaceAll('=', '')}';
  }

  String _join(String parent, String child) {
    return parent.isEmpty ? child : '$parent/$child';
  }

  String _parentPath(String path) {
    final separator = path.lastIndexOf('/');
    return separator < 0 ? '' : path.substring(0, separator);
  }

  String _nameFromPath(String path) {
    return path.split('/').last;
  }

  String? _stringMetadata(Map<String, Object?>? metadata, String key) {
    final value = metadata?[key];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  int? _intMetadata(Map<String, Object?>? metadata, String key) {
    final value = metadata?[key];
    return value is int ? value : null;
  }

  bool? _boolMetadata(Map<String, Object?>? metadata, String key) {
    final value = metadata?[key];
    return value is bool ? value : null;
  }

  T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
    for (final value in values) {
      if (test(value)) {
        return value;
      }
    }
    return null;
  }
}

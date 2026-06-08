import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/user_visible_sketch_mirror.dart';

class FilesystemProjectRepository implements ProjectRepository {
  FilesystemProjectRepository({
    Directory? rootDirectory,
    UserVisibleSketchMirror? userVisibleMirror,
  }) : _rootDirectory = rootDirectory,
       _userVisibleMirror = userVisibleMirror;

  static const String _metadataFileName = '.p5de.json';

  final Directory? _rootDirectory;
  final UserVisibleSketchMirror? _userVisibleMirror;

  @override
  Future<Project> create({required String name}) async {
    final projectName = SketchName(name);
    final root = await _root();
    await root.create(recursive: true);
    if (await _topLevelNameExists(projectName.normalized)) {
      throw DuplicateProjectNameException();
    }

    final target = Directory(
      '${root.path}${Platform.pathSeparator}${_folderNameFor(projectName)}',
    );
    await target.create(recursive: true);
    await _syncUserVisibleMirror();
    return _projectFromDirectory(target);
  }

  @override
  Future<void> rename({
    required String projectId,
    required String newName,
  }) async {
    final directory = await _directoryForProjectId(projectId);
    if (directory == null) {
      throw ProjectNotFoundException();
    }

    final name = SketchName(newName);
    final root = await _root();
    if (await _topLevelNameExists(
      name.normalized,
      excludingDirectory: directory,
    )) {
      throw DuplicateProjectNameException();
    }
    final target = Directory(
      '${root.path}${Platform.pathSeparator}${_folderNameFor(name)}',
    );
    if (target.path != directory.path && await target.exists()) {
      throw DuplicateProjectNameException();
    }
    if (target.path != directory.path) {
      await directory.rename(target.path);
      await _syncUserVisibleMirror();
    }
  }

  @override
  Future<void> deleteById(String projectId) async {
    final directory = await _directoryForProjectId(projectId);
    if (directory == null) {
      throw ProjectNotFoundException();
    }
    await directory.delete(recursive: true);
    await _syncUserVisibleMirror();
  }

  @override
  Future<Project?> findById(String projectId) async {
    final directory = await _directoryForProjectId(projectId);
    if (directory == null) {
      return null;
    }
    return _projectFromDirectory(directory);
  }

  @override
  Future<List<Project>> list({String? query}) async {
    final root = await _root();
    if (!await root.exists()) {
      await root.create(recursive: true);
      await _syncUserVisibleMirror();
      return const [];
    }
    await _syncUserVisibleMirror();

    final normalizedQuery = query?.trim().toLowerCase();
    final projects = <Project>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory || _isHiddenDirectory(entity)) {
        continue;
      }
      if (await _readSketch(entity) != null) {
        continue;
      }
      final project = await _projectFromDirectory(entity);
      if (normalizedQuery == null ||
          normalizedQuery.isEmpty ||
          project.name.normalized.contains(normalizedQuery)) {
        projects.add(project);
      }
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  @override
  Future<List<Sketch>> listSketches(String projectId, {String? query}) async {
    final directory = await _directoryForProjectId(projectId);
    if (directory == null) {
      throw ProjectNotFoundException();
    }
    final sketches = await _readSketchesInProject(directory);
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

  @override
  Future<List<ProjectSketchMatch>> listFavoriteSketches({String? query}) async {
    final root = await _root();
    if (!await root.exists()) {
      await root.create(recursive: true);
      return const [];
    }

    final normalizedQuery = query?.trim().toLowerCase();
    final matches = <ProjectSketchMatch>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory || _isHiddenDirectory(entity)) {
        continue;
      }
      if (await _hasSketchSource(entity)) {
        continue;
      }
      matches.addAll(
        await _favoriteSketchMatchesInProject(entity, normalizedQuery),
      );
    }
    matches.sort((a, b) => b.sketch.updatedAt.compareTo(a.sketch.updatedAt));
    return matches;
  }

  @override
  Future<List<ProjectSketchMatch>> searchSketches(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const [];
    }
    final matches = <ProjectSketchMatch>[];
    final projects = await list();
    for (final project in projects) {
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
    Iterable<Sketch> sketches,
  ) async {
    final projectDirectory = await _directoryForProjectId(projectId);
    if (projectDirectory == null) {
      throw ProjectNotFoundException();
    }

    final normalizedNames = (await _readSketchesInProject(
      projectDirectory,
    )).map((sketch) => sketch.name.normalized).toSet();
    for (final sketch in sketches) {
      if (!normalizedNames.add(sketch.name.normalized)) {
        throw DuplicateSketchNameException();
      }
    }

    for (final sketch in sketches) {
      await _writeSketch(projectDirectory, sketch, previousDirectory: null);
    }
    await _syncUserVisibleMirror();
  }

  @override
  Future<void> updateSketch(String projectId, Sketch sketch) async {
    final projectDirectory = await _directoryForProjectId(projectId);
    if (projectDirectory == null) {
      throw ProjectNotFoundException();
    }
    final previousDirectory = await _directoryForSketchId(
      projectDirectory,
      sketch.id,
    );
    if (previousDirectory == null) {
      throw SketchNotFoundException();
    }
    await _writeSketch(
      projectDirectory,
      sketch,
      previousDirectory: previousDirectory,
    );
    await _syncUserVisibleMirror();
  }

  @override
  Future<void> deleteSketchById(String projectId, String sketchId) async {
    final projectDirectory = await _directoryForProjectId(projectId);
    if (projectDirectory == null) {
      throw ProjectNotFoundException();
    }
    final directory = await _directoryForSketchId(projectDirectory, sketchId);
    if (directory == null) {
      throw SketchNotFoundException();
    }
    await directory.delete(recursive: true);
    await _syncUserVisibleMirror();
  }

  Future<void> _syncUserVisibleMirror() async {
    final mirror = _userVisibleMirror;
    if (mirror == null) {
      return;
    }
    try {
      await mirror.syncFrom(await _root());
    } catch (_) {
      // The public Download mirror is a convenience, not source of truth.
    }
  }

  @override
  Future<Sketch?> findSketchById(String projectId, String sketchId) async {
    final projectDirectory = await _directoryForProjectId(projectId);
    if (projectDirectory == null) {
      throw ProjectNotFoundException();
    }
    final directory = await _directoryForSketchId(projectDirectory, sketchId);
    if (directory == null) {
      return null;
    }
    return _readSketch(directory);
  }

  @override
  Future<bool> existsSketchByNormalizedName(
    String projectId,
    String normalizedName, {
    String? excludingSketchId,
  }) async {
    final sketches = await listSketches(projectId);
    return sketches.any((sketch) {
      if (excludingSketchId != null && sketch.id == excludingSketchId) {
        return false;
      }
      return sketch.name.normalized == normalizedName;
    });
  }

  Future<List<Sketch>> _readSketchesInProject(Directory project) async {
    final sketches = <Sketch>[];
    await for (final entity in project.list(followLinks: false)) {
      if (entity is! Directory || _isHiddenDirectory(entity)) {
        continue;
      }
      final sketch = await _readSketch(entity);
      if (sketch != null) {
        sketches.add(sketch);
      }
    }
    return sketches;
  }

  Future<List<ProjectSketchMatch>> _favoriteSketchMatchesInProject(
    Directory projectDirectory,
    String? normalizedQuery,
  ) async {
    final stat = await projectDirectory.stat();
    var sketchCount = 0;
    var childUpdatedAt = stat.modified.millisecondsSinceEpoch;
    final favoriteSketches = <Sketch>[];

    await for (final entity in projectDirectory.list(followLinks: false)) {
      if (entity is! Directory || _isHiddenDirectory(entity)) {
        continue;
      }
      final summary = await _readSketchSummary(entity);
      if (summary == null) {
        continue;
      }
      sketchCount++;
      if (summary.updatedAt > childUpdatedAt) {
        childUpdatedAt = summary.updatedAt;
      }
      if (!summary.isFavorite ||
          !_matchesQuery(summary.name, normalizedQuery)) {
        continue;
      }
      final sketch = await _readSketch(entity);
      if (sketch != null && sketch.isFavorite) {
        favoriteSketches.add(sketch);
      }
    }

    if (favoriteSketches.isEmpty) {
      return const [];
    }
    final name = SketchName(_nameFromDirectory(projectDirectory));
    final project = Project(
      id: _projectIdForName(name.value),
      name: name,
      createdAt: stat.modified.millisecondsSinceEpoch,
      updatedAt: childUpdatedAt,
      sketchCount: sketchCount,
    );
    return favoriteSketches
        .map((sketch) => ProjectSketchMatch(project: project, sketch: sketch))
        .toList(growable: false);
  }

  Future<_SketchSummary?> _readSketchSummary(Directory directory) async {
    final metadata = await _readMetadata(directory);
    final sourceFile = await _sourceFileFor(directory, metadata);
    if (sourceFile == null) {
      return null;
    }

    final fallbackName = sourceFile.hasDefaultName
        ? _nameFromDirectory(directory)
        : _fileNameFromPath(sourceFile.file.path);
    final rawName = _stringMetadata(metadata, 'name') ?? fallbackName;
    final name = SketchName(rawName);
    final modified = await sourceFile.file.lastModified();
    return _SketchSummary(
      name: name,
      updatedAt:
          _intMetadata(metadata, 'updatedAt') ??
          modified.millisecondsSinceEpoch,
      isFavorite: _boolMetadata(metadata, 'isFavorite') ?? false,
    );
  }

  Future<bool> _hasSketchSource(Directory directory) async {
    return await _sourceFileFor(directory, await _readMetadata(directory)) !=
        null;
  }

  bool _matchesQuery(SketchName name, String? normalizedQuery) {
    return normalizedQuery == null ||
        normalizedQuery.isEmpty ||
        name.normalized.contains(normalizedQuery);
  }

  Future<void> _writeSketch(
    Directory projectDirectory,
    Sketch sketch, {
    required Directory? previousDirectory,
  }) async {
    final previousSourceFile = previousDirectory == null
        ? null
        : await _sourceFileFor(
            previousDirectory,
            await _readMetadata(previousDirectory),
          );
    final sourceFileName = sketch.language.fileNameForSketchName(
      sketch.name.value,
    );

    final target = await _availableSketchDirectoryFor(
      projectDirectory,
      sketch,
      previousDirectory,
    );
    if (previousDirectory != null && previousDirectory.path != target.path) {
      await previousDirectory.rename(target.path);
    }
    await target.create(recursive: true);

    await _removeLanguageFilesExcept(target, sketch.language);
    await _removePreviousSourceFile(
      target,
      previousSourceFile,
      exceptFileName: sourceFileName,
    );
    await File(
      '${target.path}${Platform.pathSeparator}$sourceFileName',
    ).writeAsString(sketch.code);
    await _metadataFile(target).writeAsString(jsonEncode(_toMetadata(sketch)));
  }

  Future<Directory?> _directoryForProjectId(String projectId) async {
    final root = await _root();
    if (!await root.exists()) {
      return null;
    }
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory || _isHiddenDirectory(entity)) {
        continue;
      }
      if (await _readSketch(entity) != null) {
        continue;
      }
      if (_projectIdForName(_nameFromDirectory(entity)) == projectId) {
        return entity;
      }
    }
    return null;
  }

  Future<bool> _topLevelNameExists(
    String normalizedName, {
    Directory? excludingDirectory,
  }) async {
    final root = await _root();
    if (!await root.exists()) {
      return false;
    }
    final excludingPath = excludingDirectory?.absolute.path;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory || _isHiddenDirectory(entity)) {
        continue;
      }
      if (excludingPath != null && entity.absolute.path == excludingPath) {
        continue;
      }
      if (_nameFromDirectory(entity).trim().toLowerCase() == normalizedName) {
        return true;
      }
    }
    return false;
  }

  Future<Directory?> _directoryForSketchId(
    Directory projectDirectory,
    String sketchId,
  ) async {
    await for (final entity in projectDirectory.list(followLinks: false)) {
      if (entity is! Directory || _isHiddenDirectory(entity)) {
        continue;
      }
      final metadata = await _readMetadata(entity);
      if (_stringMetadata(metadata, 'id') == sketchId) {
        return entity;
      }
      if (metadata == null) {
        final sketch = await _readSketch(entity);
        if (sketch?.id == sketchId) {
          return entity;
        }
      }
    }
    return null;
  }

  Future<Directory> _availableSketchDirectoryFor(
    Directory projectDirectory,
    Sketch sketch,
    Directory? previousDirectory,
  ) async {
    final preferred = Directory(
      '${projectDirectory.path}${Platform.pathSeparator}'
      '${_folderNameFor(sketch.name)}',
    );
    if (previousDirectory != null && previousDirectory.path == preferred.path) {
      return preferred;
    }
    if (!await preferred.exists()) {
      return preferred;
    }
    final existing = await _readSketch(preferred);
    if (existing?.id == sketch.id) {
      return preferred;
    }
    return Directory(
      '${projectDirectory.path}${Platform.pathSeparator}'
      '${_folderNameFor(sketch.name)}-${_shortId(sketch.id)}',
    );
  }

  Future<Project> _projectFromDirectory(Directory directory) async {
    final name = SketchName(_nameFromDirectory(directory));
    final stat = await directory.stat();
    final sketches = await _readSketchesInProject(directory);
    final childUpdatedAt = sketches.fold<int>(
      stat.modified.millisecondsSinceEpoch,
      (current, sketch) =>
          sketch.updatedAt > current ? sketch.updatedAt : current,
    );
    return Project(
      id: _projectIdForName(name.value),
      name: name,
      createdAt: stat.modified.millisecondsSinceEpoch,
      updatedAt: childUpdatedAt,
      sketchCount: sketches.length,
    );
  }

  Future<Sketch?> _readSketch(Directory directory) async {
    final metadata = await _readMetadata(directory);
    final sourceFile = await _sourceFileFor(directory, metadata);
    if (sourceFile == null) {
      return null;
    }

    final language = sourceFile.language;
    final codeFile = sourceFile.file;
    final fallbackName = sourceFile.hasDefaultName
        ? _nameFromDirectory(directory)
        : _fileNameFromPath(codeFile.path);
    final rawName = _stringMetadata(metadata, 'name') ?? fallbackName;
    final name = SketchName(rawName);
    final now = await codeFile.lastModified();
    final sketch = Sketch(
      id: _stringMetadata(metadata, 'id') ?? _legacyIdFor(name),
      name: name,
      language: language,
      code: await codeFile.readAsString(),
      createdAt:
          _intMetadata(metadata, 'createdAt') ?? now.millisecondsSinceEpoch,
      updatedAt:
          _intMetadata(metadata, 'updatedAt') ?? now.millisecondsSinceEpoch,
      isFavorite: _boolMetadata(metadata, 'isFavorite') ?? false,
    );

    if (metadata == null) {
      await _metadataFile(
        directory,
      ).writeAsString(jsonEncode(_toMetadata(sketch)));
    }
    return sketch;
  }

  Future<Map<String, Object?>?> _readMetadata(Directory directory) async {
    final file = _metadataFile(directory);
    if (!await file.exists()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        return decoded.cast<String, Object?>();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<_SketchSourceFile?> _sourceFileFor(
    Directory directory,
    Map<String, Object?>? metadata,
  ) async {
    final rawLanguage = _stringMetadata(metadata, 'language');
    if (rawLanguage != null) {
      final language = SketchLanguage.fromStorageValue(rawLanguage);
      return _metadataSourceFileFor(
            directory,
            language,
            _stringMetadata(metadata, 'sourceFileName'),
          ) ??
          _defaultSourceFileFor(directory, language) ??
          await _firstSourceFileWithLanguage(directory, language);
    }

    for (final language in SketchLanguage.values) {
      final sourceFile = _defaultSourceFileFor(directory, language);
      if (sourceFile != null) {
        return sourceFile;
      }
    }

    for (final language in SketchLanguage.values) {
      final sourceFile = await _firstSourceFileWithLanguage(
        directory,
        language,
      );
      if (sourceFile != null) {
        return sourceFile;
      }
    }
    return null;
  }

  _SketchSourceFile? _defaultSourceFileFor(
    Directory directory,
    SketchLanguage language,
  ) {
    final file = File(
      '${directory.path}${Platform.pathSeparator}${language.fileName}',
    );
    return file.existsSync()
        ? _SketchSourceFile(
            file: file,
            language: language,
            hasDefaultName: true,
          )
        : null;
  }

  _SketchSourceFile? _metadataSourceFileFor(
    Directory directory,
    SketchLanguage language,
    String? sourceFileName,
  ) {
    if (sourceFileName == null ||
        sourceFileName.contains('/') ||
        sourceFileName.contains(r'\')) {
      return null;
    }
    if (!_matchesLanguageExtension(sourceFileName, language)) {
      return null;
    }

    final file = File(
      '${directory.path}${Platform.pathSeparator}$sourceFileName',
    );
    return file.existsSync()
        ? _SketchSourceFile(
            file: file,
            language: language,
            hasDefaultName: sourceFileName == language.fileName,
          )
        : null;
  }

  Future<_SketchSourceFile?> _firstSourceFileWithLanguage(
    Directory directory,
    SketchLanguage language,
  ) async {
    final extension = _extensionFor(language);
    if (extension.isEmpty) {
      return null;
    }

    final files = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File &&
          _fileNameFromPath(entity.path).toLowerCase().endsWith(extension) &&
          _fileNameFromPath(entity.path) != language.fileName) {
        files.add(entity);
      }
    }
    if (files.isEmpty) {
      return null;
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return _SketchSourceFile(
      file: files.first,
      language: language,
      hasDefaultName: false,
    );
  }

  Future<void> _removeLanguageFilesExcept(
    Directory directory,
    SketchLanguage language,
  ) async {
    for (final candidate in SketchLanguage.values) {
      if (candidate == language) {
        continue;
      }
      final file = File(
        '${directory.path}${Platform.pathSeparator}${candidate.fileName}',
      );
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _removePreviousSourceFile(
    Directory directory,
    _SketchSourceFile? previousSourceFile, {
    required String exceptFileName,
  }) async {
    if (previousSourceFile == null) {
      return;
    }
    final previousFileName = _fileNameFromPath(previousSourceFile.file.path);
    if (previousFileName == exceptFileName) {
      return;
    }
    final file = File(
      '${directory.path}${Platform.pathSeparator}$previousFileName',
    );
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _root() async {
    if (_rootDirectory != null) {
      return _rootDirectory;
    }
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}${Platform.pathSeparator}sketches');
  }

  File _metadataFile(Directory directory) {
    return File('${directory.path}${Platform.pathSeparator}$_metadataFileName');
  }

  Map<String, Object?> _toMetadata(Sketch sketch) {
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

  String _folderNameFor(SketchName name) {
    final sanitized = name.value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    return sanitized.isEmpty ? name.normalized : sanitized;
  }

  String _nameFromDirectory(Directory directory) {
    final normalizedPath = directory.path.replaceAll(r'\', '/');
    return normalizedPath.split('/').last;
  }

  String _fileNameFromPath(String path) {
    final normalizedPath = path.replaceAll(r'\', '/');
    return normalizedPath.split('/').last;
  }

  String _extensionFor(SketchLanguage language) {
    final dotIndex = language.fileName.lastIndexOf('.');
    if (dotIndex < 0) {
      return '';
    }
    return language.fileName.substring(dotIndex).toLowerCase();
  }

  bool _matchesLanguageExtension(String fileName, SketchLanguage language) {
    final extension = _extensionFor(language);
    return extension.isNotEmpty && fileName.toLowerCase().endsWith(extension);
  }

  String _projectIdForName(String name) {
    final normalized = name.trim().toLowerCase();
    return 'project_${base64UrlEncode(utf8.encode(normalized)).replaceAll('=', '')}';
  }

  String _legacyIdFor(SketchName name) {
    return 'fs_${base64UrlEncode(utf8.encode(name.normalized)).replaceAll('=', '')}';
  }

  String _shortId(String id) {
    return id
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
        .padRight(8, '0')
        .substring(0, 8);
  }

  bool _isHiddenDirectory(Directory directory) {
    return _nameFromDirectory(directory).startsWith('.');
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
}

class _SketchSourceFile {
  const _SketchSourceFile({
    required this.file,
    required this.language,
    required this.hasDefaultName,
  });

  final File file;
  final SketchLanguage language;
  final bool hasDefaultName;
}

class _SketchSummary {
  const _SketchSummary({
    required this.name,
    required this.updatedAt,
    required this.isFavorite,
  });

  final SketchName name;
  final int updatedAt;
  final bool isFavorite;
}

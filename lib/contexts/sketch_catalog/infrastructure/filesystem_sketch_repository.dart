import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/user_visible_sketch_mirror.dart';

class FilesystemSketchRepository implements SketchRepository {
  FilesystemSketchRepository({
    Directory? rootDirectory,
    SketchRepository? legacyRepository,
    UserVisibleSketchMirror? userVisibleMirror,
  }) : _rootDirectory = rootDirectory,
       _legacyRepository = legacyRepository,
       _userVisibleMirror = userVisibleMirror;

  static const String _metadataFileName = '.p5de.json';
  static const String _migrationMarkerFileName = '.p5de_sqlite_migrated';

  final Directory? _rootDirectory;
  final SketchRepository? _legacyRepository;
  final UserVisibleSketchMirror? _userVisibleMirror;

  @override
  Future<void> create(Sketch sketch) async {
    await _writeSketch(sketch, previousDirectory: null);
    await _syncUserVisibleMirror();
  }

  @override
  Future<void> update(Sketch sketch) async {
    final previousDirectory = await _directoryForId(sketch.id);
    await _writeSketch(sketch, previousDirectory: previousDirectory);
    await _syncUserVisibleMirror();
  }

  @override
  Future<void> deleteById(String sketchId) async {
    final directory = await _directoryForId(sketchId);
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
      await _syncUserVisibleMirror();
    }
  }

  @override
  Future<Sketch?> findById(String sketchId) async {
    final sketches = await list();
    for (final sketch in sketches) {
      if (sketch.id == sketchId) {
        return sketch;
      }
    }
    return null;
  }

  @override
  Future<List<Sketch>> list({String? query}) async {
    await _migrateLegacySketchesIfNeeded();
    final sketches = await _readAllFromDisk();
    if (query == null || query.trim().isEmpty) {
      await _syncUserVisibleMirror();
    }
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
  Future<List<Sketch>> listFavorites({String? query}) async {
    await _migrateLegacySketchesIfNeeded();
    final sketches = await _readFavoritesFromDisk(query: query);
    sketches.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sketches;
  }

  Future<List<Sketch>> _readAllFromDisk() async {
    final root = await _root();
    if (!await root.exists()) {
      await root.create(recursive: true);
      return const [];
    }

    final sketches = <Sketch>[];
    await for (final entity in root.list(followLinks: false)) {
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

  Future<List<Sketch>> _readFavoritesFromDisk({String? query}) async {
    final root = await _root();
    if (!await root.exists()) {
      await root.create(recursive: true);
      return const [];
    }

    final normalizedQuery = query?.trim().toLowerCase();
    final sketches = <Sketch>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory || _isHiddenDirectory(entity)) {
        continue;
      }
      final summary = await _readSketchSummary(entity);
      if (summary == null ||
          !summary.isFavorite ||
          !_matchesQuery(summary.name, normalizedQuery)) {
        continue;
      }
      final sketch = await _readSketch(entity);
      if (sketch != null && sketch.isFavorite) {
        sketches.add(sketch);
      }
    }
    return sketches;
  }

  @override
  Future<bool> existsByNormalizedName(
    String normalizedName, {
    String? excludingSketchId,
  }) async {
    await _migrateLegacySketchesIfNeeded();
    final sketches = await _readAllFromDisk();
    for (final sketch in sketches) {
      if (sketch.name.normalized == normalizedName &&
          sketch.id != excludingSketchId) {
        return true;
      }
    }
    return false;
  }

  Future<void> _migrateLegacySketchesIfNeeded() async {
    final legacyRepository = _legacyRepository;
    if (legacyRepository == null) {
      return;
    }
    final root = await _root();
    await root.create(recursive: true);
    final marker = File(
      '${root.path}${Platform.pathSeparator}$_migrationMarkerFileName',
    );
    if (await marker.exists()) {
      return;
    }

    final diskSketches = await _readAllFromDisk();
    final diskNames = diskSketches
        .map((sketch) => sketch.name.normalized)
        .toSet();
    final legacySketches = await legacyRepository.list();
    for (final sketch in legacySketches) {
      if (diskNames.contains(sketch.name.normalized)) {
        continue;
      }
      await _writeSketch(sketch, previousDirectory: null);
      diskNames.add(sketch.name.normalized);
    }
    await marker.writeAsString(DateTime.now().toUtc().toIso8601String());
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
      // The public Documents mirror is a convenience, not source of truth.
    }
  }

  Future<void> _writeSketch(
    Sketch sketch, {
    required Directory? previousDirectory,
  }) async {
    final root = await _root();
    await root.create(recursive: true);
    final previousSourceFile = previousDirectory == null
        ? null
        : await _sourceFileFor(
            previousDirectory,
            await _readMetadata(previousDirectory),
          );
    final sourceFileName = sketch.language.fileNameForSketchName(
      sketch.name.value,
    );

    final target = await _availableDirectoryFor(sketch, previousDirectory);
    if (previousDirectory != null && previousDirectory.path != target.path) {
      if (await target.exists()) {
        await target.delete(recursive: true);
      }
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

  Future<Directory?> _directoryForId(String sketchId) async {
    final root = await _root();
    if (!await root.exists()) {
      return null;
    }
    await for (final entity in root.list(followLinks: false)) {
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

  Future<Directory> _availableDirectoryFor(
    Sketch sketch,
    Directory? previousDirectory,
  ) async {
    final root = await _root();
    final preferred = Directory(
      '${root.path}${Platform.pathSeparator}${_folderNameFor(sketch)}',
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
      '${root.path}${Platform.pathSeparator}'
      '${_folderNameFor(sketch)}-${_shortId(sketch.id)}',
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

  String _folderNameFor(Sketch sketch) {
    final sanitized = sketch.name.value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    return sanitized.isEmpty ? sketch.id : sanitized;
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

  bool _matchesQuery(SketchName name, String? normalizedQuery) {
    return normalizedQuery == null ||
        normalizedQuery.isEmpty ||
        name.normalized.contains(normalizedQuery);
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

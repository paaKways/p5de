import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:p5de/contexts/sketch_catalog/application/sketch_catalog_exporter.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/user_visible_sketch_mirror.dart';

class UserVisibleSketchCatalogExporter implements SketchCatalogExporter {
  const UserVisibleSketchCatalogExporter({
    required SketchRepository sketchRepository,
    required ProjectRepository projectRepository,
    UserVisibleSketchMirror mirror =
        const MethodChannelUserVisibleSketchMirror(),
    Directory? stagingRoot,
  }) : _sketchRepository = sketchRepository,
       _projectRepository = projectRepository,
       _mirror = mirror,
       _stagingRoot = stagingRoot;

  final SketchRepository _sketchRepository;
  final ProjectRepository _projectRepository;
  final UserVisibleSketchMirror _mirror;
  final Directory? _stagingRoot;

  Future<Directory> _root() async {
    if (_stagingRoot != null) {
      return _stagingRoot;
    }
    final documents = await getApplicationDocumentsDirectory();
    return Directory(
      '${documents.path}${Platform.pathSeparator}export_staging'
      '${Platform.pathSeparator}sketches',
    );
  }

  @override
  Future<String> exportAll() async {
    final items = <SketchCatalogExportItem>[];
    for (final project in await _projectRepository.list()) {
      for (final sketch in await _projectRepository.listSketches(project.id)) {
        items.add(
          SketchCatalogExportItem.project(project: project, sketch: sketch),
        );
      }
    }
    for (final sketch in await _sketchRepository.list()) {
      items.add(SketchCatalogExportItem.standalone(sketch));
    }
    return exportItems(items);
  }

  @override
  Future<String> exportItems(Iterable<SketchCatalogExportItem> items) async {
    final root = await _root();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    await root.create(recursive: true);

    final projectDirectories = <String, Directory>{};
    for (final item in items) {
      final project = item.project;
      if (project == null) {
        final directory = await _availableDirectory(
          root,
          item.sketch.name.value,
          item.sketch.id,
        );
        await _writeSketch(directory, item.sketch);
        continue;
      }

      final projectDirectory = projectDirectories.putIfAbsent(
        project.id,
        () => Directory(
          '${root.path}${Platform.pathSeparator}'
          '${_folderNameFor(project.name.value)}',
        ),
      );
      if (!await projectDirectory.exists()) {
        await projectDirectory.create(recursive: true);
      }
      final sketchDirectory = await _availableDirectory(
        projectDirectory,
        item.sketch.name.value,
        item.sketch.id,
      );
      await _writeSketch(sketchDirectory, item.sketch);
    }
    await _mirror.syncFrom(root);
    return 'Download/SuaCode IDE/sketches';
  }

  Future<void> _writeSketch(Directory directory, Sketch sketch) async {
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      '${sketch.language.fileNameForSketchName(sketch.name.value)}',
    );
    await file.writeAsString(sketch.code);
  }

  Future<Directory> _availableDirectory(
    Directory parent,
    String name,
    String id,
  ) async {
    final preferred = Directory(
      '${parent.path}${Platform.pathSeparator}${_folderNameFor(name)}',
    );
    if (!await preferred.exists()) {
      return preferred;
    }
    return Directory(
      '${parent.path}${Platform.pathSeparator}${_folderNameFor(name)}'
      '-${_shortId(id)}',
    );
  }

  String _folderNameFor(String name) {
    final sanitized = name
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    return sanitized.isEmpty ? 'Untitled' : sanitized;
  }

  String _shortId(String id) {
    return id
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
        .padRight(8, '0')
        .substring(0, 8);
  }
}

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';

class NativeSketchFileStore {
  NativeSketchFileStore({Directory? rootDirectory})
    : _rootDirectory = rootDirectory;

  final Directory? _rootDirectory;

  Future<void> write(Sketch sketch) async {
    final directory = await _directoryFor(sketch);
    await directory.create(recursive: true);

    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      '${sketch.language.fileName}',
    );
    await file.writeAsString(sketch.code);
  }

  Future<void> sync(Iterable<Sketch> sketches) async {
    for (final sketch in sketches) {
      await write(sketch);
    }
  }

  Future<void> delete(Sketch sketch) async {
    final directory = await _directoryFor(sketch);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<Directory> _directoryFor(Sketch sketch) async {
    final root = _rootDirectory ?? await _defaultRootDirectory();
    return Directory(
      '${root.path}${Platform.pathSeparator}${_folderNameFor(sketch)}',
    );
  }

  Future<Directory> _defaultRootDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}${Platform.pathSeparator}sketches');
  }

  String _folderNameFor(Sketch sketch) {
    final sanitized = sketch.name.value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    return sanitized.isEmpty ? sketch.id : sanitized;
  }
}

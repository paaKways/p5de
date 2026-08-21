import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/saf_catalog_store.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/saf_directory_bridge.dart';

void main() {
  test('selected folder is the source of truth for project sketches', () async {
    final bridge = _MemorySafDirectoryBridge();
    final store = SafCatalogStore(bridge: bridge);

    final project = await store.createProject('Course');
    final original = _sketch(id: 'one', name: 'Graph', code: 'old');
    await store.createProjectSketch(project.id, original);
    await bridge.writeText('Course/Graph/Helper.pde', 'void helper() {}');

    expect((await store.listProjectSketches(project.id)).single, original);
    expect(bridge.files['Course/Graph/Graph.pde'], 'old');

    final updated = original.copyWith(
      name: SketchName('Graph Updated'),
      code: 'new',
      updatedAt: 20,
    );
    await store.updateProjectSketch(project.id, updated);

    expect(await bridge.exists('Course/Graph'), isFalse);
    expect(bridge.files['Course/Graph Updated/Graph Updated.pde'], 'new');
    expect(bridge.files['Course/Graph Updated/Helper.pde'], 'void helper() {}');
    expect(
      (await store.findProjectSketch(project.id, original.id))?.code,
      'new',
    );

    await store.deleteProjectSketch(project.id, original.id);
    expect(await store.listProjectSketches(project.id), isEmpty);
  });

  test('reads externally created standalone sketches from the tree', () async {
    final bridge = _MemorySafDirectoryBridge();
    await bridge.createDirectory('External');
    await bridge.writeText('External/External.pde', 'void setup() {}');
    final store = SafCatalogStore(bridge: bridge);

    final sketches = await store.listStandaloneSketches();

    expect(sketches, hasLength(1));
    expect(sketches.single.name.value, 'External');
    expect(sketches.single.code, 'void setup() {}');
    expect(bridge.files, contains('External/.p5de.json'));
  });

  test(
    'reads Processing files when Android appended a txt extension',
    () async {
      final bridge = _MemorySafDirectoryBridge();
      await bridge.createDirectory('Course/Graph');
      await bridge.writeText('Course/Graph/Graph.pde.txt', 'void setup() {}');
      await bridge.writeText(
        'Course/Graph/.p5de.json',
        '{"id":"graph","sourceFileName":"Graph.pde",'
            '"createdAt":10,"updatedAt":20}',
      );
      final store = SafCatalogStore(bridge: bridge);
      final project = (await store.listProjects()).single;

      final sketches = await store.listProjectSketches(project.id);

      expect(sketches, hasLength(1));
      expect(sketches.single.name.value, 'Graph');
      expect(sketches.single.language, SketchLanguage.processingJava);
      expect(sketches.single.code, 'void setup() {}');
    },
  );

  test(
    'reuses the project path and reads sketch folders concurrently',
    () async {
      final bridge = _MemorySafDirectoryBridge(
        delay: const Duration(milliseconds: 5),
      );
      final store = SafCatalogStore(bridge: bridge);
      final project = await store.createProject('Course');
      await store.createProjectSketches(project.id, [
        _sketch(id: 'one', name: 'One', code: '1'),
        _sketch(id: 'two', name: 'Two', code: '2'),
        _sketch(id: 'three', name: 'Three', code: '3'),
      ]);
      bridge.resetReadMetrics();

      final sketches = await store.listProjectSketches(project.id);

      expect(sketches, hasLength(3));
      expect(bridge.rootListCount, 0);
      expect(bridge.maxConcurrentReads, greaterThan(1));
    },
  );
}

Sketch _sketch({
  required String id,
  required String name,
  required String code,
}) {
  return Sketch(
    id: id,
    name: SketchName(name),
    language: SketchLanguage.processingJava,
    code: code,
    createdAt: 10,
    updatedAt: 10,
  );
}

class _MemorySafDirectoryBridge extends SafDirectoryBridge {
  _MemorySafDirectoryBridge({this.delay = Duration.zero});

  final Duration delay;
  final directories = <String>{''};
  final files = <String, String>{};
  var _clock = 1;
  var _concurrentReads = 0;
  var maxConcurrentReads = 0;
  var rootListCount = 0;

  void resetReadMetrics() {
    _concurrentReads = 0;
    maxConcurrentReads = 0;
    rootListCount = 0;
  }

  @override
  Future<List<SafDocumentEntry>> list(String path) async {
    if (path.isEmpty) {
      rootListCount++;
    }
    _concurrentReads++;
    if (_concurrentReads > maxConcurrentReads) {
      maxConcurrentReads = _concurrentReads;
    }
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final prefix = path.isEmpty ? '' : '$path/';
    final entries = <SafDocumentEntry>[];
    for (final directory in directories) {
      if (directory.isEmpty || !directory.startsWith(prefix)) {
        continue;
      }
      final remainder = directory.substring(prefix.length);
      if (remainder.isEmpty || remainder.contains('/')) {
        continue;
      }
      entries.add(_entry(directory, isDirectory: true));
    }
    for (final file in files.keys) {
      if (!file.startsWith(prefix)) {
        continue;
      }
      final remainder = file.substring(prefix.length);
      if (remainder.isEmpty || remainder.contains('/')) {
        continue;
      }
      entries.add(_entry(file, isDirectory: false));
    }
    _concurrentReads--;
    return entries;
  }

  @override
  Future<String> readText(String path) async {
    _concurrentReads++;
    if (_concurrentReads > maxConcurrentReads) {
      maxConcurrentReads = _concurrentReads;
    }
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final content = files[path]!;
    _concurrentReads--;
    return content;
  }

  @override
  Future<void> writeText(
    String path,
    String content, {
    String mimeType = 'text/plain',
  }) async {
    final parent = _parent(path);
    if (!directories.contains(parent)) {
      await createDirectory(parent);
    }
    files[path] = content;
    _clock++;
  }

  @override
  Future<void> createDirectory(String path) async {
    var current = '';
    for (final segment in path.split('/').where((part) => part.isNotEmpty)) {
      current = current.isEmpty ? segment : '$current/$segment';
      directories.add(current);
    }
    _clock++;
  }

  @override
  Future<String> rename(String path, String newName) async {
    final parent = _parent(path);
    final target = parent.isEmpty ? newName : '$parent/$newName';
    final directoryUpdates = <String, String>{};
    for (final directory in directories) {
      if (directory == path || directory.startsWith('$path/')) {
        directoryUpdates[directory] =
            '$target${directory.substring(path.length)}';
      }
    }
    final fileUpdates = <String, String>{};
    for (final file in files.keys) {
      if (file == path || file.startsWith('$path/')) {
        fileUpdates[file] = '$target${file.substring(path.length)}';
      }
    }
    for (final update in directoryUpdates.entries) {
      directories
        ..remove(update.key)
        ..add(update.value);
    }
    for (final update in fileUpdates.entries) {
      final content = files.remove(update.key)!;
      files[update.value] = content;
    }
    _clock++;
    return target;
  }

  @override
  Future<void> delete(String path) async {
    directories.removeWhere(
      (directory) => directory == path || directory.startsWith('$path/'),
    );
    files.removeWhere((file, _) => file == path || file.startsWith('$path/'));
    _clock++;
  }

  @override
  Future<bool> exists(String path) async {
    return directories.contains(path) || files.containsKey(path);
  }

  SafDocumentEntry _entry(String path, {required bool isDirectory}) {
    return SafDocumentEntry(
      name: path.split('/').last,
      path: path,
      uri: 'memory://$path',
      isDirectory: isDirectory,
      mimeType: isDirectory ? 'vnd.android.document/directory' : 'text/plain',
      lastModified: _clock,
      size: isDirectory ? 0 : files[path]?.length ?? 0,
    );
  }

  String _parent(String path) {
    final separator = path.lastIndexOf('/');
    return separator < 0 ? '' : path.substring(0, separator);
  }
}

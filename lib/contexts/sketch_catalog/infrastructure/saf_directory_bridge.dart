import 'package:flutter/services.dart';

class SafDirectorySelection {
  const SafDirectorySelection({required this.uri, required this.name});

  factory SafDirectorySelection.fromMap(Map<Object?, Object?> map) {
    return SafDirectorySelection(
      uri: map['uri'] as String,
      name: map['name'] as String,
    );
  }

  final String uri;
  final String name;
}

class SafDocumentEntry {
  const SafDocumentEntry({
    required this.name,
    required this.path,
    required this.uri,
    required this.isDirectory,
    required this.mimeType,
    required this.lastModified,
    required this.size,
  });

  factory SafDocumentEntry.fromMap(Map<Object?, Object?> map) {
    return SafDocumentEntry(
      name: map['name'] as String,
      path: map['path'] as String,
      uri: map['uri'] as String,
      isDirectory: map['isDirectory'] as bool,
      mimeType: map['mimeType'] as String,
      lastModified: (map['lastModified'] as num?)?.toInt() ?? 0,
      size: (map['size'] as num?)?.toInt() ?? 0,
    );
  }

  final String name;
  final String path;
  final String uri;
  final bool isDirectory;
  final String mimeType;
  final int lastModified;
  final int size;
}

class SafDirectoryBridge {
  const SafDirectoryBridge();

  static const MethodChannel _channel = MethodChannel(
    'ai.suacode.ide/saf_directory',
  );

  Future<SafDirectorySelection?> getSelectedDirectory() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'getDirectory',
    );
    return result == null ? null : SafDirectorySelection.fromMap(result);
  }

  Future<SafDirectorySelection?> pickDirectory() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'pickDirectory',
    );
    return result == null ? null : SafDirectorySelection.fromMap(result);
  }

  Future<List<SafDocumentEntry>> list(String path) async {
    final result = await _channel.invokeListMethod<Object?>('list', {
      'path': path,
    });
    return (result ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(SafDocumentEntry.fromMap)
        .toList(growable: false);
  }

  Future<String> readText(String path) async {
    return await _channel.invokeMethod<String>('readText', {'path': path}) ??
        '';
  }

  Future<void> writeText(
    String path,
    String content, {
    String mimeType = 'text/plain',
  }) {
    return _channel.invokeMethod<void>('writeText', {
      'path': path,
      'content': content,
      'mimeType': mimeType,
    });
  }

  Future<void> createDirectory(String path) {
    return _channel.invokeMethod<void>('createDirectory', {'path': path});
  }

  Future<String> rename(String path, String newName) async {
    return await _channel.invokeMethod<String>('rename', {
          'path': path,
          'newName': newName,
        }) ??
        path;
  }

  Future<void> delete(String path) {
    return _channel.invokeMethod<void>('delete', {'path': path});
  }

  Future<bool> exists(String path) async {
    return await _channel.invokeMethod<bool>('exists', {'path': path}) ?? false;
  }
}

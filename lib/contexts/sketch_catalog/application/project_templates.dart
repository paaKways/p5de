import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';

enum ProjectTemplate {
  empty,
  suacodeAfrica;

  String get label {
    switch (this) {
      case ProjectTemplate.empty:
        return 'Empty';
      case ProjectTemplate.suacodeAfrica:
        return 'SuaCode (Intro to Prog)';
    }
  }

  String? get manifestAsset {
    switch (this) {
      case ProjectTemplate.empty:
        return null;
      case ProjectTemplate.suacodeAfrica:
        return 'assets/default_projects/suacode_africa/manifest.json';
    }
  }

  String? get seedKey {
    switch (this) {
      case ProjectTemplate.empty:
        return null;
      case ProjectTemplate.suacodeAfrica:
        return 'default_project_suacode_africa_v1';
    }
  }

  String? get defaultProjectName {
    switch (this) {
      case ProjectTemplate.empty:
        return null;
      case ProjectTemplate.suacodeAfrica:
        return 'SuaCode (Intro to Prog)';
    }
  }
}

class BundledProjectTemplate {
  const BundledProjectTemplate({
    required this.language,
    required this.sketches,
  });

  final SketchLanguage language;
  final List<BundledProjectTemplateSketch> sketches;

  static Future<BundledProjectTemplate?> load(
    ProjectTemplate template, {
    AssetBundle? bundle,
  }) async {
    final assetBundle = bundle ?? rootBundle;
    final manifestAsset = template.manifestAsset;
    if (manifestAsset == null) {
      return null;
    }

    final value = jsonDecode(await assetBundle.loadString(manifestAsset));
    if (value is! Map) {
      throw const FormatException(
        'Bundled project manifest must be an object.',
      );
    }

    final map = value.cast<String, Object?>();
    final rawSketches = map['sketches'];
    if (rawSketches is! List) {
      throw const FormatException('Bundled project sketches must be a list.');
    }

    return BundledProjectTemplate(
      language: SketchLanguage.fromStorageValue(
        _optionalString(map, 'language') ??
            SketchLanguage.processingJava.storageValue,
      ),
      sketches: rawSketches
          .map((entry) => BundledProjectTemplateSketch.fromJson(entry))
          .toList(growable: false),
    );
  }
}

class BundledProjectTemplateSketch {
  const BundledProjectTemplateSketch({required this.name, required this.asset});

  final String name;
  final String asset;

  Future<Sketch> toSketch({
    required AssetBundle bundle,
    required IdGenerator idGenerator,
    required Clock clock,
    required SketchLanguage language,
    required int offset,
  }) async {
    final timestamp = clock.now().millisecondsSinceEpoch - offset;
    return Sketch(
      id: idGenerator.newId(),
      name: SketchName(name),
      language: language,
      code: await bundle.loadString(asset),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  factory BundledProjectTemplateSketch.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Bundled sketch must be an object.');
    }
    final map = value.cast<String, Object?>();
    return BundledProjectTemplateSketch(
      name: _requiredString(map, 'name'),
      asset: _requiredString(map, 'asset'),
    );
  }
}

String _requiredString(Map<String, Object?> map, String key) {
  final value = _optionalString(map, key);
  if (value == null) {
    throw FormatException('Missing required string "$key".');
  }
  return value;
}

String? _optionalString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}

import 'package:equatable/equatable.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';

class EditorDraft extends Equatable {
  const EditorDraft({
    required this.sketchId,
    required this.name,
    required this.language,
    required this.savedCode,
    required this.currentCode,
    required this.updatedAt,
  });

  factory EditorDraft.fromSketch(Sketch sketch) {
    return EditorDraft(
      sketchId: sketch.id,
      name: sketch.name.value,
      language: sketch.language,
      savedCode: sketch.code,
      currentCode: sketch.code,
      updatedAt: sketch.updatedAt,
    );
  }

  final String sketchId;
  final String name;
  final SketchLanguage language;
  final String savedCode;
  final String currentCode;
  final int updatedAt;

  bool get isDirty => currentCode != savedCode;

  EditorDraft copyWith({
    String? savedCode,
    String? currentCode,
    int? updatedAt,
  }) {
    return EditorDraft(
      sketchId: sketchId,
      name: name,
      language: language,
      savedCode: savedCode ?? this.savedCode,
      currentCode: currentCode ?? this.currentCode,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    sketchId,
    name,
    language,
    savedCode,
    currentCode,
    updatedAt,
  ];
}

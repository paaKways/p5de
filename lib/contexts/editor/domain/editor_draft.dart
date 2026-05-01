import 'package:equatable/equatable.dart';

class EditorDraft extends Equatable {
  const EditorDraft({
    required this.sketchId,
    required this.sketchName,
    required this.code,
    required this.lastSavedAt,
    required this.isDirty,
  });

  final String sketchId;
  final String sketchName;
  final String code;
  final int lastSavedAt;
  final bool isDirty;

  EditorDraft copyWith({
    String? sketchName,
    String? code,
    int? lastSavedAt,
    bool? isDirty,
  }) {
    return EditorDraft(
      sketchId: sketchId,
      sketchName: sketchName ?? this.sketchName,
      code: code ?? this.code,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  List<Object?> get props => [sketchId, sketchName, code, lastSavedAt, isDirty];
}

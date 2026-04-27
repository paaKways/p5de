part of 'editor_bloc.dart';

enum EditorStatus { initial, loading, ready, saving, failure }

class EditorState extends Equatable {
  const EditorState({
    this.status = EditorStatus.initial,
    this.draft,
    this.savedSketch,
    this.errorMessage,
  });

  final EditorStatus status;
  final EditorDraft? draft;
  final Sketch? savedSketch;
  final String? errorMessage;

  bool get isDirty => draft?.isDirty ?? false;
  bool get isSaving => status == EditorStatus.saving;

  EditorState copyWith({
    EditorStatus? status,
    EditorDraft? draft,
    Sketch? savedSketch,
    String? errorMessage,
    bool clearSavedSketch = false,
    bool clearErrorMessage = false,
  }) {
    return EditorState(
      status: status ?? this.status,
      draft: draft ?? this.draft,
      savedSketch: clearSavedSketch ? null : savedSketch ?? this.savedSketch,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, draft, savedSketch, errorMessage];
}

part of 'editor_bloc.dart';

enum EditorStatus { initial, loading, ready, saving, error }

class EditorState extends Equatable {
  const EditorState({
    this.status = EditorStatus.initial,
    this.draft,
    this.errorMessage,
  });

  final EditorStatus status;
  final EditorDraft? draft;
  final String? errorMessage;

  EditorState copyWith({
    EditorStatus? status,
    EditorDraft? draft,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return EditorState(
      status: status ?? this.status,
      draft: draft ?? this.draft,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, draft, errorMessage];
}

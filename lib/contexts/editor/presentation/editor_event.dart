part of 'editor_bloc.dart';

sealed class EditorEvent extends Equatable {
  const EditorEvent();

  @override
  List<Object?> get props => [];
}

class EditorStarted extends EditorEvent {
  const EditorStarted(this.sketchId);

  final String sketchId;

  @override
  List<Object?> get props => [sketchId];
}

class EditorCodeChanged extends EditorEvent {
  const EditorCodeChanged(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

class EditorSaveRequested extends EditorEvent {
  const EditorSaveRequested();
}

class EditorAppBackgrounded extends EditorEvent {
  const EditorAppBackgrounded();
}

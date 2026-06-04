part of 'runtime_preview_bloc.dart';

sealed class RuntimePreviewEvent extends Equatable {
  const RuntimePreviewEvent();

  @override
  List<Object?> get props => [];
}

class RuntimePreviewRunStarted extends RuntimePreviewEvent {
  const RuntimePreviewRunStarted();
}

class RuntimePreviewStatusChanged extends RuntimePreviewEvent {
  const RuntimePreviewStatusChanged(this.status);

  final String status;

  @override
  List<Object?> get props => [status];
}

class RuntimePreviewLogReceived extends RuntimePreviewEvent {
  const RuntimePreviewLogReceived({required this.level, required this.message});

  final RuntimeConsoleLevel level;
  final String message;

  @override
  List<Object?> get props => [level, message];
}

class RuntimePreviewErrorReceived extends RuntimePreviewEvent {
  const RuntimePreviewErrorReceived({
    required this.message,
    this.stack,
    this.diagnostics = const [],
  });

  final String message;
  final String? stack;
  final List<RuntimeDiagnostic> diagnostics;

  @override
  List<Object?> get props => [message, stack, diagnostics];
}

class RuntimePreviewFirstFrameReceived extends RuntimePreviewEvent {
  const RuntimePreviewFirstFrameReceived();
}

class RuntimePreviewStopped extends RuntimePreviewEvent {
  const RuntimePreviewStopped();
}

class RuntimePreviewWatchdogTimedOut extends RuntimePreviewEvent {
  const RuntimePreviewWatchdogTimedOut();
}

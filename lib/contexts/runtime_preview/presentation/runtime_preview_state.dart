part of 'runtime_preview_bloc.dart';

enum RuntimePreviewStatus {
  idle,
  starting,
  compiling,
  loading,
  running,
  stopped,
  failure,
}

class RuntimePreviewState extends Equatable {
  const RuntimePreviewState({
    this.status = RuntimePreviewStatus.idle,
    this.consoleEntries = const [],
    this.errorMessage,
    this.hasFirstFrame = false,
  });

  final RuntimePreviewStatus status;
  final List<RuntimeConsoleEntry> consoleEntries;
  final String? errorMessage;
  final bool hasFirstFrame;

  bool get isBusy =>
      status == RuntimePreviewStatus.starting ||
      status == RuntimePreviewStatus.compiling ||
      status == RuntimePreviewStatus.loading;

  RuntimePreviewState copyWith({
    RuntimePreviewStatus? status,
    List<RuntimeConsoleEntry>? consoleEntries,
    String? errorMessage,
    bool? hasFirstFrame,
    bool clearErrorMessage = false,
  }) {
    return RuntimePreviewState(
      status: status ?? this.status,
      consoleEntries: consoleEntries ?? this.consoleEntries,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      hasFirstFrame: hasFirstFrame ?? this.hasFirstFrame,
    );
  }

  @override
  List<Object?> get props => [
    status,
    consoleEntries,
    errorMessage,
    hasFirstFrame,
  ];
}

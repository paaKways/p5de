import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:p5de/contexts/runtime_preview/domain/runtime_console_entry.dart';

part 'runtime_preview_event.dart';
part 'runtime_preview_state.dart';

class RuntimePreviewBloc
    extends Bloc<RuntimePreviewEvent, RuntimePreviewState> {
  RuntimePreviewBloc() : super(const RuntimePreviewState()) {
    on<RuntimePreviewRunStarted>(_onRunStarted);
    on<RuntimePreviewStatusChanged>(_onStatusChanged);
    on<RuntimePreviewLogReceived>(_onLogReceived);
    on<RuntimePreviewErrorReceived>(_onErrorReceived);
    on<RuntimePreviewFirstFrameReceived>(_onFirstFrameReceived);
    on<RuntimePreviewStopped>(_onStopped);
    on<RuntimePreviewWatchdogTimedOut>(_onWatchdogTimedOut);
  }

  void _onRunStarted(
    RuntimePreviewRunStarted event,
    Emitter<RuntimePreviewState> emit,
  ) {
    emit(
      const RuntimePreviewState(
        status: RuntimePreviewStatus.starting,
        consoleEntries: [],
      ),
    );
  }

  void _onStatusChanged(
    RuntimePreviewStatusChanged event,
    Emitter<RuntimePreviewState> emit,
  ) {
    emit(
      state.copyWith(
        status: _mapStatus(event.status),
        clearErrorMessage: event.status != 'failure',
      ),
    );
  }

  void _onLogReceived(
    RuntimePreviewLogReceived event,
    Emitter<RuntimePreviewState> emit,
  ) {
    final message = _stripPhaseLog(event.message);
    if (message.trim().isEmpty) {
      return;
    }
    emit(
      state.copyWith(
        consoleEntries: [
          ...state.consoleEntries,
          RuntimeConsoleEntry(level: event.level, message: message),
        ],
      ),
    );
  }

  void _onErrorReceived(
    RuntimePreviewErrorReceived event,
    Emitter<RuntimePreviewState> emit,
  ) {
    final entries = <RuntimeConsoleEntry>[
      ...state.consoleEntries,
      for (final diagnostic in event.diagnostics)
        RuntimeConsoleEntry(
          level: RuntimeConsoleLevel.error,
          message: '${diagnostic.displayLocation} - ${diagnostic.message}',
          line: diagnostic.lineNumber,
          column: diagnostic.columnNumber,
        ),
    ];

    if (event.message.trim().isNotEmpty &&
        !entries.any((entry) => entry.message.contains(event.message))) {
      entries.add(
        RuntimeConsoleEntry(
          level: RuntimeConsoleLevel.error,
          message: event.message,
        ),
      );
    }

    emit(
      state.copyWith(
        status: RuntimePreviewStatus.failure,
        consoleEntries: entries,
        errorMessage: event.message,
      ),
    );
  }

  void _onFirstFrameReceived(
    RuntimePreviewFirstFrameReceived event,
    Emitter<RuntimePreviewState> emit,
  ) {
    emit(
      state.copyWith(
        status: RuntimePreviewStatus.running,
        hasFirstFrame: true,
        clearErrorMessage: true,
      ),
    );
  }

  void _onStopped(
    RuntimePreviewStopped event,
    Emitter<RuntimePreviewState> emit,
  ) {
    emit(
      state.copyWith(
        status: RuntimePreviewStatus.stopped,
        clearErrorMessage: true,
      ),
    );
  }

  void _onWatchdogTimedOut(
    RuntimePreviewWatchdogTimedOut event,
    Emitter<RuntimePreviewState> emit,
  ) {
    const message =
        'Processing Java runtime did not reach first frame within 60 seconds. '
        'The runtime was stopped so the sketch can be revised or restarted.';
    emit(
      state.copyWith(
        status: RuntimePreviewStatus.failure,
        consoleEntries: [
          ...state.consoleEntries,
          const RuntimeConsoleEntry(
            level: RuntimeConsoleLevel.error,
            message: message,
          ),
        ],
        errorMessage: message,
      ),
    );
  }

  RuntimePreviewStatus _mapStatus(String rawStatus) {
    return switch (rawStatus) {
      'compiling' => RuntimePreviewStatus.compiling,
      'loading' => RuntimePreviewStatus.loading,
      'running' => RuntimePreviewStatus.running,
      'stopped' => RuntimePreviewStatus.stopped,
      'failure' => RuntimePreviewStatus.failure,
      _ => state.status,
    };
  }

  String _stripPhaseLog(String message) {
    return message
        .replaceAll(
          RegExp(r'(^|\n)Phase log:\n(?:- .*(?:\n|$))+', multiLine: true),
          '\n',
        )
        .trim();
  }
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/runtime_preview/domain/runtime_console_entry.dart';
import 'package:p5de/contexts/runtime_preview/presentation/runtime_preview_bloc.dart';

void main() {
  group('RuntimePreviewBloc', () {
    blocTest<RuntimePreviewBloc, RuntimePreviewState>(
      'tracks compile to first-frame lifecycle',
      build: RuntimePreviewBloc.new,
      act: (bloc) {
        bloc
          ..add(const RuntimePreviewRunStarted())
          ..add(const RuntimePreviewStatusChanged('compiling'))
          ..add(const RuntimePreviewStatusChanged('loading'))
          ..add(const RuntimePreviewFirstFrameReceived());
      },
      expect: () => [
        const RuntimePreviewState(status: RuntimePreviewStatus.starting),
        const RuntimePreviewState(status: RuntimePreviewStatus.compiling),
        const RuntimePreviewState(status: RuntimePreviewStatus.loading),
        const RuntimePreviewState(
          status: RuntimePreviewStatus.running,
          hasFirstFrame: true,
        ),
      ],
    );

    blocTest<RuntimePreviewBloc, RuntimePreviewState>(
      'records mapped compiler diagnostics as console errors',
      build: RuntimePreviewBloc.new,
      act: (bloc) {
        bloc
          ..add(const RuntimePreviewRunStarted())
          ..add(
            const RuntimePreviewErrorReceived(
              message: 'missing semicolon',
              diagnostics: [
                RuntimeDiagnostic(
                  fileName: 'Sketch.pde',
                  lineNumber: 4,
                  message: 'missing semicolon',
                  severity: 'ERROR',
                ),
              ],
            ),
          );
      },
      expect: () => [
        const RuntimePreviewState(status: RuntimePreviewStatus.starting),
        isA<RuntimePreviewState>()
            .having(
              (state) => state.status,
              'status',
              RuntimePreviewStatus.failure,
            )
            .having(
              (state) => state.consoleEntries.single.level,
              'level',
              RuntimeConsoleLevel.error,
            )
            .having(
              (state) => state.consoleEntries.single.message,
              'message',
              'Sketch.pde:4 - missing semicolon',
            ),
      ],
    );
  });
}

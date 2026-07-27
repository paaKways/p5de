import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:p5de/app/telemetry/app_telemetry.dart';
import 'package:p5de/contexts/editor/application/load_sketch_for_edit.dart';
import 'package:p5de/contexts/editor/application/save_sketch.dart';
import 'package:p5de/contexts/editor/domain/editor_draft.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';

part 'editor_event.dart';
part 'editor_state.dart';

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc({
    required LoadSketchForEdit loadSketchForEdit,
    required SaveSketch saveSketch,
    AppTelemetry telemetry = const NoopAppTelemetry(),
  }) : _loadSketchForEdit = loadSketchForEdit,
       _saveSketch = saveSketch,
       _telemetry = telemetry,
       super(const EditorState()) {
    on<EditorLoaded>(_onLoaded);
    on<EditorCodeChanged>(_onCodeChanged);
    on<EditorSaveRequested>(_onSaveRequested);
  }

  final LoadSketchForEdit _loadSketchForEdit;
  final SaveSketch _saveSketch;
  final AppTelemetry _telemetry;

  Future<void> _onLoaded(EditorLoaded event, Emitter<EditorState> emit) async {
    emit(state.copyWith(status: EditorStatus.loading, clearErrorMessage: true));
    try {
      final draft = await _loadSketchForEdit(event.sketchId);
      unawaited(_telemetry.setCustomKey('current_sketch_id', event.sketchId));
      unawaited(
        _telemetry.logEvent(
          'editor_open',
          parameters: {
            'sketch_id': event.sketchId,
            'language': draft.language.storageValue,
          },
        ),
      );
      emit(state.copyWith(status: EditorStatus.ready, draft: draft));
    } catch (error, stackTrace) {
      unawaited(
        _telemetry.recordError(
          error,
          stackTrace,
          reason: 'editor_load_failed',
          parameters: {'sketch_id': event.sketchId},
        ),
      );
      emit(
        state.copyWith(
          status: EditorStatus.failure,
          errorMessage: _mapError(error),
        ),
      );
    }
  }

  void _onCodeChanged(EditorCodeChanged event, Emitter<EditorState> emit) {
    final draft = state.draft;
    if (draft == null || draft.currentCode == event.code) {
      return;
    }

    emit(
      state.copyWith(
        draft: draft.copyWith(currentCode: event.code),
        clearSavedSketch: true,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> _onSaveRequested(
    EditorSaveRequested event,
    Emitter<EditorState> emit,
  ) async {
    final draft = state.draft;
    if (draft == null ||
        !draft.isDirty ||
        state.status == EditorStatus.saving) {
      return;
    }

    emit(state.copyWith(status: EditorStatus.saving, clearErrorMessage: true));
    try {
      final savedSketch = await _saveSketch(draft);
      unawaited(
        _telemetry.logEvent(
          'editor_save',
          parameters: {
            'sketch_id': draft.sketchId,
            'language': draft.language.storageValue,
            'code_length': savedSketch.code.length,
          },
        ),
      );
      final latestDraft = state.draft ?? draft;
      final savedDraft = latestDraft.copyWith(
        savedCode: savedSketch.code,
        updatedAt: savedSketch.updatedAt,
      );
      emit(
        state.copyWith(
          status: EditorStatus.ready,
          draft: savedDraft,
          savedSketch: savedSketch,
        ),
      );
      if (savedDraft.isDirty) {
        add(const EditorSaveRequested());
      }
    } catch (error, stackTrace) {
      unawaited(
        _telemetry.recordError(
          error,
          stackTrace,
          reason: 'editor_save_failed',
          parameters: {'sketch_id': draft.sketchId},
        ),
      );
      emit(
        state.copyWith(
          status: EditorStatus.ready,
          errorMessage: _mapError(error),
        ),
      );
    }
  }

  String _mapError(Object error) {
    if (error is SketchNotFoundException) {
      return 'Sketch not found.';
    }
    return 'Unable to save sketch.';
  }
}

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:p5de/contexts/editor/application/load_sketch_for_edit.dart';
import 'package:p5de/contexts/editor/application/save_sketch.dart';
import 'package:p5de/contexts/editor/application/update_draft.dart';
import 'package:p5de/contexts/editor/domain/editor_draft.dart';
import 'package:p5de/contexts/editor/infrastructure/draft_persistence_adapter.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';

part 'editor_event.dart';
part 'editor_state.dart';

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc({
    required LoadSketchForEdit loadSketchForEdit,
    required UpdateDraft updateDraft,
    required SaveSketch saveSketch,
    required DraftPersistenceAdapter draftPersistence,
    this.autosaveDelay = const Duration(milliseconds: 800),
  }) : _loadSketchForEdit = loadSketchForEdit,
       _updateDraft = updateDraft,
       _saveSketch = saveSketch,
       _draftPersistence = draftPersistence,
       super(const EditorState()) {
    on<EditorStarted>(_onStarted);
    on<EditorCodeChanged>(_onCodeChanged);
    on<EditorSaveRequested>(_onSaveRequested);
    on<EditorAppBackgrounded>(_onAppBackgrounded);
  }

  final LoadSketchForEdit _loadSketchForEdit;
  final UpdateDraft _updateDraft;
  final SaveSketch _saveSketch;
  final DraftPersistenceAdapter _draftPersistence;
  final Duration autosaveDelay;
  Timer? _autosaveTimer;

  Future<void> _onStarted(
    EditorStarted event,
    Emitter<EditorState> emit,
  ) async {
    emit(state.copyWith(status: EditorStatus.loading, clearErrorMessage: true));
    try {
      // Load persisted sketch and cached draft concurrently to reduce startup wait.
      final results = await Future.wait<Object?>([
        _loadSketchForEdit(event.sketchId),
        _draftPersistence.read(event.sketchId),
      ]);
      final baseDraft = results[0]! as EditorDraft;
      final cachedDraft = results[1] as EditorDraft?;

      // Prefer unsaved cached draft when available.
      final initialDraft = cachedDraft ?? baseDraft;

      emit(state.copyWith(status: EditorStatus.ready, draft: initialDraft));
    } catch (error) {
      emit(
        state.copyWith(
          status: EditorStatus.error,
          errorMessage: _mapError(error),
        ),
      );
    }
  }

  Future<void> _onCodeChanged(
    EditorCodeChanged event,
    Emitter<EditorState> emit,
  ) async {
    // ignore: avoid_print
    print('EditorBloc _onCodeChanged');
    final current = state.draft;
    if (current == null) {
      return;
    }

    final next = _updateDraft(draft: current, nextCode: event.code);
    emit(state.copyWith(status: EditorStatus.ready, draft: next));
    await _draftPersistence.write(next);

    // Autosave on typing pause to avoid disk writes on every keystroke.
    _autosaveTimer?.cancel();
    if (next.isDirty) {
      _autosaveTimer = Timer(autosaveDelay, () {
        if (!isClosed) {
          add(const EditorSaveRequested());
        }
      });
    }
  }

  Future<void> _onSaveRequested(
    EditorSaveRequested event,
    Emitter<EditorState> emit,
  ) async {
    final draft = state.draft;
    if (draft == null || !draft.isDirty) {
      return;
    }

    emit(state.copyWith(status: EditorStatus.saving, clearErrorMessage: true));
    try {
      final saved = await _saveSketch(draft);
      await _draftPersistence.clear(saved.sketchId);
      emit(state.copyWith(status: EditorStatus.ready, draft: saved));
    } catch (error) {
      emit(
        state.copyWith(
          status: EditorStatus.error,
          errorMessage: _mapError(error),
        ),
      );
    }
  }

  Future<void> _onAppBackgrounded(
    EditorAppBackgrounded event,
    Emitter<EditorState> emit,
  ) async {
    // Lifecycle-triggered save reduces lost edits during tab/app switches.
    if (state.draft?.isDirty ?? false) {
      add(const EditorSaveRequested());
    }
  }

  String _mapError(Object error) {
    if (error is SketchNotFoundException) {
      return 'Sketch not found.';
    }
    return 'Unexpected editor error.';
  }

  @override
  Future<void> close() {
    _autosaveTimer?.cancel();
    return super.close();
  }
}





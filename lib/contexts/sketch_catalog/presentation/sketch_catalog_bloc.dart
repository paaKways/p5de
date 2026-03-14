import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/delete_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/rename_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/search_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/sketch_templates.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';

part 'sketch_catalog_event.dart';
part 'sketch_catalog_state.dart';

class SketchCatalogBloc extends Bloc<SketchCatalogEvent, SketchCatalogState> {
  SketchCatalogBloc({
    required CreateSketch createSketch,
    required RenameSketch renameSketch,
    required DeleteSketch deleteSketch,
    required ListSketches listSketches,
    required SearchSketches searchSketches,
  }) : _createSketch = createSketch,
       _renameSketch = renameSketch,
       _deleteSketch = deleteSketch,
       _listSketches = listSketches,
       _searchSketches = searchSketches,
       super(const SketchCatalogState()) {
    on<SketchCatalogLoaded>(_onLoaded);
    on<SketchCatalogQueryChanged>(_onQueryChanged);
    on<SketchCatalogCreateRequested>(_onCreateRequested);
    on<SketchCatalogRenameRequested>(_onRenameRequested);
    on<SketchCatalogDeleteRequested>(_onDeleteRequested);
  }

  final CreateSketch _createSketch;
  final RenameSketch _renameSketch;
  final DeleteSketch _deleteSketch;
  final ListSketches _listSketches;
  final SearchSketches _searchSketches;

  Future<void> _onLoaded(
    SketchCatalogLoaded event,
    Emitter<SketchCatalogState> emit,
  ) async {
    await _refresh(emit, query: state.query);
  }

  Future<void> _onQueryChanged(
    SketchCatalogQueryChanged event,
    Emitter<SketchCatalogState> emit,
  ) async {
    emit(state.copyWith(query: event.query, clearErrorMessage: true));
    await _refresh(emit, query: event.query);
  }

  Future<void> _onCreateRequested(
    SketchCatalogCreateRequested event,
    Emitter<SketchCatalogState> emit,
  ) async {
    try {
      await _createSketch(name: event.name, code: event.code ?? kDefaultSketchTemplate);
      await _refresh(emit, query: state.query);
    } catch (error) {
      emit(state.copyWith(errorMessage: _mapError(error)));
    }
  }

  Future<void> _onRenameRequested(
    SketchCatalogRenameRequested event,
    Emitter<SketchCatalogState> emit,
  ) async {
    try {
      await _renameSketch(sketchId: event.sketchId, newName: event.newName);
      await _refresh(emit, query: state.query);
    } catch (error) {
      emit(state.copyWith(errorMessage: _mapError(error)));
    }
  }

  Future<void> _onDeleteRequested(
    SketchCatalogDeleteRequested event,
    Emitter<SketchCatalogState> emit,
  ) async {
    try {
      await _deleteSketch(event.sketchId);
      await _refresh(emit, query: state.query);
    } catch (error) {
      emit(state.copyWith(errorMessage: _mapError(error)));
    }
  }

  Future<void> _refresh(
    Emitter<SketchCatalogState> emit, {
    required String query,
  }) async {
    // Keep previous list visible while a refresh is in progress.
    emit(
      state.copyWith(
        status: SketchCatalogStatus.loading,
        clearErrorMessage: true,
      ),
    );
    try {
      // Empty query lists all sketches; otherwise use repository-backed search.
      final sketches = query.trim().isEmpty
          ? await _listSketches()
          : await _searchSketches(query);
      emit(
        state.copyWith(status: SketchCatalogStatus.success, sketches: sketches),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: SketchCatalogStatus.failure,
          errorMessage: _mapError(error),
        ),
      );
    }
  }

  String _mapError(Object error) {
    // Map domain/application exceptions to user-facing copy.
    if (error is InvalidSketchNameException) {
      return error.message;
    }
    if (error is DuplicateSketchNameException) {
      return 'A sketch with that name already exists.';
    }
    if (error is SketchNotFoundException) {
      return 'Sketch not found.';
    }
    return 'Unexpected error. Please try again.';
  }
}


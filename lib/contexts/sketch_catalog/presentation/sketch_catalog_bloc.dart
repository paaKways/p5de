import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:p5de/app/telemetry/app_telemetry.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/delete_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/delete_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_favorite_project_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_favorite_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_projects.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/project_templates.dart';
import 'package:p5de/contexts/sketch_catalog/application/rename_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/rename_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/search_project_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/search_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/sketch_templates.dart';
import 'package:p5de/contexts/sketch_catalog/application/toggle_project_sketch_favorite.dart';
import 'package:p5de/contexts/sketch_catalog/application/toggle_sketch_favorite.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
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
    required ListFavoriteSketches listFavoriteSketches,
    required SearchSketches searchSketches,
    required CreateProject createProject,
    required RenameProject renameProject,
    required DeleteProject deleteProject,
    required ListProjects listProjects,
    required ListFavoriteProjectSketches listFavoriteProjectSketches,
    required SearchProjectSketches searchProjectSketches,
    required ToggleSketchFavorite toggleSketchFavorite,
    required ToggleProjectSketchFavorite toggleProjectSketchFavorite,
    AppTelemetry telemetry = const NoopAppTelemetry(),
  }) : _createSketch = createSketch,
       _renameSketch = renameSketch,
       _deleteSketch = deleteSketch,
       _listSketches = listSketches,
       _listFavoriteSketches = listFavoriteSketches,
       _searchSketches = searchSketches,
       _createProject = createProject,
       _renameProject = renameProject,
       _deleteProject = deleteProject,
       _listProjects = listProjects,
       _listFavoriteProjectSketches = listFavoriteProjectSketches,
       _searchProjectSketches = searchProjectSketches,
       _toggleSketchFavorite = toggleSketchFavorite,
       _toggleProjectSketchFavorite = toggleProjectSketchFavorite,
       _telemetry = telemetry,
       super(const SketchCatalogState()) {
    on<SketchCatalogLoaded>(_onLoaded);
    on<SketchCatalogQueryChanged>(_onQueryChanged);
    on<SketchCatalogCreateRequested>(_onCreateRequested);
    on<SketchCatalogRenameRequested>(_onRenameRequested);
    on<SketchCatalogDeleteRequested>(_onDeleteRequested);
    on<SketchCatalogProjectCreateRequested>(_onProjectCreateRequested);
    on<SketchCatalogProjectRenameRequested>(_onProjectRenameRequested);
    on<SketchCatalogProjectDeleteRequested>(_onProjectDeleteRequested);
    on<SketchCatalogFilterChanged>(_onFilterChanged);
    on<SketchCatalogFavoriteToggled>(_onFavoriteToggled);
    on<SketchCatalogProjectSketchFavoriteToggled>(
      _onProjectSketchFavoriteToggled,
    );
  }

  final CreateSketch _createSketch;
  final RenameSketch _renameSketch;
  final DeleteSketch _deleteSketch;
  final ListSketches _listSketches;
  final ListFavoriteSketches _listFavoriteSketches;
  final SearchSketches _searchSketches;
  final CreateProject _createProject;
  final RenameProject _renameProject;
  final DeleteProject _deleteProject;
  final ListProjects _listProjects;
  final ListFavoriteProjectSketches _listFavoriteProjectSketches;
  final SearchProjectSketches _searchProjectSketches;
  final ToggleSketchFavorite _toggleSketchFavorite;
  final ToggleProjectSketchFavorite _toggleProjectSketchFavorite;
  final AppTelemetry _telemetry;

  Future<void> _onLoaded(
    SketchCatalogLoaded event,
    Emitter<SketchCatalogState> emit,
  ) async {
    await _refresh(emit, query: state.query, filter: state.filter);
  }

  Future<void> _onQueryChanged(
    SketchCatalogQueryChanged event,
    Emitter<SketchCatalogState> emit,
  ) async {
    emit(state.copyWith(query: event.query, clearErrorMessage: true));
    await _refresh(emit, query: event.query, filter: state.filter);
  }

  Future<void> _onCreateRequested(
    SketchCatalogCreateRequested event,
    Emitter<SketchCatalogState> emit,
  ) async {
    try {
      const language = SketchLanguage.processingJava;
      await _createSketch(
        name: event.name,
        language: language,
        code: event.code ?? defaultSketchTemplateFor(language),
      );
      unawaited(
        _telemetry.logEvent(
          'sketch_create',
          parameters: {'source': 'catalog', 'language': language.storageValue},
        ),
      );
      await _refresh(emit, query: state.query, filter: state.filter);
    } catch (error, stackTrace) {
      _recordBlocError(error, stackTrace, 'sketch_create_failed');
      emit(state.copyWith(errorMessage: _mapError(error)));
    }
  }

  Future<void> _onRenameRequested(
    SketchCatalogRenameRequested event,
    Emitter<SketchCatalogState> emit,
  ) async {
    try {
      await _renameSketch(sketchId: event.sketchId, newName: event.newName);
      unawaited(
        _telemetry.logEvent(
          'sketch_rename',
          parameters: {'source': 'catalog', 'sketch_id': event.sketchId},
        ),
      );
      await _refresh(emit, query: state.query, filter: state.filter);
    } catch (error, stackTrace) {
      _recordBlocError(error, stackTrace, 'sketch_rename_failed');
      emit(state.copyWith(errorMessage: _mapError(error)));
    }
  }

  Future<void> _onDeleteRequested(
    SketchCatalogDeleteRequested event,
    Emitter<SketchCatalogState> emit,
  ) async {
    try {
      await _deleteSketch(event.sketchId);
      unawaited(
        _telemetry.logEvent(
          'sketch_delete',
          parameters: {'source': 'catalog', 'sketch_id': event.sketchId},
        ),
      );
      await _refresh(emit, query: state.query, filter: state.filter);
    } catch (error, stackTrace) {
      _recordBlocError(error, stackTrace, 'sketch_delete_failed');
      emit(state.copyWith(errorMessage: _mapError(error)));
    }
  }

  Future<void> _onProjectCreateRequested(
    SketchCatalogProjectCreateRequested event,
    Emitter<SketchCatalogState> emit,
  ) async {
    try {
      await _createProject(name: event.name, template: event.template);
      unawaited(
        _telemetry.logEvent(
          'project_create',
          parameters: {'source': 'catalog', 'template': event.template.name},
        ),
      );
      await _refresh(emit, query: state.query, filter: state.filter);
    } catch (error, stackTrace) {
      _recordBlocError(error, stackTrace, 'project_create_failed');
      emit(state.copyWith(errorMessage: _mapError(error)));
    }
  }

  Future<void> _onProjectRenameRequested(
    SketchCatalogProjectRenameRequested event,
    Emitter<SketchCatalogState> emit,
  ) async {
    try {
      await _renameProject(projectId: event.projectId, newName: event.newName);
      unawaited(
        _telemetry.logEvent(
          'project_rename',
          parameters: {'source': 'catalog', 'project_id': event.projectId},
        ),
      );
      await _refresh(emit, query: state.query, filter: state.filter);
    } catch (error, stackTrace) {
      _recordBlocError(error, stackTrace, 'project_rename_failed');
      emit(state.copyWith(errorMessage: _mapError(error)));
    }
  }

  Future<void> _onProjectDeleteRequested(
    SketchCatalogProjectDeleteRequested event,
    Emitter<SketchCatalogState> emit,
  ) async {
    try {
      await _deleteProject(event.projectId);
      unawaited(
        _telemetry.logEvent(
          'project_delete',
          parameters: {'source': 'catalog', 'project_id': event.projectId},
        ),
      );
      await _refresh(emit, query: state.query, filter: state.filter);
    } catch (error, stackTrace) {
      _recordBlocError(error, stackTrace, 'project_delete_failed');
      emit(state.copyWith(errorMessage: _mapError(error)));
    }
  }

  Future<void> _onFilterChanged(
    SketchCatalogFilterChanged event,
    Emitter<SketchCatalogState> emit,
  ) async {
    if (event.filter == state.filter) {
      if (state.errorMessage != null) {
        emit(state.copyWith(clearErrorMessage: true));
      }
      return;
    }

    final previousFilter = state.filter;
    final canReuseCurrentCatalog =
        state.status == SketchCatalogStatus.success &&
        event.filter != SketchCatalogFilter.favourites &&
        previousFilter != SketchCatalogFilter.favourites;

    emit(state.copyWith(filter: event.filter, clearErrorMessage: true));
    unawaited(
      _telemetry.logEvent(
        'catalog_filter_change',
        parameters: {'filter': event.filter.name},
      ),
    );
    if (canReuseCurrentCatalog) {
      return;
    }

    await _refresh(emit, query: state.query, filter: event.filter);
  }

  Future<void> _onFavoriteToggled(
    SketchCatalogFavoriteToggled event,
    Emitter<SketchCatalogState> emit,
  ) async {
    try {
      await _toggleSketchFavorite(event.sketchId);
      unawaited(
        _telemetry.logEvent(
          'sketch_favorite_toggle',
          parameters: {'source': 'catalog', 'sketch_id': event.sketchId},
        ),
      );
      await _refresh(emit, query: state.query, filter: state.filter);
    } catch (error, stackTrace) {
      _recordBlocError(error, stackTrace, 'sketch_favorite_toggle_failed');
      emit(state.copyWith(errorMessage: _mapError(error)));
    }
  }

  Future<void> _onProjectSketchFavoriteToggled(
    SketchCatalogProjectSketchFavoriteToggled event,
    Emitter<SketchCatalogState> emit,
  ) async {
    try {
      await _toggleProjectSketchFavorite(
        projectId: event.projectId,
        sketchId: event.sketchId,
      );
      unawaited(
        _telemetry.logEvent(
          'sketch_favorite_toggle',
          parameters: {
            'source': 'project',
            'project_id': event.projectId,
            'sketch_id': event.sketchId,
          },
        ),
      );
      await _refresh(emit, query: state.query, filter: state.filter);
    } catch (error, stackTrace) {
      _recordBlocError(
        error,
        stackTrace,
        'project_sketch_favorite_toggle_failed',
      );
      emit(state.copyWith(errorMessage: _mapError(error)));
    }
  }

  Future<void> _refresh(
    Emitter<SketchCatalogState> emit, {
    required String query,
    required SketchCatalogFilter filter,
  }) async {
    // Keep previous list visible while a refresh is in progress.
    emit(
      state.copyWith(
        status: SketchCatalogStatus.loading,
        clearErrorMessage: true,
      ),
    );
    try {
      final trimmedQuery = query.trim();
      if (trimmedQuery.isNotEmpty) {
        unawaited(
          _telemetry.logEvent(
            'catalog_search',
            parameters: {
              'query_length': trimmedQuery.length,
              'filter': filter.name,
            },
          ),
        );
      }
      if (filter == SketchCatalogFilter.favourites) {
        final sketches = await _listFavoriteSketches(
          query: trimmedQuery.isEmpty ? null : query,
        );
        final projectSketchMatches = await _listFavoriteProjectSketches(
          query: trimmedQuery.isEmpty ? null : query,
        );
        emit(
          state.copyWith(
            status: SketchCatalogStatus.success,
            sketches: sketches,
            projects: const <Project>[],
            projectSketchMatches: projectSketchMatches,
            filter: filter,
          ),
        );
        return;
      }

      var sketches = trimmedQuery.isEmpty
          ? await _listSketches()
          : await _searchSketches(query);
      var projects = await _listProjects(query: query);
      var projectSketchMatches = trimmedQuery.isEmpty
          ? const <ProjectSketchMatch>[]
          : await _searchProjectSketches(query);

      emit(
        state.copyWith(
          status: SketchCatalogStatus.success,
          sketches: sketches,
          projects: projects,
          projectSketchMatches: projectSketchMatches,
          filter: filter,
        ),
      );
    } catch (error, stackTrace) {
      _recordBlocError(error, stackTrace, 'catalog_refresh_failed');
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
    if (error is DuplicateProjectNameException) {
      return 'A folder with that name already exists.';
    }
    if (error is SketchNotFoundException) {
      return 'Sketch not found.';
    }
    if (error is ProjectNotFoundException) {
      return 'Folder not found.';
    }
    return 'Unexpected error. Please try again.';
  }

  void _recordBlocError(Object error, StackTrace stackTrace, String reason) {
    unawaited(
      _telemetry.recordError(
        error,
        stackTrace,
        reason: reason,
        parameters: {
          'catalog_filter': state.filter.name,
          'catalog_query_length': state.query.trim().length,
        },
      ),
    );
  }
}

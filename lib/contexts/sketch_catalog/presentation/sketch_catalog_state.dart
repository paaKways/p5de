part of 'sketch_catalog_bloc.dart';

enum SketchCatalogStatus { initial, loading, success, failure }

enum SketchCatalogFilter { all, recent, favourites }

class SketchCatalogState extends Equatable {
  const SketchCatalogState({
    this.status = SketchCatalogStatus.initial,
    this.sketches = const [],
    this.projects = const [],
    this.projectSketchMatches = const [],
    this.query = '',
    this.filter = SketchCatalogFilter.all,
    this.errorMessage,
  });

  final SketchCatalogStatus status;
  final List<Sketch> sketches;
  final List<Project> projects;
  final List<ProjectSketchMatch> projectSketchMatches;
  final String query;
  final SketchCatalogFilter filter;
  final String? errorMessage;

  SketchCatalogState copyWith({
    SketchCatalogStatus? status,
    List<Sketch>? sketches,
    List<Project>? projects,
    List<ProjectSketchMatch>? projectSketchMatches,
    String? query,
    SketchCatalogFilter? filter,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return SketchCatalogState(
      status: status ?? this.status,
      sketches: sketches ?? this.sketches,
      projects: projects ?? this.projects,
      projectSketchMatches: projectSketchMatches ?? this.projectSketchMatches,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    sketches,
    projects,
    projectSketchMatches,
    query,
    filter,
    errorMessage,
  ];
}

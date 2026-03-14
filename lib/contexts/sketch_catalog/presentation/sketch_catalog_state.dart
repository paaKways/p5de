part of 'sketch_catalog_bloc.dart';

enum SketchCatalogStatus { initial, loading, success, failure }

class SketchCatalogState extends Equatable {
  const SketchCatalogState({
    this.status = SketchCatalogStatus.initial,
    this.sketches = const [],
    this.query = '',
    this.errorMessage,
  });

  final SketchCatalogStatus status;
  final List<Sketch> sketches;
  final String query;
  final String? errorMessage;

  SketchCatalogState copyWith({
    SketchCatalogStatus? status,
    List<Sketch>? sketches,
    String? query,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return SketchCatalogState(
      status: status ?? this.status,
      sketches: sketches ?? this.sketches,
      query: query ?? this.query,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, sketches, query, errorMessage];
}

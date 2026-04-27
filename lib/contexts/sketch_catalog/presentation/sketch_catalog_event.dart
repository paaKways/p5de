part of 'sketch_catalog_bloc.dart';

sealed class SketchCatalogEvent extends Equatable {
  const SketchCatalogEvent();

  @override
  List<Object?> get props => [];
}

class SketchCatalogLoaded extends SketchCatalogEvent {
  const SketchCatalogLoaded();
}

class SketchCatalogQueryChanged extends SketchCatalogEvent {
  const SketchCatalogQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class SketchCatalogCreateRequested extends SketchCatalogEvent {
  const SketchCatalogCreateRequested(this.name, {this.language, this.code});

  final String name;
  final SketchLanguage? language;
  final String? code;

  @override
  List<Object?> get props => [name, language, code];
}

class SketchCatalogRenameRequested extends SketchCatalogEvent {
  const SketchCatalogRenameRequested({
    required this.sketchId,
    required this.newName,
  });

  final String sketchId;
  final String newName;

  @override
  List<Object?> get props => [sketchId, newName];
}

class SketchCatalogDeleteRequested extends SketchCatalogEvent {
  const SketchCatalogDeleteRequested(this.sketchId);

  final String sketchId;

  @override
  List<Object?> get props => [sketchId];
}

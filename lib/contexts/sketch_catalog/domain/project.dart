import 'package:equatable/equatable.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';

class Project extends Equatable {
  const Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.sketchCount,
  });

  final String id;
  final SketchName name;
  final int createdAt;
  final int updatedAt;
  final int sketchCount;

  @override
  List<Object?> get props => [
    id,
    name.value,
    createdAt,
    updatedAt,
    sketchCount,
  ];
}

class ProjectSketchMatch extends Equatable {
  const ProjectSketchMatch({required this.project, required this.sketch});

  final Project project;
  final Sketch sketch;

  @override
  List<Object?> get props => [project, sketch];
}

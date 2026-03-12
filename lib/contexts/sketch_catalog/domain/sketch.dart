import 'package:equatable/equatable.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';

class Sketch extends Equatable {
  const Sketch({
    required this.id,
    required this.name,
    required this.code,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final SketchName name;
  final String code;
  final int createdAt;
  final int updatedAt;

  Sketch copyWith({SketchName? name, String? code, int? updatedAt}) {
    return Sketch(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name.value, code, createdAt, updatedAt];
}

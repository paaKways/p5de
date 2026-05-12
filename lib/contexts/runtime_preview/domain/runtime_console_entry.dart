import 'package:equatable/equatable.dart';

enum RuntimeConsoleLevel { info, warning, error }

class RuntimeConsoleEntry extends Equatable {
  const RuntimeConsoleEntry({
    required this.level,
    required this.message,
    this.line,
    this.column,
  });

  final RuntimeConsoleLevel level;
  final String message;
  final int? line;
  final int? column;

  @override
  List<Object?> get props => [level, message, line, column];
}

class RuntimeDiagnostic extends Equatable {
  const RuntimeDiagnostic({
    required this.message,
    this.fileName,
    this.lineNumber,
    this.columnNumber,
    this.severity,
  });

  factory RuntimeDiagnostic.fromPayload(Map<String, Object?> payload) {
    return RuntimeDiagnostic(
      message: (payload['message'] as String?) ?? 'Compiler diagnostic',
      fileName: payload['fileName'] as String?,
      lineNumber: (payload['lineNumber'] as num?)?.toInt(),
      columnNumber: (payload['columnNumber'] as num?)?.toInt(),
      severity: payload['severity'] as String?,
    );
  }

  final String message;
  final String? fileName;
  final int? lineNumber;
  final int? columnNumber;
  final String? severity;

  String get displayLocation {
    final name = fileName ?? 'Sketch.pde';
    final line = lineNumber;
    if (line == null) {
      return name;
    }
    final column = columnNumber;
    return column == null ? '$name:$line' : '$name:$line:$column';
  }

  @override
  List<Object?> get props => [
    message,
    fileName,
    lineNumber,
    columnNumber,
    severity,
  ];
}

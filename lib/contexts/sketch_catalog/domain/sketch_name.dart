class InvalidSketchNameException implements Exception {
  InvalidSketchNameException(this.message);

  final String message;
}

class SketchName {
  SketchName(String value)
    : value = _validateAndNormalize(value),
      normalized = _normalize(value);

  final String value;
  final String normalized;

  static String _validateAndNormalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw InvalidSketchNameException('Sketch name cannot be empty.');
    }
    if (trimmed.length > 120) {
      throw InvalidSketchNameException(
        'Sketch name cannot exceed 120 characters.',
      );
    }
    return trimmed;
  }

  static String _normalize(String raw) => raw.trim().toLowerCase();
}

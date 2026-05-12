enum SketchLanguage {
  processingJava(
    storageValue: 'processing_java',
    displayName: 'Processing Java',
    fileName: 'Sketch.pde',
  ),
  p5js(storageValue: 'p5js', displayName: 'p5.js', fileName: 'sketch.js');

  const SketchLanguage({
    required this.storageValue,
    required this.displayName,
    required this.fileName,
  });

  final String storageValue;
  final String displayName;
  final String fileName;

  String get fileExtension {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1);
  }

  String fileNameForSketchName(String sketchName) {
    final trimmedName = sketchName.trim();
    if (trimmedName.isEmpty) {
      return fileName;
    }

    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0) {
      return trimmedName;
    }

    final extension = fileName.substring(dotIndex);
    if (trimmedName.toLowerCase().endsWith(extension.toLowerCase())) {
      return trimmedName;
    }

    return '$trimmedName$extension';
  }

  static SketchLanguage fromStorageValue(String value) {
    return SketchLanguage.values.firstWhere(
      (language) => language.storageValue == value,
      orElse: () => SketchLanguage.p5js,
    );
  }
}

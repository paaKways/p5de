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

  static SketchLanguage fromStorageValue(String value) {
    return SketchLanguage.values.firstWhere(
      (language) => language.storageValue == value,
      orElse: () => SketchLanguage.p5js,
    );
  }
}

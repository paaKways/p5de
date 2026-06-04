enum SketchStorageBackend {
  drift('drift', 'Drift (SQLite)'),
  filesystem('filesystem', 'Filesystem');

  const SketchStorageBackend(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static SketchStorageBackend fromStorageValue(String? value) {
    return SketchStorageBackend.values.firstWhere(
      (backend) => backend.storageValue == value,
      orElse: () => SketchStorageBackend.filesystem,
    );
  }
}

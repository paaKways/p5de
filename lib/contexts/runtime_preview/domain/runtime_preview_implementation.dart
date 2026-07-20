enum RuntimePreviewImplementation {
  standard('standard', 'Standard preview'),
  fullscreenPhysical('fullscreen_physical', 'Full-screen physical preview');

  const RuntimePreviewImplementation(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static RuntimePreviewImplementation fromStorageValue(String? value) {
    return RuntimePreviewImplementation.values.firstWhere(
      (implementation) => implementation.storageValue == value,
      orElse: () => RuntimePreviewImplementation.standard,
    );
  }
}

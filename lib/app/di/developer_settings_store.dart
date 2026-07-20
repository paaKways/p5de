import 'package:p5de/app/di/sketch_storage_backend.dart';
import 'package:p5de/contexts/runtime_preview/domain/runtime_preview_implementation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeveloperSettingsStore {
  const DeveloperSettingsStore();

  static const String _storageBackendKey = 'developer.sketch_storage_backend';
  static const String _runtimePreviewImplementationKey =
      'developer.runtime_preview_implementation';

  Future<SketchStorageBackend> loadStorageBackend() async {
    final preferences = await SharedPreferences.getInstance();
    return SketchStorageBackend.fromStorageValue(
      preferences.getString(_storageBackendKey),
    );
  }

  Future<void> saveStorageBackend(SketchStorageBackend backend) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageBackendKey, backend.storageValue);
  }

  Future<RuntimePreviewImplementation>
  loadRuntimePreviewImplementation() async {
    final preferences = await SharedPreferences.getInstance();
    return RuntimePreviewImplementation.fromStorageValue(
      preferences.getString(_runtimePreviewImplementationKey),
    );
  }

  Future<void> saveRuntimePreviewImplementation(
    RuntimePreviewImplementation implementation,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _runtimePreviewImplementationKey,
      implementation.storageValue,
    );
  }
}

import 'package:p5de/app/di/sketch_storage_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeveloperSettingsStore {
  const DeveloperSettingsStore();

  static const String _storageBackendKey = 'developer.sketch_storage_backend';

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
}

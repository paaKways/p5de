import 'package:p5de/contexts/sketch_catalog/application/seed_default_projects.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesDefaultProjectSeedStore
    implements DefaultProjectSeedStore {
  const SharedPreferencesDefaultProjectSeedStore();

  static const String _keyPrefix = 'default_project_seed.handled.';

  @override
  Future<bool> isDefaultProjectSeedHandled(String seedKey) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_keyFor(seedKey)) ?? false;
  }

  @override
  Future<void> markDefaultProjectSeedHandled(String seedKey) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_keyFor(seedKey), true);
  }

  String _keyFor(String seedKey) => '$_keyPrefix$seedKey';
}

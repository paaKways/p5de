import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/app/di/developer_settings_store.dart';
import 'package:p5de/contexts/runtime_preview/domain/runtime_preview_implementation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('runtime preview implementation defaults to standard', () {
    expect(
      RuntimePreviewImplementation.fromStorageValue(null),
      RuntimePreviewImplementation.standard,
    );
    expect(
      RuntimePreviewImplementation.fromStorageValue('unknown'),
      RuntimePreviewImplementation.standard,
    );
  });

  test('saves and loads runtime preview implementation', () async {
    const store = DeveloperSettingsStore();

    expect(
      await store.loadRuntimePreviewImplementation(),
      RuntimePreviewImplementation.standard,
    );

    await store.saveRuntimePreviewImplementation(
      RuntimePreviewImplementation.fullscreenPhysical,
    );

    expect(
      await store.loadRuntimePreviewImplementation(),
      RuntimePreviewImplementation.fullscreenPhysical,
    );
  });
}

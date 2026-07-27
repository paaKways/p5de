import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/app/di/developer_settings_store.dart';
import 'package:p5de/contexts/runtime_preview/domain/runtime_preview_implementation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('runtime preview implementation defaults to full-screen physical', () {
    expect(
      RuntimePreviewImplementation.fromStorageValue(null),
      RuntimePreviewImplementation.fullscreenPhysical,
    );
    expect(
      RuntimePreviewImplementation.fromStorageValue('unknown'),
      RuntimePreviewImplementation.fullscreenPhysical,
    );
  });

  test('saves and loads runtime preview implementation', () async {
    const store = DeveloperSettingsStore();

    expect(
      await store.loadRuntimePreviewImplementation(),
      RuntimePreviewImplementation.fullscreenPhysical,
    );

    await store.saveRuntimePreviewImplementation(
      RuntimePreviewImplementation.standard,
    );

    expect(
      await store.loadRuntimePreviewImplementation(),
      RuntimePreviewImplementation.standard,
    );
  });
}

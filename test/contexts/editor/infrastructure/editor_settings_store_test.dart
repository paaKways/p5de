import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/editor/infrastructure/editor_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('uses a smaller editor font size by default', () async {
    const store = EditorSettingsStore();

    expect(await store.loadFontSize(), EditorSettingsStore.defaultFontSize);
    expect(EditorSettingsStore.defaultFontSize, 14);
  });

  test('persists and clamps the editor font size', () async {
    const store = EditorSettingsStore();

    await store.saveFontSize(18);
    expect(await store.loadFontSize(), 18);

    await store.saveFontSize(100);
    expect(await store.loadFontSize(), EditorSettingsStore.maximumFontSize);
  });
}

import 'package:shared_preferences/shared_preferences.dart';

class EditorSettingsStore {
  const EditorSettingsStore();

  static const int defaultFontSize = 14;
  static const int minimumFontSize = 12;
  static const int maximumFontSize = 24;
  static const String _fontSizeKey = 'editor.font_size';

  Future<int> loadFontSize() async {
    final preferences = await SharedPreferences.getInstance();
    return _clampFontSize(preferences.getInt(_fontSizeKey));
  }

  Future<void> saveFontSize(int fontSize) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_fontSizeKey, _clampFontSize(fontSize));
  }

  int _clampFontSize(int? fontSize) {
    return (fontSize ?? defaultFontSize).clamp(
      minimumFontSize,
      maximumFontSize,
    );
  }
}

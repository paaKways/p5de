import 'dart:convert';

import 'package:p5de/contexts/editor/domain/editor_draft.dart';
import 'package:p5de/contexts/editor/infrastructure/draft_persistence_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsDraftPersistenceAdapter implements DraftPersistenceAdapter {
  static const String _keyPrefix = 'p5de.editor_draft.';

  @override
  Future<EditorDraft?> read(String sketchId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$sketchId');
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return EditorDraft(
        sketchId: json['sketchId'] as String,
        sketchName: json['sketchName'] as String,
        code: json['code'] as String,
        lastSavedAt: json['lastSavedAt'] as int,
        isDirty: json['isDirty'] as bool,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(EditorDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'sketchId': draft.sketchId,
      'sketchName': draft.sketchName,
      'code': draft.code,
      'lastSavedAt': draft.lastSavedAt,
      'isDirty': draft.isDirty,
    };
    await prefs.setString('$_keyPrefix${draft.sketchId}', jsonEncode(payload));
  }

  @override
  Future<void> clear(String sketchId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$sketchId');
  }
}

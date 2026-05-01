import 'package:p5de/contexts/editor/domain/editor_draft.dart';

abstract class DraftPersistenceAdapter {
  Future<EditorDraft?> read(String sketchId);

  Future<void> write(EditorDraft draft);

  Future<void> clear(String sketchId);
}

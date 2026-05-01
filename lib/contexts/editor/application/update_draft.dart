import 'package:p5de/contexts/editor/domain/editor_draft.dart';

class UpdateDraft {
  const UpdateDraft();

  EditorDraft call({required EditorDraft draft, required String nextCode}) {
    if (nextCode == draft.code) {
      return draft;
    }

    return draft.copyWith(code: nextCode, isDirty: true);
  }
}

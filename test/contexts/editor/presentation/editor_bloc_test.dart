import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/editor/application/load_sketch_for_edit.dart';
import 'package:p5de/contexts/editor/application/save_sketch.dart';
import 'package:p5de/contexts/editor/application/update_draft.dart';
import 'package:p5de/contexts/editor/domain/editor_draft.dart';
import 'package:p5de/contexts/editor/infrastructure/draft_persistence_adapter.dart';
import 'package:p5de/contexts/editor/presentation/editor_bloc.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/shared/clock.dart';

void main() {
  group('EditorBloc', () {
    late _InMemorySketchRepository repository;
    late EditorBloc bloc;

    setUp(() {
      repository = _InMemorySketchRepository(
        items: [
          Sketch(
            id: 's-1',
            name: SketchName('Demo'),
            code: 'function setup() {}',
            createdAt: 100,
            updatedAt: 100,
          ),
        ],
      );

      bloc = EditorBloc(
        loadSketchForEdit: LoadSketchForEdit(repository),
        updateDraft: const UpdateDraft(),
        saveSketch: SaveSketch(repository: repository, clock: _FixedClock(200)),
        draftPersistence: _InMemoryDraftPersistence(),
        autosaveDelay: const Duration(milliseconds: 20),
      );
    });

    tearDown(() async {
      await bloc.close();
    });

    blocTest<EditorBloc, EditorState>(
      'loads sketch into ready state',
      build: () => bloc,
      act: (bloc) => bloc.add(const EditorStarted('s-1')),
      expect: () => [
        const EditorState(status: EditorStatus.loading),
        isA<EditorState>()
            .having((s) => s.status, 'status', EditorStatus.ready)
            .having((s) => s.draft?.sketchId, 'id', 's-1')
            .having((s) => s.draft?.isDirty, 'dirty', false),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'marks draft dirty on code change',
      build: () => bloc,
      seed: () => const EditorState(
        status: EditorStatus.ready,
        draft: EditorDraft(
          sketchId: 's-1',
          sketchName: 'Demo',
          code: 'function setup() {}',
          lastSavedAt: 100,
          isDirty: false,
        ),
      ),
      act: (bloc) => bloc.add(const EditorCodeChanged('new code')),
      expect: () => [
        isA<EditorState>()
            .having((s) => s.status, 'status', EditorStatus.ready)
            .having((s) => s.draft?.isDirty, 'dirty', true)
            .having((s) => s.draft?.code, 'code', 'new code'),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'autosaves after typing pause',
      build: () => bloc,
      seed: () => const EditorState(
        status: EditorStatus.ready,
        draft: EditorDraft(
          sketchId: 's-1',
          sketchName: 'Demo',
          code: 'function setup() {}',
          lastSavedAt: 100,
          isDirty: false,
        ),
      ),
      act: (bloc) => bloc.add(const EditorCodeChanged('changed code')),
      wait: const Duration(milliseconds: 40),
      expect: () => [
        isA<EditorState>()
            .having((s) => s.status, 'status', EditorStatus.ready)
            .having((s) => s.draft?.isDirty, 'dirty', true),
        isA<EditorState>().having(
          (s) => s.status,
          'status',
          EditorStatus.saving,
        ),
        isA<EditorState>()
            .having((s) => s.status, 'status', EditorStatus.ready)
            .having((s) => s.draft?.isDirty, 'dirty', false)
            .having((s) => s.draft?.lastSavedAt, 'savedAt', 200),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'saves immediately on app background event when dirty',
      build: () => bloc,
      seed: () => const EditorState(
        status: EditorStatus.ready,
        draft: EditorDraft(
          sketchId: 's-1',
          sketchName: 'Demo',
          code: 'changed code',
          lastSavedAt: 100,
          isDirty: true,
        ),
      ),
      act: (bloc) => bloc.add(const EditorAppBackgrounded()),
      expect: () => [
        isA<EditorState>().having(
          (s) => s.status,
          'status',
          EditorStatus.saving,
        ),
        isA<EditorState>()
            .having((s) => s.status, 'status', EditorStatus.ready)
            .having((s) => s.draft?.isDirty, 'dirty', false),
      ],
    );
  });
}

class _InMemorySketchRepository implements SketchRepository {
  _InMemorySketchRepository({required List<Sketch> items})
    : _items = List<Sketch>.from(items);

  final List<Sketch> _items;

  @override
  Future<void> create(Sketch sketch) async {
    _items.add(sketch);
  }

  @override
  Future<void> deleteById(String sketchId) async {
    _items.removeWhere((item) => item.id == sketchId);
  }

  @override
  Future<bool> existsByNormalizedName(
    String normalizedName, {
    String? excludingSketchId,
  }) async {
    return _items.any((item) {
      if (excludingSketchId != null && item.id == excludingSketchId) {
        return false;
      }
      return item.name.normalized == normalizedName;
    });
  }

  @override
  Future<Sketch?> findById(String sketchId) async {
    for (final item in _items) {
      if (item.id == sketchId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<Sketch>> list({String? query}) async {
    return List<Sketch>.from(_items);
  }

  @override
  Future<void> update(Sketch sketch) async {
    final index = _items.indexWhere((item) => item.id == sketch.id);
    if (index < 0) {
      throw SketchNotFoundException();
    }
    _items[index] = sketch;
  }
}

class _FixedClock implements Clock {
  _FixedClock(this._epochMs);

  final int _epochMs;

  @override
  DateTime now() => DateTime.fromMillisecondsSinceEpoch(_epochMs);
}

class _InMemoryDraftPersistence implements DraftPersistenceAdapter {
  final Map<String, EditorDraft> _drafts = {};

  @override
  Future<void> clear(String sketchId) async {
    _drafts.remove(sketchId);
  }

  @override
  Future<EditorDraft?> read(String sketchId) async {
    return _drafts[sketchId];
  }

  @override
  Future<void> write(EditorDraft draft) async {
    _drafts[draft.sketchId] = draft;
  }
}

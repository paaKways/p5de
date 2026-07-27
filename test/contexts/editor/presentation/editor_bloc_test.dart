import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/editor/application/load_sketch_for_edit.dart';
import 'package:p5de/contexts/editor/application/save_sketch.dart';
import 'package:p5de/contexts/editor/presentation/editor_bloc.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/shared/clock.dart';

void main() {
  group('EditorBloc', () {
    late _InMemorySketchRepository repository;

    setUp(() {
      repository = _InMemorySketchRepository();
    });

    EditorBloc buildBloc() {
      return EditorBloc(
        loadSketchForEdit: LoadSketchForEdit(repository),
        saveSketch: SaveSketch(repository: repository, clock: _FixedClock()),
      );
    }

    blocTest<EditorBloc, EditorState>(
      'loads sketch into a clean draft',
      build: () {
        repository.seed(_sketch());
        return buildBloc();
      },
      act: (bloc) => bloc.add(const EditorLoaded('sketch-1')),
      expect: () => [
        const EditorState(status: EditorStatus.loading),
        isA<EditorState>()
            .having((state) => state.status, 'status', EditorStatus.ready)
            .having((state) => state.draft?.sketchId, 'sketchId', 'sketch-1')
            .having(
              (state) => state.draft?.currentCode,
              'code',
              'void setup() {}',
            )
            .having((state) => state.isDirty, 'dirty', false),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'tracks dirty state when code changes',
      build: () {
        repository.seed(_sketch());
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const EditorLoaded('sketch-1'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorCodeChanged('void draw() {}'));
      },
      skip: 2,
      expect: () => [
        isA<EditorState>()
            .having((state) => state.status, 'status', EditorStatus.ready)
            .having(
              (state) => state.draft?.currentCode,
              'code',
              'void draw() {}',
            )
            .having((state) => state.isDirty, 'dirty', true),
      ],
    );

    blocTest<EditorBloc, EditorState>(
      'saves draft and marks it clean',
      build: () {
        repository.seed(_sketch());
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const EditorLoaded('sketch-1'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorCodeChanged('void draw() {}'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const EditorSaveRequested());
      },
      skip: 3,
      expect: () => [
        isA<EditorState>().having(
          (state) => state.status,
          'status',
          EditorStatus.saving,
        ),
        isA<EditorState>()
            .having((state) => state.status, 'status', EditorStatus.ready)
            .having((state) => state.isDirty, 'dirty', false)
            .having(
              (state) => state.savedSketch?.code,
              'savedCode',
              'void draw() {}',
            )
            .having((state) => state.savedSketch?.updatedAt, 'updatedAt', 2000),
      ],
      verify: (_) async {
        final saved = await repository.findById('sketch-1');
        expect(saved?.code, 'void draw() {}');
        expect(saved?.updatedAt, 2000);
      },
    );

    blocTest<EditorBloc, EditorState>(
      'emits not found error when load misses',
      build: buildBloc,
      act: (bloc) => bloc.add(const EditorLoaded('missing')),
      expect: () => [
        const EditorState(status: EditorStatus.loading),
        const EditorState(
          status: EditorStatus.failure,
          errorMessage: 'Sketch not found.',
        ),
      ],
    );

    test(
      'preserves edits made while saving and saves the newest code',
      () async {
        repository.seed(_sketch());
        final firstSaveBarrier = Completer<void>();
        repository.nextUpdateBarrier = firstSaveBarrier;
        final bloc = buildBloc();
        addTearDown(bloc.close);

        bloc.add(const EditorLoaded('sketch-1'));
        await bloc.stream.firstWhere(
          (state) => state.status == EditorStatus.ready && state.draft != null,
        );

        bloc.add(const EditorCodeChanged('first edit'));
        await bloc.stream.firstWhere(
          (state) => state.draft?.currentCode == 'first edit',
        );
        bloc.add(const EditorSaveRequested());
        await bloc.stream.firstWhere((state) => state.isSaving);

        bloc.add(const EditorCodeChanged('newer edit'));
        await bloc.stream.firstWhere(
          (state) => state.isSaving && state.draft?.currentCode == 'newer edit',
        );

        firstSaveBarrier.complete();
        await bloc.stream.firstWhere(
          (state) =>
              !state.isSaving &&
              !state.isDirty &&
              state.savedSketch?.code == 'newer edit',
        );

        expect(repository.updatedCodes, ['first edit', 'newer edit']);
        expect((await repository.findById('sketch-1'))?.code, 'newer edit');
      },
    );
  });
}

Sketch _sketch() {
  return Sketch(
    id: 'sketch-1',
    name: SketchName('Sketch One'),
    language: SketchLanguage.processingJava,
    code: 'void setup() {}',
    createdAt: 1000,
    updatedAt: 1000,
  );
}

class _InMemorySketchRepository implements SketchRepository {
  final List<Sketch> _items = [];
  final List<String> updatedCodes = [];
  Completer<void>? nextUpdateBarrier;

  void seed(Sketch sketch) {
    _items.add(sketch);
  }

  @override
  Future<void> create(Sketch sketch) async => _items.add(sketch);

  @override
  Future<void> deleteById(String sketchId) async =>
      _items.removeWhere((item) => item.id == sketchId);

  @override
  Future<bool> existsByNormalizedName(
    String normalizedName, {
    String? excludingSketchId,
  }) async {
    return _items.any((item) => item.name.normalized == normalizedName);
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
  Future<List<Sketch>> list({String? query}) async => _items;

  @override
  Future<List<Sketch>> listFavorites({String? query}) async {
    return _items.where((item) => item.isFavorite).toList(growable: false);
  }

  @override
  Future<void> update(Sketch sketch) async {
    updatedCodes.add(sketch.code);
    final barrier = nextUpdateBarrier;
    nextUpdateBarrier = null;
    if (barrier != null) {
      await barrier.future;
    }
    final index = _items.indexWhere((item) => item.id == sketch.id);
    if (index < 0) {
      throw SketchNotFoundException();
    }
    _items[index] = sketch;
  }
}

class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime.fromMillisecondsSinceEpoch(2000);
}

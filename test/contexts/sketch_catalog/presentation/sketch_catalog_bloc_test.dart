import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/delete_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/rename_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/search_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_bloc.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';

void main() {
  group('SketchCatalogBloc', () {
    late _InMemorySketchRepository repository;
    late SketchCatalogBloc bloc;

    setUp(() {
      repository = _InMemorySketchRepository();
      bloc = SketchCatalogBloc(
        createSketch: CreateSketch(
          repository: repository,
          idGenerator: _IncrementalIdGenerator(),
          clock: _FixedClock(),
        ),
        renameSketch: RenameSketch(
          repository: repository,
          clock: _FixedClock(),
        ),
        deleteSketch: DeleteSketch(repository),
        listSketches: ListSketches(repository),
        searchSketches: SearchSketches(repository),
      );
    });

    tearDown(() async {
      await bloc.close();
    });

    blocTest<SketchCatalogBloc, SketchCatalogState>(
      'loads empty catalog',
      build: () => bloc,
      act: (bloc) => bloc.add(const SketchCatalogLoaded()),
      expect: () => const [
        SketchCatalogState(status: SketchCatalogStatus.loading),
        SketchCatalogState(status: SketchCatalogStatus.success),
      ],
    );

    blocTest<SketchCatalogBloc, SketchCatalogState>(
      'creates sketch and updates list',
      build: () => bloc,
      act: (bloc) async {
        bloc.add(const SketchCatalogLoaded());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SketchCatalogCreateRequested('My Sketch'));
      },
      expect: () => [
        const SketchCatalogState(status: SketchCatalogStatus.loading),
        const SketchCatalogState(status: SketchCatalogStatus.success),
        const SketchCatalogState(status: SketchCatalogStatus.loading),
        isA<SketchCatalogState>()
            .having((s) => s.status, 'status', SketchCatalogStatus.success)
            .having((s) => s.sketches.length, 'count', 1)
            .having((s) => s.sketches.first.name.value, 'name', 'My Sketch'),
      ],
    );

    blocTest<SketchCatalogBloc, SketchCatalogState>(
      'emits error on duplicate name',
      build: () => bloc,
      seed: () => const SketchCatalogState(status: SketchCatalogStatus.success),
      act: (bloc) async {
        await repository.create(
          Sketch(
            id: 'id-1',
            name: SketchName('Sketch A'),
            code: '',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
        bloc.add(const SketchCatalogCreateRequested(' sketch a '));
      },
      expect: () => [
        isA<SketchCatalogState>().having(
          (s) => s.errorMessage,
          'error',
          'A sketch with that name already exists.',
        ),
      ],
    );

    blocTest<SketchCatalogBloc, SketchCatalogState>(
      'renames existing sketch',
      build: () => bloc,
      act: (bloc) async {
        await repository.create(
          Sketch(
            id: 'id-10',
            name: SketchName('Old Name'),
            code: '',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
        bloc.add(
          const SketchCatalogRenameRequested(
            sketchId: 'id-10',
            newName: 'New Name',
          ),
        );
      },
      expect: () => [
        const SketchCatalogState(status: SketchCatalogStatus.loading),
        isA<SketchCatalogState>()
            .having((s) => s.status, 'status', SketchCatalogStatus.success)
            .having((s) => s.sketches.first.name.value, 'name', 'New Name'),
      ],
    );

    blocTest<SketchCatalogBloc, SketchCatalogState>(
      'deletes existing sketch',
      build: () => bloc,
      act: (bloc) async {
        await repository.create(
          Sketch(
            id: 'id-20',
            name: SketchName('Delete Me'),
            code: '',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
        bloc.add(const SketchCatalogDeleteRequested('id-20'));
      },
      expect: () => [
        const SketchCatalogState(status: SketchCatalogStatus.loading),
        const SketchCatalogState(status: SketchCatalogStatus.success),
      ],
    );

    blocTest<SketchCatalogBloc, SketchCatalogState>(
      'search filters catalog by query',
      build: () => bloc,
      act: (bloc) async {
        await repository.create(
          Sketch(
            id: 'id-30',
            name: SketchName('Alpha'),
            code: '',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
        await repository.create(
          Sketch(
            id: 'id-31',
            name: SketchName('Beta'),
            code: '',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
        bloc.add(const SketchCatalogQueryChanged('alp'));
      },
      expect: () => [
        const SketchCatalogState(query: 'alp'),
        const SketchCatalogState(
          status: SketchCatalogStatus.loading,
          query: 'alp',
        ),
        isA<SketchCatalogState>()
            .having((s) => s.status, 'status', SketchCatalogStatus.success)
            .having((s) => s.query, 'query', 'alp')
            .having((s) => s.sketches.length, 'count', 1)
            .having((s) => s.sketches.first.name.value, 'name', 'Alpha'),
      ],
    );

    blocTest<SketchCatalogBloc, SketchCatalogState>(
      'emits not found error for rename on missing sketch',
      build: () => bloc,
      act: (bloc) => bloc.add(
        const SketchCatalogRenameRequested(
          sketchId: 'missing-id',
          newName: 'Any',
        ),
      ),
      expect: () => [
        isA<SketchCatalogState>().having(
          (s) => s.errorMessage,
          'error',
          'Sketch not found.',
        ),
      ],
    );
  });
}

class _InMemorySketchRepository implements SketchRepository {
  final List<Sketch> _items = [];

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
    var output = List<Sketch>.from(_items);
    if (query != null && query.trim().isNotEmpty) {
      final normalized = query.trim().toLowerCase();
      output = output
          .where((item) => item.name.normalized.contains(normalized))
          .toList(growable: false);
    }
    output.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return output;
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
  @override
  DateTime now() => DateTime.fromMillisecondsSinceEpoch(1000);
}

class _IncrementalIdGenerator implements IdGenerator {
  int _count = 0;

  @override
  String newId() {
    _count++;
    return 'id-$_count';
  }
}

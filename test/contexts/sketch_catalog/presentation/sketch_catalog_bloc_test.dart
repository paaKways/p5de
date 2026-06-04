import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/delete_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/delete_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_favorite_project_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_favorite_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_projects.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/rename_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/rename_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/search_project_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/search_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/toggle_project_sketch_favorite.dart';
import 'package:p5de/contexts/sketch_catalog/application/toggle_sketch_favorite.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/in_memory_project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/project_scoped_sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_bloc.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';

void main() {
  group('SketchCatalogBloc', () {
    late _InMemorySketchRepository repository;
    late InMemoryProjectRepository projectRepository;
    late SketchCatalogBloc bloc;

    setUp(() {
      repository = _InMemorySketchRepository();
      projectRepository = InMemoryProjectRepository();
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
        listFavoriteSketches: ListFavoriteSketches(repository),
        searchSketches: SearchSketches(repository),
        createProject: CreateProject(
          projectRepository,
          clock: _FixedClock(),
          idGenerator: _IncrementalIdGenerator(),
        ),
        renameProject: RenameProject(projectRepository),
        deleteProject: DeleteProject(projectRepository),
        listProjects: ListProjects(projectRepository),
        listFavoriteProjectSketches: ListFavoriteProjectSketches(
          projectRepository,
        ),
        searchProjectSketches: SearchProjectSketches(projectRepository),
        toggleSketchFavorite: ToggleSketchFavorite(repository),
        toggleProjectSketchFavorite: ToggleProjectSketchFavorite(
          projectRepository,
        ),
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
            .having((s) => s.sketches.first.name.value, 'name', 'My Sketch')
            .having(
              (s) => s.sketches.first.language,
              'language',
              SketchLanguage.processingJava,
            ),
      ],
    );

    blocTest<SketchCatalogBloc, SketchCatalogState>(
      'creates Processing Java sketch even if another language is requested',
      build: () => bloc,
      act: (bloc) => bloc.add(
        const SketchCatalogCreateRequested(
          'PDE Sketch',
          language: SketchLanguage.p5js,
        ),
      ),
      expect: () => [
        const SketchCatalogState(status: SketchCatalogStatus.loading),
        isA<SketchCatalogState>()
            .having((s) => s.status, 'status', SketchCatalogStatus.success)
            .having(
              (s) => s.sketches.first.language,
              'language',
              SketchLanguage.processingJava,
            )
            .having(
              (s) => s.sketches.first.code,
              'code',
              contains('void setup'),
            ),
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
      'creates project and updates catalog',
      build: () => bloc,
      act: (bloc) =>
          bloc.add(const SketchCatalogProjectCreateRequested('Arcade')),
      expect: () => [
        const SketchCatalogState(status: SketchCatalogStatus.loading),
        isA<SketchCatalogState>()
            .having((s) => s.status, 'status', SketchCatalogStatus.success)
            .having((s) => s.projects.length, 'projects', 1)
            .having((s) => s.projects.first.name.value, 'name', 'Arcade'),
      ],
    );

    blocTest<SketchCatalogBloc, SketchCatalogState>(
      'search includes projects',
      build: () => bloc,
      act: (bloc) async {
        await projectRepository.create(name: 'Arcade Cabinet');
        bloc.add(const SketchCatalogQueryChanged('cab'));
      },
      expect: () => [
        const SketchCatalogState(query: 'cab'),
        const SketchCatalogState(
          status: SketchCatalogStatus.loading,
          query: 'cab',
        ),
        isA<SketchCatalogState>()
            .having((s) => s.status, 'status', SketchCatalogStatus.success)
            .having((s) => s.projects.length, 'projects', 1)
            .having(
              (s) => s.projects.first.name.value,
              'project name',
              'Arcade Cabinet',
            ),
      ],
    );

    blocTest<SketchCatalogBloc, SketchCatalogState>(
      'search includes sketches inside projects',
      build: () => bloc,
      act: (bloc) async {
        final project = await projectRepository.create(name: 'Arcade');
        final scopedRepository = ProjectScopedSketchRepository(
          projectRepository: projectRepository,
          projectId: project.id,
        );
        await CreateSketch(
          repository: scopedRepository,
          idGenerator: _IncrementalIdGenerator(),
          clock: _FixedClock(),
        )(name: 'Project Pong');
        bloc.add(const SketchCatalogQueryChanged('pong'));
      },
      expect: () => [
        const SketchCatalogState(query: 'pong'),
        const SketchCatalogState(
          status: SketchCatalogStatus.loading,
          query: 'pong',
        ),
        isA<SketchCatalogState>()
            .having((s) => s.status, 'status', SketchCatalogStatus.success)
            .having(
              (s) => s.projectSketchMatches.length,
              'project sketch matches',
              1,
            )
            .having(
              (s) => s.projectSketchMatches.first.project.name.value,
              'project name',
              'Arcade',
            )
            .having(
              (s) => s.projectSketchMatches.first.sketch.name.value,
              'sketch name',
              'Project Pong',
            ),
      ],
    );

    blocTest<SketchCatalogBloc, SketchCatalogState>(
      'filters standalone sketches by favourites',
      build: () => bloc,
      act: (bloc) async {
        await repository.create(
          Sketch(
            id: 'id-40',
            name: SketchName('Starred'),
            code: '',
            createdAt: 1,
            updatedAt: 1,
            isFavorite: true,
          ),
        );
        await repository.create(
          Sketch(
            id: 'id-41',
            name: SketchName('Plain'),
            code: '',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
        bloc.add(
          const SketchCatalogFilterChanged(SketchCatalogFilter.favourites),
        );
      },
      expect: () => [
        const SketchCatalogState(filter: SketchCatalogFilter.favourites),
        const SketchCatalogState(
          status: SketchCatalogStatus.loading,
          filter: SketchCatalogFilter.favourites,
        ),
        isA<SketchCatalogState>()
            .having((s) => s.status, 'status', SketchCatalogStatus.success)
            .having((s) => s.filter, 'filter', SketchCatalogFilter.favourites)
            .having((s) => s.sketches.length, 'sketch count', 1)
            .having((s) => s.sketches.first.name.value, 'name', 'Starred'),
      ],
    );

    blocTest<SketchCatalogBloc, SketchCatalogState>(
      'recent filter keeps projects as project rows',
      build: () => bloc,
      act: (bloc) async {
        final project = await projectRepository.create(name: 'Arcade');
        final scopedRepository = ProjectScopedSketchRepository(
          projectRepository: projectRepository,
          projectId: project.id,
        );
        await CreateSketch(
          repository: scopedRepository,
          idGenerator: _IncrementalIdGenerator(),
          clock: _FixedClock(),
        )(name: 'Project Pong');
        bloc.add(const SketchCatalogFilterChanged(SketchCatalogFilter.recent));
      },
      expect: () => [
        const SketchCatalogState(filter: SketchCatalogFilter.recent),
        const SketchCatalogState(
          status: SketchCatalogStatus.loading,
          filter: SketchCatalogFilter.recent,
        ),
        isA<SketchCatalogState>()
            .having((s) => s.status, 'status', SketchCatalogStatus.success)
            .having((s) => s.filter, 'filter', SketchCatalogFilter.recent)
            .having((s) => s.projects.length, 'projects', 1)
            .having(
              (s) => s.projects.first.name.value,
              'project name',
              'Arcade',
            )
            .having(
              (s) => s.projectSketchMatches,
              'project sketch matches',
              isEmpty,
            ),
      ],
    );

    blocTest<SketchCatalogBloc, SketchCatalogState>(
      'favourites include sketches inside projects',
      build: () => bloc,
      act: (bloc) async {
        final project = await projectRepository.create(name: 'Arcade');
        final scopedRepository = ProjectScopedSketchRepository(
          projectRepository: projectRepository,
          projectId: project.id,
        );
        final created = await CreateSketch(
          repository: scopedRepository,
          idGenerator: _IncrementalIdGenerator(),
          clock: _FixedClock(),
        )(name: 'Project Star');
        await ToggleSketchFavorite(scopedRepository)(created.id);
        bloc.add(
          const SketchCatalogFilterChanged(SketchCatalogFilter.favourites),
        );
      },
      expect: () => [
        const SketchCatalogState(filter: SketchCatalogFilter.favourites),
        const SketchCatalogState(
          status: SketchCatalogStatus.loading,
          filter: SketchCatalogFilter.favourites,
        ),
        isA<SketchCatalogState>()
            .having((s) => s.status, 'status', SketchCatalogStatus.success)
            .having(
              (s) => s.projectSketchMatches.length,
              'project sketch matches',
              1,
            )
            .having(
              (s) => s.projectSketchMatches.first.sketch.name.value,
              'sketch name',
              'Project Star',
            ),
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
  Future<List<Sketch>> listFavorites({String? query}) async {
    final normalized = query?.trim().toLowerCase();
    final output = _items
        .where((item) {
          if (!item.isFavorite) {
            return false;
          }
          return normalized == null ||
              normalized.isEmpty ||
              item.name.normalized.contains(normalized);
        })
        .toList(growable: false);
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

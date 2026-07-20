import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/app/di/developer_settings_store.dart';
import 'package:p5de/contexts/runtime_preview/domain/runtime_preview_implementation.dart';
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
import 'package:p5de/contexts/sketch_catalog/application/sketch_catalog_exporter.dart';
import 'package:p5de/contexts/sketch_catalog/application/toggle_project_sketch_favorite.dart';
import 'package:p5de/contexts/sketch_catalog/application/toggle_sketch_favorite.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_name.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/in_memory_project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_bloc.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_page.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders catalog shell', (tester) async {
    final repository = _InMemorySketchRepository();
    await _pumpCatalog(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('My Sketches'), findsOneWidget);
    expect(find.text('No sketches yet.'), findsOneWidget);
    expect(find.byKey(const Key('catalog_add_fab')), findsOneWidget);
    expect(find.byKey(const Key('catalog_add_sketch')), findsNothing);
    expect(find.byKey(const Key('catalog_add_project')), findsNothing);
    expect(find.byKey(const Key('catalog_search_field')), findsOneWidget);

    await _openCreateMenu(tester);

    expect(find.byKey(const Key('catalog_add_sketch')), findsOneWidget);
    expect(find.byKey(const Key('catalog_add_project')), findsOneWidget);
  });

  testWidgets('create sketch dialog remains usable with keyboard inset', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 700)
      ..devicePixelRatio = 1
      ..viewInsets = const FakeViewPadding(bottom: 310);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    final repository = _InMemorySketchRepository();
    await _pumpCatalog(tester, repository);
    await tester.pump();

    await _openCreateMenu(tester);
    await tester.tap(find.byKey(const Key('catalog_add_sketch')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('create_sketch_dialog')), findsOneWidget);
    expect(find.byKey(const Key('create_sketch_name_field')), findsOneWidget);
    expect(find.byKey(const Key('create_sketch_runtime_value')), findsNothing);
    expect(find.text('Runtime'), findsNothing);
    expect(find.text('Processing (.pde)'), findsNothing);
    expect(find.textContaining('p5.js'), findsNothing);
    expect(find.text('Create Sketch'), findsOneWidget);
  });

  testWidgets('create sketch dialog only creates Processing Java sketches', (
    tester,
  ) async {
    final repository = _InMemorySketchRepository();
    await _pumpCatalog(tester, repository);
    await tester.pump();

    await _openCreateMenu(tester);
    await tester.tap(find.byKey(const Key('catalog_add_sketch')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('create_sketch_name_field')),
      'Particles',
    );
    await tester.tap(find.text('Create Sketch'));
    await tester.pumpAndSettle();

    expect(repository._items, hasLength(1));
    expect(repository._items.single.language, SketchLanguage.processingJava);
    expect(
      repository._items.single.language.fileNameForSketchName(
        repository._items.single.name.value,
      ),
      'Particles.pde',
    );
    expect(find.textContaining('p5.js'), findsNothing);
  });

  testWidgets('creates a standalone sketch from the expanded FAB', (
    tester,
  ) async {
    final repository = _InMemorySketchRepository();
    await _pumpCatalog(tester, repository);
    await tester.pump();

    await _openCreateMenu(tester);
    await tester.tap(find.byKey(const Key('catalog_add_sketch')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('create_sketch_name_field')),
      'Standalone',
    );
    await tester.tap(find.text('Create Sketch'));
    await tester.pumpAndSettle();

    expect(repository._items, hasLength(1));
    expect(repository._items.single.name.value, 'Standalone');
    expect(repository._items.single.language, SketchLanguage.processingJava);
    expect(find.text('Standalone'), findsOneWidget);
  });

  testWidgets('creates and opens a project list item', (tester) async {
    final repository = _InMemorySketchRepository();
    final projectRepository = InMemoryProjectRepository();
    await _pumpCatalog(tester, repository, projectRepository);
    await tester.pump();

    await _openCreateMenu(tester);
    await tester.tap(find.byKey(const Key('catalog_add_project')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('create_project_name_field')),
      'Arcade',
    );
    await tester.tap(find.text('Create Project'));
    await tester.pumpAndSettle();

    expect(find.text('Arcade'), findsOneWidget);
    expect(find.text('Project - 0 sketches'), findsOneWidget);

    await tester.tap(find.text('Arcade'));
    await tester.pumpAndSettle();

    expect(find.text('No sketches in this project yet.'), findsOneWidget);
    expect(find.byKey(const Key('project_add_sketch_fab')), findsOneWidget);
  });

  testWidgets('creates a project from the SuaCode Africa template', (
    tester,
  ) async {
    final repository = _InMemorySketchRepository();
    final projectRepository = InMemoryProjectRepository();
    await _pumpCatalog(tester, repository, projectRepository);
    await tester.pump();

    await _openCreateMenu(tester);
    await tester.tap(find.byKey(const Key('catalog_add_project')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('create_project_name_field')),
      'My Africa Course',
    );
    await tester.tap(find.byKey(const Key('create_project_template_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SuaCode Africa').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Project'));
    await tester.pump();

    expect(
      find.byKey(const Key('create_project_progress_label')),
      findsOneWidget,
    );

    await tester.pumpAndSettle();

    expect(find.text('My Africa Course'), findsOneWidget);
    expect(find.text('Project - 28 sketches'), findsOneWidget);
    final project = (await projectRepository.list()).single;
    final sketches = await projectRepository.listSketches(project.id);
    expect(sketches, hasLength(28));
    expect(sketches.first.name.value, 'Intro');
    expect(sketches.last.name.value, 'Assignment 6');

    await tester.tap(find.text('My Africa Course'));
    await tester.pumpAndSettle();

    expect(find.text('Intro'), findsOneWidget);
  });

  testWidgets('refreshes catalog after project creation dialog closes', (
    tester,
  ) async {
    final repository = _InMemorySketchRepository();
    final projectRepository = _SlowCreateProjectRepository();
    await _pumpCatalog(tester, repository, projectRepository);
    await tester.pump();

    await _openCreateMenu(tester);
    await tester.tap(find.byKey(const Key('catalog_add_project')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('create_project_name_field')),
      'Arcade',
    );

    final listCallsBeforeCreate = projectRepository.listCallCount;
    await tester.tap(find.text('Create Project'));
    await tester.pump();

    expect(find.byKey(const Key('create_project_dialog')), findsOneWidget);
    expect(projectRepository.listCallCount, listCallsBeforeCreate);

    projectRepository.allowCreate();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create_project_dialog')), findsNothing);
    expect(projectRepository.listCallCount, greaterThan(listCallsBeforeCreate));
    expect(find.text('Arcade'), findsOneWidget);
  });

  testWidgets('leaving an unchanged project does not reload the catalog', (
    tester,
  ) async {
    final repository = _InMemorySketchRepository();
    final projectRepository = _CountingProjectRepository();
    await _pumpCatalog(tester, repository, projectRepository);
    await tester.pump();

    await _openCreateMenu(tester);
    await tester.tap(find.byKey(const Key('catalog_add_project')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('create_project_name_field')),
      'Arcade',
    );
    await tester.tap(find.text('Create Project'));
    await tester.pumpAndSettle();

    final listCallsBeforeOpen = projectRepository.listCallCount;
    await tester.tap(find.text('Arcade'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Arcade'), findsOneWidget);
    expect(projectRepository.listCallCount, listCallsBeforeOpen);
  });

  testWidgets('favourites pill filters starred sketches', (tester) async {
    final repository = _InMemorySketchRepository();
    await repository.create(
      Sketch(
        id: 'favourite-id',
        name: SketchName('Favourite Sketch'),
        language: SketchLanguage.processingJava,
        code: '',
        createdAt: 1,
        updatedAt: 1,
        isFavorite: true,
      ),
    );
    await repository.create(
      Sketch(
        id: 'plain-id',
        name: SketchName('Plain Sketch'),
        language: SketchLanguage.processingJava,
        code: '',
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    await _pumpCatalog(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catalog_filter_favourites')));
    await tester.pumpAndSettle();

    expect(find.text('Favourite Sketch'), findsOneWidget);
    expect(find.text('Plain Sketch'), findsNothing);
  });

  testWidgets('star action adds a standalone sketch to favourites', (
    tester,
  ) async {
    final repository = _InMemorySketchRepository();
    await repository.create(
      Sketch(
        id: 'plain-id',
        name: SketchName('Plain Sketch'),
        language: SketchLanguage.processingJava,
        code: '',
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    await _pumpCatalog(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sketch_favorite_plain-id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog_filter_favourites')));
    await tester.pumpAndSettle();

    expect(repository._items.single.isFavorite, isTrue);
    expect(find.text('Plain Sketch'), findsOneWidget);
  });

  testWidgets('long press selects multiple sketches and deletes them', (
    tester,
  ) async {
    final repository = _InMemorySketchRepository();
    await repository.create(
      Sketch(
        id: 'first-id',
        name: SketchName('First Sketch'),
        language: SketchLanguage.processingJava,
        code: '',
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    await repository.create(
      Sketch(
        id: 'second-id',
        name: SketchName('Second Sketch'),
        language: SketchLanguage.processingJava,
        code: '',
        createdAt: 2,
        updatedAt: 2,
      ),
    );
    await _pumpCatalog(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sketch_favorite_first-id')), findsOneWidget);
    expect(find.byKey(const Key('sketch_rename_first-id')), findsNothing);
    expect(find.byKey(const Key('sketch_delete_first-id')), findsNothing);
    expect(find.byKey(const Key('catalog_selection_export')), findsNothing);

    await tester.longPress(find.byKey(const Key('sketch_tile_first-id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sketch_tile_second-id')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog_selection_app_bar')), findsOneWidget);
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.byKey(const Key('catalog_selection_delete')), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog_selection_delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete sketches'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository._items, isEmpty);
    expect(find.byKey(const Key('catalog_selection_app_bar')), findsNothing);
    expect(find.text('No sketches yet.'), findsOneWidget);
  });

  testWidgets('long press selects multiple sketches and exports them', (
    tester,
  ) async {
    final repository = _InMemorySketchRepository();
    final exporter = _RecordingSketchCatalogExporter();
    await repository.create(
      Sketch(
        id: 'first-id',
        name: SketchName('First Sketch'),
        language: SketchLanguage.processingJava,
        code: 'void setup() {}',
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    await repository.create(
      Sketch(
        id: 'second-id',
        name: SketchName('Second Sketch'),
        language: SketchLanguage.processingJava,
        code: 'void draw() {}',
        createdAt: 2,
        updatedAt: 2,
      ),
    );
    await _pumpCatalogWith(tester, repository, exporter: exporter);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog_export_sketches')), findsNothing);

    await tester.longPress(find.byKey(const Key('sketch_tile_first-id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sketch_tile_second-id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog_selection_export')));
    await tester.pumpAndSettle();

    expect(exporter.exportedItems, hasLength(2));
    expect(
      exporter.exportedItems.map((item) => item.sketch.id),
      containsAll(<String>['first-id', 'second-id']),
    );
    expect(repository._items, hasLength(2));
    expect(find.byKey(const Key('catalog_selection_app_bar')), findsNothing);
  });

  testWidgets('developer settings only expose runtime preview toggle', (
    tester,
  ) async {
    final repository = _InMemorySketchRepository();
    await _pumpCatalogWith(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catalog_debug_overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog_developer_settings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('developer_settings_dialog')), findsOneWidget);
    expect(
      find.byKey(const Key('developer_runtime_preview_toggle')),
      findsOneWidget,
    );
    expect(find.text('Storage backend'), findsNothing);
    expect(find.text('Drift (SQLite)'), findsNothing);
    expect(find.text('Filesystem'), findsNothing);
  });

  testWidgets('developer runtime preview toggle persists selection', (
    tester,
  ) async {
    final repository = _InMemorySketchRepository();
    await _pumpCatalogWith(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('catalog_debug_overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog_developer_settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('developer_runtime_preview_toggle')));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    expect(
      await const DeveloperSettingsStore().loadRuntimePreviewImplementation(),
      RuntimePreviewImplementation.fullscreenPhysical,
    );
  });

  testWidgets('renames a project list item', (tester) async {
    final repository = _InMemorySketchRepository();
    final projectRepository = InMemoryProjectRepository();
    await _pumpCatalog(tester, repository, projectRepository);
    await tester.pump();

    await _openCreateMenu(tester);
    await tester.tap(find.byKey(const Key('catalog_add_project')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('create_project_name_field')),
      'Arcade',
    );
    await tester.tap(find.text('Create Project'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Arcade Renamed');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Arcade'), findsNothing);
    expect(find.text('Arcade Renamed'), findsOneWidget);
  });
}

Future<void> _openCreateMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('catalog_add_fab')));
  await tester.pumpAndSettle();
}

Future<void> _pumpCatalog(
  WidgetTester tester,
  _InMemorySketchRepository repository, [
  InMemoryProjectRepository? projectRepository,
]) {
  return _pumpCatalogWith(
    tester,
    repository,
    projectRepository: projectRepository,
  );
}

Future<void> _pumpCatalogWith(
  WidgetTester tester,
  _InMemorySketchRepository repository, {
  InMemoryProjectRepository? projectRepository,
  SketchCatalogExporter? exporter,
}) async {
  final projects = projectRepository ?? InMemoryProjectRepository();
  final idGenerator = _FakeIdGenerator();
  final bloc = SketchCatalogBloc(
    createSketch: CreateSketch(
      repository: repository,
      idGenerator: idGenerator,
      clock: _FixedClock(),
    ),
    renameSketch: RenameSketch(repository: repository, clock: _FixedClock()),
    deleteSketch: DeleteSketch(repository),
    listSketches: ListSketches(repository),
    listFavoriteSketches: ListFavoriteSketches(repository),
    searchSketches: SearchSketches(repository),
    createProject: CreateProject(
      projects,
      clock: _FixedClock(),
      idGenerator: idGenerator,
    ),
    renameProject: RenameProject(projects),
    deleteProject: DeleteProject(projects),
    listProjects: ListProjects(projects),
    listFavoriteProjectSketches: ListFavoriteProjectSketches(projects),
    searchProjectSketches: SearchProjectSketches(projects),
    toggleSketchFavorite: ToggleSketchFavorite(repository),
    toggleProjectSketchFavorite: ToggleProjectSketchFavorite(projects),
  )..add(const SketchCatalogLoaded());

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: bloc,
        child: SketchCatalogPage(
          sketchRepository: repository,
          projectRepository: projects,
          exporter: exporter,
          createProject: CreateProject(
            projects,
            clock: _FixedClock(),
            idGenerator: idGenerator,
          ),
          idGenerator: idGenerator,
          clock: _FixedClock(),
        ),
      ),
    ),
  );
}

class _RecordingSketchCatalogExporter implements SketchCatalogExporter {
  List<SketchCatalogExportItem> exportedItems = const [];

  @override
  Future<String> exportAll() async {
    return 'Download/SuaCode IDE/sketches';
  }

  @override
  Future<String> exportItems(Iterable<SketchCatalogExportItem> items) async {
    exportedItems = items.toList(growable: false);
    return 'Download/SuaCode IDE/sketches';
  }
}

class _InMemorySketchRepository implements SketchRepository {
  final List<Sketch> _items = [];

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
    final index = _items.indexWhere((item) => item.id == sketch.id);
    if (index < 0) {
      throw SketchNotFoundException();
    }
    _items[index] = sketch;
  }
}

class _CountingProjectRepository extends InMemoryProjectRepository {
  int listCallCount = 0;

  @override
  Future<List<Project>> list({String? query}) {
    listCallCount += 1;
    return super.list(query: query);
  }
}

class _SlowCreateProjectRepository extends _CountingProjectRepository {
  final Completer<void> _createCompleter = Completer<void>();

  void allowCreate() {
    if (!_createCompleter.isCompleted) {
      _createCompleter.complete();
    }
  }

  @override
  Future<Project> create({required String name}) async {
    await _createCompleter.future;
    return super.create(name: name);
  }
}

class _FakeIdGenerator implements IdGenerator {
  int _count = 0;

  @override
  String newId() {
    _count++;
    return 'id-$_count';
  }
}

class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime.fromMillisecondsSinceEpoch(1000);
}

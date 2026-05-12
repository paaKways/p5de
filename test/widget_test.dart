import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/delete_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/rename_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/search_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_bloc.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_page.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';

void main() {
  testWidgets('renders catalog shell', (tester) async {
    final repository = _InMemorySketchRepository();
    await _pumpCatalog(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('My Sketches'), findsOneWidget);
    expect(find.text('No sketches yet.'), findsOneWidget);
    expect(find.byKey(const Key('catalog_add_fab')), findsOneWidget);
    expect(find.byKey(const Key('catalog_search_field')), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('catalog_add_fab')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('create_sketch_dialog')), findsOneWidget);
    expect(find.byKey(const Key('create_sketch_name_field')), findsOneWidget);
    expect(
      find.byKey(const Key('create_sketch_runtime_dropdown')),
      findsOneWidget,
    );
    expect(find.text('Create Sketch'), findsOneWidget);
  });

  testWidgets('create sketch dialog uses selected runtime extension', (
    tester,
  ) async {
    final repository = _InMemorySketchRepository();
    await _pumpCatalog(tester, repository);
    await tester.pump();

    await tester.tap(find.byKey(const Key('catalog_add_fab')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('create_sketch_name_field')),
      'Particles',
    );
    await tester.tap(find.byKey(const Key('create_sketch_runtime_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('p5.js (.js)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Sketch'));
    await tester.pumpAndSettle();

    expect(repository._items, hasLength(1));
    expect(repository._items.single.language, SketchLanguage.p5js);
    expect(
      repository._items.single.language.fileNameForSketchName(
        repository._items.single.name.value,
      ),
      'Particles.js',
    );
  });
}

Future<void> _pumpCatalog(
  WidgetTester tester,
  _InMemorySketchRepository repository,
) async {
  final bloc = SketchCatalogBloc(
    createSketch: CreateSketch(
      repository: repository,
      idGenerator: _FakeIdGenerator(),
      clock: _FixedClock(),
    ),
    renameSketch: RenameSketch(repository: repository, clock: _FixedClock()),
    deleteSketch: DeleteSketch(repository),
    listSketches: ListSketches(repository),
    searchSketches: SearchSketches(repository),
  )..add(const SketchCatalogLoaded());

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: bloc,
        child: SketchCatalogPage(
          sketchRepository: repository,
          clock: _FixedClock(),
        ),
      ),
    ),
  );
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
  Future<void> update(Sketch sketch) async {
    final index = _items.indexWhere((item) => item.id == sketch.id);
    if (index < 0) {
      throw SketchNotFoundException();
    }
    _items[index] = sketch;
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

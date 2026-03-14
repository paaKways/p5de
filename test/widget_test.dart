import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/delete_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/rename_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/search_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_bloc.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_page.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';

void main() {
  testWidgets('renders catalog shell', (tester) async {
    final repository = _InMemorySketchRepository();
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
        home: BlocProvider.value(value: bloc, child: const SketchCatalogPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Sketches'), findsOneWidget);
    expect(find.text('No sketches yet.'), findsOneWidget);
    expect(find.byKey(const Key('catalog_add_fab')), findsOneWidget);
    expect(find.byKey(const Key('catalog_search_field')), findsOneWidget);
  });
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
  Future<Sketch?> findById(String sketchId) async => null;

  @override
  Future<List<Sketch>> list({String? query}) async => _items;

  @override
  Future<void> update(Sketch sketch) async {}
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

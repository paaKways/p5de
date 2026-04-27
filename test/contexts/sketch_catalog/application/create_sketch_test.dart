import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';

void main() {
  group('CreateSketch', () {
    test('creates sketch when name is unique', () async {
      final repository = _InMemorySketchRepository();
      final useCase = CreateSketch(
        repository: repository,
        idGenerator: _FakeIdGenerator('id-123'),
        clock: _FakeClock(DateTime.fromMillisecondsSinceEpoch(1000)),
      );

      final created = await useCase.call(name: 'Hello World');

      expect(created.id, 'id-123');
      expect(created.name.value, 'Hello World');
      expect(created.language, SketchLanguage.p5js);
      expect(repository.items, hasLength(1));
    });

    test('creates Processing Java sketch with default PDE template', () async {
      final repository = _InMemorySketchRepository();
      final useCase = CreateSketch(
        repository: repository,
        idGenerator: _FakeIdGenerator('id-pde'),
        clock: _FakeClock(DateTime.fromMillisecondsSinceEpoch(1000)),
      );

      final created = await useCase.call(
        name: 'Processing Sketch',
        language: SketchLanguage.processingJava,
      );

      expect(created.language, SketchLanguage.processingJava);
      expect(created.code, contains('void setup()'));
      expect(created.code, contains('void draw()'));
    });

    test('throws on duplicate name', () async {
      final repository = _InMemorySketchRepository();
      final useCase = CreateSketch(
        repository: repository,
        idGenerator: _FakeIdGenerator('id-456'),
        clock: _FakeClock(DateTime.fromMillisecondsSinceEpoch(1000)),
      );

      await useCase.call(name: 'Sketch A');

      expect(
        () => useCase.call(name: ' sketch a '),
        throwsA(isA<DuplicateSketchNameException>()),
      );
    });
  });
}

class _InMemorySketchRepository implements SketchRepository {
  final List<Sketch> items = [];

  @override
  Future<void> create(Sketch sketch) async {
    items.add(sketch);
  }

  @override
  Future<void> deleteById(String sketchId) async {
    items.removeWhere((item) => item.id == sketchId);
  }

  @override
  Future<bool> existsByNormalizedName(
    String normalizedName, {
    String? excludingSketchId,
  }) async {
    return items.any((item) {
      if (excludingSketchId != null && item.id == excludingSketchId) {
        return false;
      }
      return item.name.normalized == normalizedName;
    });
  }

  @override
  Future<Sketch?> findById(String sketchId) async {
    for (final item in items) {
      if (item.id == sketchId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<Sketch>> list({String? query}) async {
    if (query == null || query.trim().isEmpty) {
      return List<Sketch>.from(items);
    }
    final normalized = query.trim().toLowerCase();
    return items
        .where((item) => item.name.normalized.contains(normalized))
        .toList(growable: false);
  }

  @override
  Future<void> update(Sketch sketch) async {
    final index = items.indexWhere((item) => item.id == sketch.id);
    if (index < 0) {
      throw SketchNotFoundException();
    }
    items[index] = sketch;
  }
}

class _FakeClock implements Clock {
  _FakeClock(this._now);

  final DateTime _now;

  @override
  DateTime now() => _now;
}

class _FakeIdGenerator implements IdGenerator {
  _FakeIdGenerator(this._id);

  final String _id;

  @override
  String newId() => _id;
}

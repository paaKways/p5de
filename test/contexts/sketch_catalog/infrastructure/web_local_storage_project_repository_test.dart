import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_projects.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/toggle_sketch_favorite.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/project_scoped_sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/web_local_storage_project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/web_local_storage_sketch_repository.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists browser projects and project sketches', () async {
    final firstRepository = WebLocalStorageProjectRepository();
    final project = await CreateProject(
      firstRepository,
      clock: _FixedClock(1700000000000),
      idGenerator: _FixedIdGenerator('web-project-template-id'),
    )(name: 'Arcade');
    final firstScopedRepository = ProjectScopedSketchRepository(
      projectRepository: firstRepository,
      projectId: project.id,
    );

    await CreateSketch(
      repository: firstScopedRepository,
      idGenerator: _FixedIdGenerator('web-project-sketch-1'),
      clock: _FixedClock(1700000000000),
    )(name: 'Pong');
    await ToggleSketchFavorite(firstScopedRepository)('web-project-sketch-1');

    final secondRepository = WebLocalStorageProjectRepository();
    final projects = await ListProjects(secondRepository)();
    expect(projects, hasLength(1));
    expect(projects.first.name.value, 'Arcade');
    expect(projects.first.sketchCount, 1);

    final secondScopedRepository = ProjectScopedSketchRepository(
      projectRepository: secondRepository,
      projectId: projects.first.id,
    );
    final sketches = await ListSketches(secondScopedRepository)();
    expect(sketches, hasLength(1));
    expect(sketches.first.name.value, 'Pong');

    final favoriteMatches = await secondRepository.listFavoriteSketches();
    expect(favoriteMatches, hasLength(1));
    expect(favoriteMatches.single.sketch.name.value, 'Pong');

    await clearSketchCatalogWebStorage();

    final clearedRepository = WebLocalStorageProjectRepository();
    expect(await ListProjects(clearedRepository)(), isEmpty);
  });
}

class _FixedClock implements Clock {
  _FixedClock(this._epochMs);

  final int _epochMs;

  @override
  DateTime now() => DateTime.fromMillisecondsSinceEpoch(_epochMs);
}

class _FixedIdGenerator implements IdGenerator {
  _FixedIdGenerator(this._id);

  final String _id;

  @override
  String newId() => _id;
}

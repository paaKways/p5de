import 'package:p5de/contexts/sketch_catalog/application/create_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/delete_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/rename_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/search_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/drift_sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/sketch_catalog_database.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';

class AppDependencies {
  AppDependencies._({
    required this.clock,
    required this.idGenerator,
    required this.sketchCatalogDatabase,
    required this.sketchRepository,
    required this.createSketch,
    required this.renameSketch,
    required this.deleteSketch,
    required this.listSketches,
    required this.searchSketches,
  });

  final Clock clock;
  final IdGenerator idGenerator;
  final SketchCatalogDatabase sketchCatalogDatabase;
  final SketchRepository sketchRepository;

  final CreateSketch createSketch;
  final RenameSketch renameSketch;
  final DeleteSketch deleteSketch;
  final ListSketches listSketches;
  final SearchSketches searchSketches;

  factory AppDependencies.bootstrap() {
    final clock = SystemClock();
    final idGenerator = UuidV4Generator();
    final sketchCatalogDatabase = SketchCatalogDatabase();
    final sketchRepository = DriftSketchRepository(sketchCatalogDatabase);

    return AppDependencies._(
      clock: clock,
      idGenerator: idGenerator,
      sketchCatalogDatabase: sketchCatalogDatabase,
      sketchRepository: sketchRepository,
      createSketch: CreateSketch(
        repository: sketchRepository,
        idGenerator: idGenerator,
        clock: clock,
      ),
      renameSketch: RenameSketch(repository: sketchRepository, clock: clock),
      deleteSketch: DeleteSketch(sketchRepository),
      listSketches: ListSketches(sketchRepository),
      searchSketches: SearchSketches(sketchRepository),
    );
  }
}

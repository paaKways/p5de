import 'package:p5de/app/di/sketch_repository_factory_native.dart'
    if (dart.library.html) 'package:p5de/app/di/sketch_repository_factory_web.dart'
    if (dart.library.js_interop) 'package:p5de/app/di/sketch_repository_factory_web.dart'
    as sketch_repository_factory;
import 'package:p5de/contexts/sketch_catalog/application/create_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/delete_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/rename_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/search_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';

class AppDependencies {
  AppDependencies._({
    required this.clock,
    required this.idGenerator,
    required this.sketchRepository,
    required this.createSketch,
    required this.renameSketch,
    required this.deleteSketch,
    required this.listSketches,
    required this.searchSketches,
  });

  final Clock clock;
  final IdGenerator idGenerator;
  final SketchRepository sketchRepository;

  final CreateSketch createSketch;
  final RenameSketch renameSketch;
  final DeleteSketch deleteSketch;
  final ListSketches listSketches;
  final SearchSketches searchSketches;

  factory AppDependencies.bootstrap() {
    final clock = SystemClock();
    final idGenerator = UuidV4Generator();
    // Platform-specific: Drift on native, in-memory on web.
    final sketchRepository = sketch_repository_factory.createSketchRepository();

    return AppDependencies._(
      clock: clock,
      idGenerator: idGenerator,
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

import 'package:p5de/app/di/sketch_repository_factory_native.dart'
    if (dart.library.html) 'package:p5de/app/di/sketch_repository_factory_web.dart'
    as sketch_repository_factory;
import 'package:p5de/contexts/editor/application/load_sketch_for_edit.dart';
import 'package:p5de/contexts/editor/application/save_sketch.dart';
import 'package:p5de/contexts/editor/application/update_draft.dart';
import 'package:p5de/contexts/editor/domain/editor_draft.dart';
import 'package:p5de/contexts/editor/infrastructure/draft_persistence_adapter.dart';
import 'package:p5de/contexts/editor/infrastructure/shared_prefs_draft_persistence_adapter.dart';
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
    required this.loadSketchForEdit,
    required this.updateDraft,
    required this.saveSketch,
    required this.draftPersistence,
  });

  final Clock clock;
  final IdGenerator idGenerator;
  final SketchRepository sketchRepository;

  final CreateSketch createSketch;
  final RenameSketch renameSketch;
  final DeleteSketch deleteSketch;
  final ListSketches listSketches;
  final SearchSketches searchSketches;

  final LoadSketchForEdit loadSketchForEdit;
  final UpdateDraft updateDraft;
  final SaveSketch saveSketch;
  final DraftPersistenceAdapter draftPersistence;

  factory AppDependencies.bootstrap() {
    final clock = SystemClock();
    final idGenerator = UuidV4Generator();
    // Platform-specific: Drift on native, browser storage on web.
    final sketchRepository = sketch_repository_factory.createSketchRepository();

    return AppDependencies._build(
      clock: clock,
      idGenerator: idGenerator,
      sketchRepository: sketchRepository,
      draftPersistence: SharedPrefsDraftPersistenceAdapter(),
    );
  }

  factory AppDependencies.forTesting({
    required Clock clock,
    required IdGenerator idGenerator,
    required SketchRepository sketchRepository,
    DraftPersistenceAdapter? draftPersistence,
  }) {
    return AppDependencies._build(
      clock: clock,
      idGenerator: idGenerator,
      sketchRepository: sketchRepository,
      draftPersistence: draftPersistence ?? _InMemoryDraftPersistenceAdapter(),
    );
  }

  factory AppDependencies._build({
    required Clock clock,
    required IdGenerator idGenerator,
    required SketchRepository sketchRepository,
    required DraftPersistenceAdapter draftPersistence,
  }) {
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
      loadSketchForEdit: LoadSketchForEdit(sketchRepository),
      updateDraft: const UpdateDraft(),
      saveSketch: SaveSketch(repository: sketchRepository, clock: clock),
      draftPersistence: draftPersistence,
    );
  }
}

class _InMemoryDraftPersistenceAdapter implements DraftPersistenceAdapter {
  final Map<String, EditorDraft> _drafts = {};

  @override
  Future<void> clear(String sketchId) async {
    _drafts.remove(sketchId);
  }

  @override
  Future<EditorDraft?> read(String sketchId) async {
    return _drafts[sketchId];
  }

  @override
  Future<void> write(EditorDraft draft) async {
    _drafts[draft.sketchId] = draft;
  }
}

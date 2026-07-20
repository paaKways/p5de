import 'package:p5de/app/di/sketch_repository_factory_native.dart'
    if (dart.library.html) 'package:p5de/app/di/sketch_repository_factory_web.dart'
    if (dart.library.js_interop) 'package:p5de/app/di/sketch_repository_factory_web.dart'
    as sketch_repository_factory;
import 'package:p5de/app/di/shared_preferences_default_project_seed_store.dart';
import 'package:p5de/app/di/developer_settings_store.dart';
import 'package:p5de/app/di/sketch_storage_backend.dart';
import 'package:p5de/app/telemetry/app_telemetry.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/delete_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/delete_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_favorite_project_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_favorite_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_project_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_projects.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/rename_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/rename_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/search_project_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/search_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/seed_default_projects.dart';
import 'package:p5de/contexts/sketch_catalog/application/sketch_catalog_exporter.dart';
import 'package:p5de/contexts/sketch_catalog/application/toggle_project_sketch_favorite.dart';
import 'package:p5de/contexts/sketch_catalog/application/toggle_sketch_favorite.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';

class AppDependencies {
  AppDependencies._({
    required this.clock,
    required this.idGenerator,
    required this.storageBackend,
    required this.developerSettingsStore,
    required this.telemetry,
    required this.sketchRepository,
    required this.projectRepository,
    required this.sketchCatalogExporter,
    required this.createSketch,
    required this.renameSketch,
    required this.deleteSketch,
    required this.listSketches,
    required this.listFavoriteSketches,
    required this.searchSketches,
    required this.createProject,
    required this.renameProject,
    required this.deleteProject,
    required this.listProjects,
    required this.listProjectSketches,
    required this.listFavoriteProjectSketches,
    required this.searchProjectSketches,
    required this.toggleSketchFavorite,
    required this.toggleProjectSketchFavorite,
  });

  final Clock clock;
  final IdGenerator idGenerator;
  final SketchStorageBackend storageBackend;
  final DeveloperSettingsStore developerSettingsStore;
  final AppTelemetry telemetry;
  final SketchRepository sketchRepository;
  final ProjectRepository projectRepository;
  final SketchCatalogExporter? sketchCatalogExporter;

  final CreateSketch createSketch;
  final RenameSketch renameSketch;
  final DeleteSketch deleteSketch;
  final ListSketches listSketches;
  final ListFavoriteSketches listFavoriteSketches;
  final SearchSketches searchSketches;
  final CreateProject createProject;
  final RenameProject renameProject;
  final DeleteProject deleteProject;
  final ListProjects listProjects;
  final ListProjectSketches listProjectSketches;
  final ListFavoriteProjectSketches listFavoriteProjectSketches;
  final SearchProjectSketches searchProjectSketches;
  final ToggleSketchFavorite toggleSketchFavorite;
  final ToggleProjectSketchFavorite toggleProjectSketchFavorite;

  static Future<AppDependencies> bootstrap({
    AppTelemetry telemetry = const NoopAppTelemetry(),
  }) async {
    const storageBackend = SketchStorageBackend.filesystem;
    final hasExistingInstallEvidence = await sketch_repository_factory
        .hasPersistedSketchCatalogStorage(storageBackend: storageBackend);
    final dependencies = AppDependencies.forStorageBackend(
      telemetry: telemetry,
      storageBackend: storageBackend,
    );
    try {
      await SeedDefaultProjects(
        createProject: dependencies.createProject,
        projectRepository: dependencies.projectRepository,
        sketchRepository: dependencies.sketchRepository,
        seedStore: const SharedPreferencesDefaultProjectSeedStore(),
      )(hasExistingInstallEvidence: hasExistingInstallEvidence);
    } catch (error, stackTrace) {
      await telemetry.recordError(
        error,
        stackTrace,
        reason: 'default_project_seed',
      );
    }
    return dependencies;
  }

  factory AppDependencies.forStorageBackend({
    required SketchStorageBackend storageBackend,
    AppTelemetry telemetry = const NoopAppTelemetry(),
  }) {
    final clock = SystemClock();
    final idGenerator = UuidV4Generator();
    const developerSettingsStore = DeveloperSettingsStore();
    final sketchRepository = sketch_repository_factory.createSketchRepository(
      storageBackend: storageBackend,
    );
    final projectRepository = sketch_repository_factory.createProjectRepository(
      storageBackend: storageBackend,
    );
    final sketchCatalogExporter = sketch_repository_factory
        .createSketchCatalogExporter(
          sketchRepository: sketchRepository,
          projectRepository: projectRepository,
        );

    return AppDependencies._(
      clock: clock,
      idGenerator: idGenerator,
      storageBackend: storageBackend,
      developerSettingsStore: developerSettingsStore,
      telemetry: telemetry,
      sketchRepository: sketchRepository,
      projectRepository: projectRepository,
      sketchCatalogExporter: sketchCatalogExporter,
      createSketch: CreateSketch(
        repository: sketchRepository,
        idGenerator: idGenerator,
        clock: clock,
      ),
      renameSketch: RenameSketch(repository: sketchRepository, clock: clock),
      deleteSketch: DeleteSketch(sketchRepository),
      listSketches: ListSketches(sketchRepository),
      listFavoriteSketches: ListFavoriteSketches(sketchRepository),
      searchSketches: SearchSketches(sketchRepository),
      createProject: CreateProject(
        projectRepository,
        clock: clock,
        idGenerator: idGenerator,
      ),
      renameProject: RenameProject(projectRepository),
      deleteProject: DeleteProject(projectRepository),
      listProjects: ListProjects(projectRepository),
      listProjectSketches: ListProjectSketches(projectRepository),
      listFavoriteProjectSketches: ListFavoriteProjectSketches(
        projectRepository,
      ),
      searchProjectSketches: SearchProjectSketches(projectRepository),
      toggleSketchFavorite: ToggleSketchFavorite(sketchRepository),
      toggleProjectSketchFavorite: ToggleProjectSketchFavorite(
        projectRepository,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:p5de/app/di/app_dependencies.dart';
import 'package:p5de/app/splash_screen.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_bloc.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_page.dart';

class P5deApp extends StatelessWidget {
  const P5deApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(dependencies.storageBackend),
      create: (_) => SketchCatalogBloc(
        createSketch: dependencies.createSketch,
        renameSketch: dependencies.renameSketch,
        deleteSketch: dependencies.deleteSketch,
        listSketches: dependencies.listSketches,
        listFavoriteSketches: dependencies.listFavoriteSketches,
        searchSketches: dependencies.searchSketches,
        createProject: dependencies.createProject,
        renameProject: dependencies.renameProject,
        deleteProject: dependencies.deleteProject,
        listProjects: dependencies.listProjects,
        listFavoriteProjectSketches: dependencies.listFavoriteProjectSketches,
        searchProjectSketches: dependencies.searchProjectSketches,
        toggleSketchFavorite: dependencies.toggleSketchFavorite,
        toggleProjectSketchFavorite: dependencies.toggleProjectSketchFavorite,
        telemetry: dependencies.telemetry,
      )..add(const SketchCatalogLoaded()),
      child: MaterialApp(
        title: 'SuaCode IDE',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        home: AppSplashGate(
          child: SketchCatalogPage(
            sketchRepository: dependencies.sketchRepository,
            projectRepository: dependencies.projectRepository,
            exporter: dependencies.sketchCatalogExporter,
            developerSettingsStore: dependencies.developerSettingsStore,
            createProject: dependencies.createProject,
            idGenerator: dependencies.idGenerator,
            clock: dependencies.clock,
            telemetry: dependencies.telemetry,
          ),
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

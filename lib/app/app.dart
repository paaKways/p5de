import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:p5de/app/di/app_dependencies.dart';
import 'package:p5de/contexts/editor/presentation/editor_page.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_bloc.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_page.dart';

class P5deApp extends StatelessWidget {
  const P5deApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SketchCatalogBloc(
        createSketch: dependencies.createSketch,
        renameSketch: dependencies.renameSketch,
        deleteSketch: dependencies.deleteSketch,
        listSketches: dependencies.listSketches,
        searchSketches: dependencies.searchSketches,
      )..add(const SketchCatalogLoaded()),
      child: MaterialApp(
        title: 'p5de',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        home: SketchCatalogPage(
          onOpenSketch: (context, sketchId) {
            Navigator.of(context).push(
              PageRouteBuilder<void>(
                transitionDuration: const Duration(milliseconds: 180),
                reverseTransitionDuration: const Duration(milliseconds: 160),
                pageBuilder: (_, __, ___) =>
                    EditorPage(dependencies: dependencies, sketchId: sketchId),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      );
                      return FadeTransition(opacity: curved, child: child);
                    },
              ),
            );
          },
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

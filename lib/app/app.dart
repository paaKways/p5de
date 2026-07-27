import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:p5de/app/app_theme.dart';
import 'package:p5de/app/di/app_dependencies.dart';
import 'package:p5de/app/di/sketch_storage_backend.dart';
import 'package:p5de/app/splash_screen.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/saf_directory_bridge.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_bloc.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_page.dart';

class P5deApp extends StatelessWidget {
  const P5deApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SuaCode IDE',
      theme: AppTheme.light,
      home: AppSplashGate(
        child: dependencies.storageBackend == SketchStorageBackend.saf
            ? _SelectedDirectoryGate(dependencies: dependencies)
            : _CatalogHome(dependencies: dependencies),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _SelectedDirectoryGate extends StatefulWidget {
  const _SelectedDirectoryGate({required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<_SelectedDirectoryGate> createState() => _SelectedDirectoryGateState();
}

class _SelectedDirectoryGateState extends State<_SelectedDirectoryGate> {
  late Future<SafDirectorySelection?> _selectionFuture;
  bool _preparing = false;
  String? _errorMessage;

  SafDirectoryBridge get _bridge => widget.dependencies.safDirectoryBridge!;

  @override
  void initState() {
    super.initState();
    _selectionFuture = _bridge.getSelectedDirectory();
  }

  Future<void> _chooseDirectory() async {
    setState(() {
      _errorMessage = null;
      _preparing = true;
    });
    try {
      final selection = await _bridge.pickDirectory();
      if (selection == null) {
        if (mounted) {
          setState(() => _preparing = false);
        }
        return;
      }
      await widget.dependencies.initializeSelectedDirectory();
      if (mounted) {
        setState(() {
          _preparing = false;
          _selectionFuture = Future.value(selection);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _preparing = false;
          _errorMessage =
              'SuaCode IDE could not prepare that folder. Choose another '
              'folder with read and write access.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SafDirectorySelection?>(
      future: _selectionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StorageLoadingScreen();
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _DirectorySelectionScreen(
            preparing: _preparing,
            errorMessage: snapshot.hasError
                ? 'The previous folder permission is no longer available.'
                : _errorMessage,
            onChooseDirectory: _preparing ? null : _chooseDirectory,
          );
        }
        return _CatalogHome(
          key: ValueKey(snapshot.data!.uri),
          dependencies: widget.dependencies,
        );
      },
    );
  }
}

class _CatalogHome extends StatelessWidget {
  const _CatalogHome({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
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
      child: SketchCatalogPage(
        sketchRepository: dependencies.sketchRepository,
        projectRepository: dependencies.projectRepository,
        exporter: dependencies.sketchCatalogExporter,
        createProject: dependencies.createProject,
        idGenerator: dependencies.idGenerator,
        clock: dependencies.clock,
        telemetry: dependencies.telemetry,
      ),
    );
  }
}

class _StorageLoadingScreen extends StatelessWidget {
  const _StorageLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _DirectorySelectionScreen extends StatelessWidget {
  const _DirectorySelectionScreen({
    required this.preparing,
    required this.errorMessage,
    required this.onChooseDirectory,
  });

  final bool preparing;
  final String? errorMessage;
  final VoidCallback? onChooseDirectory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('selected_directory_setup'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.folder_open_rounded,
                      size: 52,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Choose your sketch folder',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 28,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This folder becomes the source of truth. SuaCode IDE will '
                    'read and save sketches there directly—no duplicate mirror.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _DirectoryBenefit(
                    icon: Icons.visibility_outlined,
                    text: 'Your sketches stay visible in your file manager.',
                  ),
                  const SizedBox(height: 12),
                  const _DirectoryBenefit(
                    icon: Icons.sync_alt_rounded,
                    text: 'External edits appear when the catalog refreshes.',
                  ),
                  const SizedBox(height: 12),
                  const _DirectoryBenefit(
                    icon: Icons.lock_outline_rounded,
                    text: 'Access is limited to the folder you select.',
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.errorSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.errorBorder),
                      ),
                      child: Text(
                        errorMessage!,
                        key: const Key('selected_directory_error'),
                        style: const TextStyle(
                          color: AppColors.error,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      key: const Key('choose_sketch_directory'),
                      onPressed: onChooseDirectory,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: preparing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.create_new_folder_outlined),
                      label: Text(
                        preparing ? 'Preparing folder…' : 'Choose folder',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryBenefit extends StatelessWidget {
  const _DirectoryBenefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

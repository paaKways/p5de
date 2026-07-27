import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:p5de/app/telemetry/app_telemetry.dart';
import 'package:p5de/contexts/editor/presentation/editor_page.dart';
import 'package:p5de/contexts/runtime_preview/domain/runtime_preview_implementation.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_project.dart';
import 'package:p5de/contexts/sketch_catalog/application/project_templates.dart';
import 'package:p5de/contexts/sketch_catalog/application/sketch_catalog_exporter.dart';
import 'package:p5de/contexts/sketch_catalog/application/sketch_templates.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/web_local_storage_sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/project_detail_page.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_bloc.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';
import 'package:p5de/shared/updated_at_formatter.dart';

class SketchCatalogPage extends StatefulWidget {
  const SketchCatalogPage({
    required this.sketchRepository,
    required this.projectRepository,
    required this.createProject,
    required this.idGenerator,
    required this.clock,
    this.exporter,
    this.telemetry = const NoopAppTelemetry(),
    super.key,
  });

  final SketchRepository sketchRepository;
  final ProjectRepository projectRepository;
  final CreateProject createProject;
  final IdGenerator idGenerator;
  final Clock clock;
  final SketchCatalogExporter? exporter;
  final AppTelemetry telemetry;

  @override
  State<SketchCatalogPage> createState() => _SketchCatalogPageState();
}

class _SketchCatalogPageState extends State<SketchCatalogPage> {
  SketchRepository get sketchRepository => widget.sketchRepository;
  ProjectRepository get projectRepository => widget.projectRepository;
  CreateProject get createProject => widget.createProject;
  IdGenerator get idGenerator => widget.idGenerator;
  Clock get clock => widget.clock;
  AppTelemetry get telemetry => widget.telemetry;

  final Set<_SelectedSketchKey> _selectedSketches = <_SelectedSketchKey>{};
  bool _exporting = false;
  bool _deletingSelection = false;
  bool get _selectionMode => _selectedSketches.isNotEmpty;
  bool get _selectionBusy => _exporting || _deletingSelection;

  @override
  void initState() {
    super.initState();
    unawaited(telemetry.setCurrentScreen('catalog'));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SketchCatalogBloc, SketchCatalogState>(
      // Show one snackbar per new error emitted by the bloc.
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage &&
          current.errorMessage != null,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: _selectionMode
            ? _buildSelectionAppBar(context)
            : _buildDefaultAppBar(context),
        floatingActionButton: _selectionMode
            ? null
            : _CatalogCreateFab(
                onCreateSketch: () => _showCreateDialog(context),
                onCreateProject: () => _showCreateProjectDialog(context),
              ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  key: const Key('catalog_search_field'),
                  decoration: const InputDecoration(
                    labelText: 'Search sketches...',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(top: 12),
                  ),
                  onChanged: (value) => context.read<SketchCatalogBloc>().add(
                    SketchCatalogQueryChanged(value),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BlocBuilder<SketchCatalogBloc, SketchCatalogState>(
                buildWhen: (previous, current) =>
                    previous.filter != current.filter,
                builder: (context, state) {
                  return SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            key: const Key('catalog_filter_all'),
                            label: 'All',
                            active: state.filter == SketchCatalogFilter.all,
                            onTap: () => context.read<SketchCatalogBloc>().add(
                              const SketchCatalogFilterChanged(
                                SketchCatalogFilter.all,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            key: const Key('catalog_filter_recent'),
                            label: 'Recent',
                            active: state.filter == SketchCatalogFilter.recent,
                            onTap: () => context.read<SketchCatalogBloc>().add(
                              const SketchCatalogFilterChanged(
                                SketchCatalogFilter.recent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            key: const Key('catalog_filter_favourites'),
                            label: 'Favourites',
                            active:
                                state.filter == SketchCatalogFilter.favourites,
                            onTap: () => context.read<SketchCatalogBloc>().add(
                              const SketchCatalogFilterChanged(
                                SketchCatalogFilter.favourites,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: BlocBuilder<SketchCatalogBloc, SketchCatalogState>(
                builder: (context, state) {
                  if (state.status == SketchCatalogStatus.loading &&
                      state.sketches.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.sketches.isEmpty &&
                      state.projects.isEmpty &&
                      state.projectSketchMatches.isEmpty) {
                    return const Center(child: Text('No sketches yet.'));
                  }

                  final itemCount =
                      state.projects.length +
                      state.projectSketchMatches.length +
                      state.sketches.length;
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (index < state.projects.length) {
                        final project = state.projects[index];
                        return _ProjectTile(
                          project: project,
                          onOpen: () => _openProject(context, project),
                          onRename: () => _showRenameProjectDialog(
                            context,
                            projectId: project.id,
                            currentName: project.name.value,
                          ),
                          onDelete: () => _confirmDeleteProject(
                            context,
                            projectId: project.id,
                            projectName: project.name.value,
                          ),
                        );
                      }

                      final projectMatchIndex = index - state.projects.length;
                      if (projectMatchIndex <
                          state.projectSketchMatches.length) {
                        final match =
                            state.projectSketchMatches[projectMatchIndex];
                        final selectionKey = _SelectedSketchKey.project(
                          projectId: match.project.id,
                          sketchId: match.sketch.id,
                        );
                        final selected = _selectedSketches.contains(
                          selectionKey,
                        );
                        return _ProjectSketchTile(
                          match: match,
                          selected: selected,
                          selectionMode: _selectionMode,
                          onOpen: () => _selectionMode
                              ? _toggleSketchSelection(selectionKey)
                              : _openProjectSketch(context, match),
                          onLongPress: () => _selectSketch(selectionKey),
                          onToggleFavorite: () =>
                              context.read<SketchCatalogBloc>().add(
                                SketchCatalogProjectSketchFavoriteToggled(
                                  projectId: match.project.id,
                                  sketchId: match.sketch.id,
                                ),
                              ),
                        );
                      }

                      final sketchIndex =
                          projectMatchIndex - state.projectSketchMatches.length;
                      final sketch = state.sketches[sketchIndex];
                      final color =
                          _thumbnailColors[index % _thumbnailColors.length];
                      final selectionKey = _SelectedSketchKey.standalone(
                        sketch.id,
                      );
                      final selected = _selectedSketches.contains(selectionKey);

                      return Card(
                        key: Key('sketch_tile_${sketch.id}'),
                        margin: const EdgeInsets.only(bottom: 10),
                        color: selected
                            ? const Color(0xFFEFF6FF)
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                        child: ListTile(
                          onTap: () => _selectionMode
                              ? _toggleSketchSelection(selectionKey)
                              : _openEditor(context, sketch),
                          onLongPress: () => _selectSketch(selectionKey),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  color.withValues(alpha: 0.26),
                                  color.withValues(alpha: 0.06),
                                ],
                              ),
                            ),
                            child: _selectionMode
                                ? Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: selected
                                        ? const Color(0xFF256AF4)
                                        : const Color(0xFF64748B),
                                  )
                                : Icon(
                                    Icons.data_object_outlined,
                                    color: color,
                                  ),
                          ),
                          title: Text(
                            sketch.name.value,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            'Edited ${formatUpdatedAt(sketch.updatedAt)} - ${sketch.language.displayName}',
                          ),
                          trailing: Wrap(
                            spacing: 2,
                            children: [
                              IconButton(
                                key: Key('sketch_favorite_${sketch.id}'),
                                tooltip: sketch.isFavorite
                                    ? 'Remove favourite'
                                    : 'Add favourite',
                                color: sketch.isFavorite
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF64748B),
                                icon: Icon(
                                  sketch.isFavorite
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                ),
                                onPressed: () =>
                                    context.read<SketchCatalogBloc>().add(
                                      SketchCatalogFavoriteToggled(sketch.id),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildDefaultAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 16,
      title: const Text(
        'My Sketches',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
      ),
      actions: [
        if (kIsWeb && kDebugMode)
          IconButton(
            key: const Key('catalog_clear_web_data'),
            tooltip: 'Clear local web data',
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed: () => _clearWebData(context),
          ),
        const SizedBox(width: 6),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(BuildContext context) {
    final selectedCount = _selectedSketches.length;
    return AppBar(
      key: const Key('catalog_selection_app_bar'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        key: const Key('catalog_selection_clear'),
        tooltip: 'Clear selection',
        icon: const Icon(Icons.close),
        onPressed: _selectionBusy ? null : _clearSketchSelection,
      ),
      title: Text(
        '$selectedCount selected',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
      ),
      actions: [
        if (widget.exporter != null)
          _exporting
              ? const _AppBarActionProgress()
              : IconButton(
                  key: const Key('catalog_selection_export'),
                  tooltip: 'Export selected',
                  icon: const Icon(Icons.drive_folder_upload_outlined),
                  onPressed: _selectionBusy
                      ? null
                      : () => _exportSelectedSketches(context),
                ),
        _deletingSelection
            ? const _AppBarActionProgress()
            : IconButton(
                key: const Key('catalog_selection_delete'),
                tooltip: 'Delete selected',
                icon: const Icon(Icons.delete_outline),
                onPressed: _selectionBusy
                    ? null
                    : () => _confirmDeleteSelection(context),
              ),
        const SizedBox(width: 6),
      ],
    );
  }

  void _selectSketch(_SelectedSketchKey key) {
    if (_selectionBusy) {
      return;
    }
    setState(() {
      _selectedSketches.add(key);
    });
  }

  void _toggleSketchSelection(_SelectedSketchKey key) {
    if (_selectionBusy) {
      return;
    }
    setState(() {
      if (!_selectedSketches.remove(key)) {
        _selectedSketches.add(key);
      }
    });
  }

  void _clearSketchSelection() {
    setState(_selectedSketches.clear);
  }

  Future<void> _clearWebData(BuildContext context) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear local web data'),
          content: const Text(
            'This will remove all sketches stored in browser local data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true || !context.mounted) {
      return;
    }

    await clearSketchCatalogWebStorage();
    if (!context.mounted) {
      return;
    }

    context.read<SketchCatalogBloc>().add(const SketchCatalogLoaded());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Web sketch data cleared.')));
  }

  Future<void> _exportSelectedSketches(BuildContext context) async {
    final exporter = widget.exporter;
    if (exporter == null || _selectionBusy || _selectedSketches.isEmpty) {
      return;
    }

    setState(() {
      _exporting = true;
    });
    unawaited(
      telemetry.logEvent(
        'catalog_export_started',
        parameters: {'source': 'catalog_selection'},
      ),
    );

    try {
      final items = await _selectedExportItems();
      if (items.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No selected sketches to export.')),
          );
        }
        return;
      }
      final exportedPath = await exporter.exportItems(items);
      unawaited(
        telemetry.logEvent(
          'catalog_export_completed',
          parameters: {
            'path': exportedPath,
            'source': 'catalog_selection',
            'sketch_count': items.length,
          },
        ),
      );
      if (!context.mounted) {
        return;
      }
      setState(_selectedSketches.clear);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${items.length} ${items.length == 1 ? 'sketch' : 'sketches'} to $exportedPath.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      unawaited(
        telemetry.recordError(
          error,
          stackTrace,
          reason: 'catalog_selection_export_failed',
        ),
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to export sketches.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteSelection(BuildContext context) async {
    if (_selectionBusy || _selectedSketches.isEmpty) {
      return;
    }
    final selectedCount = _selectedSketches.length;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            selectedCount == 1 ? 'Delete selected sketch' : 'Delete sketches',
          ),
          content: Text(
            'Delete $selectedCount selected ${selectedCount == 1 ? 'sketch' : 'sketches'}? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !context.mounted) {
      return;
    }

    final selectedKeys = _selectedSketches.toList(growable: false);
    setState(() {
      _deletingSelection = true;
    });
    try {
      for (final key in selectedKeys) {
        final projectId = key.projectId;
        if (projectId == null) {
          await sketchRepository.deleteById(key.sketchId);
        } else {
          await projectRepository.deleteSketchById(projectId, key.sketchId);
        }
      }
      unawaited(
        telemetry.logEvent(
          'sketch_delete_many',
          parameters: {
            'source': 'catalog_selection',
            'sketch_count': selectedKeys.length,
          },
        ),
      );
      if (!context.mounted) {
        return;
      }
      setState(_selectedSketches.clear);
      context.read<SketchCatalogBloc>().add(const SketchCatalogLoaded());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted ${selectedKeys.length} ${selectedKeys.length == 1 ? 'sketch' : 'sketches'}.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      unawaited(
        telemetry.recordError(
          error,
          stackTrace,
          reason: 'catalog_selection_delete_failed',
        ),
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete selected sketches.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingSelection = false;
        });
      }
    }
  }

  Future<List<SketchCatalogExportItem>> _selectedExportItems() async {
    final items = <SketchCatalogExportItem>[];
    for (final key in _selectedSketches) {
      final projectId = key.projectId;
      if (projectId == null) {
        final sketch = await sketchRepository.findById(key.sketchId);
        if (sketch != null) {
          items.add(SketchCatalogExportItem.standalone(sketch));
        }
        continue;
      }

      final project = await projectRepository.findById(projectId);
      final sketch = await projectRepository.findSketchById(
        projectId,
        key.sketchId,
      );
      if (project != null && sketch != null) {
        items.add(
          SketchCatalogExportItem.project(project: project, sketch: sketch),
        );
      }
    }
    return items;
  }

  Future<void> _openEditor(BuildContext context, Sketch sketch) async {
    unawaited(
      telemetry.logEvent(
        'sketch_open',
        parameters: {
          'source': 'catalog',
          'sketch_id': sketch.id,
          'language': sketch.language.storageValue,
        },
      ),
    );
    final updatedSketch = await Navigator.of(context).push<Sketch>(
      MaterialPageRoute<Sketch>(
        builder: (_) => EditorPage(
          sketch: sketch,
          sketchRepository: sketchRepository,
          clock: clock,
          telemetry: telemetry,
          runtimePreviewImplementation: defaultRuntimePreviewImplementation,
        ),
      ),
    );
    unawaited(telemetry.setCurrentScreen('catalog'));
    if (updatedSketch != null && context.mounted) {
      context.read<SketchCatalogBloc>().add(const SketchCatalogLoaded());
    }
  }

  Future<void> _openProject(BuildContext context, Project project) async {
    unawaited(
      telemetry.logEvent(
        'project_open',
        parameters: {'source': 'catalog', 'project_id': project.id},
      ),
    );
    final projectChanged = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProjectDetailPage(
          project: project,
          projectRepository: projectRepository,
          clock: clock,
          idGenerator: idGenerator,
          exporter: widget.exporter,
          telemetry: telemetry,
          runtimePreviewImplementation: defaultRuntimePreviewImplementation,
        ),
      ),
    );
    unawaited(telemetry.setCurrentScreen('catalog'));
    if (projectChanged == true && context.mounted) {
      context.read<SketchCatalogBloc>().add(const SketchCatalogLoaded());
    }
  }

  Future<void> _openProjectSketch(
    BuildContext context,
    ProjectSketchMatch match,
  ) async {
    unawaited(
      telemetry.logEvent(
        'project_sketch_open',
        parameters: {
          'source': 'catalog_search',
          'project_id': match.project.id,
          'sketch_id': match.sketch.id,
          'language': match.sketch.language.storageValue,
        },
      ),
    );
    final projectChanged = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProjectDetailPage(
          project: match.project,
          projectRepository: projectRepository,
          clock: clock,
          idGenerator: idGenerator,
          initialSketchId: match.sketch.id,
          exporter: widget.exporter,
          telemetry: telemetry,
          runtimePreviewImplementation: defaultRuntimePreviewImplementation,
        ),
      ),
    );
    unawaited(telemetry.setCurrentScreen('catalog'));
    if (projectChanged == true && context.mounted) {
      context.read<SketchCatalogBloc>().add(const SketchCatalogLoaded());
    }
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _CreateSketchDialog(
          onCreate: (name) {
            context.read<SketchCatalogBloc>().add(
              SketchCatalogCreateRequested(
                name,
                language: SketchLanguage.processingJava,
                code: defaultSketchTemplateFor(SketchLanguage.processingJava),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateProjectDialog(BuildContext context) async {
    final projectCreated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _CreateProjectDialog(
          onCreate: (request, onProgress) async {
            await createProject(
              name: request.name,
              template: request.template,
              onProgress: onProgress,
            );
          },
        );
      },
    );
    if (projectCreated == true && context.mounted) {
      context.read<SketchCatalogBloc>().add(const SketchCatalogLoaded());
    }
  }

  Future<void> _showRenameProjectDialog(
    BuildContext context, {
    required String projectId,
    required String currentName,
  }) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _RenameEntityDialog(
          title: 'Rename folder',
          currentName: currentName,
        );
      },
    );
    if (newName == null || !context.mounted) {
      return;
    }

    context.read<SketchCatalogBloc>().add(
      SketchCatalogProjectRenameRequested(
        projectId: projectId,
        newName: newName,
      ),
    );
  }

  Future<void> _confirmDeleteProject(
    BuildContext context, {
    required String projectId,
    required String projectName,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete folder'),
          content: Text(
            'Delete "$projectName" and all sketches inside it? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true && context.mounted) {
      context.read<SketchCatalogBloc>().add(
        SketchCatalogProjectDeleteRequested(projectId),
      );
    }
  }
}

class _CatalogCreateFab extends StatefulWidget {
  const _CatalogCreateFab({
    required this.onCreateSketch,
    required this.onCreateProject,
  });

  final VoidCallback onCreateSketch;
  final VoidCallback onCreateProject;

  @override
  State<_CatalogCreateFab> createState() => _CatalogCreateFabState();
}

class _CatalogCreateFabState extends State<_CatalogCreateFab> {
  bool _isOpen = false;

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
  }

  void _runAction(VoidCallback action) {
    setState(() => _isOpen = false);
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _isOpen
              ? Column(
                  key: const ValueKey<String>('catalog_create_menu_open'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _CatalogCreateAction(
                      key: const Key('catalog_add_sketch'),
                      heroTag: 'catalog_add_sketch_action',
                      icon: Icons.note_add_outlined,
                      label: 'New sketch',
                      onPressed: () => _runAction(widget.onCreateSketch),
                    ),
                    const SizedBox(height: 12),
                    _CatalogCreateAction(
                      key: const Key('catalog_add_project'),
                      heroTag: 'catalog_add_project_action',
                      icon: Icons.create_new_folder_outlined,
                      label: 'New folder',
                      onPressed: () => _runAction(widget.onCreateProject),
                    ),
                    const SizedBox(height: 12),
                  ],
                )
              : const SizedBox.shrink(
                  key: ValueKey<String>('catalog_create_menu_closed'),
                ),
        ),
        FloatingActionButton(
          key: const Key('catalog_add_fab'),
          heroTag: 'catalog_add_fab',
          tooltip: _isOpen ? 'Close create menu' : 'Create',
          backgroundColor: const Color(0xFF256AF4),
          onPressed: _toggle,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 120),
            child: Icon(
              _isOpen ? Icons.close : Icons.add,
              key: ValueKey<bool>(_isOpen),
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogCreateAction extends StatelessWidget {
  const _CatalogCreateAction({
    required super.key,
    required this.heroTag,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String heroTag;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: heroTag,
      tooltip: label,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1E293B),
      elevation: 3,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _CreateSketchDialog extends StatefulWidget {
  const _CreateSketchDialog({required this.onCreate});

  final ValueChanged<String> onCreate;

  @override
  State<_CreateSketchDialog> createState() => _CreateSketchDialogState();
}

class _CreateSketchDialogState extends State<_CreateSketchDialog> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom - 32;
    final dialogMaxHeight = availableHeight > 680 ? 680.0 : availableHeight;

    return Dialog(
      key: const Key('create_sketch_dialog'),
      alignment: media.viewInsets.bottom > 0
          ? Alignment.topCenter
          : Alignment.center,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: dialogMaxHeight < 280 ? 280 : dialogMaxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 22, 24, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'New Sketch',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Create a new workspace to start your design journey.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sketch name',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('create_sketch_name_field'),
                      controller: _nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Enter sketch name...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 12,
                  overflowSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF256AF4),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: () {
                        widget.onCreate(_nameController.text);
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Create Sketch'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateProjectDialog extends StatefulWidget {
  const _CreateProjectDialog({required this.onCreate});

  final Future<void> Function(
    _CreateProjectRequest request,
    ProjectCreationProgressCallback onProgress,
  )
  onCreate;

  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final TextEditingController _nameController = TextEditingController();
  ProjectTemplate _template = ProjectTemplate.empty;
  ProjectCreationProgress? _progress;
  String? _errorMessage;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom - 32;
    final dialogMaxHeight = availableHeight > 680 ? 680.0 : availableHeight;

    return Dialog(
      key: const Key('create_project_dialog'),
      alignment: media.viewInsets.bottom > 0
          ? Alignment.topCenter
          : Alignment.center,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: dialogMaxHeight < 340 ? 340 : dialogMaxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 22, 24, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'New Folder',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Create a folder for related sketches.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Folder name',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('create_project_name_field'),
                      controller: _nameController,
                      autofocus: true,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        hintText: 'Enter folder name...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Content',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ProjectTemplate>(
                      key: const Key('create_project_template_dropdown'),
                      initialValue: _template,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      disabledHint: Text(_template.label),
                      items: ProjectTemplate.values
                          .map(
                            (template) => DropdownMenuItem<ProjectTemplate>(
                              value: template,
                              child: Text(template.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _submitting
                          ? null
                          : (template) {
                              if (template != null) {
                                setState(() => _template = template);
                              }
                            },
                    ),
                    if (_submitting) ...[
                      const SizedBox(height: 18),
                      LinearProgressIndicator(value: _progress?.value),
                      const SizedBox(height: 10),
                      Text(
                        _progress?.label ?? 'Creating folder...',
                        key: const Key('create_project_progress_label'),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        key: const Key('create_project_error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 12,
                  overflowSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF256AF4),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Create Folder'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
      _progress = const ProjectCreationProgress(
        stage: ProjectCreationStage.creatingProject,
      );
    });

    try {
      await widget.onCreate(
        _CreateProjectRequest(name: _nameController.text, template: _template),
        (progress) {
          if (mounted) {
            setState(() => _progress = progress);
          }
        },
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = 'Unable to create folder.';
      });
    }
  }
}

class _CreateProjectRequest {
  const _CreateProjectRequest({required this.name, required this.template});

  final String name;
  final ProjectTemplate template;
}

class _AppBarActionProgress extends StatelessWidget {
  const _AppBarActionProgress();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 48,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _SelectedSketchKey {
  const _SelectedSketchKey._({required this.sketchId, this.projectId});

  const _SelectedSketchKey.standalone(String sketchId)
    : this._(sketchId: sketchId);

  const _SelectedSketchKey.project({
    required String projectId,
    required String sketchId,
  }) : this._(projectId: projectId, sketchId: sketchId);

  final String? projectId;
  final String sketchId;

  @override
  bool operator ==(Object other) {
    return other is _SelectedSketchKey &&
        other.projectId == projectId &&
        other.sketchId == sketchId;
  }

  @override
  int get hashCode => Object.hash(projectId, sketchId);
}

class _RenameEntityDialog extends StatefulWidget {
  const _RenameEntityDialog({required this.title, required this.currentName});

  final String title;
  final String currentName;

  @override
  State<_RenameEntityDialog> createState() => _RenameEntityDialogState();
}

class _RenameEntityDialogState extends State<_RenameEntityDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'New name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final Project project;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('project_tile_${project.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: ListTile(
        onTap: onOpen,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFEEF2FF),
          ),
          child: const Icon(
            Icons.folder_open_outlined,
            color: Color(0xFF4F46E5),
          ),
        ),
        title: Text(
          project.name.value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Folder - ${project.sketchCount} ${project.sketchCount == 1 ? 'sketch' : 'sketches'}',
        ),
        trailing: Wrap(
          spacing: 2,
          children: [
            IconButton(
              key: Key('project_rename_${project.id}'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: onRename,
            ),
            IconButton(
              key: Key('project_delete_${project.id}'),
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectSketchTile extends StatelessWidget {
  const _ProjectSketchTile({
    required this.match,
    required this.selected,
    required this.selectionMode,
    required this.onOpen,
    required this.onLongPress,
    required this.onToggleFavorite,
  });

  final ProjectSketchMatch match;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('project_sketch_tile_${match.project.id}_${match.sketch.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      color: selected ? const Color(0xFFEFF6FF) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: ListTile(
        onTap: onOpen,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFEFF6FF),
          ),
          child: selectionMode
              ? Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected
                      ? const Color(0xFF256AF4)
                      : const Color(0xFF64748B),
                )
              : const Icon(
                  Icons.data_object_outlined,
                  color: Color(0xFF256AF4),
                ),
        ),
        title: Text(
          match.sketch.name.value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('In ${match.project.name.value}'),
        trailing: IconButton(
          key: Key(
            'project_match_favorite_${match.project.id}_${match.sketch.id}',
          ),
          tooltip: match.sketch.isFavorite
              ? 'Remove favourite'
              : 'Add favourite',
          color: match.sketch.isFavorite
              ? const Color(0xFFF59E0B)
              : const Color(0xFF64748B),
          icon: Icon(
            match.sketch.isFavorite
                ? Icons.star_rounded
                : Icons.star_border_rounded,
          ),
          onPressed: onToggleFavorite,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFF256AF4) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF475569),
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

const List<Color> _thumbnailColors = <Color>[
  Color(0xFF256AF4),
  Color(0xFF8B5CF6),
  Color(0xFF10B981),
  Color(0xFFF97316),
];

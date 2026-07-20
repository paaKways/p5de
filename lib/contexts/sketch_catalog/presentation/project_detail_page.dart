import 'dart:async';

import 'package:flutter/material.dart';
import 'package:p5de/app/telemetry/app_telemetry.dart';
import 'package:p5de/contexts/editor/presentation/editor_page.dart';
import 'package:p5de/contexts/runtime_preview/domain/runtime_preview_implementation.dart';
import 'package:p5de/contexts/sketch_catalog/application/create_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/delete_sketch.dart';
import 'package:p5de/contexts/sketch_catalog/application/list_sketches.dart';
import 'package:p5de/contexts/sketch_catalog/application/sketch_catalog_exporter.dart';
import 'package:p5de/contexts/sketch_catalog/application/sketch_templates.dart';
import 'package:p5de/contexts/sketch_catalog/application/toggle_sketch_favorite.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project.dart';
import 'package:p5de/contexts/sketch_catalog/domain/project_repository.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/project_scoped_sketch_repository.dart';
import 'package:p5de/shared/clock.dart';
import 'package:p5de/shared/id_generator.dart';
import 'package:p5de/shared/updated_at_formatter.dart';

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({
    required this.project,
    required this.projectRepository,
    required this.clock,
    required this.idGenerator,
    this.initialSketchId,
    this.exporter,
    this.runtimePreviewImplementation = RuntimePreviewImplementation.standard,
    this.telemetry = const NoopAppTelemetry(),
    super.key,
  });

  final Project project;
  final ProjectRepository projectRepository;
  final Clock clock;
  final IdGenerator idGenerator;
  final String? initialSketchId;
  final SketchCatalogExporter? exporter;
  final RuntimePreviewImplementation runtimePreviewImplementation;
  final AppTelemetry telemetry;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  late final SketchRepository _sketchRepository;
  late final CreateSketch _createSketch;
  late final DeleteSketch _deleteSketch;
  late final ListSketches _listSketches;
  late final ToggleSketchFavorite _toggleFavorite;

  List<Sketch> _sketches = const [];
  bool _loading = true;
  String? _errorMessage;
  bool _initialSketchOpened = false;
  bool _hasProjectChanges = false;
  final Set<String> _selectedSketchIds = <String>{};
  bool _exportingSelection = false;
  bool _deletingSelection = false;

  bool get _selectionMode => _selectedSketchIds.isNotEmpty;
  bool get _selectionBusy => _exportingSelection || _deletingSelection;

  @override
  void initState() {
    super.initState();
    _sketchRepository = ProjectScopedSketchRepository(
      projectRepository: widget.projectRepository,
      projectId: widget.project.id,
    );
    _createSketch = CreateSketch(
      repository: _sketchRepository,
      idGenerator: widget.idGenerator,
      clock: widget.clock,
    );
    _deleteSketch = DeleteSketch(_sketchRepository);
    _listSketches = ListSketches(_sketchRepository);
    _toggleFavorite = ToggleSketchFavorite(_sketchRepository);
    unawaited(widget.telemetry.setCurrentScreen('project_detail'));
    unawaited(
      widget.telemetry.setCustomKey('current_project_id', widget.project.id),
    );
    unawaited(
      widget.telemetry.logEvent(
        'project_open',
        parameters: {'project_id': widget.project.id},
      ),
    );
    unawaited(_refresh(openInitialSketch: true));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _closeProject();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        appBar: _selectionMode
            ? _buildSelectionAppBar()
            : _buildDefaultAppBar(context),
        floatingActionButton: _selectionMode
            ? null
            : FloatingActionButton(
                key: const Key('project_add_sketch_fab'),
                backgroundColor: const Color(0xFF256AF4),
                onPressed: _showCreateSketchDialog,
                child: const Icon(Icons.add, color: Colors.white),
              ),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildDefaultAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: const Icon(Icons.arrow_back),
        onPressed: _closeProject,
      ),
      title: Text(
        widget.project.name.value,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final selectedCount = _selectedSketchIds.length;
    return AppBar(
      key: const Key('project_selection_app_bar'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        key: const Key('project_selection_clear'),
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
          _exportingSelection
              ? const _ProjectActionProgress()
              : IconButton(
                  key: const Key('project_selection_export'),
                  tooltip: 'Export selected',
                  icon: const Icon(Icons.drive_folder_upload_outlined),
                  onPressed: _selectionBusy ? null : _exportSelectedSketches,
                ),
        _deletingSelection
            ? const _ProjectActionProgress()
            : IconButton(
                key: const Key('project_selection_delete'),
                tooltip: 'Delete selected',
                icon: const Icon(Icons.delete_outline),
                onPressed: _selectionBusy ? null : _confirmDeleteSelection,
              ),
        const SizedBox(width: 6),
      ],
    );
  }

  void _closeProject() {
    Navigator.of(context).pop(_hasProjectChanges);
  }

  Widget _buildBody() {
    if (_loading && _sketches.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    if (_sketches.isEmpty) {
      return const Center(child: Text('No sketches in this folder yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: _sketches.length,
      itemBuilder: (context, index) {
        final sketch = _sketches[index];
        final selected = _selectedSketchIds.contains(sketch.id);
        return Card(
          key: Key('project_sketch_${sketch.id}'),
          margin: const EdgeInsets.only(bottom: 10),
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          child: ListTile(
            onTap: () => _selectionMode
                ? _toggleSketchSelection(sketch.id)
                : _openEditor(sketch),
            onLongPress: () => _selectSketch(sketch.id),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFEFF6FF),
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
                  : const Icon(
                      Icons.data_object_outlined,
                      color: Color(0xFF256AF4),
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
                  key: Key('project_sketch_favorite_${sketch.id}'),
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
                  onPressed: () => _toggleSketchFavorite(sketch),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectSketch(String sketchId) {
    if (_selectionBusy) {
      return;
    }
    setState(() {
      _selectedSketchIds.add(sketchId);
    });
  }

  void _toggleSketchSelection(String sketchId) {
    if (_selectionBusy) {
      return;
    }
    setState(() {
      if (!_selectedSketchIds.remove(sketchId)) {
        _selectedSketchIds.add(sketchId);
      }
    });
  }

  void _clearSketchSelection() {
    setState(_selectedSketchIds.clear);
  }

  Future<void> _refresh({bool openInitialSketch = false}) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final sketches = await _listSketches();
      if (!mounted) {
        return;
      }
      setState(() {
        _sketches = sketches;
        _loading = false;
      });
      if (openInitialSketch) {
        _openInitialSketchIfNeeded(sketches);
      }
    } catch (error, stackTrace) {
      unawaited(
        widget.telemetry.recordError(
          error,
          stackTrace,
          reason: 'project_detail_load_failed',
          parameters: {'project_id': widget.project.id},
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to load folder sketches.';
      });
    }
  }

  void _openInitialSketchIfNeeded(List<Sketch> sketches) {
    final initialSketchId = widget.initialSketchId;
    if (_initialSketchOpened || initialSketchId == null) {
      return;
    }
    for (final sketch in sketches) {
      if (sketch.id == initialSketchId) {
        _initialSketchOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_openEditor(sketch));
          }
        });
        return;
      }
    }
  }

  Future<void> _openEditor(Sketch sketch) async {
    unawaited(
      widget.telemetry.logEvent(
        'project_sketch_open',
        parameters: {
          'project_id': widget.project.id,
          'sketch_id': sketch.id,
          'language': sketch.language.storageValue,
        },
      ),
    );
    final updatedSketch = await Navigator.of(context).push<Sketch>(
      MaterialPageRoute<Sketch>(
        builder: (_) => EditorPage(
          sketch: sketch,
          sketchRepository: _sketchRepository,
          clock: widget.clock,
          telemetry: widget.telemetry,
          runtimePreviewImplementation: widget.runtimePreviewImplementation,
        ),
      ),
    );
    unawaited(widget.telemetry.setCurrentScreen('project_detail'));
    if (updatedSketch != null && updatedSketch != sketch && mounted) {
      _hasProjectChanges = true;
      await _refresh();
    }
  }

  Future<void> _showCreateSketchDialog() async {
    var sketchCreated = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _ProjectSketchDialog(
          title: 'New Sketch',
          fieldLabel: 'Sketch name',
          actionLabel: 'Create Sketch',
          onSubmit: (name) async {
            try {
              await _createSketch(
                name: name,
                language: SketchLanguage.processingJava,
                code: defaultSketchTemplateFor(SketchLanguage.processingJava),
              );
              sketchCreated = true;
              _hasProjectChanges = true;
              unawaited(
                widget.telemetry.logEvent(
                  'sketch_create',
                  parameters: {
                    'source': 'project',
                    'project_id': widget.project.id,
                    'language': SketchLanguage.processingJava.storageValue,
                  },
                ),
              );
            } catch (error, stackTrace) {
              unawaited(
                widget.telemetry.recordError(
                  error,
                  stackTrace,
                  reason: 'project_sketch_create_failed',
                  parameters: {'project_id': widget.project.id},
                ),
              );
              rethrow;
            }
          },
        );
      },
    );
    if (sketchCreated && mounted) {
      await _refresh();
    }
  }

  Future<void> _confirmDeleteSelection() async {
    if (_selectionBusy || _selectedSketchIds.isEmpty) {
      return;
    }
    final selectedCount = _selectedSketchIds.length;
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

    if (shouldDelete != true || !mounted) {
      return;
    }

    final selectedIds = _selectedSketchIds.toList(growable: false);
    setState(() {
      _deletingSelection = true;
    });
    try {
      for (final sketchId in selectedIds) {
        await _deleteSketch(sketchId);
      }
      _hasProjectChanges = true;
      unawaited(
        widget.telemetry.logEvent(
          'sketch_delete_many',
          parameters: {
            'source': 'project_selection',
            'project_id': widget.project.id,
            'sketch_count': selectedIds.length,
          },
        ),
      );
      if (mounted) {
        setState(_selectedSketchIds.clear);
        await _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Deleted ${selectedIds.length} ${selectedIds.length == 1 ? 'sketch' : 'sketches'}.',
              ),
            ),
          );
        }
      }
    } catch (error, stackTrace) {
      unawaited(
        widget.telemetry.recordError(
          error,
          stackTrace,
          reason: 'project_selection_delete_failed',
          parameters: {'project_id': widget.project.id},
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete selected sketches.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingSelection = false;
        });
      }
    }
  }

  Future<void> _exportSelectedSketches() async {
    final exporter = widget.exporter;
    if (exporter == null || _selectionBusy || _selectedSketchIds.isEmpty) {
      return;
    }
    setState(() {
      _exportingSelection = true;
    });
    try {
      final selectedItems = _sketches
          .where((sketch) => _selectedSketchIds.contains(sketch.id))
          .map(
            (sketch) => SketchCatalogExportItem.project(
              project: widget.project,
              sketch: sketch,
            ),
          )
          .toList(growable: false);
      if (selectedItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No selected sketches to export.')),
        );
        return;
      }
      final exportedPath = await exporter.exportItems(selectedItems);
      unawaited(
        widget.telemetry.logEvent(
          'catalog_export_completed',
          parameters: {
            'path': exportedPath,
            'source': 'project_selection',
            'project_id': widget.project.id,
            'sketch_count': selectedItems.length,
          },
        ),
      );
      if (!mounted) {
        return;
      }
      setState(_selectedSketchIds.clear);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${selectedItems.length} ${selectedItems.length == 1 ? 'sketch' : 'sketches'} to $exportedPath.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      unawaited(
        widget.telemetry.recordError(
          error,
          stackTrace,
          reason: 'project_selection_export_failed',
          parameters: {'project_id': widget.project.id},
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to export selected sketches.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _exportingSelection = false;
        });
      }
    }
  }

  Future<void> _toggleSketchFavorite(Sketch sketch) async {
    await _toggleFavorite(sketch.id);
    _hasProjectChanges = true;
    unawaited(
      widget.telemetry.logEvent(
        'sketch_favorite_toggle',
        parameters: {
          'source': 'project',
          'project_id': widget.project.id,
          'sketch_id': sketch.id,
        },
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }
}

class _ProjectActionProgress extends StatelessWidget {
  const _ProjectActionProgress();

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

class _ProjectSketchDialog extends StatefulWidget {
  const _ProjectSketchDialog({
    required this.title,
    required this.fieldLabel,
    required this.actionLabel,
    required this.onSubmit,
  });

  final String title;
  final String fieldLabel;
  final String actionLabel;
  final Future<void> Function(String name) onSubmit;

  @override
  State<_ProjectSketchDialog> createState() => _ProjectSketchDialogState();
}

class _ProjectSketchDialogState extends State<_ProjectSketchDialog> {
  late final TextEditingController _controller;
  String? _errorMessage;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
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
        decoration: InputDecoration(
          labelText: widget.fieldLabel,
          errorText: _errorMessage,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await widget.onSubmit(_controller.text);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = 'Unable to save sketch.';
      });
    }
  }
}

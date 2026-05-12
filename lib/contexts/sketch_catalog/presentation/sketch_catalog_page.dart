import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:p5de/contexts/editor/presentation/editor_page.dart';
import 'package:p5de/contexts/sketch_catalog/application/sketch_templates.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/web_local_storage_sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_bloc.dart';
import 'package:p5de/shared/clock.dart';

class SketchCatalogPage extends StatelessWidget {
  const SketchCatalogPage({
    required this.sketchRepository,
    required this.clock,
    super.key,
  });

  final SketchRepository sketchRepository;
  final Clock clock;

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
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 16,
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF256AF4).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.draw_outlined,
                  color: Color(0xFF256AF4),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'My Sketches',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
              ),
            ],
          ),
          actions: [
            if (kIsWeb && kDebugMode)
              IconButton(
                key: const Key('catalog_clear_web_data'),
                tooltip: 'Clear local web data',
                icon: const Icon(Icons.cleaning_services_outlined),
                onPressed: () => _clearWebData(context),
              ),
            IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
            const SizedBox(width: 6),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          key: const Key('catalog_add_fab'),
          backgroundColor: const Color(0xFF256AF4),
          onPressed: () => _showCreateDialog(context),
          child: const Icon(Icons.add, color: Colors.white),
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
              child: Row(
                children: const [
                  _FilterChip(label: 'All', active: true),
                  SizedBox(width: 8),
                  _FilterChip(label: 'Recent'),
                  SizedBox(width: 8),
                  _FilterChip(label: 'Favorites'),
                ],
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
                  if (state.sketches.isEmpty) {
                    return const Center(child: Text('No sketches yet.'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                    itemCount: state.sketches.length,
                    itemBuilder: (context, index) {
                      final sketch = state.sketches[index];
                      final color =
                          _thumbnailColors[index % _thumbnailColors.length];

                      return Card(
                        key: Key('sketch_tile_${sketch.id}'),
                        margin: const EdgeInsets.only(bottom: 10),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                        child: ListTile(
                          onTap: () => _openEditor(context, sketch),
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
                            child: Icon(Icons.auto_awesome, color: color),
                          ),
                          title: Text(
                            sketch.name.value,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            'Edited ${_formatTimestamp(sketch.updatedAt)} - ${sketch.language.displayName}',
                          ),
                          trailing: Wrap(
                            spacing: 2,
                            children: [
                              IconButton(
                                key: Key('sketch_rename_${sketch.id}'),
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _showRenameDialog(
                                  context,
                                  sketchId: sketch.id,
                                  currentName: sketch.name.value,
                                ),
                              ),
                              IconButton(
                                key: Key('sketch_delete_${sketch.id}'),
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _confirmDelete(
                                  context,
                                  sketchId: sketch.id,
                                  sketchName: sketch.name.value,
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

  Future<void> _openEditor(BuildContext context, Sketch sketch) async {
    final updatedSketch = await Navigator.of(context).push<Sketch>(
      MaterialPageRoute<Sketch>(
        builder: (_) => EditorPage(
          sketch: sketch,
          sketchRepository: sketchRepository,
          clock: clock,
        ),
      ),
    );
    if (updatedSketch != null && context.mounted) {
      context.read<SketchCatalogBloc>().add(const SketchCatalogLoaded());
    }
  }

  Future<void> _confirmDelete(
    BuildContext context, {
    required String sketchId,
    required String sketchName,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete sketch'),
          content: Text('Delete "$sketchName"? This cannot be undone.'),
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
        SketchCatalogDeleteRequested(sketchId),
      );
    }
  }

  // Render compact relative metadata like "2h ago" for list cards.
  String _formatTimestamp(int epochMs) {
    final now = DateTime.now();
    final updated = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final diff = now.difference(updated);

    if (diff.inMinutes < 1) {
      return 'just now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }

    final year = updated.year.toString().padLeft(4, '0');
    final month = updated.month.toString().padLeft(2, '0');
    final day = updated.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final nameController = TextEditingController();
    var language = SketchLanguage.processingJava;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final media = MediaQuery.of(dialogContext);
              final availableHeight =
                  media.size.height - media.viewInsets.bottom - 32;
              final dialogMaxHeight = availableHeight > 680
                  ? 680.0
                  : availableHeight;

              return Dialog(
                key: const Key('create_sketch_dialog'),
                alignment: media.viewInsets.bottom > 0
                    ? Alignment.topCenter
                    : Alignment.center,
                backgroundColor: Colors.white,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
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
                                controller: nameController,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: 'Enter sketch name...',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Runtime',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<SketchLanguage>(
                                key: const Key(
                                  'create_sketch_runtime_dropdown',
                                ),
                                initialValue: language,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                items: SketchLanguage.values
                                    .map(
                                      (runtime) => DropdownMenuItem(
                                        value: runtime,
                                        child: Text(
                                          _runtimeDropdownLabel(runtime),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setDialogState(() => language = value);
                                },
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
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF256AF4),
                                  ),
                                  onPressed: () {
                                    context.read<SketchCatalogBloc>().add(
                                      SketchCatalogCreateRequested(
                                        nameController.text,
                                        language: language,
                                        code: defaultSketchTemplateFor(
                                          language,
                                        ),
                                      ),
                                    );
                                    Navigator.of(dialogContext).pop();
                                  },
                                  icon: const Icon(
                                    Icons.arrow_forward,
                                    size: 18,
                                  ),
                                  label: const Text('Create Sketch'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context, {
    required String sketchId,
    required String currentName,
  }) async {
    final controller = TextEditingController(text: currentName);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename sketch'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'New name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                // Renaming follows the same domain rules as creation.
                context.read<SketchCatalogBloc>().add(
                  SketchCatalogRenameRequested(
                    sketchId: sketchId,
                    newName: controller.text,
                  ),
                );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? const Color(0xFF256AF4) : Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
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
    );
  }
}

String _runtimeDropdownLabel(SketchLanguage language) {
  switch (language) {
    case SketchLanguage.processingJava:
      return 'Processing (.${language.fileExtension})';
    case SketchLanguage.p5js:
      return 'p5.js (.${language.fileExtension})';
  }
}

const List<Color> _thumbnailColors = <Color>[
  Color(0xFF256AF4),
  Color(0xFF8B5CF6),
  Color(0xFF10B981),
  Color(0xFFF97316),
];

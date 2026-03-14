import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:p5de/contexts/sketch_catalog/application/sketch_templates.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/web_local_storage_sketch_repository.dart';
import 'package:p5de/contexts/sketch_catalog/presentation/sketch_catalog_bloc.dart';

class SketchCatalogPage extends StatelessWidget {
  const SketchCatalogPage({super.key});

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
                            'Edited ${_formatTimestamp(sketch.updatedAt)} • p5.js',
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
    var templateChoice = _SketchTemplateChoice.defaultStarter;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'New Sketch',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Create a new workspace to start your design journey.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sketch name',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Enter sketch name...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select a template',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    _TemplateTile(
                      title: 'Blank',
                      subtitle: 'Start with a clean canvas',
                      icon: Icons.crop_square_outlined,
                      selected: templateChoice == _SketchTemplateChoice.blank,
                      onTap: () => setDialogState(
                        () => templateChoice = _SketchTemplateChoice.blank,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _TemplateTile(
                      title: 'Default Starter',
                      subtitle: 'Pre-configured p5 setup and draw functions',
                      icon: Icons.dashboard_customize_outlined,
                      selected:
                          templateChoice ==
                          _SketchTemplateChoice.defaultStarter,
                      onTap: () => setDialogState(
                        () => templateChoice =
                            _SketchTemplateChoice.defaultStarter,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF256AF4),
                  ),
                  onPressed: () {
                    final code = templateChoice == _SketchTemplateChoice.blank
                        ? ''
                        : kDefaultSketchTemplate;

                    context.read<SketchCatalogBloc>().add(
                      SketchCatalogCreateRequested(
                        nameController.text,
                        code: code,
                      ),
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Create Sketch'),
                ),
              ],
            );
          },
        );
      },
    );
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

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF256AF4) : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF256AF4).withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: const Color(0xFF256AF4), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? const Color(0xFF256AF4)
                  : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SketchTemplateChoice { blank, defaultStarter }

const List<Color> _thumbnailColors = <Color>[
  Color(0xFF256AF4),
  Color(0xFF8B5CF6),
  Color(0xFF10B981),
  Color(0xFFF97316),
];

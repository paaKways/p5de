import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:p5de/app/telemetry/app_telemetry.dart';
import 'package:p5de/contexts/editor/application/load_sketch_for_edit.dart';
import 'package:p5de/contexts/editor/application/save_sketch.dart';
import 'package:p5de/contexts/editor/presentation/codemirror_editor_view.dart';
import 'package:p5de/contexts/editor/presentation/editor_bloc.dart';
import 'package:p5de/contexts/runtime_preview/presentation/runtime_preview_page.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_language.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch_repository.dart';
import 'package:p5de/shared/clock.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({
    required this.sketch,
    required this.sketchRepository,
    required this.clock,
    this.telemetry = const NoopAppTelemetry(),
    super.key,
  });

  final Sketch sketch;
  final SketchRepository sketchRepository;
  final Clock clock;
  final AppTelemetry telemetry;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with WidgetsBindingObserver {
  late final EditorBloc _bloc;
  final GlobalKey<CodeMirrorEditorViewState> _editorKey =
      GlobalKey<CodeMirrorEditorViewState>();
  late Sketch _sketch;
  Timer? _autosaveTimer;
  int _line = 1;
  int _column = 1;
  bool _hasLoggedEditThisSession = false;

  bool get _runtimeAvailable =>
      _sketch.language == SketchLanguage.processingJava;

  @override
  void initState() {
    super.initState();
    _sketch = widget.sketch;
    _bloc = EditorBloc(
      loadSketchForEdit: LoadSketchForEdit(widget.sketchRepository),
      saveSketch: SaveSketch(
        repository: widget.sketchRepository,
        clock: widget.clock,
      ),
      telemetry: widget.telemetry,
    )..add(EditorLoaded(_sketch.id));
    unawaited(widget.telemetry.setCurrentScreen('editor'));
    unawaited(widget.telemetry.setCustomKey('current_sketch_id', _sketch.id));
    unawaited(
      widget.telemetry.setCustomKey(
        'current_language',
        _sketch.language.storageValue,
      ),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    _bloc.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _requestSave();
    }
  }

  void _requestSave() {
    _autosaveTimer?.cancel();
    if (_bloc.state.isDirty && !_bloc.state.isSaving) {
      _bloc.add(const EditorSaveRequested());
    }
  }

  Future<void> _insertTextAtSelection(String value) async {
    final pair = switch (value) {
      '{' => ('{}', 1),
      '(' => ('()', 1),
      '[' => ('[]', 1),
      _ => (value, value.length),
    };
    await _editorKey.currentState?.insertText(pair.$1, cursorOffset: pair.$2);
  }

  void _handleEditorReady() {}

  Future<void> _runEditorCommand(String command) async {
    unawaited(
      widget.telemetry.logEvent(
        'editor_command',
        parameters: {'command': command, 'sketch_id': _sketch.id},
      ),
    );
    await _editorKey.currentState?.runCommand(command);
  }

  Future<void> _openRuntimePreview(EditorState state) async {
    final code = state.draft?.currentCode ?? _sketch.code;
    final previewSketch = _sketch.copyWith(code: code);
    unawaited(
      widget.telemetry.logEvent(
        'runtime_open',
        parameters: {
          'sketch_id': _sketch.id,
          'language': _sketch.language.storageValue,
          'code_length': code.length,
        },
      ),
    );
    _requestSave();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RuntimePreviewPage(
          sketch: previewSketch,
          initialCode: code,
          telemetry: widget.telemetry,
        ),
      ),
    );
    unawaited(widget.telemetry.setCurrentScreen('editor'));
  }

  void _handleEditorChanged(String code) {
    if (!_hasLoggedEditThisSession) {
      _hasLoggedEditThisSession = true;
      unawaited(
        widget.telemetry.logEvent(
          'editor_edit',
          parameters: {
            'sketch_id': _sketch.id,
            'language': _sketch.language.storageValue,
          },
        ),
      );
    }
    _bloc.add(EditorCodeChanged(code));
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 1), _requestSave);
  }

  void _handleCursorChanged(int line, int column) {
    if (mounted) {
      setState(() {
        _line = line;
        _column = column;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EditorBloc, EditorState>(
      bloc: _bloc,
      listenWhen: (previous, current) =>
          previous.savedSketch != current.savedSketch ||
          previous.errorMessage != current.errorMessage ||
          previous.draft != current.draft,
      listener: (context, state) {
        final savedSketch = state.savedSketch;
        if (savedSketch != null && savedSketch != _sketch) {
          _sketch = savedSketch;
        }

        final errorMessage = state.errorMessage;
        if (errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      },
      builder: (context, state) {
        return PopScope(
          canPop: !state.isDirty,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }
            final shouldLeave = await _confirmDiscard();
            if (shouldLeave && context.mounted) {
              Navigator.of(context).pop(_sketch);
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFFF5F6F8),
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  if (!state.isDirty || await _confirmDiscard()) {
                    if (context.mounted) {
                      Navigator.of(context).pop(_sketch);
                    }
                  }
                },
              ),
              title: const Text(
                'Code Editor',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
              ),
              actions: [
                IconButton(
                  tooltip: 'Undo',
                  icon: const Icon(Icons.undo),
                  onPressed: () => _runEditorCommand('undo'),
                ),
                IconButton(
                  tooltip: 'Redo',
                  icon: const Icon(Icons.redo),
                  onPressed: () => _runEditorCommand('redo'),
                ),
                IconButton(
                  tooltip: _runtimeAvailable
                      ? 'Run'
                      : 'p5.js runtime is on hold',
                  icon: const Icon(Icons.play_arrow),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFEAF1FF),
                    foregroundColor: const Color(0xFF256AF4),
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: state.draft == null || !_runtimeAvailable
                      ? null
                      : () => _openRuntimePreview(state),
                ),
                IconButton(
                  tooltip: 'Save',
                  icon: state.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  onPressed: state.isDirty && !state.isSaving
                      ? _requestSave
                      : null,
                ),
                const SizedBox(width: 6),
              ],
            ),
            body: Column(
              children: [
                _EditorTabs(
                  activeFileName: _sketch.language.fileNameForSketchName(
                    _sketch.name.value,
                  ),
                ),
                _EditorStatus(
                  languageLabel: _sketch.language.displayName,
                  isDirty: state.isDirty,
                  isSaving: state.isSaving,
                ),
                Expanded(
                  child: CodeMirrorEditorView(
                    key: _editorKey,
                    code: _sketch.code,
                    language: _sketch.language.storageValue,
                    onChanged: _handleEditorChanged,
                    onCursorChanged: _handleCursorChanged,
                    onReady: _handleEditorReady,
                  ),
                ),
                _EditorKeyboardToolbar(onInsert: _insertTextAtSelection),
                _EditorBottomActions(
                  line: _line,
                  column: _column,
                  onFind: () => _runEditorCommand('find'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your unsaved editor changes will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
    return result == true;
  }
}

class _EditorTabs extends StatelessWidget {
  const _EditorTabs({required this.activeFileName});

  final String activeFileName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SizedBox(
        height: 58,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            _FileTab(
              label: activeFileName,
              active: true,
              accent: const Color(0xFF256AF4),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileTab extends StatelessWidget {
  const _FileTab({
    required this.label,
    required this.active,
    required this.accent,
  });

  final String label;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: active ? accent : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF111827) : const Color(0xFF64748B),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorStatus extends StatelessWidget {
  const _EditorStatus({
    required this.languageLabel,
    required this.isDirty,
    required this.isSaving,
  });

  final String languageLabel;
  final bool isDirty;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final label = isSaving ? 'Saving' : (isDirty ? 'Unsaved' : 'Saved');
    final color = isDirty || isSaving
        ? const Color(0xFFB45309)
        : const Color(0xFF166534);
    final background = isDirty || isSaving
        ? const Color(0xFFFEF3C7)
        : const Color(0xFFDDFBE8);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 10, color: color),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Text(
            languageLabel,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorKeyboardToolbar extends StatelessWidget {
  const _EditorKeyboardToolbar({required this.onInsert});

  final ValueChanged<String> onInsert;

  static const _symbols = ['{', '}', '(', ')', '[', ']', '=', '+', ';'];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          itemBuilder: (context, index) {
            return SizedBox(
              width: 70,
              child: OutlinedButton(
                onPressed: () => onInsert(_symbols[index]),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Text(
                  _symbols[index],
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          },
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemCount: _symbols.length,
        ),
      ),
    );
  }
}

class _EditorBottomActions extends StatelessWidget {
  const _EditorBottomActions({
    required this.line,
    required this.column,
    required this.onFind,
  });

  final int line;
  final int column;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Row(
        children: [
          InkWell(
            onTap: onFind,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.search, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Text(
                    'Find',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Text(
            'Ln $line, Col $column',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

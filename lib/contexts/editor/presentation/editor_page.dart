import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:p5de/app/di/app_dependencies.dart';
import 'package:p5de/contexts/editor/infrastructure/inappwebview_code_editor.dart';
import 'package:p5de/contexts/editor/infrastructure/web_code_editor_stub.dart'
    if (dart.library.html) 'package:p5de/contexts/editor/infrastructure/web_code_editor.dart'
    as web_editor;
import 'package:p5de/contexts/editor/presentation/editor_bloc.dart';

class EditorPage extends StatelessWidget {
  const EditorPage({
    required this.dependencies,
    required this.sketchId,
    this.forcePlainTextEditor = false,
    super.key,
  });

  final AppDependencies dependencies;
  final String sketchId;
  final bool forcePlainTextEditor;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EditorBloc(
        loadSketchForEdit: dependencies.loadSketchForEdit,
        updateDraft: dependencies.updateDraft,
        saveSketch: dependencies.saveSketch,
        draftPersistence: dependencies.draftPersistence,
      )..add(EditorStarted(sketchId)),
      child: _EditorView(forcePlainTextEditor: forcePlainTextEditor),
    );
  }
}

class _EditorView extends StatefulWidget {
  const _EditorView({required this.forcePlainTextEditor});

  final bool forcePlainTextEditor;

  @override
  State<_EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<_EditorView> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  bool _syncingText = false;

  bool get _useWebCodeEditor => kIsWeb && !widget.forcePlainTextEditor;
  bool get _useWebViewEditor => !kIsWeb && !widget.forcePlainTextEditor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      context.read<EditorBloc>().add(const EditorAppBackgrounded());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EditorBloc, EditorState>(
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: BlocBuilder<EditorBloc, EditorState>(
            builder: (context, state) {
              final name = state.draft?.sketchName ?? 'Code Editor';
              return Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              );
            },
          ),
          actions: [
            BlocBuilder<EditorBloc, EditorState>(
              builder: (context, state) {
                final dirty = state.draft?.isDirty ?? false;
                return IconButton(
                  key: const Key('editor_save_button'),
                  tooltip: 'Save',
                  onPressed: dirty
                      ? () => context.read<EditorBloc>().add(
                          const EditorSaveRequested(),
                        )
                      : null,
                  icon: const Icon(Icons.save_outlined),
                );
              },
            ),
            IconButton(
              tooltip: 'Run (coming soon)',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Runtime preview is next milestone.'),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      _tabItem(
                        label: 'sketch.js',
                        active: true,
                        icon: Icons.javascript,
                        iconColor: const Color(0xFFF59E0B),
                      ),
                      _tabItem(
                        label: 'index.html',
                        icon: Icons.html,
                        iconColor: const Color(0xFFF97316),
                      ),
                      _tabItem(
                        label: 'style.css',
                        icon: Icons.css,
                        iconColor: const Color(0xFF256AF4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      BlocBuilder<EditorBloc, EditorState>(
                        builder: (context, state) {
                          return _saveIndicator(
                            status: state.status,
                            isDirty: state.draft?.isDirty ?? false,
                            lastSavedAt: state.draft?.lastSavedAt,
                          );
                        },
                      ),
                      const Spacer(),
                      const Text(
                        'Ln/Col live tracking in CodeMirror milestone',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<EditorBloc, EditorState>(
                builder: (context, state) {
                  if (state.status == EditorStatus.loading ||
                      state.status == EditorStatus.initial) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final draft = state.draft;
                  if (draft == null) {
                    return const Center(child: Text('Unable to load sketch.'));
                  }

                  if (!_syncingText && _controller.text != draft.code) {
                    _syncingText = true;
                    _controller.text = draft.code;
                    _controller.selection = TextSelection.collapsed(
                      offset: _controller.text.length,
                    );
                    _syncingText = false;
                  }

                  if (_useWebCodeEditor) {
                    return _buildWebCodeEditor(draft.code);
                  }

                  if (_useWebViewEditor) {
                    return _buildWebViewEditor(draft.code);
                  }

                  return _buildPlainTextEditor();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebCodeEditor(String code) {
    return Container(
      color: const Color(0xFF0F172A),
      child: web_editor.WebCodeEditor(
        key: const Key('editor_code_field'),
        initialCode: code,
        onCodeChanged: (value) {
          context.read<EditorBloc>().add(EditorCodeChanged(value));
        },
      ),
    );
  }

  Widget _buildWebViewEditor(String code) {
    return Container(
      color: const Color(0xFF0F172A),
      child: InAppWebViewCodeEditor(
        key: const Key('editor_code_field'),
        initialCode: code,
        onCodeChanged: (value) {
          context.read<EditorBloc>().add(EditorCodeChanged(value));
        },
      ),
    );
  }

  Widget _buildPlainTextEditor() {
    final lineCount = _lineCountOf(_controller.text);
    return Container(
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 44,
                  padding: const EdgeInsets.only(top: 16, right: 8),
                  decoration: const BoxDecoration(color: Color(0xFF111C2F)),
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: lineCount,
                    itemBuilder: (context, index) {
                      return Text(
                        '${index + 1}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: TextField(
                    key: const Key('editor_code_field'),
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 14,
                      height: 1.45,
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      if (_syncingText) {
                        return;
                      }
                      context.read<EditorBloc>().add(EditorCodeChanged(value));
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(color: Color(0xFF0B1322)),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _Keycap('{'),
                _Keycap('}'),
                _Keycap('('),
                _Keycap(')'),
                _Keycap('['),
                _Keycap(']'),
                _Keycap('='),
                _Keycap('+'),
                _Keycap(';'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabItem({
    required String label,
    required IconData icon,
    required Color iconColor,
    bool active = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: active ? const Color(0xFF256AF4) : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveIndicator({
    required EditorStatus status,
    required bool isDirty,
    required int? lastSavedAt,
  }) {
    String text;
    Color bg;
    Color fg;

    if (status == EditorStatus.saving) {
      text = 'Saving...';
      bg = const Color(0xFFE0E7FF);
      fg = const Color(0xFF3730A3);
    } else if (isDirty) {
      text = 'Unsaved changes';
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else {
      final savedLabel = lastSavedAt == null
          ? 'Not saved yet'
          : 'Saved ${_formatSavedAt(lastSavedAt)}';
      text = savedLabel;
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    }

    return Container(
      key: const Key('editor_save_indicator'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  int _lineCountOf(String text) {
    if (text.isEmpty) {
      return 1;
    }
    return '\n'.allMatches(text).length + 1;
  }

  String _formatSavedAt(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _Keycap extends StatelessWidget {
  const _Keycap(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

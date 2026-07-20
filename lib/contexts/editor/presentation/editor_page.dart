import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:p5de/app/telemetry/app_telemetry.dart';
import 'package:p5de/contexts/editor/application/load_sketch_for_edit.dart';
import 'package:p5de/contexts/editor/application/save_sketch.dart';
import 'package:p5de/contexts/editor/presentation/codemirror_editor_view.dart';
import 'package:p5de/contexts/editor/presentation/editor_bloc.dart';
import 'package:p5de/contexts/runtime_preview/domain/runtime_preview_implementation.dart';
import 'package:p5de/contexts/runtime_preview/presentation/fullscreen_runtime_preview_page.dart';
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
    this.runtimePreviewImplementation = RuntimePreviewImplementation.standard,
    super.key,
  });

  final Sketch sketch;
  final SketchRepository sketchRepository;
  final Clock clock;
  final AppTelemetry telemetry;
  final RuntimePreviewImplementation runtimePreviewImplementation;

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

  Future<void> _handleShortcutInput(String value) async {
    if (value == '\t') {
      await _runEditorCommand('tab');
      return;
    }
    await _insertTextAtSelection(value);
  }

  Future<void> _openColorPicker() async {
    await _showDialogAboveEditor<void>(
      builder: (_) => const _ColorPickerDialog(),
    );
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

  Future<T?> _showDialogAboveEditor<T>({required WidgetBuilder builder}) async {
    await _editorKey.currentState?.setPointerEventsEnabled(false);
    try {
      if (!mounted) {
        return null;
      }
      return await showDialog<T>(context: context, builder: builder);
    } finally {
      await _editorKey.currentState?.setPointerEventsEnabled(true);
    }
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
    switch (widget.runtimePreviewImplementation) {
      case RuntimePreviewImplementation.standard:
        await _openStandardPreview(previewSketch, code);
      case RuntimePreviewImplementation.fullscreenPhysical:
        await _openFullscreenPhysicalPreview(previewSketch, code);
    }
    unawaited(widget.telemetry.setCurrentScreen('editor'));
  }

  Future<void> _openStandardPreview(Sketch sketch, String code) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RuntimePreviewPage(
          sketch: sketch,
          initialCode: code,
          telemetry: widget.telemetry,
        ),
      ),
    );
  }

  Future<void> _openFullscreenPhysicalPreview(Sketch sketch, String code) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FullscreenRuntimePreviewPage(
          sketch: sketch,
          initialCode: code,
          telemetry: widget.telemetry,
        ),
      ),
    );
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
                _EditorKeyboardToolbar(onInsert: _handleShortcutInput),
                _EditorBottomActions(
                  line: _line,
                  column: _column,
                  onFind: () => _runEditorCommand('find'),
                  onFormat: () => _runEditorCommand('format'),
                  onColor: _openColorPicker,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDiscard() async {
    final result = await _showDialogAboveEditor<bool>(
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

  static const _shortcuts = [
    _EditorShortcut(
      label: 'Tab',
      value: '\t',
      width: 104,
      icon: Icons.keyboard_tab,
    ),
    _EditorShortcut(label: '{', value: '{'),
    _EditorShortcut(label: '}', value: '}'),
    _EditorShortcut(label: '(', value: '('),
    _EditorShortcut(label: ')', value: ')'),
    _EditorShortcut(label: '[', value: '['),
    _EditorShortcut(label: ']', value: ']'),
    _EditorShortcut(label: '=', value: '='),
    _EditorShortcut(label: '+', value: '+'),
    _EditorShortcut(label: ';', value: ';'),
  ];

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
            final shortcut = _shortcuts[index];
            return SizedBox(
              width: shortcut.width,
              child: Tooltip(
                message: shortcut.label == 'Tab'
                    ? 'Insert tab'
                    : 'Insert ${shortcut.label}',
                child: OutlinedButton(
                  onPressed: () => onInsert(shortcut.value),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F172A),
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: _ShortcutButtonContent(shortcut: shortcut),
                ),
              ),
            );
          },
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemCount: _shortcuts.length,
        ),
      ),
    );
  }
}

class _EditorShortcut {
  const _EditorShortcut({
    required this.label,
    required this.value,
    this.width = 70,
    this.icon,
  });

  final String label;
  final String value;
  final double width;
  final IconData? icon;
}

class _ShortcutButtonContent extends StatelessWidget {
  const _ShortcutButtonContent({required this.shortcut});

  final _EditorShortcut shortcut;

  @override
  Widget build(BuildContext context) {
    final icon = shortcut.icon;
    final textStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: icon == null ? 22 : 14,
      fontWeight: FontWeight.w800,
    );

    if (icon == null) {
      return Text(shortcut.label, style: textStyle);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 4),
        Text(shortcut.label, style: textStyle),
      ],
    );
  }
}

class _EditorBottomActions extends StatelessWidget {
  const _EditorBottomActions({
    required this.line,
    required this.column,
    required this.onFind,
    required this.onFormat,
    required this.onColor,
  });

  final int line;
  final int column;
  final VoidCallback onFind;
  final VoidCallback onFormat;
  final VoidCallback onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _EditorActionButton(
                    icon: Icons.search,
                    label: 'Find',
                    onTap: onFind,
                  ),
                  const SizedBox(width: 16),
                  _EditorActionButton(
                    icon: Icons.format_align_left,
                    label: 'Auto-Format',
                    onTap: onFormat,
                  ),
                  const SizedBox(width: 16),
                  _EditorActionButton(
                    icon: Icons.palette_outlined,
                    label: 'Color',
                    onTap: onColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
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

class _EditorActionButton extends StatelessWidget {
  const _EditorActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ColorComponent { red, green, blue, hue, saturation, brightness }

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog();

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late final TextEditingController _hexController;
  late final TextEditingController _redController;
  late final TextEditingController _greenController;
  late final TextEditingController _blueController;
  late final TextEditingController _hueController;
  late final TextEditingController _saturationController;
  late final TextEditingController _brightnessController;
  HSVColor _hsvColor = HSVColor.fromColor(const Color(0xFF256AF4));
  String? _hexError;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(text: _hexCode);
    _redController = TextEditingController(text: _red.toString());
    _greenController = TextEditingController(text: _green.toString());
    _blueController = TextEditingController(text: _blue.toString());
    _hueController = TextEditingController(text: _hue.toString());
    _saturationController = TextEditingController(text: _saturation.toString());
    _brightnessController = TextEditingController(text: _brightness.toString());
  }

  @override
  void dispose() {
    _hexController.dispose();
    _redController.dispose();
    _greenController.dispose();
    _blueController.dispose();
    _hueController.dispose();
    _saturationController.dispose();
    _brightnessController.dispose();
    super.dispose();
  }

  Color get _color => _hsvColor.toColor();
  int get _red => _colorChannel(_color.r);
  int get _green => _colorChannel(_color.g);
  int get _blue => _colorChannel(_color.b);
  int get _hue => _hsvColor.hue.round();
  int get _saturation => (_hsvColor.saturation * 100).round();
  int get _brightness => (_hsvColor.value * 100).round();
  String get _hexCode => _toHex(_red, _green, _blue);

  static String _toHex(int red, int green, int blue) {
    return '#${red.toRadixString(16).padLeft(2, '0')}'
            '${green.toRadixString(16).padLeft(2, '0')}'
            '${blue.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  static int _colorChannel(double value) {
    return (value * 255).round().clamp(0, 255).toInt();
  }

  void _setHexText(String value) {
    _setControllerText(_hexController, value);
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _syncTextFields() {
    _setHexText(_hexCode);
    _setControllerText(_redController, _red.toString());
    _setControllerText(_greenController, _green.toString());
    _setControllerText(_blueController, _blue.toString());
    _setControllerText(_hueController, _hue.toString());
    _setControllerText(_saturationController, _saturation.toString());
    _setControllerText(_brightnessController, _brightness.toString());
  }

  void _setColor(Color color) {
    setState(() {
      _hsvColor = HSVColor.fromColor(color);
      _hexError = null;
      _syncTextFields();
    });
  }

  void _setHsv({double? hue, double? saturation, double? brightness}) {
    setState(() {
      _hsvColor = _hsvColor.withHue((hue ?? _hsvColor.hue).clamp(0, 360));
      _hsvColor = _hsvColor.withSaturation(
        (saturation ?? _hsvColor.saturation).clamp(0, 1),
      );
      _hsvColor = _hsvColor.withValue(
        (brightness ?? _hsvColor.value).clamp(0, 1),
      );
      _hexError = null;
      _syncTextFields();
    });
  }

  void _handleHexChanged(String value) {
    final parsed = _parseHex(value);
    setState(() {
      if (parsed == null) {
        _hexError = 'Use RGB hex, e.g. #256AF4';
        return;
      }
      _hsvColor = HSVColor.fromColor(
        Color.fromARGB(255, parsed.$1, parsed.$2, parsed.$3),
      );
      _hexError = null;
      _syncTextFields();
    });
  }

  void _handleComponentChanged(_ColorComponent component, String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      return;
    }
    switch (component) {
      case _ColorComponent.red:
      case _ColorComponent.green:
      case _ColorComponent.blue:
        final red = component == _ColorComponent.red
            ? parsed.clamp(0, 255)
            : _red;
        final green = component == _ColorComponent.green
            ? parsed.clamp(0, 255)
            : _green;
        final blue = component == _ColorComponent.blue
            ? parsed.clamp(0, 255)
            : _blue;
        _setColor(Color.fromARGB(255, red, green, blue));
      case _ColorComponent.hue:
        _setHsv(hue: parsed.clamp(0, 360).toDouble());
      case _ColorComponent.saturation:
        _setHsv(saturation: parsed.clamp(0, 100) / 100);
      case _ColorComponent.brightness:
        _setHsv(brightness: parsed.clamp(0, 100) / 100);
    }
  }

  (int, int, int)? _parseHex(String value) {
    var hex = value.trim();
    if (hex.startsWith('#')) {
      hex = hex.substring(1);
    }
    if (RegExp(r'^[0-9a-fA-F]{3}$').hasMatch(hex)) {
      hex = hex.split('').map((character) => '$character$character').join();
    }
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
      return null;
    }
    return (
      int.parse(hex.substring(0, 2), radix: 16),
      int.parse(hex.substring(2, 4), radix: 16),
      int.parse(hex.substring(4, 6), radix: 16),
    );
  }

  Future<void> _copyHex() async {
    await Clipboard.setData(ClipboardData(text: _hexCode));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Hex code copied')));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom - 32;
    final dialogMaxHeight = availableHeight > 620 ? 620.0 : availableHeight;
    const panel = Colors.white;
    const text = Color(0xFF0F172A);
    const softSurface = Color(0xFFF8FAFC);
    const border = Color(0xFFE2E8F0);
    const accent = Color(0xFF256AF4);

    return Dialog(
      alignment: media.viewInsets.bottom > 0
          ? Alignment.topCenter
          : Alignment.center,
      backgroundColor: panel,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 360,
          maxHeight: dialogMaxHeight < 360 ? 360 : dialogMaxHeight,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.palette_outlined, color: accent, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Color Selector',
                    style: TextStyle(
                      color: text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 178,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SaturationValuePicker(
                        hsvColor: _hsvColor,
                        onChanged: (saturation, brightness) => _setHsv(
                          saturation: saturation,
                          brightness: brightness,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 34,
                      child: _HuePicker(
                        hue: _hsvColor.hue,
                        onChanged: (hue) => _setHsv(hue: hue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      decoration: InputDecoration(
                        errorText: _hexError,
                        filled: true,
                        fillColor: softSurface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: accent, width: 2),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9a-fA-F#]'),
                        ),
                      ],
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: _handleHexChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFEAF1FF),
                        foregroundColor: accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      tooltip: 'Copy hex code',
                      onPressed: _copyHex,
                      icon: const Icon(Icons.copy, size: 24),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _ColorValueField(
                          label: 'R:',
                          controller: _redController,
                          onChanged: (value) => _handleComponentChanged(
                            _ColorComponent.red,
                            value,
                          ),
                        ),
                        _ColorValueField(
                          label: 'G:',
                          controller: _greenController,
                          onChanged: (value) => _handleComponentChanged(
                            _ColorComponent.green,
                            value,
                          ),
                        ),
                        _ColorValueField(
                          label: 'B:',
                          controller: _blueController,
                          onChanged: (value) => _handleComponentChanged(
                            _ColorComponent.blue,
                            value,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 26),
                  Expanded(
                    child: Column(
                      children: [
                        _ColorValueField(
                          label: 'H:',
                          controller: _hueController,
                          maxLength: 3,
                          onChanged: (value) => _handleComponentChanged(
                            _ColorComponent.hue,
                            value,
                          ),
                        ),
                        _ColorValueField(
                          label: 'S:',
                          controller: _saturationController,
                          maxLength: 3,
                          onChanged: (value) => _handleComponentChanged(
                            _ColorComponent.saturation,
                            value,
                          ),
                        ),
                        _ColorValueField(
                          label: 'B:',
                          controller: _brightnessController,
                          maxLength: 3,
                          onChanged: (value) => _handleComponentChanged(
                            _ColorComponent.brightness,
                            value,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 10,
                overflowSpacing: 8,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaturationValuePicker extends StatelessWidget {
  const _SaturationValuePicker({
    required this.hsvColor,
    required this.onChanged,
  });

  final HSVColor hsvColor;
  final void Function(double saturation, double brightness) onChanged;

  void _handlePosition(Offset localPosition, Size size) {
    final saturation = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final brightness = (1 - localPosition.dy / size.height).clamp(0.0, 1.0);
    onChanged(saturation, brightness);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanDown: (details) => _handlePosition(details.localPosition, size),
          onPanUpdate: (details) =>
              _handlePosition(details.localPosition, size),
          child: CustomPaint(
            painter: _SaturationValuePainter(hsvColor: hsvColor),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _SaturationValuePainter extends CustomPainter {
  const _SaturationValuePainter({required this.hsvColor});

  final HSVColor hsvColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, hsvColor.hue, 1, 1).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
    final indicator = Offset(
      hsvColor.saturation * size.width,
      (1 - hsvColor.value) * size.height,
    );
    canvas.drawCircle(indicator, 6, Paint()..color = Colors.white);
    canvas.drawCircle(
      indicator,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.black54,
    );
  }

  @override
  bool shouldRepaint(_SaturationValuePainter oldDelegate) {
    return oldDelegate.hsvColor != hsvColor;
  }
}

class _HuePicker extends StatelessWidget {
  const _HuePicker({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  void _handlePosition(Offset localPosition, Size size) {
    onChanged((localPosition.dy / size.height * 360).clamp(0.0, 360.0));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanDown: (details) => _handlePosition(details.localPosition, size),
          onPanUpdate: (details) =>
              _handlePosition(details.localPosition, size),
          child: CustomPaint(
            painter: _HuePainter(hue: hue),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _HuePainter extends CustomPainter {
  const _HuePainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const colors = [
      Color(0xFFFF0000),
      Color(0xFFFFFF00),
      Color(0xFF00FF00),
      Color(0xFF00FFFF),
      Color(0xFF0000FF),
      Color(0xFFFF00FF),
      Color(0xFFFF0000),
    ];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(rect),
    );
    final y = (hue / 360 * size.height).clamp(0.0, size.height);
    final marker = Rect.fromLTWH(0, y - 3, size.width, 6);
    canvas.drawRect(marker, Paint()..color = Colors.white);
    canvas.drawRect(
      marker,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black45,
    );
  }

  @override
  bool shouldRepaint(_HuePainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}

class _ColorValueField extends StatelessWidget {
  const _ColorValueField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.maxLength = 3,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                contentPadding: const EdgeInsets.only(bottom: 5),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF256AF4), width: 2),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(maxLength),
              ],
              keyboardType: TextInputType.number,
              maxLength: maxLength,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

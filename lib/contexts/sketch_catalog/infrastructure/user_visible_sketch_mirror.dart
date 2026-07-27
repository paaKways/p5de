import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

abstract class UserVisibleSketchMirror {
  Future<void> syncFrom(Directory sourceDirectory);
}

/// Keeps routine saves from waiting for the comparatively slow user-visible
/// directory copy.
///
/// Only one copy runs at a time. Requests received during a copy are collapsed
/// into a single follow-up copy from the most recently requested source.
class CoalescingUserVisibleSketchMirror implements UserVisibleSketchMirror {
  CoalescingUserVisibleSketchMirror(this._delegate);

  final UserVisibleSketchMirror _delegate;

  Future<void>? _activeSync;
  Directory? _pendingSource;

  @override
  Future<void> syncFrom(Directory sourceDirectory) {
    _pendingSource = sourceDirectory;
    _startDrain();
    return Future<void>.value();
  }

  void _startDrain() {
    if (_activeSync != null) {
      return;
    }

    final sync = Future<void>.microtask(_drain);
    _activeSync = sync;
    unawaited(sync);
  }

  Future<void> _drain() async {
    try {
      while (_pendingSource != null) {
        final sourceDirectory = _pendingSource!;
        _pendingSource = null;
        try {
          await _delegate.syncFrom(sourceDirectory);
        } catch (_) {
          // Mirroring is a convenience copy. The repository source is already
          // durable, so a mirror failure must not fail or delay an editor save.
        }
      }
    } finally {
      _activeSync = null;
      if (_pendingSource != null) {
        _startDrain();
      }
    }
  }
}

class MethodChannelUserVisibleSketchMirror implements UserVisibleSketchMirror {
  const MethodChannelUserVisibleSketchMirror();

  static const MethodChannel _channel = MethodChannel(
    'ai.suacode.ide/user_visible_sketches',
  );

  @override
  Future<void> syncFrom(Directory sourceDirectory) async {
    await _channel.invokeMethod<void>('syncSketchesDirectory', {
      'sourcePath': sourceDirectory.path,
    });
  }
}

import 'dart:io';

import 'package:flutter/services.dart';

abstract class UserVisibleSketchMirror {
  Future<void> syncFrom(Directory sourceDirectory);
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

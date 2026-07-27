import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/contexts/sketch_catalog/infrastructure/user_visible_sketch_mirror.dart';

void main() {
  test('returns before the delegate finishes', () async {
    final delegate = _ControlledSketchMirror();
    final mirror = CoalescingUserVisibleSketchMirror(delegate);

    await mirror.syncFrom(Directory('first'));
    await delegate.waitForCallCount(1);

    expect(delegate.calls.single.path, 'first');
    expect(delegate.pendingCalls, hasLength(1));

    delegate.completeNext();
  });

  test('coalesces requests made while a sync is running', () async {
    final delegate = _ControlledSketchMirror();
    final mirror = CoalescingUserVisibleSketchMirror(delegate);

    await mirror.syncFrom(Directory('first'));
    await delegate.waitForCallCount(1);

    await mirror.syncFrom(Directory('second'));
    await mirror.syncFrom(Directory('latest'));

    expect(delegate.calls, hasLength(1));

    delegate.completeNext();
    await delegate.waitForCallCount(2);

    expect(delegate.calls.map((directory) => directory.path), [
      'first',
      'latest',
    ]);

    delegate.completeNext();
    await Future<void>.delayed(Duration.zero);
    expect(delegate.calls, hasLength(2));
  });

  test('a failed background sync does not prevent the next sync', () async {
    final delegate = _ControlledSketchMirror();
    final mirror = CoalescingUserVisibleSketchMirror(delegate);

    await mirror.syncFrom(Directory('first'));
    await delegate.waitForCallCount(1);
    await mirror.syncFrom(Directory('second'));

    delegate.failNext();
    await delegate.waitForCallCount(2);

    expect(delegate.calls.last.path, 'second');
    delegate.completeNext();
  });
}

class _ControlledSketchMirror implements UserVisibleSketchMirror {
  final calls = <Directory>[];
  final pendingCalls = <Completer<void>>[];
  final _callCountWaiters = <int, Completer<void>>{};

  @override
  Future<void> syncFrom(Directory sourceDirectory) {
    calls.add(sourceDirectory);
    final call = Completer<void>();
    pendingCalls.add(call);
    _callCountWaiters.remove(calls.length)?.complete();
    return call.future;
  }

  Future<void> waitForCallCount(int count) {
    if (calls.length >= count) {
      return Future<void>.value();
    }
    return (_callCountWaiters[count] ??= Completer<void>()).future;
  }

  void completeNext() {
    pendingCalls.removeAt(0).complete();
  }

  void failNext() {
    pendingCalls.removeAt(0).completeError(StateError('mirror failed'));
  }
}

import 'package:flutter/foundation.dart';

abstract class AppTelemetry {
  const AppTelemetry();

  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  });

  Future<void> setCurrentScreen(String screenName);

  Future<void> setCustomKey(String key, Object? value);

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, Object?> parameters = const {},
  });

  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  });
}

class NoopAppTelemetry extends AppTelemetry {
  const NoopAppTelemetry();

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async {}

  @override
  Future<void> setCurrentScreen(String screenName) async {}

  @override
  Future<void> setCustomKey(String key, Object? value) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, Object?> parameters = const {},
  }) async {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      'Noop telemetry error'
      '${reason == null ? '' : ' ($reason)'}'
      '${fatal ? ' [fatal]' : ''}: $error',
    );
    if (parameters.isNotEmpty) {
      debugPrint('Noop telemetry parameters: $parameters');
    }
    debugPrintStack(stackTrace: stackTrace);
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      'Noop telemetry Flutter error'
      '${details.context == null ? '' : ' (${details.context})'}'
      '${fatal ? ' [fatal]' : ''}: ${details.exception}',
    );
    debugPrintStack(stackTrace: details.stack);
  }
}

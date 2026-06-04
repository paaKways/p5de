import 'dart:math' as math;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:p5de/app/telemetry/app_telemetry.dart';

const bool _crashlyticsCollectionEnabled = bool.fromEnvironment(
  'P5DE_CRASHLYTICS_ENABLED',
  defaultValue: kReleaseMode,
);

class FirebaseAppTelemetry extends AppTelemetry {
  FirebaseAppTelemetry._({
    required FirebaseAnalytics analytics,
    required FirebaseCrashlytics? crashlytics,
  }) : _analytics = analytics,
       _crashlytics = crashlytics;

  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics? _crashlytics;

  static Future<AppTelemetry> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final crashlytics = kIsWeb ? null : FirebaseCrashlytics.instance;
      if (crashlytics != null) {
        await crashlytics.setCrashlyticsCollectionEnabled(
          _crashlyticsCollectionEnabled,
        );
        await crashlytics.setCustomKey('app_runtime', 'flutter');
        await crashlytics.setCustomKey(
          'crashlytics_collection_enabled',
          _crashlyticsCollectionEnabled,
        );
      }

      return FirebaseAppTelemetry._(
        analytics: FirebaseAnalytics.instance,
        crashlytics: crashlytics,
      );
    } catch (error) {
      debugPrint('Firebase telemetry disabled: $error');
      return const NoopAppTelemetry();
    }
  }

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  }) async {
    try {
      await _analytics.logEvent(
        name: _safeAnalyticsName(name),
        parameters: _safeParameters(parameters),
      );
      await _crashlytics?.log('event:${_safeAnalyticsName(name)}');
    } catch (error) {
      debugPrint('Telemetry event dropped: $name ($error)');
    }
  }

  @override
  Future<void> setCurrentScreen(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
      await setCustomKey('current_screen', screenName);
    } catch (error) {
      debugPrint('Telemetry screen dropped: $screenName ($error)');
    }
  }

  @override
  Future<void> setCustomKey(String key, Object? value) async {
    final crashlytics = _crashlytics;
    if (crashlytics == null) {
      return;
    }

    try {
      await crashlytics.setCustomKey(_safeCrashlyticsKey(key), value ?? '');
    } catch (error) {
      debugPrint('Crashlytics key dropped: $key ($error)');
    }
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, Object?> parameters = const {},
  }) async {
    final crashlytics = _crashlytics;
    if (crashlytics == null) {
      return;
    }

    try {
      for (final entry in _safeParameters(parameters).entries) {
        await crashlytics.setCustomKey(entry.key, entry.value);
      }
      await crashlytics.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
    } catch (recordingError) {
      debugPrint('Crashlytics error dropped: $recordingError');
    }
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    final crashlytics = _crashlytics;
    if (crashlytics == null) {
      return;
    }

    try {
      if (fatal) {
        await crashlytics.recordFlutterFatalError(details);
      } else {
        await crashlytics.recordFlutterError(details);
      }
    } catch (error) {
      debugPrint('Flutter Crashlytics error dropped: $error');
    }
  }
}

Map<String, Object> _safeParameters(Map<String, Object?> parameters) {
  final output = <String, Object>{};
  for (final entry in parameters.entries) {
    final value = entry.value;
    if (value == null) {
      continue;
    }

    output[_safeCrashlyticsKey(entry.key)] = switch (value) {
      String() => value.length > 100 ? value.substring(0, 100) : value,
      int() => value,
      double() => value,
      bool() => value ? 1 : 0,
      _ => value.toString(),
    };
  }
  return output;
}

String _safeAnalyticsName(String raw) {
  final normalized = _safeName(raw);
  final withPrefix = RegExp(r'^[a-zA-Z]').hasMatch(normalized)
      ? normalized
      : 'event_$normalized';
  return withPrefix.substring(0, math.min(40, withPrefix.length));
}

String _safeCrashlyticsKey(String raw) {
  final normalized = _safeName(raw);
  return normalized.substring(0, math.min(40, normalized.length));
}

String _safeName(String raw) {
  final normalized = raw
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  return normalized.isEmpty ? 'unknown' : normalized;
}

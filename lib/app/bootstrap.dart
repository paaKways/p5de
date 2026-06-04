import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:p5de/app/app.dart';
import 'package:p5de/app/di/app_dependencies.dart';
import 'package:p5de/app/telemetry/app_telemetry.dart';
import 'package:p5de/app/telemetry/firebase_app_telemetry.dart';

Future<void> bootstrap() {
  AppTelemetry telemetry = const NoopAppTelemetry();
  final bootstrapFuture = runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      telemetry = await FirebaseAppTelemetry.initialize();
      _installErrorReporting(telemetry);

      await telemetry.logEvent(
        'app_open',
        parameters: {'debug_mode': kDebugMode, 'release_mode': kReleaseMode},
      );

      final dependencies = await AppDependencies.bootstrap(
        telemetry: telemetry,
      );
      runApp(P5deApp(dependencies: dependencies));
    },
    (error, stackTrace) {
      unawaited(
        telemetry.recordError(
          error,
          stackTrace,
          fatal: true,
          reason: 'run_zoned_guarded',
        ),
      );
    },
  );
  return bootstrapFuture ?? Future<void>.value();
}

void _installErrorReporting(AppTelemetry telemetry) {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(telemetry.recordFlutterError(details));
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      telemetry.recordError(
        error,
        stackTrace,
        fatal: true,
        reason: 'platform_dispatcher',
      ),
    );
    return true;
  };
}

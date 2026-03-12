import 'package:flutter/widgets.dart';
import 'package:p5de/app/app.dart';
import 'package:p5de/app/di/app_dependencies.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dependencies = AppDependencies.bootstrap();
  runApp(P5deApp(dependencies: dependencies));
}

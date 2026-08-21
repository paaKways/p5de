import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/app/app.dart';
import 'package:p5de/app/di/app_dependencies.dart';
import 'package:p5de/app/di/sketch_storage_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('ai.suacode.ide/saf_directory');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('asks the user to approve access to the prepared folder', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getDirectory');
          return null;
        });

    await tester.pumpWidget(
      P5deApp(
        dependencies: AppDependencies.forStorageBackend(
          storageBackend: SketchStorageBackend.saf,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    expect(find.text('Allow folder access'), findsOneWidget);
    expect(
      find.textContaining('Approve access to the SuaCode IDE sketch folder'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Approve folder access'),
      findsOneWidget,
    );
  });
}

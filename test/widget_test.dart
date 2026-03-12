import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/app/app.dart';
import 'package:p5de/app/di/app_dependencies.dart';

void main() {
  testWidgets('renders milestone 0 bootstrap message', (tester) async {
    await tester.pumpWidget(P5deApp(dependencies: AppDependencies.bootstrap()));

    expect(find.text('Milestone 0 foundation ready'), findsOneWidget);
  });
}

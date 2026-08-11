import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/app/splash_screen.dart';

void main() {
  testWidgets('renders the SuaCode splash brand', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SuaCodeSplashScreen()));

    expect(find.text('SuaCode IDE'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
      (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName,
      SuaCodeSplashScreen.logoAsset,
    );
    expect(
      SuaCodeSplashScreen.logoAsset,
      'assets/images/suacode-ide-logo.png',
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFFF7FBF6),
    );
  });

  testWidgets('transitions from splash to app content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppSplashGate(
          duration: Duration(milliseconds: 10),
          child: Text('Catalog ready'),
        ),
      ),
    );

    expect(find.text('SuaCode IDE'), findsOneWidget);
    expect(find.text('Catalog ready'), findsNothing);

    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Catalog ready'), findsOneWidget);
  });
}

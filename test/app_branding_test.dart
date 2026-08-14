import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/widgets/app_logo.dart';

void main() {
  testWidgets('shows the branded app logo in the app UI', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppLogo(size: 80),
          ),
        ),
      ),
    );

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Spendly'), findsOneWidget);
  });
}

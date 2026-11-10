// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:kiraz_frontend/main.dart';
import 'package:kiraz_frontend/screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('KirazApp initializes and renders SplashScreen smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'isFirstLaunch': false});

    await tester.pumpWidget(const KirazApp());

    // Verify SplashScreen is rendered
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('kiraZ'), findsOneWidget);

    // Let the splash timer finish and transition occur
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump();
  });
}

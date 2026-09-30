import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:horizon_app/main.dart';
import 'package:horizon_app/services/pocketbase_service.dart';

void main() {
  testWidgets('App starts with login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await PocketBaseService().init();

    await tester.pumpWidget(const HorizonApp());

    expect(find.text('Horizon'), findsOneWidget);
    expect(find.text('Rocketry Team Portal'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}

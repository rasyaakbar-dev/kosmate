import 'package:flutter_test/flutter_test.dart';
import 'package:kosmate/core/di/service_locator.dart';
import 'package:kosmate/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
    );
    ServiceLocator.instance.setup();
  });

  testWidgets('app displays the splash screen', (tester) async {
    await tester.pumpWidget(const KosMateApp());

    expect(find.text('KosMate'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  });
}

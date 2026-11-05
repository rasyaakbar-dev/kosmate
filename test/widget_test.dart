import 'package:flutter_test/flutter_test.dart';
import 'package:kosmate/main.dart';

void main() {
  testWidgets('KosMate app loads smoke test', (WidgetTester tester) async {
    // Tests that KosMateApp can be instantiated
    expect(const KosMateApp(), isNotNull);
  });
}

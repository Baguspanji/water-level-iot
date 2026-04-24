import 'package:flutter_test/flutter_test.dart';

import 'package:alert_water_level/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // App should render the home page (waiting state initially)
    expect(find.text('Menunggu data sensor…'), findsOneWidget);
  });
}

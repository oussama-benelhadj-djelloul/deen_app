import 'package:flutter_test/flutter_test.dart';

import 'package:deen_app/main.dart';
import 'package:deen_app/onboarding_screen.dart';

void main() {
  testWidgets('app launches on onboarding', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}

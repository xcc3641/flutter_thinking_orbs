import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';
import 'package:flutter_thinking_orbs/flutter_thinking_orbs.dart';

void main() {
  testWidgets('ThinkingOrbsExampleApp mounts and displays orbs and labels', (
    tester,
  ) async {
    await tester.pumpWidget(const ThinkingOrbsExampleApp());

    expect(find.text('ThinkingOrbs'), findsOneWidget);
    expect(find.byType(ThinkingOrb), findsWidgets);
    expect(find.byType(ThinkingOrbLabel), findsWidgets);
    expect(find.text('Searching the web…'), findsWidgets);
  });
}

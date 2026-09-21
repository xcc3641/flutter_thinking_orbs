import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';
import 'package:flutter_thinking_orbs/flutter_thinking_orbs.dart';

void main() {
  testWidgets('ThinkingOrbsExampleApp mounts and displays orbs and labels', (
    tester,
  ) async {
    await tester.pumpWidget(const ThinkingOrbsExampleApp());
    await tester.pump();

    expect(find.text('ThinkingOrbs'), findsOneWidget);
    expect(find.byType(ThinkingOrb), findsWidgets);
    expect(find.byType(TabBar), findsOneWidget);

    // Switch language to English
    final langButton = find.text('EN');
    expect(langButton, findsOneWidget);
    await tester.tap(langButton);
    await tester.pump();

    expect(find.text('All Designs'), findsOneWidget);
    expect(find.text('AI Scenarios'), findsOneWidget);
    expect(find.text('Playground'), findsOneWidget);

    // Switch to Scenarios tab and wait for tab transition
    await tester.tap(find.text('AI Scenarios'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ThinkingOrbLabel), findsWidgets);

    // Switch to Playground tab and wait for tab transition
    await tester.tap(find.text('Playground'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ThinkingOrb), findsWidgets);
    expect(find.text('Select Design'), findsOneWidget);
    expect(find.text('Tuned Base Size'), findsOneWidget);
  });
}

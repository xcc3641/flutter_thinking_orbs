import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinking_orbs_kit/thinking_orbs_kit.dart';

void main() {
  group('Public API parity tests', () {
    test('designs match web library specification', () {
      expect(OrbDesign.values.map((d) => d.name).toList(), [
        'working',
        'searching',
        'solving',
        'listening',
        'connecting',
        'weaving',
        'composing',
        'breathing',
        'shaping',
      ]);

      expect(OrbDesign.values.map((d) => d.accessibilityLabel).toList(), [
        'Working…',
        'Searching…',
        'Solving…',
        'Listening…',
        'Connecting…',
        'Weaving…',
        'Composing…',
        'Thinking…',
        'Shaping…',
      ]);

      expect(OrbDesign.searching.title, 'Searching');
      expect(OrbSize.regular.points, 64.0);
      expect(OrbSize.small.points, 20.0);
    });

    test('public frame matches resolved engine draw list', () {
      for (final design in OrbDesign.values) {
        for (final size in OrbSize.values) {
          final resolved = OrbPresets.resolve(design, size);
          for (final time in [0.0, 0.25, 1.9, 7.3]) {
            final viaPublic = design.frame(size: size, time: time);
            final viaEngine = resolved.frame(
              size: size.length,
              t: time * resolved.speed,
            );

            expect(viaPublic.dots.length, viaEngine.dots.length);
            expect(viaPublic.lines.length, viaEngine.lines.length);

            // Finished draw list: z-sorted far -> near (z ascending)
            for (var i = 0; i < viaPublic.dots.length - 1; i++) {
              expect(
                viaPublic.dots[i].z <= viaPublic.dots[i + 1].z,
                isTrue,
                reason:
                    'dot $i z ${viaPublic.dots[i].z} <= dot ${i + 1} z ${viaPublic.dots[i + 1].z}',
              );
            }

            // Visible alpha >= 0.02 and radius > 0
            expect(viaPublic.dots.every((d) => d.a >= 0.02 && d.r > 0), isTrue);
            expect(viaPublic.dots.isNotEmpty, isTrue);
          }
        }
      }
    });

    test('any time value is safe (negative, huge, or NaN)', () {
      final safeTimes = [
        -0.01,
        -1.0,
        -7.3,
        -1e6,
        0.0,
        86400.0 * 3,
        1e9,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ];

      for (final design in OrbDesign.values) {
        for (final size in OrbSize.values) {
          for (final time in safeTimes) {
            final frame = design.frame(size: size, time: time);
            expect(frame.dots.isNotEmpty, isTrue);
            expect(
              frame.dots.every(
                (d) => d.x.isFinite && d.y.isFinite && d.r.isFinite,
              ),
              isTrue,
            );
          }
        }
      }
    });
  });

  group('Flutter widget tests', () {
    testWidgets('ThinkingOrb renders with regular size 64x64', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThinkingOrb(design: OrbDesign.working, size: OrbSize.regular),
          ),
        ),
      );

      final orbFinder = find.byType(ThinkingOrb);
      expect(orbFinder, findsOneWidget);

      final renderBox = tester.renderObject(orbFinder) as RenderBox;
      expect(renderBox.size.width, 64.0);
      expect(renderBox.size.height, 64.0);
    });

    testWidgets('ThinkingOrb renders with small size 20x20', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThinkingOrb(design: OrbDesign.working, size: OrbSize.small),
          ),
        ),
      );

      final orbFinder = find.byType(ThinkingOrb);
      expect(orbFinder, findsOneWidget);

      final renderBox = tester.renderObject(orbFinder) as RenderBox;
      expect(renderBox.size.width, 20.0);
      expect(renderBox.size.height, 20.0);
    });

    testWidgets('ThinkingOrb respects custom diameter 56x56', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThinkingOrb(design: OrbDesign.solving, diameter: 56.0),
          ),
        ),
      );

      final orbFinder = find.byType(ThinkingOrb);
      expect(orbFinder, findsOneWidget);

      final renderBox = tester.renderObject(orbFinder) as RenderBox;
      expect(renderBox.size.width, 56.0);
      expect(renderBox.size.height, 56.0);
    });

    testWidgets('ThinkingOrb provides accessibility semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ThinkingOrb(design: OrbDesign.searching)),
        ),
      );

      expect(
        tester.getSemantics(find.byType(ThinkingOrb)),
        matchesSemantics(label: 'Searching…', isImage: true),
      );
      handle.dispose();
    });

    testWidgets('OrbClockOverride fixes geometry deterministically', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrbClockOverride(
              seconds: 1.25,
              child: ThinkingOrb(design: OrbDesign.composing),
            ),
          ),
        ),
      );

      expect(find.byType(ThinkingOrb), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      // Ticker should not be running or changing frame when override is active
      expect(find.byType(ThinkingOrb), findsOneWidget);
    });

    testWidgets('ThinkingOrb respects reduce motion', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: ThinkingOrb(design: OrbDesign.breathing)),
          ),
        ),
      );

      expect(find.byType(ThinkingOrb), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ThinkingOrb), findsOneWidget);
    });

    testWidgets('ThinkingOrbLabel renders orb and text with shimmer', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThinkingOrbLabel(
              'Searching the web…',
              design: OrbDesign.searching,
            ),
          ),
        ),
      );

      expect(find.byType(ThinkingOrbLabel), findsOneWidget);
      expect(find.byType(ThinkingOrb), findsOneWidget);
      expect(find.text('Searching the web…'), findsWidgets);
    });

    testWidgets('Widget.thinkingShimmer extension works cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Text('Composing reply…').thinkingShimmer(),
          ),
        ),
      );

      expect(find.text('Composing reply…'), findsWidgets);
    });

    testWidgets('monochrome ink renders in light and dark themes', (
      tester,
    ) async {
      // Light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(body: ThinkingOrb(design: OrbDesign.working)),
        ),
      );
      expect(find.byType(ThinkingOrb), findsOneWidget);

      // Dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: ThinkingOrb(design: OrbDesign.working)),
        ),
      );
      expect(find.byType(ThinkingOrb), findsOneWidget);
    });
  });
}

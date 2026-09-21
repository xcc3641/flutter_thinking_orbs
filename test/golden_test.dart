import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thinking_orb/thinking_orb.dart';

class GoldenResolved {
  GoldenResolved({required this.mode, required this.speed, required this.opts});

  factory GoldenResolved.fromJson(Map<String, dynamic> json) {
    return GoldenResolved(
      mode: json['mode'] as String,
      speed: (json['speed'] as num).toDouble(),
      opts: (json['opts'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
    );
  }

  final String mode;
  final double speed;
  final Map<String, double> opts;
}

class GoldenCase {
  GoldenCase({
    required this.key,
    required this.state,
    required this.size,
    required this.t,
    required this.dotCount,
    required this.lineCount,
    required this.dots,
    required this.lines,
  });

  factory GoldenCase.fromJson(Map<String, dynamic> json) {
    return GoldenCase(
      key: json['key'] as String,
      state: json['state'] as String,
      size: json['size'] as int,
      t: (json['t'] as num).toDouble(),
      dotCount: json['dotCount'] as int,
      lineCount: json['lineCount'] as int,
      dots: (json['dots'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      lines: (json['lines'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  final String key;
  final String state;
  final int size;
  final double t;
  final int dotCount;
  final int lineCount;
  final List<double> dots;
  final List<double> lines;
}

class GoldenData {
  GoldenData({
    required this.tolerance,
    required this.resolved,
    required this.cases,
  });

  factory GoldenData.load() {
    var file = File('test/resources/orbs-golden.json');
    if (!file.existsSync()) {
      file = File('resources/orbs-golden.json');
    }
    final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final tolerance = (raw['tolerance'] as num).toDouble();
    final resolvedMap = (raw['resolved'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, GoldenResolved.fromJson(v as Map<String, dynamic>)),
    );
    final casesList = (raw['cases'] as List<dynamic>)
        .map((e) => GoldenCase.fromJson(e as Map<String, dynamic>))
        .toList();
    return GoldenData(
      tolerance: tolerance,
      resolved: resolvedMap,
      cases: casesList,
    );
  }

  final double tolerance;
  final Map<String, GoldenResolved> resolved;
  final List<GoldenCase> cases;
}

void main() {
  late final GoldenData golden;

  setUpAll(() {
    golden = GoldenData.load();
  });

  test('presetsResolveExactlyLikeTheWeb', () {
    expect(
      golden.resolved.length,
      equals(OrbDesign.values.length * OrbSize.values.length),
    );
    for (final design in OrbDesign.values) {
      for (final size in OrbSize.values) {
        final key = '${design.name}-${size.value}';
        final want = golden.resolved[key];
        expect(want, isNotNull, reason: 'golden has no $key');
        if (want == null) continue;

        final got = OrbPresets.resolve(design, size);
        expect(got.mode.name, equals(want.mode), reason: '$key mode');
        expect(got.speed, equals(want.speed), reason: '$key speed');
        expect(
          got.opts.keys.toSet(),
          equals(want.opts.keys.toSet()),
          reason: '$key option keys',
        );
        for (final entry in want.opts.entries) {
          final gotVal = got.opts[entry.key];
          expect(gotVal, isNotNull, reason: '$key.${entry.key} missing');
          expect(
            (gotVal! - entry.value).abs(),
            lessThan(1e-12),
            reason: '$key.${entry.key}',
          );
        }
      }
    }
  });

  test('geometryMatchesTheWeb', () {
    expect(golden.cases.length, equals(72));

    for (final design in OrbDesign.values) {
      for (final size in OrbSize.values) {
        final cases = golden.cases
            .where((c) => c.state == design.name && c.size == size.value)
            .toList();
        expect(
          cases.length,
          equals(4),
          reason: '${design.name}-${size.value} cases count',
        );

        for (final c in cases) {
          final frame = OrbPresets.resolve(
            design,
            size,
          ).frame(size: size.length, t: c.t);
          expect(
            frame.dots.length,
            equals(c.dotCount),
            reason: '${c.key} dot count',
          );
          expect(
            frame.lines.length,
            equals(c.lineCount),
            reason: '${c.key} line count',
          );
          if (frame.dots.length != c.dotCount ||
              frame.lines.length != c.lineCount) {
            continue;
          }

          final tol = golden.tolerance;
          final want = <List<double>>[];
          for (var i = 0; i < c.dots.length; i += 6) {
            want.add(c.dots.sublist(i, i + 6));
          }
          final got = frame.dots
              .map((d) => [d.x, d.y, d.z, d.r, d.white, d.a])
              .toList();

          bool close(List<double> a, List<double> b) {
            for (var k = 0; k < a.length; k++) {
              if ((a[k] - b[k]).abs() > tol) return false;
            }
            return true;
          }

          final used = List<bool>.filled(want.length, false);
          String? firstMiss;
          for (var i = 0; i < got.length; i++) {
            if (!used[i] && close(got[i], want[i])) {
              used[i] = true;
              continue;
            }
            // not in its own slot: accept only a slot tied with it in depth
            var j = i;
            while (j > 0 && (want[j - 1][2] - got[i][2]).abs() <= tol) {
              j -= 1;
            }
            var matched = false;
            while (j < want.length && want[j][2] <= got[i][2] + tol) {
              if (!used[j] && close(got[i], want[j])) {
                used[j] = true;
                matched = true;
                break;
              }
              j += 1;
            }
            if (!matched && firstMiss == null) {
              firstMiss = 'dot $i: got ${got[i]} want ${want[i]}';
            }
          }
          expect(firstMiss, isNull, reason: '${c.key}: $firstMiss');

          for (var i = 0; i < frame.lines.length; i++) {
            final line = frame.lines[i];
            final values = [
              line.x1,
              line.y1,
              line.x2,
              line.y2,
              line.white,
              line.a,
              line.w,
            ];
            final expected = c.lines.sublist(i * 7, i * 7 + 7);
            expect(close(values, expected), isTrue, reason: '${c.key} line $i');
          }
        }
      }
    }
  });
}

import 'dart:math' as math;

import '../frame.dart';
import 'presets.dart';

/// The geometry behind every orb: pure maths over (size, t, opts).
abstract final class OrbEngine {
  static OrbFrame frame(
    OrbMode mode, {
    required double size,
    required double t,
    required OrbOpts opts,
  }) {
    switch (mode) {
      case OrbMode.orbits:
        return orbits(size, t, opts);
      case OrbMode.globe:
        return globe(size, t, opts);
      case OrbMode.rubik:
        return rubik(size, t, opts);
      case OrbMode.wave:
        return wave(size, t, opts);
      case OrbMode.web:
        return web(size, t, opts);
      case OrbMode.braid:
        return braid(size, t, opts);
      case OrbMode.ribbon:
      case OrbMode.ring:
        return ribbon(size, t, opts);
      case OrbMode.morph:
        return morph(size, t, opts);
    }
  }

  // MARK: - Primitives

  /// JavaScript's `Math.round`: halves go toward +∞.
  static double jsRound(double x) => (x + 0.5).floorToDouble();

  static double frac(double x) => x - x.floorToDouble();

  static double lerp(double a, double b, double f) => a + (b - a) * f;

  /// Deterministic hash in [0, 1).
  static double hashD(double a, double b) {
    final h = math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
    return h - h.floorToDouble();
  }

  /// Value noise on a 2-D lattice: smooth, deterministic, cheap.
  static double vnoise(double x, double y) {
    final xi = x.floorToDouble();
    final yi = y.floorToDouble();
    var fx = x - xi;
    var fy = y - yi;
    fx = fx * fx * (3 - 2 * fx);
    fy = fy * fy * (3 - 2 * fy);
    final a = hashD(xi, yi);
    final b = hashD(xi + 1, yi);
    final c = hashD(xi, yi + 1);
    final d = hashD(xi + 1, yi + 1);
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
  }

  /// Stable directions on a unit sphere (Fibonacci lattice).
  static (double, double, double) fibDir(int i, double n) {
    final golden = math.pi * (3 - math.sqrt(5.0));
    final y = 1 - (2 * (i + 0.5)) / n;
    final rad = math.sqrt(1 - y * y);
    final a = i * golden;
    return (rad * math.cos(a), y, rad * math.sin(a));
  }

  /// Shortest signed angular distance, wrapped to (-π, π].
  static double angleDelta(double a, double b) {
    return math.atan2(math.sin(a - b), math.cos(a - b));
  }

  /// Dot radii were tuned for a 300-pt frame; sub-linear scaling keeps small
  /// spinners legible.
  static double radiusScale(double size, double p) {
    return math.pow(size / 300, p).toDouble();
  }

  /// Drop invisible marks, clamp radii to the mode's floor, and z-sort
  /// far → near (stable, like the web's Array.sort) into draw order.
  static OrbFrame finalize(
    List<OrbDot> dots,
    List<OrbLine> lines, {
    required double rMin,
  }) {
    final visible = <({int index, OrbDot dot})>[];
    for (var i = 0; i < dots.length; i++) {
      final d = dots[i];
      if (d.a >= 0.02) {
        d.r = math.max(rMin, d.r);
        visible.add((index: i, dot: d));
      }
    }
    visible.sort((a, b) {
      if (a.dot.z != b.dot.z) {
        return a.dot.z.compareTo(b.dot.z);
      }
      return a.index.compareTo(b.index);
    });
    final outDots = visible.map((e) => e.dot).toList();
    final outLines = lines.where((l) => l.a >= 0.02).toList();
    return OrbFrame(dots: outDots, lines: outLines);
  }

  static double _count(OrbOpts o, String key, double fallback) {
    return o[key] ?? fallback;
  }

  static int _below(double n) => n > 0 ? n.ceil() : 0;

  static int _through(double n) => n >= 0 ? n.floor() + 1 : 0;

  // MARK: - Orbits — working

  static OrbFrame orbits(double size, double t, OrbOpts o) {
    final cx = size / 2;
    final cy = size / 2;
    final rBound = (size / 2) * 0.82;
    final pt = Projector(yaw: t * 0.12, tilt: 0.3, cx: cx, cy: cy, scale: 1);
    final rs = radiusScale(size, o['rsPow'] ?? 0.6);

    final orbitN = _count(o, 'orbitN', 12);
    final ghostN = _count(o, 'ghostN', 40);
    final particles = _count(o, 'particles', 3);
    final ghostR = o['ghostR'] ?? 0.9;
    final ghostA = o['ghostA'] ?? 0.5;
    final partR = o['partR'] ?? 1.2;
    final partRDepth = o['partRDepth'] ?? 1.6;

    final dots = <OrbDot>[];
    final belowOrbitN = _below(orbitN);
    final belowGhostN = _below(ghostN);
    final belowParticles = _below(particles);

    for (var orb = 0; orb < belowOrbitN; orb++) {
      final forb = orb.toDouble();
      final h1 = hashD(forb, 1.7);
      final h2 = hashD(forb, 5.2);
      final h3 = hashD(forb, 8.9);
      final ro = rBound * (0.45 + 0.52 * h1);
      final th = h1 * 2 * math.pi;
      final phi = math.acos(2 * h2 - 1);
      final nx = math.sin(phi) * math.cos(th);
      final ny = math.cos(phi);
      final nz = math.sin(phi) * math.sin(th);
      var ux = -ny;
      var uy = nx;
      const uz = 0.0;
      final ul = math.max(1e-6, math.sqrt(ux * ux + uy * uy));
      ux /= ul;
      uy /= ul;
      final vx = ny * uz - nz * uy;
      final vy = nz * ux - nx * uz;
      final vz = nx * uy - ny * ux;
      final speed = (0.25 + 0.55 * h3) * (h3 > 0.5 ? 1.0 : -1.0);

      // ghost path
      for (var k = 0; k < belowGhostN; k++) {
        final a = (k / ghostN) * 2 * math.pi;
        final (px, py, z) = pt(
          (ux * math.cos(a) + vx * math.sin(a)) * ro,
          (uy * math.cos(a) + vy * math.sin(a)) * ro,
          (uz * math.cos(a) + vz * math.sin(a)) * ro,
        );
        final depth = (z / ro + 1) / 2;
        dots.add(
          OrbDot(
            x: px,
            y: py,
            z: z,
            r: ghostR * rs,
            white: 0.72,
            a: ghostA * (0.4 + 0.6 * depth),
          ),
        );
      }

      // the particles doing the work
      for (var m = 0; m < belowParticles; m++) {
        final a = t * speed + (m / particles) * 2 * math.pi + h2 * 6;
        final (px, py, z) = pt(
          (ux * math.cos(a) + vx * math.sin(a)) * ro,
          (uy * math.cos(a) + vy * math.sin(a)) * ro,
          (uz * math.cos(a) + vz * math.sin(a)) * ro,
        );
        final depth = (z / ro + 1) / 2;
        dots.add(
          OrbDot(
            x: px,
            y: py,
            z: z,
            r: (partR + partRDepth * depth) * rs,
            white: 0.3 - 0.22 * depth,
          ),
        );
      }
    }
    return finalize(dots, const [], rMin: o['rMin'] ?? 0.3);
  }

  // MARK: - Globe — searching

  static OrbFrame globe(double size, double t, OrbOpts o) {
    const spin = 0.5;
    final cx = size / 2;
    final cy = size / 2;
    final radius = (size / 2) * 0.82;
    final tilt = 0.4 + 0.06 * math.sin(t * 0.35);
    final pt = Projector(
      yaw: t * spin,
      tilt: tilt,
      cx: cx,
      cy: cy,
      scale: radius,
    );
    final scan = t * (spin + (1.7 - spin) * (o['scanMul'] ?? 1.0));
    final rs = radiusScale(size, o['rsPow'] ?? 0.6);
    final dimBase = o['dimBase'] ?? 1.0;
    final rBase = o['rBase'] ?? 0.6;
    final rDepth = o['rDepth'] ?? 1.7;
    final rBoost = o['rBoost'] ?? 1.0;
    final inkFar = o['inkFar'] ?? 0.62;
    final inkSpan = o['inkSpan'] ?? 0.54;

    final dots = <OrbDot>[];
    final latRings = _count(o, 'latRings', 17);
    final lonDensity = o['lonDensity'] ?? 44.0;
    final throughLatRings = _through(latRings);
    for (var li = 0; li < throughLatRings; li++) {
      final lat = -math.pi / 2 + (li / latRings) * math.pi;
      final cosLat = math.cos(lat);
      final sinLat = math.sin(lat);
      final lonCount = math.max(1, jsRound(cosLat.abs() * lonDensity).toInt());
      for (var lj = 0; lj < lonCount; lj++) {
        final lon = (lj / lonCount) * 2 * math.pi;
        final (px, py, z) = pt(
          cosLat * math.cos(lon),
          sinLat,
          cosLat * math.sin(lon),
        );
        final depth = (z + 1) / 2;
        final d = angleDelta(lon + t * spin, scan);
        final boost = math.exp(-(d * d) / 0.18) * math.max(0.0, z);
        dots.add(
          OrbDot(
            x: px,
            y: py,
            z: z,
            r: (rBase + rDepth * depth + rBoost * boost) * rs,
            white: inkFar - inkSpan * depth,
            a: dimBase + (1.0 - dimBase) * math.min(1.0, boost),
          ),
        );
      }
    }
    return finalize(dots, const [], rMin: o['rMin'] ?? 0.3);
  }

  // MARK: - Rubik — solving

  static OrbFrame rubik(double size, double t, OrbOpts o) {
    final cx = size / 2;
    final cy = size / 2;
    final rBound = (size / 2) * 0.82;
    final pt = Projector(
      yaw: t * 0.55,
      tilt: 0.35 + 0.1 * math.sin(t * 0.9),
      cx: cx,
      cy: cy,
      scale: rBound,
    );
    final rs = radiusScale(size, o['rsPow'] ?? 0.6);
    final moveCount = _count(o, 'moveCount', 14).toInt();
    final moves = _makeMoves(moveCount);
    final sc = _solveCycle(t, moveCount, 0.42, 1.2);
    final rBase = o['rBase'] ?? 0.6;
    final rDepth = o['rDepth'] ?? 1.7;
    final rActive = o['rActive'] ?? 0.3;
    final inkFar = o['inkFar'] ?? 0.62;
    final inkSpan = o['inkSpan'] ?? 0.54;

    final dots = <OrbDot>[];
    final latRings = _count(o, 'latRings', 15);
    final lonDensity = o['lonDensity'] ?? 40.0;
    final throughLatRings = _through(latRings);
    for (var li = 0; li < throughLatRings; li++) {
      final lat = -math.pi / 2 + (li / latRings) * math.pi;
      final cosLat = math.cos(lat);
      final sinLat = math.sin(lat);
      final lonCount = math.max(1, jsRound(cosLat.abs() * lonDensity).toInt());
      for (var lj = 0; lj < lonCount; lj++) {
        final lon = (lj / lonCount) * 2 * math.pi;
        final (x, y, z, inActive) = _applyMoves(
          cosLat * math.cos(lon),
          sinLat,
          cosLat * math.sin(lon),
          moves,
          sc.amount,
          sc.active,
        );
        final (px, py, zr) = pt(x, y, z);
        final depth = (zr + 1) / 2;
        dots.add(
          OrbDot(
            x: px,
            y: py,
            z: zr,
            r: (rBase + rDepth * depth + (inActive ? rActive : 0.0)) * rs,
            white: inkFar - inkSpan * depth - (inActive ? 0.14 : 0.0),
          ),
        );
      }
    }
    return finalize(dots, const [], rMin: o['rMin'] ?? 0.3);
  }

  static ({List<double> amount, int active}) _solveCycle(
    double time,
    int count,
    double slotDur,
    double rest,
  ) {
    final cyc = 2 * count * slotDur + rest;
    var tc = time.remainder(cyc);
    if (tc < 0) tc += cyc;
    final amount = List<double>.filled(count, 0.0);
    var active = -1;
    if (tc < 2 * count * slotDur) {
      final slot = (tc / slotDur).floor();
      final p = (tc - slot * slotDur) / slotDur;
      final cl = math.min(1.0, p / 0.7);
      final ep = 1.0 - math.pow(1.0 - cl, 3.0).toDouble();
      if (slot < count) {
        for (var i = 0; i < slot; i++) {
          amount[i] = 1.0;
        }
        amount[slot] = ep;
        active = slot;
      } else {
        final u = 2 * count - 1 - slot;
        for (var i = 0; i < u; i++) {
          amount[i] = 1.0;
        }
        amount[u] = 1.0 - ep;
        active = u;
      }
    }
    return (amount: amount, active: active);
  }

  static List<_Move> _makeMoves(int count) {
    return List.generate(count, (i) {
      final fi = i.toDouble();
      final axis = math.min(2, (hashD(fi, 2.3) * 3).floor());
      final lo =
          -1.0 + 0.5 * math.min(3.0, (hashD(fi, 5.9) * 4).floorToDouble());
      final dir = hashD(fi, 7.7) < 0.5 ? 1.0 : -1.0;
      return _Move(axis: axis, lo: lo, hi: lo + 0.5, ang: (dir * math.pi) / 2);
    });
  }

  static (double, double, double, bool) _applyMoves(
    double px,
    double py,
    double pz,
    List<_Move> moves,
    List<double> amount,
    int active,
  ) {
    var x = px;
    var y = py;
    var z = pz;
    var inActive = false;
    for (var i = 0; i < moves.length; i++) {
      if (amount[i] <= 0) continue;
      final mv = moves[i];
      final coord = mv.axis == 0 ? x : (mv.axis == 1 ? y : z);
      if (coord < mv.lo || coord >= mv.hi) continue;
      if (i == active) inActive = true;
      final a = mv.ang * amount[i];
      final ca = math.cos(a);
      final sa = math.sin(a);
      if (mv.axis == 0) {
        final y2 = y * ca - z * sa;
        z = y * sa + z * ca;
        y = y2;
      } else if (mv.axis == 1) {
        final x2 = x * ca + z * sa;
        z = -x * sa + z * ca;
        x = x2;
      } else {
        final x2 = x * ca - y * sa;
        y = x * sa + y * ca;
        x = x2;
      }
    }
    return (x, y, z, inActive);
  }

  // MARK: - Wave — listening

  static OrbFrame wave(double size, double t, OrbOpts o) {
    final cx = size / 2;
    final cy = size / 2;
    final rBound = (size / 2) * 0.874;
    final pt = Projector(yaw: t * 0.18, tilt: 0.38, cx: cx, cy: cy, scale: 1);
    final rs = radiusScale(size, o['rsPow'] ?? 0.6);
    final rBase = o['rBase'] ?? 0.6;
    final rDepth = o['rDepth'] ?? 1.7;

    final dots = <OrbDot>[];
    final rings = _count(o, 'rings', 15);
    final lonDensity = o['lonDensity'] ?? 40.0;
    final throughRings = _through(rings);
    for (var ri = 0; ri < throughRings; ri++) {
      final fri = ri.toDouble();
      final lat = -math.pi / 2 + (fri / rings) * math.pi;
      final cosLat = math.cos(lat);
      final sinLat = math.sin(lat);
      final w =
          0.62 * math.sin(t * 2.1 - fri * 0.52) +
          0.38 * math.sin(t * 1.27 + fri * 0.83);
      final rr = rBound * (0.88 + 0.105 * w);
      final lonCount = math.max(1, jsRound(cosLat.abs() * lonDensity).toInt());
      for (var lj = 0; lj < lonCount; lj++) {
        final lon = (lj / lonCount) * 2 * math.pi;
        final (px, py, z) = pt(
          cosLat * math.cos(lon) * rr,
          sinLat * rr,
          cosLat * math.sin(lon) * rr,
        );
        final depth = (z / rBound + 1) / 2;
        final crest = math.max(0.0, w);
        dots.add(
          OrbDot(
            x: px,
            y: py,
            z: z,
            r: (rBase + rDepth * depth) * (1 + 0.4 * crest) * rs,
            white: 0.66 - 0.56 * depth - 0.1 * crest,
          ),
        );
      }
    }
    return finalize(dots, const [], rMin: o['rMin'] ?? 0.3);
  }

  // MARK: - Web — connecting

  static OrbFrame web(double size, double t, OrbOpts o) {
    final cx = size / 2;
    final cy = size / 2;
    final rBound = (size / 2) * 0.8 * (o['spread'] ?? 1.0);
    final pt = Projector(
      yaw: t * 0.12,
      tilt: 0.32,
      cx: cx,
      cy: cy,
      scale: rBound,
    );
    final rs = radiusScale(size, o['rsPow'] ?? 0.6);

    final nodeN = _count(o, 'nodeN', 30);
    final thr = o['thr'] ?? 0.72;
    final nodeR = o['nodeR'] ?? 1.4;
    final nodeRDepth = o['nodeRDepth'] ?? 1.8;
    final lineW = o['lineW'] ?? 0.8;

    final nodes = <(double, double, double)>[];
    final belowNodeN = _below(nodeN);
    for (var i = 0; i < belowNodeN; i++) {
      final fi = i.toDouble();
      final d = fibDir(i, nodeN);
      final x = d.$1 + 0.3 * (vnoise(fi * 0.31 + 9, t * 0.24) - 0.5) * 2;
      final y = d.$2 + 0.3 * (vnoise(fi * 0.53 + 27, t * 0.21) - 0.5) * 2;
      final z = d.$3 + 0.3 * (vnoise(fi * 0.77 + 55, t * 0.27) - 0.5) * 2;
      final l = math.sqrt(x * x + y * y + z * z);
      nodes.add((x / l, y / l, z / l));
    }

    final lines = <OrbLine>[];
    final dots = <OrbDot>[];

    for (var i = 0; i < belowNodeN; i++) {
      for (var j = i + 1; j < math.max(i + 1, belowNodeN); j++) {
        final dx = nodes[i].$1 - nodes[j].$1;
        final dy = nodes[i].$2 - nodes[j].$2;
        final dz = nodes[i].$3 - nodes[j].$3;
        final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
        if (dist >= thr) continue;
        final (x1, y1, z1) = pt(nodes[i].$1, nodes[i].$2, nodes[i].$3);
        final (x2, y2, z2) = pt(nodes[j].$1, nodes[j].$2, nodes[j].$3);
        final depth = ((z1 + z2) / 2 + 1) / 2;
        lines.add(
          OrbLine(
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2,
            white: 0.42,
            a: (1 - dist / thr) * (0.3 + 0.55 * depth),
            w: math.max(0.6, lineW * rs),
          ),
        );
      }
    }

    for (var i = 0; i < belowNodeN; i++) {
      final (px, py, z) = pt(nodes[i].$1, nodes[i].$2, nodes[i].$3);
      final depth = (z + 1) / 2;
      final pulse = 1 + 0.25 * math.sin(t * 1.4 + i * 2.7);
      dots.add(
        OrbDot(
          x: px,
          y: py,
          z: z,
          r: (nodeR + nodeRDepth * depth) * pulse * rs,
          white: 0.55 - 0.45 * depth,
        ),
      );
    }

    final signals = _count(o, 'signals', 5);
    final belowSignals = _below(signals);
    for (var s = 0; s < belowSignals; s++) {
      final fs = s.toDouble();
      final seg = (t * 0.55 + fs * 7.31).floorToDouble();
      final a = (hashD(seg, fs * 3.1 + 1.7) * nodeN).floor();
      final b = (hashD(seg, fs * 5.7 + 4.2) * nodeN).floor();
      if (a == b) continue;
      final f = frac(t * 0.55 + fs * 7.31);
      final x = lerp(nodes[a].$1, nodes[b].$1, f);
      final y = lerp(nodes[a].$2, nodes[b].$2, f);
      final z = lerp(nodes[a].$3, nodes[b].$3, f);
      final l = math.max(1e-6, math.sqrt(x * x + y * y + z * z));
      final (px, py, zr) = pt(x / l, y / l, z / l);
      final depth = (zr + 1) / 2;
      dots.add(
        OrbDot(
          x: px,
          y: py,
          z: zr,
          r: (nodeR * 1.5 + nodeRDepth * depth) * rs,
          white: 0.05,
          a: 0.5 + 0.5 * depth,
        ),
      );
    }

    return finalize(dots, lines, rMin: o['rMin'] ?? 0.3);
  }

  // MARK: - Braid — weaving

  static OrbFrame braid(double size, double t, OrbOpts o) {
    final cx = size / 2;
    final cy = size / 2;
    final rBound = (size / 2) * 0.76;
    final pt = Projector(yaw: t * 0.4, tilt: 0.3, cx: cx, cy: cy, scale: 1);
    final rs = radiusScale(size, o['rsPow'] ?? 0.6);
    final rBase = o['rBase'] ?? 1.2;
    final rDepth = o['rDepth'] ?? 1.8;

    final dots = <OrbDot>[];
    final ghostN = _count(o, 'ghostN', 150);
    final belowGhostN = _below(ghostN);
    for (var i = 0; i < belowGhostN; i++) {
      final d = fibDir(i, ghostN);
      final (px, py, z) = pt(d.$1 * rBound, d.$2 * rBound, d.$3 * rBound);
      final depth = (z / rBound + 1) / 2;
      dots.add(
        OrbDot(
          x: px,
          y: py,
          z: z,
          r: 0.8 * rs,
          white: 0.78,
          a: 0.1 + 0.22 * depth,
        ),
      );
    }

    final strandN = _count(o, 'strandN', 52);
    final turns = o['turns'] ?? 3.0;
    final belowStrandN = _below(strandN);
    for (var s = 0; s < 3; s++) {
      final phase = (s / 3) * 2 * math.pi;
      for (var i = 0; i < belowStrandN; i++) {
        final u = (frac(i / strandN + t * 0.045) * 2 - 1) * 0.96;
        final surf = math.sqrt(math.max(0.0, 1 - u * u));
        final endFade = math.min(1.0, (1 - u.abs()) / 0.1);
        final a = u * math.pi * turns + phase;
        final weave =
            1 + 0.075 * math.sin(u * math.pi * turns * 2 + phase * 2 + t * 0.8);
        final rr = surf * rBound * weave;
        final (px, py, zr) = pt(
          math.cos(a) * rr,
          u * rBound * weave,
          math.sin(a) * rr,
        );
        final depth = (zr / rBound + 1) / 2;
        dots.add(
          OrbDot(
            x: px,
            y: py,
            z: zr,
            r: (rBase + rDepth * depth) * rs,
            white: 0.55 - 0.45 * depth,
            a: endFade * (0.45 + 0.55 * depth),
          ),
        );
      }
    }
    return finalize(dots, const [], rMin: o['rMin'] ?? 0.3);
  }

  // MARK: - Ribbon — composing (and ring — breathing, via faceOn)

  static OrbFrame ribbon(double size, double t, OrbOpts o) {
    final cx = size / 2;
    final cy = size / 2;
    final rBound = (size / 2) * 0.78;
    final spin = o['spin'] ?? 1.0;
    const camTilt = 0.3;
    final pt = Projector(
      yaw: t * 0.1 * spin,
      tilt: camTilt,
      cx: cx,
      cy: cy,
      scale: 1,
    );
    final rs = radiusScale(size, o['rsPow'] ?? 0.6);
    final faceOn = (o['faceOn'] ?? 0.0) != 0;
    final wobMul = o['wobMul'] ?? 1.0;
    final rBase = o['rBase'] ?? 1.1;
    final rDepth = o['rDepth'] ?? 1.7;

    final dots = <OrbDot>[];
    final ghostN = _count(o, 'ghostN', 150);
    final belowGhostN = _below(ghostN);
    for (var i = 0; i < belowGhostN; i++) {
      final d = fibDir(i, ghostN);
      final (px, py, z) = pt(d.$1 * rBound, d.$2 * rBound, d.$3 * rBound);
      final depth = (z / rBound + 1) / 2;
      dots.add(
        OrbDot(
          x: px,
          y: py,
          z: z,
          r: 0.8 * rs,
          white: 0.78,
          a: 0.1 + 0.22 * depth,
        ),
      );
    }

    final ya = t * 0.24 * spin;
    final ta = faceOn ? -camTilt : 0.55 + 0.3 * math.sin(t * 0.18) * spin;
    final ux = math.cos(ya);
    const uy = 0.0;
    final uz = math.sin(ya);
    final vx = -uz * math.sin(ta);
    final vy = math.cos(ta);
    final vz = ux * math.sin(ta);
    final nx = uy * vz - uz * vy;
    final ny = uz * vx - ux * vz;
    final nz = ux * vy - uy * vx;

    final wobAmp = 0.23 * wobMul;
    final baseR = faceOn ? rBound / (1 + 0.85 * wobAmp) : rBound;

    final baseLanes = o['lanes'] ?? 5.0;
    final segs = _count(o, 'segs', 88);
    final lanes = math.max(
      1,
      jsRound(baseLanes * (o['bandMul'] ?? 1.0)).toInt(),
    );
    final mid = (lanes - 1) / 2.0;
    final belowSegs = _below(segs);
    for (var w = 0; w < lanes; w++) {
      final fw = w.toDouble();
      final laneOff = (fw - mid) * 0.075;
      final edge = (fw - mid).abs() / math.max(1.0, mid);
      for (var k = 0; k < belowSegs; k++) {
        final a = (k / segs) * 2 * math.pi;
        final wob =
            (0.16 * math.sin(a * 3 - t * 1.7 + fw * 0.22) +
                0.07 * math.sin(a * 5 + t * 1.1)) *
            wobMul;
        final radial = faceOn ? 1.0 + wob : 1.0;
        final off = faceOn ? laneOff : laneOff + wob;

        final x = ux * math.cos(a) + vx * math.sin(a) + nx * off;
        final y = uy * math.cos(a) + vy * math.sin(a) + ny * off;
        final z = uz * math.cos(a) + vz * math.sin(a) + nz * off;
        final l = math.sqrt(x * x + y * y + z * z);
        final rr = baseR * radial;
        final (px, py, zr) = pt((x / l) * rr, (y / l) * rr, (z / l) * rr);
        final depth = (zr / rBound + 1) / 2;
        dots.add(
          OrbDot(
            x: px,
            y: py,
            z: zr,
            r: (rBase + rDepth * depth) * (1 - 0.25 * edge) * rs,
            white: 0.52 - 0.44 * depth + 0.18 * edge,
            a: 0.4 + 0.6 * depth,
          ),
        );
      }
    }
    return finalize(dots, const [], rMin: o['rMin'] ?? 0.3);
  }

  // MARK: - Morph — shaping

  static const _morphHold = 1.4;
  static const _morphTime = 0.9;

  static final _triangle = _PolyPath(const [
    (0.0, -0.26),
    (0.24, 0.16),
    (-0.24, 0.16),
  ]);

  static final _square = _PolyPath(const [
    (0.0, -0.2),
    (0.2, -0.2),
    (0.2, 0.2),
    (-0.2, 0.2),
    (-0.2, -0.2),
  ]);

  static (double, double) _shapePoint(int shape, double f) {
    switch (shape) {
      case 0:
        final a = -math.pi / 2 + f * 2 * math.pi;
        return (math.cos(a) * 0.24, math.sin(a) * 0.24);
      case 1:
        return _triangle.at(f);
      default:
        return _square.at(f);
    }
  }

  static OrbFrame morph(double size, double t, OrbOpts o) {
    const kShapes = 3;
    const segDur = _morphHold + _morphTime;
    var tc = t.remainder(segDur * kShapes);
    if (tc < 0) tc += segDur * kShapes;
    final k = (tc / segDur).floor();
    final local = tc - k * segDur;
    final double m;
    if (local <= _morphHold) {
      m = 0.0;
    } else {
      final x = (local - _morphHold) / _morphTime;
      m = x * x * (3 - 2 * x);
    }
    final sprd = o['spread'] ?? 1.0;

    const mSteps = 160;
    final pts = <(double, double)>[];
    for (var i = 0; i < mSteps; i++) {
      final f = i / mSteps;
      final a = _shapePoint(k, f);
      final b = _shapePoint((k + 1) % kShapes, f);
      pts.add((
        (a.$1 + (b.$1 - a.$1) * m) * sprd,
        (a.$2 + (b.$2 - a.$2) * m) * sprd,
      ));
    }
    final lDists = <double>[];
    var total = 0.0;
    for (var i = 0; i < mSteps; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % mSteps];
      final dx = b.$1 - a.$1;
      final dy = b.$2 - a.$2;
      final l = math.sqrt(dx * dx + dy * dy);
      lDists.add(l);
      total += l;
    }

    final n = math.max(6, jsRound(34 * (o['iconD'] ?? 1.0)).toInt());
    final re = (o['rDot'] ?? 0.021) * 1.35 * sprd;
    final pulse = 1 + 0.02 * math.sin(local * 3.1);

    final dots = <OrbDot>[];
    final c2 = size / 2;
    var seg = 0;
    var acc = 0.0;
    for (var k2 = 0; k2 < n; k2++) {
      final target = (k2 / n) * total;
      while (acc + lDists[seg] < target && seg < mSteps - 1) {
        acc += lDists[seg];
        seg += 1;
      }
      final a = pts[seg];
      final b = pts[(seg + 1) % mSteps];
      final f = lDists[seg] != 0
          ? math.min(1.0, (target - acc) / lDists[seg])
          : 0.0;
      final x = (a.$1 + (b.$1 - a.$1) * f) * pulse;
      final y = (a.$2 + (b.$2 - a.$2) * f) * pulse;
      dots.add(
        OrbDot(
          x: c2 + x * size,
          y: c2 + y * size,
          z: 0.0,
          r: math.max(0.35, re * size),
          white: 0.1,
        ),
      );
    }
    return finalize(dots, const [], rMin: o['rMin'] ?? 0.25);
  }
}

/// Shared spin + tilt + orthographic projection.
class Projector {
  Projector({
    required double yaw,
    required double tilt,
    required this.cx,
    required this.cy,
    required this.scale,
  }) : st = math.sin(tilt),
       ct = math.cos(tilt),
       sy = math.sin(yaw),
       cyw = math.cos(yaw);

  final double st;
  final double ct;
  final double sy;
  final double cyw;
  final double cx;
  final double cy;
  final double scale;

  (double, double, double) call(double x, double y, double z) {
    final x1 = x * cyw + z * sy;
    final z1 = -x * sy + z * cyw;
    final y1 = y * ct - z1 * st;
    final z2 = y * st + z1 * ct;
    return (cx + x1 * scale, cy - y1 * scale, z2);
  }
}

class _Move {
  const _Move({
    required this.axis,
    required this.lo,
    required this.hi,
    required this.ang,
  });

  final int axis;
  final double lo;
  final double hi;
  final double ang;
}

class _PolyPath {
  _PolyPath(this.verts) {
    var sum = 0.0;
    for (var i = 0; i < verts.length; i++) {
      final a = verts[i];
      final b = verts[(i + 1) % verts.length];
      final dx = b.$1 - a.$1;
      final dy = b.$2 - a.$2;
      final l = math.sqrt(dx * dx + dy * dy);
      lengths.add(l);
      sum += l;
    }
    total = sum;
  }

  final List<(double, double)> verts;
  final List<double> lengths = [];
  late final double total;

  (double, double) at(double f) {
    var target = f * total;
    var i = 0;
    while (target > lengths[i] && i < verts.length - 1) {
      target -= lengths[i];
      i += 1;
    }
    final a = verts[i];
    final b = verts[(i + 1) % verts.length];
    final ff = lengths[i] != 0 ? math.min(1.0, target / lengths[i]) : 0.0;
    return (a.$1 + (b.$1 - a.$1) * ff, a.$2 + (b.$2 - a.$2) * ff);
  }
}

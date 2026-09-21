import 'dart:math' as math;

import '../design.dart';
import '../frame.dart';
import 'engine.dart';

/// The geometry builder a design runs on. `ring` shares ribbon's builder.
enum OrbMode { orbits, globe, rubik, wave, web, braid, ribbon, ring, morph }

extension OrbDesignMode on OrbDesign {
  OrbMode get mode {
    switch (this) {
      case OrbDesign.working:
        return OrbMode.orbits;
      case OrbDesign.searching:
        return OrbMode.globe;
      case OrbDesign.solving:
        return OrbMode.rubik;
      case OrbDesign.listening:
        return OrbMode.wave;
      case OrbDesign.connecting:
        return OrbMode.web;
      case OrbDesign.weaving:
        return OrbMode.braid;
      case OrbDesign.composing:
        return OrbMode.ribbon;
      case OrbDesign.breathing:
        return OrbMode.ring;
      case OrbDesign.shaping:
        return OrbMode.morph;
    }
  }
}

/// Mode options, keyed exactly as the web engine keys them. A missing key
/// falls back to the default written at its point of use.
typedef OrbOpts = Map<String, double>;

/// A (design, size) pair resolved to its builder, baked speed and options.
class OrbResolved {
  const OrbResolved({
    required this.mode,
    required this.speed,
    required this.opts,
  });

  final OrbMode mode;
  final double speed;
  final OrbOpts opts;

  /// The frame at geometry time `t` (seconds × speed) for a `size`-point box.
  /// Any time is safe, negative or not; a non-finite one draws time zero.
  OrbFrame frame({required double size, required double t}) {
    return OrbEngine.frame(
      mode,
      size: size,
      t: t.isFinite ? t : 0.0,
      opts: opts,
    );
  }
}

class OrbPreset {
  const OrbPreset({
    required this.speed,
    required this.count,
    required this.size,
    this.extra = const {},
  });

  final double speed;
  final double count;
  final double size;
  final OrbOpts extra;
}

abstract final class OrbPresets {
  /// The shipped tunings, baked on the web. `count` and `size` multiply the
  /// base profile; `speed` multiplies the shared clock.
  static OrbPreset preset(OrbMode mode, OrbSize size) {
    switch ((mode, size)) {
      case (OrbMode.orbits, OrbSize.regular):
        return const OrbPreset(speed: 1.885, count: 1.0, size: 1.0);
      case (OrbMode.orbits, OrbSize.small):
        return const OrbPreset(speed: 3.9, count: 0.238, size: 2.4);
      case (OrbMode.globe, OrbSize.regular):
        return const OrbPreset(
          speed: 2.015,
          count: 0.42,
          size: 1.15,
          extra: {'scanMul': 4.08, 'dimBase': 0.45},
        );
      case (OrbMode.globe, OrbSize.small):
        return const OrbPreset(
          speed: 2.665,
          count: 0.105,
          size: 1.75,
          extra: {'scanMul': 4.335, 'dimBase': 0.45},
        );
      case (OrbMode.rubik, OrbSize.regular):
        return const OrbPreset(speed: 1.82, count: 0.35, size: 1.05);
      case (OrbMode.rubik, OrbSize.small):
        return const OrbPreset(speed: 1.95, count: 0.088, size: 1.9);
      case (OrbMode.wave, OrbSize.regular):
        return const OrbPreset(speed: 4.388, count: 0.341, size: 1.0);
      case (OrbMode.wave, OrbSize.small):
        return const OrbPreset(speed: 3.998, count: 0.105, size: 1.6);
      case (OrbMode.web, OrbSize.regular):
        return const OrbPreset(speed: 3.315, count: 1.35, size: 0.95);
      case (OrbMode.web, OrbSize.small):
        return const OrbPreset(speed: 6.63, count: 0.25, size: 1.52);
      case (OrbMode.braid, OrbSize.regular):
        return const OrbPreset(speed: 1.625, count: 0.5, size: 1.0);
      case (OrbMode.braid, OrbSize.small):
        return const OrbPreset(speed: 2.75, count: 0.1125, size: 1.36);
      case (OrbMode.ribbon, OrbSize.regular):
        return const OrbPreset(
          speed: 2.34,
          count: 0.25,
          size: 0.85,
          extra: {'spin': 0.0, 'bandMul': 3.9, 'wobMul': 1.0},
        );
      case (OrbMode.ribbon, OrbSize.small):
        return const OrbPreset(
          speed: 3.12,
          count: 0.051,
          size: 1.073,
          extra: {'spin': 0.0, 'bandMul': 4.94, 'wobMul': 1.0},
        );
      case (OrbMode.ring, OrbSize.regular):
        return const OrbPreset(
          speed: 3.24,
          count: 0.25,
          size: 0.956,
          extra: {'spin': 0.0, 'bandMul': 3.627, 'wobMul': 0.368},
        );
      case (OrbMode.ring, OrbSize.small):
        return const OrbPreset(
          speed: 3.78,
          count: 0.028,
          size: 1.622,
          extra: {'spin': 0.0, 'bandMul': 3.968, 'wobMul': 0.565},
        );
      case (OrbMode.morph, OrbSize.regular):
        return const OrbPreset(
          speed: 2.405,
          count: 0.702,
          size: 0.395,
          extra: {'spread': 1.45},
        );
      case (OrbMode.morph, OrbSize.small):
        return const OrbPreset(
          speed: 2.08,
          count: 0.53,
          size: 1.011,
          extra: {'spread': 1.45},
        );
    }
  }

  /// Base ("fine") profiles per mode, before the preset multipliers.
  static OrbOpts base(OrbMode mode) {
    switch (mode) {
      case OrbMode.globe:
        return {
          'latRings': 17.0,
          'lonDensity': 44.0,
          'rBase': 0.6,
          'rDepth': 1.7,
          'rBoost': 1.0,
          'inkFar': 0.62,
          'inkSpan': 0.54,
          'rsPow': 0.6,
          'rMin': 0.3,
        };
      case OrbMode.orbits:
        return {
          'orbitN': 12.0,
          'ghostN': 40.0,
          'ghostR': 0.9,
          'ghostA': 0.5,
          'particles': 3.0,
          'partR': 1.2,
          'partRDepth': 1.6,
          'rsPow': 0.6,
          'rMin': 0.3,
        };
      case OrbMode.rubik:
        return {
          'latRings': 15.0,
          'lonDensity': 40.0,
          'moveCount': 14.0,
          'rBase': 0.6,
          'rDepth': 1.7,
          'rActive': 0.3,
          'inkFar': 0.62,
          'inkSpan': 0.54,
          'rsPow': 0.6,
          'rMin': 0.3,
        };
      case OrbMode.wave:
        return {
          'rings': 15.0,
          'lonDensity': 40.0,
          'rBase': 0.6,
          'rDepth': 1.7,
          'rsPow': 0.6,
          'rMin': 0.3,
        };
      case OrbMode.web:
        return {
          'nodeN': 30.0,
          'thr': 0.72,
          'signals': 5.0,
          'nodeR': 1.4,
          'nodeRDepth': 1.8,
          'lineW': 0.8,
          'rsPow': 0.6,
          'rMin': 0.3,
        };
      case OrbMode.braid:
        return {
          'strandN': 52.0,
          'turns': 3.0,
          'ghostN': 150.0,
          'rBase': 1.2,
          'rDepth': 1.8,
          'rsPow': 0.6,
          'rMin': 0.3,
        };
      case OrbMode.ribbon:
        return {
          'lanes': 5.0,
          'segs': 88.0,
          'ghostN': 150.0,
          'rBase': 1.1,
          'rDepth': 1.7,
          'rsPow': 0.6,
          'rMin': 0.3,
        };
      case OrbMode.ring:
        return {
          'lanes': 5.0,
          'segs': 88.0,
          'ghostN': 0.0,
          'faceOn': 1.0,
          'rBase': 1.1,
          'rDepth': 1.7,
          'rsPow': 0.6,
          'rMin': 0.3,
        };
      case OrbMode.morph:
        return {'rDot': 0.021, 'iconD': 1.0, 'rMin': 0.25};
    }
  }

  static const _countPairs = [
    ('latRings', 'lonDensity'),
    ('rings', 'lonDensity'),
    ('lanes', 'segs'),
  ];
  static const _countKeys = ['orbitN', 'ghostN', 'nodeN', 'strandN', 'signals'];
  static const _radiusKeys = [
    'rBase',
    'rDepth',
    'rActive',
    'rDot',
    'ghostR',
    'partR',
    'partRDepth',
    'nodeR',
    'nodeRDepth',
  ];

  static OrbOpts scaleCounts(OrbOpts opts, double scale) {
    final out = Map<String, double>.from(opts);
    final done = <String>{};
    final rt = math.sqrt(scale);
    for (final (a, b) in _countPairs) {
      final va = out[a];
      final vb = out[b];
      if (va != null && vb != null && !done.contains(a) && !done.contains(b)) {
        out[a] = math.max(2.0, OrbEngine.jsRound(va * rt));
        out[b] = math.max(2.0, OrbEngine.jsRound(vb * rt));
        done.add(a);
        done.add(b);
      }
    }
    for (final k in _countKeys) {
      final v = out[k];
      if (v != null && v != 0 && !done.contains(k)) {
        out[k] = math.max(1.0, OrbEngine.jsRound(v * scale));
      }
    }
    final iconD = out['iconD'];
    if (iconD != null) {
      out['iconD'] = math.max(0.02, iconD * scale);
    }
    return out;
  }

  static OrbOpts scaleRadii(OrbOpts opts, double scale) {
    final out = Map<String, double>.from(opts);
    for (final k in _radiusKeys) {
      final v = out[k];
      if (v != null) {
        out[k] = v * scale;
      }
    }
    out['rSizeMul'] = (out['rSizeMul'] ?? 1.0) * scale;
    return out;
  }

  static final Map<String, OrbResolved> _cache = () {
    final c = <String, OrbResolved>{};
    for (final design in OrbDesign.values) {
      for (final size in OrbSize.values) {
        c['${design.name}-${size.value}'] = _compute(design, size);
      }
    }
    return c;
  }();

  /// A (design, size) pair's builder and fully scaled options. Cached.
  static OrbResolved resolve(OrbDesign design, OrbSize size) {
    return _cache['${design.name}-${size.value}'] ?? _compute(design, size);
  }

  static OrbResolved _compute(OrbDesign design, OrbSize size) {
    final mode = design.mode;
    final p = preset(mode, size);
    var opts = base(mode);
    if (p.count != 1.0) opts = scaleCounts(opts, p.count);
    if (p.size != 1.0) opts = scaleRadii(opts, p.size);
    opts.addAll(p.extra);
    return OrbResolved(mode: mode, speed: p.speed, opts: opts);
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'clock.dart';
import 'design.dart';
import 'engine/presets.dart';

/// A dotted, genuinely 3D loading indicator for AI and agent interfaces.
///
/// ```dart
/// ThinkingOrb(design: OrbDesign.searching)                 // 64 pt
/// ThinkingOrb(design: OrbDesign.working, size: OrbSize.small) // 20 pt, sits inline with text
/// ThinkingOrb(design: OrbDesign.solving, diameter: 56)     // the 64 pt design drawn at 56 pt
/// ```
///
/// Ink is strictly monochrome and follows the theme's brightness by default:
/// dark dots on light backgrounds, light dots on dark ones.
///
/// Every orb runs on one shared clock, so orbs on screen together stay in
/// phase. An orb pauses itself while the app is in the background or paused,
/// and shows a single still frame when Reduce Motion is on.
class ThinkingOrb extends StatefulWidget {
  const ThinkingOrb({
    super.key,
    this.design = OrbDesign.working,
    this.size = OrbSize.regular,
    this.diameter,
    this.speed = 1.0,
    this.isPaused = false,
    this.color,
  });

  /// Which animation to show.
  final OrbDesign design;

  /// The tuned size: [OrbSize.regular] (64 pt) or [OrbSize.small] (20 pt).
  /// Each is its own design, with its own dot count, dot size and speed.
  final OrbSize size;

  /// Draws the chosen size's design at another size, in logical points.
  /// Leave `null` to draw it at its tuned size.
  final double? diameter;

  /// A multiplier on the design's tuned speed.
  final double speed;

  /// Freezes the orb on its current frame.
  final bool isPaused;

  /// Optional color override. If `null`, follows theme brightness with
  /// monochrome grayscale dots.
  final Color? color;

  @override
  State<ThinkingOrb> createState() => _ThinkingOrbState();
}

class _ThinkingOrbState extends State<ThinkingOrb>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  bool _isAppActive = true;
  double _currentSeconds = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentSeconds = OrbClock.seconds();
    _ticker = createTicker((_) {
      if (mounted) {
        setState(() {
          _currentSeconds = OrbClock.seconds();
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_isAppActive != active) {
      _isAppActive = active;
      _updateTicker();
    }
  }

  @override
  void didUpdateWidget(ThinkingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTicker();
  }

  void _updateTicker({bool? clockOverrideActive, bool? reduceMotionActive}) {
    final clockOverride = clockOverrideActive ?? false;
    final reduceMotion = reduceMotionActive ?? false;
    final shouldRun =
        !widget.isPaused && _isAppActive && !clockOverride && !reduceMotion;

    if (shouldRun && !_ticker.isTicking) {
      _ticker.start();
    } else if (!shouldRun && _ticker.isTicking) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = OrbPresets.resolve(widget.design, widget.size);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final clockOverride = OrbClockOverride.maybeOf(context);

    final clockOverrideActive = clockOverride != null;
    _updateTicker(
      clockOverrideActive: clockOverrideActive,
      reduceMotionActive: reduceMotion,
    );

    final double t;
    if (clockOverride != null) {
      t = clockOverride * resolved.speed * widget.speed;
    } else if (reduceMotion) {
      // One static, representative frame; follows the theme.
      t = 0.6;
    } else {
      t = _currentSeconds * resolved.speed * widget.speed;
    }

    final side = widget.diameter ?? widget.size.points;

    return Semantics(
      label: widget.design.accessibilityLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: side,
        height: side,
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size(side, side),
            painter: OrbPainter(
              resolved: resolved,
              size: widget.size,
              t: t,
              isDark: isDark,
              customColor: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

/// A CustomPainter that paints one instant of an orb frame.
class OrbPainter extends CustomPainter {
  const OrbPainter({
    required this.resolved,
    required this.size,
    required this.t,
    required this.isDark,
    this.customColor,
  });

  final OrbResolved resolved;
  final OrbSize size;
  final double t;
  final bool isDark;
  final Color? customColor;

  static final List<Color> _inks = List<Color>.generate(
    256,
    (i) => Color.fromARGB(255, i, i, i),
    growable: false,
  );

  /// Matte grayscale, one of 256 levels. On a dark ground the ink value is
  /// mirrored so near dots read bright.
  static Color ink(double white, {required bool isDark, Color? customColor}) {
    final w = white.clamp(0.0, 1.0);
    final mapped = isDark ? 1.0 - w : w;
    if (customColor != null) {
      // Tint based on customColor luminosity / lightness
      return customColor.withValues(alpha: mapped);
    }
    final level = ((mapped * 255.0 + 0.5).floor()).clamp(0, 255);
    return _inks[level];
  }

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final frame = resolved.frame(size: size.length, t: t);
    final unit = size.points;
    final scale = math.min(canvasSize.width, canvasSize.height) / unit;

    canvas.save();
    canvas.translate(
      (canvasSize.width - unit * scale) / 2.0,
      (canvasSize.height - unit * scale) / 2.0,
    );
    canvas.scale(scale, scale);

    // Lines first, so nodes sit on top of their edges
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    for (final line in frame.lines) {
      final baseColor = ink(
        line.white,
        isDark: isDark,
        customColor: customColor,
      );
      final alpha = (line.a.clamp(0.0, 1.0) * baseColor.a).clamp(0.0, 1.0);
      linePaint
        ..color = baseColor.withValues(alpha: alpha)
        ..strokeWidth = line.w;
      canvas.drawLine(
        Offset(line.x1, line.y1),
        Offset(line.x2, line.y2),
        linePaint,
      );
    }

    // Dots in array order (already z-sorted far -> near)
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final dot in frame.dots) {
      final baseColor = ink(
        dot.white,
        isDark: isDark,
        customColor: customColor,
      );
      final alpha = (dot.a.clamp(0.0, 1.0) * baseColor.a).clamp(0.0, 1.0);
      dotPaint.color = baseColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(dot.x, dot.y), dot.r, dotPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OrbPainter oldDelegate) {
    return oldDelegate.resolved != resolved ||
        oldDelegate.size != size ||
        oldDelegate.t != t ||
        oldDelegate.isDark != isDark ||
        oldDelegate.customColor != customColor;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'clock.dart';

/// Sweeps a highlight band across this widget every two seconds: the
/// thinking-orbs "shimmer" that marks a status line as live. The content
/// sits at half strength with the band passing over it at full strength,
/// so it keeps its own color and font.
///
/// Under Reduce Motion the band holds still and the content stays at full
/// strength, as it does with Increase Contrast.
class ThinkingShimmer extends StatefulWidget {
  const ThinkingShimmer({super.key, required this.child, this.isActive = true});

  /// The widget to apply the shimmer sweep across.
  final Widget child;

  /// Whether the shimmer animation is currently active.
  final bool isActive;

  @override
  State<ThinkingShimmer> createState() => _ThinkingShimmerState();
}

class _ThinkingShimmerState extends State<ThinkingShimmer>
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
  void didUpdateWidget(ThinkingShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTicker();
  }

  void _updateTicker({bool? clockOverrideActive, bool? reduceMotionActive}) {
    final clockOverride = clockOverrideActive ?? false;
    final reduceMotion = reduceMotionActive ?? false;
    final shouldRun =
        widget.isActive && _isAppActive && !clockOverride && !reduceMotion;

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
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final clockOverride = OrbClockOverride.maybeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final clockOverrideActive = clockOverride != null;
    _updateTicker(
      clockOverrideActive: clockOverrideActive,
      reduceMotionActive: reduceMotion,
    );

    // With no band (Reduce Motion) or when legibility comes first
    // (Increase Contrast), the text stays at full strength.
    final bool disableShimmer =
        (clockOverride == null && reduceMotion) || highContrast;
    final double baseOpacity = disableShimmer ? 1.0 : (isDark ? 0.50 : 0.45);

    if (disableShimmer || (!widget.isActive && clockOverride == null)) {
      return Opacity(opacity: baseOpacity, child: widget.child);
    }

    final double seconds = clockOverride ?? _currentSeconds;
    // q runs linearly 0 -> 1 over 2.0 seconds
    final double q = (seconds / 2.0) - (seconds / 2.0).floorToDouble();

    return Stack(
      children: [
        // Base dimmed content
        Opacity(opacity: baseOpacity, child: widget.child),
        // Overlay shimmer band
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (Rect bounds) {
                  final w = bounds.width;
                  if (w <= 0) {
                    return const LinearGradient(
                      colors: [Colors.transparent, Colors.transparent],
                    ).createShader(bounds);
                  }
                  final bandW = w * 0.8;
                  final startX = -w + 3.0 * w * q - w * 0.4;
                  final endX = startX + bandW;
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0x00000000),
                      Color(0xFFFFFFFF),
                      Color(0x00000000),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ).createShader(
                    Rect.fromLTRB(startX, bounds.top, endX, bounds.bottom),
                  );
                },
                child: widget.child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Extension on [Widget] providing a convenient `.thinkingShimmer()` modifier.
extension ThinkingShimmerExtension on Widget {
  /// Sweeps a highlight band across this widget every two seconds: the
  /// thinking-orbs "shimmer" that marks a status line as live.
  ///
  /// ```dart
  /// Text('Composing a reply…').thinkingShimmer();
  /// ```
  Widget thinkingShimmer({bool isActive = true}) {
    return ThinkingShimmer(isActive: isActive, child: this);
  }
}

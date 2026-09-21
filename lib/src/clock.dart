import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// One shared clock, so every orb on screen runs in phase with every other,
/// whenever it appeared.
abstract final class OrbClock {
  /// The origin timestamp initialized when the clock is first referenced.
  static final DateTime origin = DateTime.now();

  /// Returns seconds elapsed since the shared clock origin.
  /// A provided [date] can be evaluated against origin, clamped to non-negative.
  static double seconds([DateTime? date]) {
    final d = date ?? DateTime.now();
    final diff = d.difference(origin).inMicroseconds / 1000000.0;
    return math.max(0.0, diff);
  }
}

/// Pins every orb and shimmer below to this many seconds on the orb clock.
/// For deterministic snapshots and rendered golden tests; `null` runs live.
class OrbClockOverride extends InheritedWidget {
  const OrbClockOverride({
    super.key,
    required this.seconds,
    required super.child,
  });

  /// The pinned seconds value, or null to run live.
  final double? seconds;

  /// Retrieves the nearest [OrbClockOverride] value if present.
  static double? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<OrbClockOverride>()
        ?.seconds;
  }

  @override
  bool updateShouldNotify(OrbClockOverride oldWidget) =>
      seconds != oldWidget.seconds;
}

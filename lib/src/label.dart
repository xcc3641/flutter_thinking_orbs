import 'package:flutter/material.dart';

import 'design.dart';
import 'orb.dart';
import 'shimmer.dart';

/// An orb beside a shimmering status line: the standard "the agent is doing
/// something" row. Style it with standard widgets, padding, and background.
///
/// ```dart
/// ThinkingOrbLabel('Searching the web…', design: OrbDesign.searching);
///
/// ThinkingOrbLabel(
///   'Thinking…',
///   design: OrbDesign.breathing,
///   size: OrbSize.regular,
///   diameter: 48,
/// );
/// ```
class ThinkingOrbLabel extends StatelessWidget {
  /// Creates a label with a string title and shimmering effect.
  const ThinkingOrbLabel(
    this.text, {
    super.key,
    required this.design,
    this.size = OrbSize.small,
    this.diameter,
    this.speed = 1.0,
    this.isPaused = false,
    this.textStyle,
    this.spacing,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  }) : customTitle = null;

  /// Creates a label with a custom title widget (e.g. styled RichText or Column).
  const ThinkingOrbLabel.custom({
    super.key,
    required Widget title,
    required this.design,
    this.size = OrbSize.small,
    this.diameter,
    this.speed = 1.0,
    this.isPaused = false,
    this.spacing,
  }) : text = null,
       customTitle = title,
       textStyle = null,
       maxLines = 1,
       overflow = TextOverflow.ellipsis;

  /// The plain string title, if provided.
  final String? text;

  /// A custom title widget, if provided via [ThinkingOrbLabel.custom].
  final Widget? customTitle;

  /// Which orb design to display.
  final OrbDesign design;

  /// The tuned size of the orb. Defaults to [OrbSize.small] (20 pt).
  final OrbSize size;

  /// Optional diameter in logical points to draw the orb at.
  final double? diameter;

  /// Speed multiplier for the orb.
  final double speed;

  /// Freezes both the orb and the shimmer.
  final bool isPaused;

  /// Optional text style for the label.
  final TextStyle? textStyle;

  /// Gap between the orb and the title. If `null`, defaults to 12 pt for
  /// large orbs (> 32 pt) and 8 pt for inline orbs (<= 32 pt).
  final double? spacing;

  /// Maximum lines for the title.
  final int maxLines;

  /// How visual overflow should be handled.
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final effectiveDiameter = diameter ?? size.points;
    final effectiveSpacing = spacing ?? (effectiveDiameter > 32 ? 12.0 : 8.0);

    final Widget titleWidget;
    if (customTitle != null) {
      titleWidget = customTitle!;
    } else {
      titleWidget = Text(
        text ?? '',
        maxLines: maxLines,
        overflow: overflow,
        style: textStyle,
      );
    }

    final accessibilityLabel = text ?? design.accessibilityLabel;

    return Semantics(
      label: accessibilityLabel,
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: ThinkingOrb(
              design: design,
              size: size,
              diameter: diameter,
              speed: speed,
              isPaused: isPaused,
            ),
          ),
          SizedBox(width: effectiveSpacing),
          Flexible(child: titleWidget.thinkingShimmer(isActive: !isPaused)),
        ],
      ),
    );
  }
}

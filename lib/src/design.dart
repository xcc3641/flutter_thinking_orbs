import 'engine/presets.dart';
import 'frame.dart';

/// The nine orb designs. Each is its own hand-tuned animation for one thing an
/// AI or agent can be doing, so pick the design that says what is happening.
enum OrbDesign {
  /// Particles on tilted orbits. General-purpose "busy".
  working,

  /// A scan meridian sweeps a dotted globe. Web search, retrieval, lookup.
  searching,

  /// Bands scramble in quarter turns, then click back solved. Reasoning, math, code.
  solving,

  /// A waveform rolls through the latitude rings. Voice input, transcription.
  listening,

  /// A constellation wires itself, packets running the edges. Tool calls, APIs, sync.
  connecting,

  /// Three strands plait around the sphere. Planning, multi-step agents.
  weaving,

  /// An undulating multi-band sash. Writing, generating a reply.
  composing,

  /// A face-on ring slowly morphing. Idle thinking, waiting on a model.
  breathing,

  /// A dotted outline morphing circle → triangle → square. Design, image, layout work.
  shaping;

  /// The design's display name, such as "Searching".
  String get title {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1);
  }

  /// One line on what the animation shows.
  String get summary {
    switch (this) {
      case OrbDesign.working:
        return 'Particles on tilted orbits';
      case OrbDesign.searching:
        return 'A scan meridian sweeps a dotted globe';
      case OrbDesign.solving:
        return 'Bands scramble, then click back solved';
      case OrbDesign.listening:
        return 'A waveform rolls through the rings';
      case OrbDesign.connecting:
        return 'A constellation wires itself';
      case OrbDesign.weaving:
        return 'Three strands plait around the sphere';
      case OrbDesign.composing:
        return 'An undulating multi-band sash';
      case OrbDesign.breathing:
        return 'A ring slowly morphing';
      case OrbDesign.shaping:
        return 'Circle → triangle → square';
    }
  }

  /// The VoiceOver / accessibility label an orb reads unless you set your own.
  String get accessibilityLabel {
    switch (this) {
      case OrbDesign.breathing:
        return 'Thinking…';
      default:
        return '$title…';
    }
  }

  /// The draw list for this design at [time] seconds on the orb clock, at
  /// the tuned speed, in a box of `size.points` × `size.points`.
  OrbFrame frame({OrbSize size = OrbSize.regular, required double time}) {
    final resolved = OrbPresets.resolve(this, size);
    return resolved.frame(size: size.length, t: time * resolved.speed);
  }
}

/// The two tuned sizes. They are separate designs, not one design scaled:
/// each carries its own dot count, dot size and speed.
enum OrbSize {
  /// 64 pt, for chat avatars, empty states and hero moments.
  regular(64),

  /// 20 pt, for sitting inline with text: status chips, toolbars, list rows.
  small(20);

  const OrbSize(this.value);

  final int value;

  /// The size's side length in points.
  double get points => value.toDouble();

  /// The size's side length in points (alias for points).
  double get length => value.toDouble();
}

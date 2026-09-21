/// The geometry surface, for anyone who wants to draw the orbs themselves
/// (CustomPainter, Canvas, a shader). A frame is a finished draw list: every
/// value is final and the array order is the draw order.
library;

/// One dot in a frame, in the frame's own point space (0…size on both axes).
class OrbDot {
  OrbDot({
    required this.x,
    required this.y,
    required this.z,
    required this.r,
    required this.white,
    this.a = 1.0,
  });

  double x;
  double y;

  /// Depth: larger is nearer. Its scale depends on the design (a unit sphere
  /// for some, points for others, always 0 for `shaping`), so use it for
  /// ordering or relative shading only. Dots are already sorted by it.
  double z;
  double r;

  /// Ink on paper, 0 (darkest) to 1 (white). Mirror it (`1 - white`) on a
  /// dark background so near dots read bright.
  double white;

  /// Opacity, 0 to 1.
  double a;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrbDot &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          z == other.z &&
          r == other.r &&
          white == other.white &&
          a == other.a;

  @override
  int get hashCode => Object.hash(x, y, z, r, white, a);

  @override
  String toString() =>
      'OrbDot(x: $x, y: $y, z: $z, r: $r, white: $white, a: $a)';
}

/// A stroked edge between two dots (only `connecting` draws these).
class OrbLine {
  OrbLine({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.white,
    this.a = 1.0,
    required this.w,
  });

  double x1;
  double y1;
  double x2;
  double y2;

  /// Ink on paper, as [OrbDot.white].
  double white;

  /// Opacity, 0 to 1.
  double a;

  /// Stroke width in points.
  double w;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrbLine &&
          runtimeType == other.runtimeType &&
          x1 == other.x1 &&
          y1 == other.y1 &&
          x2 == other.x2 &&
          y2 == other.y2 &&
          white == other.white &&
          a == other.a &&
          w == other.w;

  @override
  int get hashCode => Object.hash(x1, y1, x2, y2, white, a, w);

  @override
  String toString() =>
      'OrbLine(x1: $x1, y1: $y1, x2: $x2, y2: $y2, white: $white, a: $a, w: $w)';
}

/// One finished instant of an orb. Draw [lines] first, then [dots] in
/// array order (far to near), as grayscale circle fills.
class OrbFrame {
  const OrbFrame({required this.dots, required this.lines});

  final List<OrbDot> dots;
  final List<OrbLine> lines;
}

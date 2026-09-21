# ThinkingOrbs Architecture Mapping: SwiftUI to Flutter

This document provides a comprehensive technical guide for porting ThinkingOrbs from SwiftUI (`ref/upstream/`) to Flutter (`lib/`). It details the conceptual translations, rendering pipelines, lifecycle optimizations, and full API parity.

---

## 1. SwiftUI $\rightarrow$ Flutter Conceptual Architecture

SwiftUI and Flutter share declarative reactive paradigms, but differ significantly in canvas primitives, animation loops, and tree inheritance mechanics.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             SWIFTUI ECOSYSTEM                               │
│                                                                             │
│  EnvironmentValues ──► TimelineView(.animation) ──► Canvas(GraphicsContext) │
│  (colorScheme, etc.)   (system cadence)            (immediate drawing)      │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ Porting Translation
┌──────────────────────────────────────▼──────────────────────────────────────┐
│                             FLUTTER ECOSYSTEM                               │
│                                                                             │
│  InheritedWidget /  ──► Ticker / RepaintBoundary ──► CustomPaint            │
│  MediaQuery / Theme     (AnimationController)        (CustomPainter + Canvas)│
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Core Subsystems Mapping

### 2.1 Drawing: `SwiftUI.Canvas` & `GraphicsContext` $\rightarrow$ `CustomPainter` & `Canvas`

#### SwiftUI Implementation
In SwiftUI, `Canvas` receives a `GraphicsContext` and a `CGSize box`. Paths are created imperatively:
```swift
Canvas { context, box in
    let frame = resolved.frame(size: size.length, t: t)
    // Scale and translate
    context.translateBy(x: dx, y: dy)
    context.scaleBy(x: scale, y: scale)
    // Stroke lines
    for line in frame.lines {
        context.opacity = line.a
        context.stroke(path, with: .color(ink), lineWidth: line.w)
    }
    // Fill dots
    for dot in frame.dots {
        context.opacity = dot.a
        context.fill(Path(ellipseIn: rect), with: .color(ink))
    }
}
```

#### Flutter Equivalent
In Flutter, drawing belongs in a dedicated `CustomPainter`. The painter receives `ui.Canvas` and `ui.Size`:
```dart
class OrbPainter extends CustomPainter {
  final OrbFrame frame;
  final OrbSize size;
  final bool dark;

  const OrbPainter({
    required this.frame,
    required this.size,
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size box) {
    final unit = size.points;
    final scale = math.min(box.width, box.height) / unit;
    
    canvas.save();
    canvas.translate(
      (box.width - unit * scale) / 2,
      (box.height - unit * scale) / 2,
    );
    canvas.scale(scale, scale);

    final linePaint = Paint()..style = PaintingStyle.stroke;
    for (final line in frame.lines) {
      linePaint
        ..strokeWidth = line.w
        ..color = inkColor(line.white, dark: dark).withValues(alpha: line.a);
      canvas.drawLine(
        Offset(line.x1, line.y1),
        Offset(line.x2, line.y2),
        linePaint,
      );
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (final dot in frame.dots) {
      dotPaint.color = inkColor(dot.white, dark: dark).withValues(alpha: dot.a);
      canvas.drawCircle(Offset(dot.x, dot.y), dot.r, dotPaint);
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OrbPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.dark != dark;
}
```
**Key Optimizations**:
- **Precomputed Ink Palette**: In Flutter, `Color.fromARGB(255, k, k, k)` should be indexed from a static `List<Color>` of 256 entries to prevent allocating color objects during frame ticks.
- **Paint Object Reuse**: Reusing a single `linePaint` and `dotPaint` instance across iterations within a frame eliminates garbage collection overhead.

---

### 2.2 Animation Loop: `TimelineView(.animation)` $\rightarrow$ `Ticker` / `AnimationController`

#### SwiftUI Implementation
SwiftUI uses `TimelineView(.animation(paused: !isRunning))` which automatically drives frame updates on display CADisplayLink cadence. Time is retrieved via `timeline.date.timeIntervalSince(OrbClock.origin)`.

#### Flutter Equivalent
In Flutter, frame-by-frame updates are driven by a `TickerProvider`:
1. **Single Orb**: A `StatefulWidget` using `SingleTickerProviderStateMixin` with an `AnimationController.unbounded()` or listening to a `Ticker`.
2. **Shared Global Clock**: A shared singleton or static clock `OrbClock` computes continuous elapsed time:
   ```dart
   class OrbClock {
     static final DateTime _origin = DateTime.now();

     static double get nowSeconds =>
         DateTime.now().difference(_origin).inMicroseconds / 1000000.0;
   }
   ```
3. **Repaint Isolation**: Every `ThinkingOrb` widget must wrap its `CustomPaint` in a `RepaintBoundary`:
   ```dart
   RepaintBoundary(
     child: CustomPaint(
       size: Size.square(diameter ?? size.points),
       painter: OrbPainter(...),
     ),
   )
   ```
   *Why this is critical*: ThinkingOrbs animate at 60/120 Hz. Without `RepaintBoundary`, the entire surrounding widget subtree (including chat bubbles, list views, and app bars) would be marked dirty and re-rasterized every frame.

---

### 2.3 Viewport Visibility & Pausing: `onViewportVisibilityChange`

#### SwiftUI Implementation
SwiftUI upstream defines a custom view extension `onViewportVisibilityChange`:
```swift
onGeometryChange(for: Bool.self) { proxy in
    let own = CGRect(origin: .zero, size: proxy.size)
    let vertical = proxy.bounds(of: .scrollView(axis: .vertical))
    let horizontal = proxy.bounds(of: .scrollView(axis: .horizontal))
    return (vertical?.intersects(own) ?? true) && (horizontal?.intersects(own) ?? true)
} action: { visible in
    isOnScreen = visible
}
```

#### Flutter Equivalent
In Flutter, off-screen pausing can be achieved through:
1. **`VisibilityDetector`** (standard ecosystem approach) or **`ScrollNotificationListener`**.
2. **`WidgetsBindingObserver` / `AppLifecycleListener`**:
   To pause the ticker when the app is backgrounded (matching `scenePhase != .background`):
   ```dart
   class _ThinkingOrbState extends State<ThinkingOrb> with WidgetsBindingObserver {
     bool _isAppActive = true;

     @override
     void didChangeAppLifecycleState(AppLifecycleState state) {
       setState(() {
         _isAppActive = state == AppLifecycleState.resumed;
       });
     }
   }
   ```
3. When `!isPaused && _isAppActive && _isVisible`: the ticker runs. Otherwise, the ticker is paused.

---

### 2.4 Status Labels & Shimmer: `ThinkingOrbLabel` $\rightarrow$ `ShaderMask`

#### SwiftUI Implementation
SwiftUI uses an overlay with a moving gradient mask:
```swift
LinearGradient(colors: [.clear, .black, .clear], startPoint: .leading, endPoint: .trailing)
    .frame(width: w * 0.8)
    .offset(x: -w + 3 * w * q - w * 0.4)
```

#### Flutter Equivalent
In Flutter, shimmer masking is implemented cleanly using `ShaderMask`:
```dart
class ThinkingShimmer extends StatelessWidget {
  final Widget child;
  final bool isActive;

  const ThinkingShimmer({
    super.key,
    required this.child,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (disableAnimations || highContrast || !isActive) {
      return child; // Render static full-strength text
    }

    final baseOpacity = isDark ? 0.50 : 0.45;

    return AnimatedBuilder(
      animation: ShimmerClock.instance,
      builder: (context, _) {
        final q = ShimmerClock.phase; // (t / 2.0) % 1.0
        return Stack(
          children: [
            Opacity(opacity: baseOpacity, child: child),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                final w = bounds.width;
                final startX = -w + 3 * w * q - 0.4 * w;
                return ui.Gradient.linear(
                  Offset(startX, 0),
                  Offset(startX + 0.8 * w, 0),
                  const [Colors.transparent, Colors.white, Colors.transparent],
                  const [0.0, 0.5, 1.0],
                );
              },
              child: child,
            ),
          ],
        );
      },
    );
  }
}
```

---

### 2.5 Environment Values: `@Environment` $\rightarrow$ `BuildContext` & `InheritedWidget`

| SwiftUI Environment | Swift Keypath | Flutter Equivalent |
|---|---|---|
| Color Scheme | `@Environment(\.colorScheme)` | `Theme.of(context).brightness == Brightness.dark` |
| Reduce Motion | `@Environment(\.accessibilityReduceMotion)` | `MediaQuery.disableAnimationsOf(context)` |
| High Contrast | `@Environment(\.colorSchemeContrast)` | `MediaQuery.highContrastOf(context)` |
| Scene Phase | `@Environment(\.scenePhase)` | `AppLifecycleListener` / `WidgetsBindingObserver` |
| Clock Override | `@Environment(\.orbClockOverride)` | `OrbClockScope.maybeOf(context)?.time` |

#### Clock Override Scope
To support golden tests and deterministic UI screenshots:
```dart
class OrbClockScope extends InheritedWidget {
  final double? overrideTime;

  const OrbClockScope({
    super.key,
    required this.overrideTime,
    required super.child,
  });

  static OrbClockScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OrbClockScope>();

  @override
  bool updateShouldNotify(OrbClockScope oldWidget) =>
      overrideTime != oldWidget.overrideTime;
}
```

---

### 2.6 Accessibility & Semantics

#### SwiftUI Implementation
```swift
.accessibilityElement(children: .ignore)
.accessibilityLabel(Text(design.accessibilityLabel))
.accessibilityAddTraits(.isImage)
```
And for `ThinkingOrbLabel`:
```swift
.accessibilityElement(children: .combine)
```

#### Flutter Equivalent
In Flutter, accessibility is configured via the `Semantics` widget:
- **Standalone `ThinkingOrb`**:
  ```dart
  Semantics(
    image: true,
    label: design.accessibilityLabel,
    excludeSemantics: true,
    child: RepaintBoundary(...),
  )
  ```
- **`ThinkingOrbLabel`**:
  ```dart
  MergeSemantics(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: ThinkingOrb(...)),
        const SizedBox(width: spacing),
        Flexible(child: ThinkingShimmer(child: Text(...))),
      ],
    ),
  )
  ```

---

## 3. Comprehensive API Parity Table

### 3.1 Design Enums & Values

| Swift Entity (`ref/upstream/`) | Dart Entity (`lib/`) | Semantics & Notes |
|---|---|---|
| `public enum OrbDesign: String, CaseIterable` | `enum OrbDesign` | 9 design cases: `working`, `searching`, `solving`, `listening`, `connecting`, `weaving`, `composing`, `breathing`, `shaping` |
| `design.title: String` | `String get title` | Display title (e.g. `"Searching"`) |
| `design.summary: String` | `String get summary` | One line description of visual motion |
| `design.accessibilityLabel: String` | `String get accessibilityLabel` | Screen reader text (`"Thinking…"` for breathing, `"$title…"` for others) |
| `design.frame(size:at:) -> OrbFrame` | `OrbFrame frame({OrbSize size, required double time})` | Evaluates geometry for given clock timestamp |
| `public enum OrbSize: Int, CaseIterable` | `enum OrbSize` | `regular = 64`, `small = 20` |
| `size.points: CGFloat` | `double get points` | 64.0 or 20.0 |
| `size.length: Double` | `double get length` | 64.0 or 20.0 |

---

### 3.2 Geometry Engine & Data Models

| Swift Entity | Dart Entity | Fields & Signature |
|---|---|---|
| `struct OrbDot: Equatable, Sendable` | `class OrbDot` | `double x, y, z, r, white, a` |
| `struct OrbLine: Equatable, Sendable` | `class OrbLine` | `double x1, y1, x2, y2, white, a, w` |
| `struct OrbFrame: Sendable` | `class OrbFrame` | `List<OrbDot> dots, List<OrbLine> lines` |
| `enum OrbMode: String` | `enum OrbMode` | Internal engine mode: `orbits, globe, rubik, wave, web, braid, ribbon, ring, morph` |
| `typealias OrbOpts = [String: Double]` | `typedef OrbOpts = Map<String, double>` | Options bag for math engine |
| `struct OrbResolved` | `class OrbResolved` | `OrbMode mode; double speed; OrbOpts opts;` |
| `OrbPresets.resolve(design, size)` | `OrbPresets.resolve(OrbDesign, OrbSize)` | Returns precomputed `OrbResolved` |
| `OrbEngine.frame(mode, size, t, opts)` | `OrbEngine.frame(OrbMode, double, double, OrbOpts)` | Evaluates raw mathematical geometry |

---

### 3.3 UI Widgets & Components

| Swift Component | Dart Component | Parameters / Constructors |
|---|---|---|
| `ThinkingOrb` | `ThinkingOrb` | `ThinkingOrb(OrbDesign design, {OrbSize size, double? diameter, double speed, bool isPaused, Key? key})` |
| `ThinkingOrbLabel` | `ThinkingOrbLabel` | `ThinkingOrbLabel(String title, {Key? key, OrbDesign design, OrbSize size, double? diameter, double speed, bool isPaused})`<br>`ThinkingOrbLabel.rich(Text title, ...)` |
| `View.thinkingShimmer(isActive:)` | `ThinkingShimmer` / `Widget.thinkingShimmer()` | Wraps text/widget with 2.0s linear highlight sweep |
| `OrbClockOverride` environment | `OrbClockScope` | `OrbClockScope({required double? overrideTime, required Widget child})` |

---

## 4. Performance & Memory Guidelines

1. **Zero Garbage in Draw Loop**:
   Avoid allocating new `Paint`, `Path`, or `String` objects inside `paint()`.
2. **Repaint Boundary Enforcement**:
   Every animated orb must remain inside a `RepaintBoundary` so that only the canvas pixels are updated on ticker events.
3. **Quantized Grayscale Lookup**:
   Use a pre-allocated 256-element `List<Color>` for ink mapping:
   ```dart
   static final List<Color> _inkPalette = List<Color>.generate(
     256,
     (i) => Color.fromARGB(255, i, i, i),
     growable: false,
   );
   ```
4. **Ticker Discipline**:
   Always pause the ticker when `TickerMode.of(context)` is false, when the widget is hidden, or when the application is paused in the background.

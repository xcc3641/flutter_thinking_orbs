//
//  ThinkingOrb.swift
//  ThinkingOrbs
//
//  One Canvas inside one TimelineView, no view per dot. Every frame is a
//  z-sorted list of grayscale circle fills (plus a few line strokes for
//  `.connecting`), 9 to 566 of them.
//

import SwiftUI

/// A dotted, genuinely 3D loading indicator for AI and agent interfaces.
///
/// ```swift
/// ThinkingOrb(.searching)                       // 64 pt
/// ThinkingOrb(.working, size: .small)           // 20 pt, sits inline with text
/// ThinkingOrb(.solving, diameter: 56)           // the 64 pt design drawn at 56 pt
/// ```
///
/// Ink is strictly monochrome and follows the environment's color scheme:
/// dark dots on light backgrounds, light dots on dark ones. Pin it with
/// `.environment(\.colorScheme, .dark)`.
///
/// Every orb runs on one shared clock, so orbs on screen together stay in
/// phase. An orb pauses itself while scrolled out of view or while the app is
/// in the background, and shows a single still frame when Reduce Motion is on.
public struct ThinkingOrb: View {

    private let design: OrbDesign
    private let size: OrbSize
    private let diameter: CGFloat?
    private let speed: Double
    private let isPaused: Bool

    /// - Parameters:
    ///   - design: Which animation to show.
    ///   - size: The tuned size: `.regular` (64 pt) or `.small` (20 pt). Each is
    ///     its own design, with its own dot count, dot size and speed.
    ///   - diameter: Draws the chosen size's design at another size, in
    ///     points. Leave `nil` to draw it at its tuned size.
    ///   - speed: A multiplier on the design's tuned speed.
    ///   - isPaused: Freezes the orb on its current frame.
    public init(
        _ design: OrbDesign = .working,
        size: OrbSize = .regular,
        diameter: CGFloat? = nil,
        speed: Double = 1,
        isPaused: Bool = false
    ) {
        self.design = design
        self.size = size
        self.diameter = diameter
        self.speed = speed
        self.isPaused = isPaused
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.orbClockOverride) private var clockOverride

    @State private var isOnScreen = true

    private var isRunning: Bool {
        !isPaused && isOnScreen && scenePhase != .background
    }

    public var body: some View {
        let resolved = OrbPresets.resolve(design, size)
        let dark = colorScheme == .dark
        let side = diameter ?? size.points

        Group {
            if let time = clockOverride {
                OrbCanvas(resolved: resolved, size: size, t: time * resolved.speed * speed, dark: dark)
            } else if reduceMotion {
                // one static, representative frame; it still follows the theme
                OrbCanvas(resolved: resolved, size: size, t: 0.6, dark: dark)
            } else {
                TimelineView(.animation(paused: !isRunning)) { timeline in
                    OrbCanvas(
                        resolved: resolved,
                        size: size,
                        t: OrbClock.seconds(at: timeline.date) * resolved.speed * speed,
                        dark: dark
                    )
                }
            }
        }
        .frame(width: side, height: side)
        .onViewportVisibilityChange { isOnScreen = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(design.accessibilityLabel))
        .accessibilityAddTraits(.isImage)
    }
}

// MARK: - Drawing

/// One instant of an orb at geometry time `t` (seconds × tuned speed).
struct OrbCanvas: View {
    let resolved: OrbResolved
    let size: OrbSize
    let t: Double
    let dark: Bool

    var body: some View {
        Canvas { context, box in
            let frame = resolved.frame(size: size.length, t: t)
            let unit = size.points
            let scale = min(box.width, box.height) / unit
            context.translateBy(x: (box.width - unit * scale) / 2, y: (box.height - unit * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            Self.paint(frame, dark: dark, in: &context)
        }
    }

    /// Lines first, so nodes sit on top of their edges, then the dots in the
    /// order they arrive (already z-sorted far → near).
    static func paint(_ frame: OrbFrame, dark: Bool, in context: inout GraphicsContext) {
        for line in frame.lines {
            var path = Path()
            path.move(to: CGPoint(x: line.x1, y: line.y1))
            path.addLine(to: CGPoint(x: line.x2, y: line.y2))
            context.opacity = line.a
            context.stroke(path, with: .color(ink(line.white, dark: dark)), lineWidth: line.w)
        }
        for dot in frame.dots {
            let rect = CGRect(x: dot.x - dot.r, y: dot.y - dot.r, width: dot.r * 2, height: dot.r * 2)
            context.opacity = dot.a
            context.fill(Path(ellipseIn: rect), with: .color(ink(dot.white, dark: dark)))
        }
    }

    /// Matte grayscale, one of 256 levels. On a dark ground the ink value is
    /// mirrored so near dots read bright. Quantised to 8 bits exactly as the
    /// web canvas's rgba() string is; alpha rides on the context's opacity,
    /// so no colour is built per dot.
    private static func ink(_ white: Double, dark: Bool) -> Color {
        let w = min(1, max(0, white))
        return inks[Int(((dark ? 1 - w : w) * 255 + 0.5).rounded(.down))]
    }

    private static let inks: [Color] = (0...255).map { Color(.sRGB, white: Double($0) / 255, opacity: 1) }
}

// MARK: - Clock and visibility

/// One shared clock, so every orb on screen runs in phase with every other,
/// whenever it appeared.
enum OrbClock {
    static let origin = Date()

    static func seconds(at date: Date) -> Double {
        // a timeline date can predate the origin, which is set on first use
        max(0, date.timeIntervalSince(origin))
    }
}

extension EnvironmentValues {
    /// Pins every orb and shimmer below to this many seconds on the orb clock.
    /// For deterministic snapshots and rendered media; `nil` runs live.
    @Entry var orbClockOverride: Double? = nil
}

extension View {
    /// Reports whether any of this view is inside the visible bounds of the
    /// scroll views around it, from the very first layout on.
    /// (`onScrollVisibilityChange` only reports crossings, so a view that
    /// starts below the fold would never hear that it is hidden.) Both axes
    /// are checked, so a card in a horizontal carousel that has itself been
    /// scrolled off a vertical page counts as hidden. Outside any scroll view
    /// it reports true.
    func onViewportVisibilityChange(_ action: @escaping (Bool) -> Void) -> some View {
        onGeometryChange(for: Bool.self) { proxy in
            let own = CGRect(origin: .zero, size: proxy.size)
            let vertical = proxy.bounds(of: .scrollView(axis: .vertical))
            let horizontal = proxy.bounds(of: .scrollView(axis: .horizontal))
            return (vertical?.intersects(own) ?? true) && (horizontal?.intersects(own) ?? true)
        } action: { visible in
            action(visible)
        }
    }
}

#Preview("All designs") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(OrbDesign.allCases) { design in
                HStack(spacing: 16) {
                    ThinkingOrb(design)
                    ThinkingOrb(design, size: .small)
                    VStack(alignment: .leading) {
                        Text(design.title).font(.headline)
                        Text(design.summary).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}

//
//  ThinkingOrbLabel.swift
//  ThinkingOrbs
//

import SwiftUI

/// An orb beside a shimmering status line: the standard "the agent is doing
/// something" row. Style it like any other view, with `.font`, `.padding`
/// and a background.
///
/// ```swift
/// ThinkingOrbLabel("Searching the web…", design: .searching)
///
/// ThinkingOrbLabel("Thinking…", design: .breathing, size: .regular)
///     .font(.title3)
///     .padding(.trailing, 24)
///     .background(.thinMaterial, in: .capsule)
/// ```
///
/// VoiceOver reads it as one element: the title.
public struct ThinkingOrbLabel: View {

    let title: Text
    private let design: OrbDesign
    private let size: OrbSize
    private let diameter: CGFloat?
    private let speed: Double
    private let isPaused: Bool

    /// Creates a label whose title is a localized string key. A string literal
    /// lands here, so it is looked up in your app's strings like `Text`'s.
    ///
    /// - Parameters:
    ///   - titleKey: The status line, such as "Reading 14 files…".
    ///   - tableName: The strings table to look the key up in.
    ///   - bundle: The bundle holding that table. `nil` is the main bundle.
    ///   - design: Which orb to show beside it.
    ///   - size: The orb's tuned size. `.small` suits body and caption text.
    ///   - diameter: Draws the orb at another size, in points.
    ///   - speed: A multiplier on the orb's tuned speed.
    ///   - isPaused: Freezes the orb and the shimmer.
    public init(
        _ titleKey: LocalizedStringKey,
        tableName: String? = nil,
        bundle: Bundle? = nil,
        design: OrbDesign,
        size: OrbSize = .small,
        diameter: CGFloat? = nil,
        speed: Double = 1,
        isPaused: Bool = false
    ) {
        self.init(Text(titleKey, tableName: tableName, bundle: bundle), design: design, size: size,
                  diameter: diameter, speed: speed, isPaused: isPaused)
    }

    /// Creates a label that shows a string as-is, without localizing it:
    /// for titles that are already localized, or are user or model content.
    @_disfavoredOverload
    public init<S: StringProtocol>(
        _ title: S,
        design: OrbDesign,
        size: OrbSize = .small,
        diameter: CGFloat? = nil,
        speed: Double = 1,
        isPaused: Bool = false
    ) {
        self.init(Text(title), design: design, size: size, diameter: diameter, speed: speed, isPaused: isPaused)
    }

    /// Creates a label from a `Text`, for a title you have styled or
    /// localized yourself.
    public init(
        _ title: Text,
        design: OrbDesign,
        size: OrbSize = .small,
        diameter: CGFloat? = nil,
        speed: Double = 1,
        isPaused: Bool = false
    ) {
        self.title = title
        self.design = design
        self.size = size
        self.diameter = diameter
        self.speed = speed
        self.isPaused = isPaused
    }

    public var body: some View {
        HStack(spacing: (diameter ?? size.points) > 32 ? 12 : 8) {
            ThinkingOrb(design, size: size, diameter: diameter, speed: speed, isPaused: isPaused)
                .accessibilityHidden(true)
            title
                .lineLimit(1)
                .thinkingShimmer(isActive: !isPaused)
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Sweeps a highlight band across this view every two seconds: the
    /// thinking-orbs "shimmer" that marks a status line as live. The content
    /// sits at half strength with the band passing over it at full strength,
    /// so it keeps its own color and font.
    ///
    /// ```swift
    /// Text("Composing a reply…").thinkingShimmer()
    /// ```
    ///
    /// Under Reduce Motion the band holds still and the content stays at full
    /// strength, as it does with Increase Contrast. Parked while scrolled out
    /// of view.
    public func thinkingShimmer(isActive: Bool = true) -> some View {
        modifier(ThinkingShimmer(isActive: isActive))
    }
}

/// The web demo's `t-shimmer`: half-strength content underneath, full-strength
/// content in a band 0.8 of the width wide, travelling left to right over two
/// seconds, linearly.
private struct ThinkingShimmer: ViewModifier {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.orbClockOverride) private var clockOverride
    @State private var isOnScreen = true

    /// The dimmed base only exists as a backdrop for the moving band. With no
    /// band (Reduce Motion) or when legibility comes first (Increase
    /// Contrast), the text stays at full strength.
    private var baseOpacity: Double {
        if clockOverride == nil && reduceMotion { return 1 }
        if contrast == .increased { return 1 }
        return colorScheme == .dark ? 0.5 : 0.45
    }

    func body(content: Content) -> some View {
        content
            .opacity(baseOpacity)
            .overlay {
                if let time = clockOverride {
                    band(content, at: time)
                } else if !reduceMotion {
                    TimelineView(.animation(paused: !isActive || !isOnScreen)) { timeline in
                        band(content, at: OrbClock.seconds(at: timeline.date))
                    }
                }
            }
            .onViewportVisibilityChange { isOnScreen = $0 }
    }

    private func band(_ content: Content, at seconds: Double) -> some View {
        let q = (seconds / 2) - (seconds / 2).rounded(.down)
        return content
            .mask {
                GeometryReader { geo in
                    let w = geo.size.width
                    LinearGradient(colors: [.clear, .black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: w * 0.8)
                        .offset(x: -w + 3 * w * q - w * 0.4)
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview("Labels") {
    VStack(alignment: .leading, spacing: 16) {
        ThinkingOrbLabel("Searching the web…", design: .searching)
        ThinkingOrbLabel("Reading 14 files…", design: .working)
            .font(.footnote)
        ThinkingOrbLabel("Thinking…", design: .breathing, size: .regular, diameter: 44)
            .font(.title3)
            .padding(6)
            .padding(.trailing, 18)
            .background(.thinMaterial, in: .capsule)
        Text("Composing a reply…").thinkingShimmer()
    }
    .padding()
}

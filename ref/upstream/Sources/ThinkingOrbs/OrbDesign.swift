//
//  OrbDesign.swift
//  ThinkingOrbs
//

import CoreGraphics

/// The nine orb designs. Each is its own hand-tuned animation for one thing an
/// AI or agent can be doing, so pick the design that says what is happening.
///
/// ```swift
/// ThinkingOrb(.searching)
/// ThinkingOrb(.composing, size: .small)
/// ```
public enum OrbDesign: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    /// Particles on tilted orbits. General-purpose "busy".
    case working
    /// A scan meridian sweeps a dotted globe. Web search, retrieval, lookup.
    case searching
    /// Bands scramble in quarter turns, then click back solved. Reasoning, math, code.
    case solving
    /// A waveform rolls through the latitude rings. Voice input, transcription.
    case listening
    /// A constellation wires itself, packets running the edges. Tool calls, APIs, sync.
    case connecting
    /// Three strands plait around the sphere. Planning, multi-step agents.
    case weaving
    /// An undulating multi-band sash. Writing, generating a reply.
    case composing
    /// A face-on ring slowly morphing. Idle thinking, waiting on a model.
    case breathing
    /// A dotted outline morphing circle → triangle → square. Design, image, layout work.
    case shaping

    public var id: String { rawValue }

    /// The design's display name, such as "Searching".
    public var title: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    /// One line on what the animation shows.
    public var summary: String {
        switch self {
        case .working: return "Particles on tilted orbits"
        case .searching: return "A scan meridian sweeps a dotted globe"
        case .solving: return "Bands scramble, then click back solved"
        case .listening: return "A waveform rolls through the rings"
        case .connecting: return "A constellation wires itself"
        case .weaving: return "Three strands plait around the sphere"
        case .composing: return "An undulating multi-band sash"
        case .breathing: return "A ring slowly morphing"
        case .shaping: return "Circle → triangle → square"
        }
    }

    /// The VoiceOver label a ``ThinkingOrb`` reads unless you set your own.
    public var accessibilityLabel: String {
        switch self {
        case .breathing: return "Thinking…"
        default: return title + "…"
        }
    }
}

/// The two tuned sizes. They are separate designs, not one design scaled:
/// each carries its own dot count, dot size and speed.
public enum OrbSize: Int, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    /// 64 pt, for chat avatars, empty states and hero moments.
    case regular = 64
    /// 20 pt, for sitting inline with text: status chips, toolbars, list rows.
    case small = 20

    public var id: Int { rawValue }

    /// The size's side length in points.
    public var points: CGFloat { CGFloat(rawValue) }

    var length: Double { Double(rawValue) }
}

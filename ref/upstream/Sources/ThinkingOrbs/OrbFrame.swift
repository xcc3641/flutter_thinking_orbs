//
//  OrbFrame.swift
//  ThinkingOrbs
//
//  The geometry surface, for anyone who wants to draw the orbs themselves
//  (SpriteKit, Metal, a watch complication, a plotter). A frame is a finished
//  draw list: every value is final and the array order is the draw order.
//

import Foundation

/// One dot in a frame, in the frame's own point space (0…size on both axes).
public struct OrbDot: Equatable, Sendable {
    public var x: Double
    public var y: Double
    /// Depth: larger is nearer. Its scale depends on the design (a unit sphere
    /// for some, points for others, always 0 for `.shaping`), so use it for
    /// ordering or relative shading only. Dots are already sorted by it.
    public var z: Double
    public var r: Double
    /// Ink on paper, 0 (darkest) to 1 (white). Mirror it (`1 - white`) on a
    /// dark background so near dots read bright.
    public var white: Double
    /// Opacity, 0 to 1.
    public var a: Double = 1
}

/// A stroked edge between two dots (only `.connecting` draws these).
public struct OrbLine: Equatable, Sendable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double
    /// Ink on paper, as ``OrbDot/white``.
    public var white: Double
    /// Opacity, 0 to 1.
    public var a: Double = 1
    /// Stroke width in points.
    public var w: Double
}

/// One finished instant of an orb. Draw ``lines`` first, then ``dots`` in
/// array order (far to near), as grayscale circle fills.
public struct OrbFrame: Sendable {
    public var dots: [OrbDot]
    public var lines: [OrbLine]
}

extension OrbDesign {

    /// The draw list for this design at `time` seconds on the orb clock, at
    /// the tuned speed, in a box of `size.points` × `size.points`.
    ///
    /// ``ThinkingOrb`` draws exactly this, so a custom renderer that paints
    /// the frame gets the same picture.
    public func frame(size: OrbSize = .regular, at time: TimeInterval) -> OrbFrame {
        let resolved = OrbPresets.resolve(self, size)
        return resolved.frame(size: size.length, t: time * resolved.speed)
    }
}

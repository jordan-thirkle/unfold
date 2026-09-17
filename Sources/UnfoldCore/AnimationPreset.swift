import Foundation

/// Timing curves for the fold. Pure functions of `t` in 0...1.
public enum Easing: String, Codable, CaseIterable, Sendable {
    case linear
    case easeOut
    case easeInOut

    /// `value(0) == 0` and `value(1) == 1` hold exactly for every case, which
    /// is what lets the simulation assert a finished fold is truly finished.
    public func value(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        switch self {
        case .linear:
            return x
        case .easeOut:
            // 1 - (1 - x)^3
            let inv = 1 - x
            return 1 - (inv * inv * inv)
        case .easeInOut:
            if x < 0.5 {
                return 4 * x * x * x
            }
            let inv = -2 * x + 2
            return 1 - (inv * inv * inv) / 2
        }
    }
}

/// Direction the two panels retract along.
public enum FoldAxis: String, Codable, CaseIterable, Sendable {
    /// Hinge is vertical; panels split left/right — the "device opening" read.
    case vertical
    /// Hinge is horizontal; panels split top/bottom — the "lid opening" read.
    case horizontal
}

/// A named, self-contained description of one fold.
///
/// Presets hold no mutable state and no rendering code, so a new animation is
/// added by describing it here rather than by touching the renderer.
public struct AnimationPreset: Equatable, Sendable, Codable {
    public var id: String
    public var name: String
    public var summary: String
    public var axis: FoldAxis
    public var easing: Easing
    /// How much of the open animation is spent fading the panels out, 0...1.
    public var fadeFraction: Double

    public init(
        id: String,
        name: String,
        summary: String,
        axis: FoldAxis,
        easing: Easing,
        fadeFraction: Double
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.axis = axis
        self.easing = easing
        self.fadeFraction = min(max(fadeFraction, 0), 1)
    }

    /// Pure mapping from progress to geometry. No time, no randomness, no I/O.
    public func state(at progress: Double) -> FoldState {
        let p = min(max(progress, 0), 1)
        let inset = p
        let angle = 180 * p
        let fadeStart = 1 - fadeFraction
        let opacity: Double
        if p <= fadeStart {
            opacity = 1
        } else if fadeFraction <= 0 {
            opacity = p >= 1 ? 0 : 1
        } else {
            opacity = 1 - ((p - fadeStart) / fadeFraction)
        }
        // The seam highlight peaks early, then decays: it reads as the light
        // catching the hinge as it opens, not as a persistent line.
        let glow = max(0, 1 - (p * 1.4))
        return FoldState(
            progress: p,
            hingeAngle: angle,
            panelInset: inset,
            opacity: min(max(opacity, 0), 1),
            seamGlow: min(max(glow, 0), 1)
        )
    }

    public static let unfold = AnimationPreset(
        id: "unfold",
        name: "Unfold",
        summary: "Two panels part from the centre, hinge light along the seam.",
        axis: .vertical,
        easing: .easeOut,
        fadeFraction: 0.35
    )

    public static let lid = AnimationPreset(
        id: "lid",
        name: "Lid",
        summary: "Top and bottom halves open away from the seam.",
        axis: .horizontal,
        easing: .easeInOut,
        fadeFraction: 0.3
    )

    public static let iris = AnimationPreset(
        id: "iris",
        name: "Iris",
        summary: "Panels retreat fast and early, leaving a soft centred glow.",
        axis: .vertical,
        easing: .easeInOut,
        fadeFraction: 0.5
    )

    public static let quiet = AnimationPreset(
        id: "quiet",
        name: "Quiet",
        summary: "Short linear retraction with almost no highlight.",
        axis: .vertical,
        easing: .linear,
        fadeFraction: 0.25
    )

    public static let all: [AnimationPreset] = [.unfold, .lid, .iris, .quiet]

    public static let fallback = AnimationPreset.unfold

    public static func preset(id: String) -> AnimationPreset {
        all.first { $0.id == id } ?? fallback
    }
}
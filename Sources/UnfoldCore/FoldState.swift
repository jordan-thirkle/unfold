import Foundation

/// The rendered geometry of a fold at one instant.
///
/// Deliberately a plain value type: the renderer reads it, nothing mutates it,
/// and two runs that reach the same `progress` produce byte-identical values.
public struct FoldState: Equatable, Sendable {
    /// 0 = fully closed (screen covered), 1 = fully open (screen clear).
    public var progress: Double
    /// Hinge rotation in degrees, 0...180.
    public var hingeAngle: Double
    /// How far each panel has retracted, as a fraction of its travel, 0...1.
    public var panelInset: Double
    /// Panel alpha. Reaches 0 before `progress` reaches 1 so there is never a
    /// hard edge left on screen.
    public var opacity: Double
    /// Intensity of the seam highlight along the hinge, 0...1.
    public var seamGlow: Double

    public init(
        progress: Double,
        hingeAngle: Double,
        panelInset: Double,
        opacity: Double,
        seamGlow: Double
    ) {
        self.progress = progress
        self.hingeAngle = hingeAngle
        self.panelInset = panelInset
        self.opacity = opacity
        self.seamGlow = seamGlow
    }

    /// Everything covered — the moment the animation starts.
    public static let closed = FoldState(
        progress: 0,
        hingeAngle: 0,
        panelInset: 0,
        opacity: 1,
        seamGlow: 1
    )

    /// Everything clear — the desktop is unobstructed.
    public static let open = FoldState(
        progress: 1,
        hingeAngle: 180,
        panelInset: 1,
        opacity: 0,
        seamGlow: 0
    )

    public var isFullyOpen: Bool { progress >= 1 }

    /// True when nothing would be drawn — used to skip a frame entirely.
    public var isInvisible: Bool { opacity <= 0.001 || panelInset >= 1 }
}
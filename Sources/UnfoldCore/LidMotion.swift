import Foundation

/// Pure angle mapping. Units are degrees; no device or rendering dependencies.
public enum LidMotion {
    public static func progress(angle: Double, openAngle: Double) -> Double {
        guard angle.isFinite, openAngle.isFinite, openAngle >= 40 else { return 0 }
        return min(1, max(0, (openAngle - angle) / (openAngle - 10)))
    }

    /// Time-based, bounded smoothing: no prediction or overshoot on reversals.
    public static func smooth(current: Double, target: Double, dt: Double) -> Double {
        guard current.isFinite, target.isFinite, dt.isFinite, dt > 0 else { return current }
        return current + (target - current) * (1 - exp(-min(dt, 0.1) / 0.055))
    }

    public static func previewProgress(seconds: Double) -> Double {
        guard seconds.isFinite else { return 0 }
        let phase = min(1, max(0, seconds / 4))
        return 0.82 * pow(sin(.pi * phase), 2)
    }
}

/// Invalidates asynchronous capture completions across stop/restart boundaries.
public struct CaptureGeneration: Sendable {
    public private(set) var value: UInt = 0
    public init() {}
    public mutating func invalidate() { value &+= 1 }
    public func accepts(_ token: UInt) -> Bool { token == value }
}

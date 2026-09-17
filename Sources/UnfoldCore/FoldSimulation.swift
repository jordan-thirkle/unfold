import Foundation

/// Fixed-timestep fold simulation.
///
/// Time is accumulated as **integer nanoseconds** and consumed in fixed steps,
/// so the state after N seconds does not depend on how those seconds were
/// delivered. One `advance(by: 0.5)` and fifty `advance(by: 0.01)` calls reach
/// byte-identical state, which is what makes the fold testable without a
/// display and reproducible in a bug report.
public struct FoldSimulation: Sendable {

    /// 125 Hz. Chosen because 8 ms is an exact integer number of nanoseconds,
    /// so `stepNanos` never introduces rounding error, and 125 Hz is faster
    /// than any display the frames are sampled on.
    public static let stepNanos: Int = 8_000_000

    /// Nanoseconds as a Double, computed once.
    public static let stepSeconds: Double = Double(stepNanos) / 1_000_000_000

    public let preset: AnimationPreset
    public let duration: Double

    /// Completed fixed steps.
    public private(set) var ticks: Int = 0
    /// Total steps this run will take. Zero for an instantaneous fold.
    public private(set) var durationTicks: Int

    private var pendingNanos: Int = 0
    private var hasStarted = false
    private var hasFinished = false

    public init(preset: AnimationPreset, duration: Double) {
        self.preset = preset
        self.duration = max(duration, 0)
        self.durationTicks = Int((max(duration, 0) / Self.stepSeconds).rounded())
    }

    /// Simulated time consumed so far. Depends only on completed steps.
    public var elapsed: Double {
        Double(ticks) * Self.stepSeconds
    }

    /// Linear progress before easing, clamped to 0...1.
    public var rawProgress: Double {
        guard durationTicks > 0 else { return 1 }
        return min(1, Double(ticks) / Double(durationTicks))
    }

    /// Eased progress — the value the preset maps to geometry.
    public var progress: Double {
        preset.easing.value(rawProgress)
    }

    /// Current renderable state.
    public var state: FoldState {
        preset.state(at: progress)
    }

    public var isFinished: Bool { hasFinished }

    /// Feeds time in and returns what happened, in order.
    ///
    /// Non-finite or non-positive input is ignored rather than trapping — a
    /// dropped frame must never crash the overlay.
    public mutating func advance(by seconds: Double) -> [UnfoldEvent] {
        guard seconds.isFinite, seconds > 0 else { return [] }

        pendingNanos += Int((seconds * 1_000_000_000).rounded())

        var events: [UnfoldEvent] = []
        if !hasStarted {
            hasStarted = true
            events.append(.started)
        }

        while pendingNanos >= Self.stepNanos {
            pendingNanos -= Self.stepNanos
            if ticks < durationTicks {
                ticks += 1
            }
            if ticks >= durationTicks {
                if !hasFinished {
                    hasFinished = true
                    events.append(.finished)
                }
            } else {
                events.append(.ticked(progress: progress))
            }
        }

        // A fold with no duration is already over before any time is fed in.
        // Without this, `durationTicks == 0` would leave the fold unannounced
        // until a whole step of time had passed.
        if durationTicks == 0 && !hasFinished {
            hasFinished = true
            events.append(.finished)
        }

        return events
    }

    /// Jumps straight to the end without animating.
    ///
    /// Used when Reduce Motion is on: the correct behaviour is "no animation",
    /// not "animation with a shorter duration".
    public mutating func completeImmediately() -> [UnfoldEvent] {
        guard !hasFinished else { return [] }
        var events: [UnfoldEvent] = []
        if !hasStarted {
            hasStarted = true
            events.append(.started)
        }
        ticks = durationTicks
        pendingNanos = 0
        hasFinished = true
        events.append(.finished)
        return events
    }
}
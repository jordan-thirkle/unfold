import AppKit
import UnfoldCore

/// Owns the overlay windows and drives the simulation clock.
///
/// The windows are created ahead of time (`prearm`) and ordered out, so when
/// the session becomes active the fold can be shown in the same run loop
/// turn — otherwise a frame of the bare desktop flashes through first.
@MainActor
final class OverlayPresenter {

    private var windows: [OverlayWindow] = []
    private var views: [FoldOverlayView] = []
    private var simulation: FoldSimulation?
    private var timer: Timer?
    private var lastTick: CFTimeInterval = 0
    private var reversed = false

    /// 60 Hz sampling. The simulation quantises to its own fixed step, so a
    /// slow or fast timer changes smoothness, never the final state.
    private static let sampleInterval: TimeInterval = 1.0 / 60.0

    /// Events are the only thing this class tells the rest of the app about.
    var onEvent: ((UnfoldEvent) -> Void)?
    var onProblem: ((String) -> Void)?

    var isPresenting: Bool { simulation != nil }

    init() {
        rebuildWindows()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Creates an overlay per screen, hidden and ready.
    func prearm() {
        if windows.isEmpty { rebuildWindows() }
    }

    func play(preset: AnimationPreset, duration: Double, reversed: Bool) {
        if windows.isEmpty { rebuildWindows() }

        let sim = FoldSimulation(preset: preset, duration: duration)
        simulation = sim
        self.reversed = reversed
        lastTick = CACurrentMediaTime()

        // Direction belongs to the preset, not the view's default axis.
        for view in views {
            view.axis = preset.axis
        }
        apply(sim)
        for window in windows {
            window.orderFrontRegardless()
        }
        // The simulation emits .started on its first tick. Do not duplicate it.

        timer?.invalidate()
        let timer = Timer.scheduledTimer(
            timeInterval: Self.sampleInterval,
            target: self,
            selector: #selector(step),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func dismiss() {
        timer?.invalidate()
        timer = nil
        simulation = nil
        for window in windows {
            window.orderOut(nil)
        }
    }

    @objc private func step() {
        guard var sim = simulation else {
            dismiss()
            return
        }

        let now = CACurrentMediaTime()
        // Clamp the delta so a stalled run loop never fast-forwards the fold
        // into a jump cut.
        let delta = min(max(now - lastTick, 0), 0.1)
        lastTick = now

        // `advance` reports `.finished` exactly once, on the step that
        // completes the fold — so this method only has to forward events.
        let events = sim.advance(by: delta)
        apply(sim)
        simulation = sim

        for event in events {
            onEvent?(event)
        }

        if sim.isFinished {
            dismiss()
        }
    }

    /// Reverse time before easing; complementing geometry loses nonlinear fades.
    static func renderState(for simulation: FoldSimulation, reversed: Bool) -> FoldState {
        guard reversed else { return simulation.state }
        return simulation.preset.state(at: simulation.preset.easing.value(1 - simulation.rawProgress))
    }

    private func apply(_ simulation: FoldSimulation) {
        let rendered = Self.renderState(for: simulation, reversed: reversed)
        for view in views {
            view.state = rendered
        }
    }

    @objc private func screenParametersChanged() {
        rebuildWindows()
    }

    private func rebuildWindows() {
        dismiss()
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        views.removeAll()

        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)
            let view = FoldOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.autoresizingMask = [.width, .height]
            window.contentView = view
            windows.append(window)
            views.append(view)
        }

        if windows.isEmpty {
            // No silent failure: an app with no windows must say so.
            onProblem?("No screens available to draw on; the animation can't run.")
        }
    }
}
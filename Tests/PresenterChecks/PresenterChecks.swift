import AppKit
import UnfoldCore

/// Runs the production presenter and renderer with a real AppKit run loop.
/// Requires a logged-in graphical session, but no UI scripting or screenshots.
@main
struct PresenterChecks {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        var failures = 0
        var starts = 0
        var finishes = 0
        func check(_ condition: Bool, _ name: String) {
            print("\(condition ? "pass" : "FAIL")  \(name)")
            if !condition { failures += 1 }
        }
        guard !NSScreen.screens.isEmpty else {
            print("FAIL: presenter checks require a graphical session")
            exit(1)
        }
        let presenter = OverlayPresenter()
        defer { presenter.dismiss() }
        let windows = app.windows.compactMap { $0 as? OverlayWindow }
        let views = windows.compactMap { $0.contentView as? FoldOverlayView }
        check(views.count == NSScreen.screens.count, "one render view per screen")
        check(windows.allSatisfy { $0.ignoresMouseEvents && !$0.canBecomeKey }, "overlays never intercept input")

        for preset in AnimationPreset.all {
            starts = 0
            finishes = 0
            var ticks = 0
            presenter.onEvent = { event in
                switch event {
                case .started: starts += 1
                case .finished: finishes += 1
                case .ticked: ticks += 1
                }
            }
            presenter.play(preset: preset, duration: 0.24, reversed: false)
            check(presenter.isPresenting && windows.allSatisfy(\.isVisible), "\(preset.id): play shows windows")
            check(views.allSatisfy { $0.axis == preset.axis }, "\(preset.id): selected axis reaches renderer")
            check(views.allSatisfy { $0.state == preset.state(at: 0) }, "\(preset.id): initial rendered state")
            var sawIntermediate = false
            let deadline = Date().addingTimeInterval(3)
            while presenter.isPresenting && Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.005))
                sawIntermediate = sawIntermediate || views.contains { $0.state.progress > 0 && $0.state.progress < 1 }
            }
            check(sawIntermediate && ticks > 0, "\(preset.id): timer advances rendered state")
            check(!presenter.isPresenting && windows.allSatisfy { !$0.isVisible }, "\(preset.id): completes and hides within timeout")
            check(views.allSatisfy { $0.state == preset.state(at: 1) }, "\(preset.id): final rendered state")
            check(starts == 1 && finishes == 1, "\(preset.id): exactly one start and finish (got \(starts)/\(finishes))")
            presenter.dismiss()
        }

        // The close path mirrors the state in `apply`, so it gets its own
        // end-to-end run: a reversed play must start from the fully open
        // state, finish exactly covered, and announce itself once.
        starts = 0
        finishes = 0
        presenter.onEvent = { event in
            switch event {
            case .started: starts += 1
            case .finished: finishes += 1
            case .ticked: break
            }
        }
        presenter.play(preset: AnimationPreset.unfold, duration: 0.24, reversed: true)
        check(views.allSatisfy { $0.state == FoldState.open }, "reversed play starts from the open state")
        let closeDeadline = Date().addingTimeInterval(3)
        while presenter.isPresenting && Date() < closeDeadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.005))
        }
        check(!presenter.isPresenting && windows.allSatisfy { !$0.isVisible }, "reversed play completes and hides")
        check(views.allSatisfy { $0.state == FoldState.closed }, "reversed play ends exactly covered")
        check(starts == 1 && finishes == 1, "reversed play announces start and finish once each (got \(starts)/\(finishes))")

        print("Presenter checks: \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}

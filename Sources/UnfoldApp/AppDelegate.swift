import AppKit
import UnfoldCore

/// Wires system signals to the overlay.
///
/// The sequencing here is the whole trick of the product. A wake is not the
/// same as "the desktop is now visible": if the Mac requires a password, the
/// desktop appears only after unlock, and if it doesn't, the desktop appears
/// immediately. Playing on the wrong one produces either a missed animation or
/// one that races the unlock screen, so both paths are handled explicitly.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let monitor = SystemEventMonitor()
    private let presenter = OverlayPresenter()
    private var menuBar: MenuBarController?
    private var store: UnfoldConfigStore?
    private var configuration = UnfoldConfiguration.default

    private var lastOpenPlay: CFTimeInterval = 0
    private var wakeTimer: Timer?

    /// Guards against a double play when several signals arrive together
    /// (wake + session activation + unlock can all land within a few frames).
    private static let openCooldown: CFTimeInterval = 1.5

    func applicationDidFinishLaunching(_ notification: Notification) {
        var problem: String?

        do {
            let directory = try UnfoldConfigStore.defaultDirectory()
            let configStore = UnfoldConfigStore(directory: directory)
            store = configStore
            let loaded = configStore.load()
            configuration = loaded.configuration
            problem = loaded.problem
        } catch {
            problem = "Could not create the settings folder (\(error.localizedDescription)). Defaults are in use and changes won't be saved."
        }

        menuBar = MenuBarController(
            configuration: configuration,
            problem: problem,
            onPreview: { [weak self] in self?.preview() },
            onConfigChanged: { [weak self] updated in self?.persist(updated) }
        )

        presenter.onProblem = { [weak self] message in
            self?.menuBar?.report(message)
        }
        presenter.prearm()

        monitor.onSignal = { [weak self] signal in
            self?.handle(signal)
        }
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        presenter.dismiss()
    }

    private func handle(_ signal: SystemSignal) {
        switch signal {
        case .woke, .screensWoke:
            // Get the windows ready before the user has finished typing.
            presenter.prearm()
            armWakeCheck()
        case .screenUnlocked:
            playOpen()
        case .sessionActivated:
            // Login or fast-user-switch return. Only animate when the desktop
            // is genuinely visible.
            if !SystemEventMonitor.isScreenLocked() {
                playOpen()
            }
        case .willSleep, .screenLocked:
            playClose()
        case .screensSlept, .sessionResigned, .screenSaverStarted:
            break
        }
    }

    /// After a wake, gives the system a moment, then checks whether a password
    /// is still standing between the user and the desktop.
    private func armWakeCheck() {
        wakeTimer?.invalidate()
        let timer = Timer.scheduledTimer(
            timeInterval: 0.35,
            target: self,
            selector: #selector(wakeCheck),
            userInfo: nil,
            repeats: false
        )
        RunLoop.main.add(timer, forMode: .common)
        wakeTimer = timer
    }

    @objc private func wakeCheck() {
        // Locked means the overlay would land on the password prompt, where
        // macOS won't draw it anyway. Wait for the unlock signal instead.
        guard !SystemEventMonitor.isScreenLocked() else { return }
        playOpen()
    }

    private func playOpen() {
        guard configuration.animateOnOpen else { return }
        guard reduceMotionAllowsAnimation else { return }

        let now = CACurrentMediaTime()
        guard now - lastOpenPlay > Self.openCooldown else { return }
        lastOpenPlay = now

        presenter.play(
            preset: configuration.preset,
            duration: configuration.openDuration,
            reversed: false
        )
    }

    private func playClose() {
        guard configuration.animateOnClose else { return }
        guard reduceMotionAllowsAnimation else { return }
        // Never interrupt the opening animation with the closing one.
        guard !presenter.isPresenting else { return }

        presenter.play(
            preset: configuration.preset,
            duration: configuration.closeDuration,
            reversed: true
        )
    }

    /// Reduce Motion is honoured as "no animation", not "faster animation".
    private var reduceMotionAllowsAnimation: Bool {
        guard configuration.respectReduceMotion else { return true }
        return !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Preview always plays: it is an explicit action, so the Reduce Motion
    /// setting must not make the menu item look broken.
    private func preview() {
        lastOpenPlay = CACurrentMediaTime()
        presenter.play(
            preset: configuration.preset,
            duration: configuration.openDuration,
            reversed: false
        )
    }

    private func persist(_ updated: UnfoldConfiguration) {
        configuration = updated
        guard let store else { return }
        do {
            try store.save(updated)
            menuBar?.report(nil)
        } catch {
            menuBar?.report("Could not save settings: \(error.localizedDescription)")
        }
    }
}
import AppKit
import CoreGraphics
import IOKit

/// Every system signal the app reacts to, in one vocabulary.
public enum SystemSignal: Equatable, Sendable {
    case woke
    case willSleep
    case screensWoke
    case screensSlept
    case sessionActivated
    case sessionResigned
    case screenUnlocked
    case screenLocked
    case screenSaverStarted
}

/// Translates macOS power/session/lid state into `SystemSignal` values.
///
/// Two of these are worth being explicit about, because they are the reason
/// the product is narrower than it first looks:
///
/// * `NSWorkspace` has **no** lock or unlock notification. `screenUnlocked`
///   and `screenLocked` therefore come from the undocumented distributed
///   notifications `com.apple.screenIsUnlocked` / `com.apple.screenIsLocked`.
///   They work, but they are not a documented API and can change.
/// * The lid is read from the IOKit registry key `AppleClamshellState`, which
///   is polled rather than pushed.
@MainActor
final class SystemEventMonitor: NSObject {

    var onSignal: ((SystemSignal) -> Void)?

    private var lastLidClosed: Bool?
    private var lidTimer: Timer?

    func start() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(self, selector: #selector(handleWake), name: NSWorkspace.didWakeNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleScreensWoke), name: NSWorkspace.screensDidWakeNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleScreensSlept), name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleSessionActivated), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleSessionResigned), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)

        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(
            self,
            selector: #selector(handleScreenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        distributed.addObserver(
            self,
            selector: #selector(handleScreenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        distributed.addObserver(
            self,
            selector: #selector(handleScreenSaverStarted),
            name: NSNotification.Name("com.apple.screensaver.didstart"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        startLidPolling()
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        lidTimer?.invalidate()
        lidTimer = nil
    }

    // MARK: - Lid

    /// Reads `AppleClamshellState` from the power-management root domain.
    /// Returns nil when the key is absent (for example on a desktop Mac).
    static func isLidClosed() -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        guard let property = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else {
            return nil
        }
        return property as? Bool
    }

    /// True when the screen is locked. Used to decide whether the desktop is
    /// already visible or still behind the password prompt.
    static func isScreenLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return false
        }
        return (session["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }

    private func startLidPolling() {
        // Clamshell state has no notification, so it is polled. Once a second
        // distinguishes "lid opened" from "woke for another reason" for the
        // cost of a single registry read.
        let timer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(pollLid),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        lidTimer = timer
    }

    /// Keeps the lid transition observable. The app reacts to wake/sleep
    /// events directly, so this only records state — it must not trigger a
    /// second open animation.
    @objc private func pollLid() {
        guard let closed = Self.isLidClosed() else { return }
        lastLidClosed = closed
    }

    // MARK: - Observers

    @objc private func handleWake(_ note: Notification) { onSignal?(.woke) }
    @objc private func handleWillSleep(_ note: Notification) { onSignal?(.willSleep) }
    @objc private func handleScreensWoke(_ note: Notification) { onSignal?(.screensWoke) }
    @objc private func handleScreensSlept(_ note: Notification) { onSignal?(.screensSlept) }
    @objc private func handleSessionActivated(_ note: Notification) { onSignal?(.sessionActivated) }
    @objc private func handleSessionResigned(_ note: Notification) { onSignal?(.sessionResigned) }
    @objc private func handleScreenUnlocked(_ note: Notification) { onSignal?(.screenUnlocked) }
    @objc private func handleScreenLocked(_ note: Notification) { onSignal?(.screenLocked) }
    @objc private func handleScreenSaverStarted(_ note: Notification) { onSignal?(.screenSaverStarted) }
}
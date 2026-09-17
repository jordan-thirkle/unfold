import AppKit
import ScreenCaptureKit
import QuartzCore
import UnfoldCore
import OSLog

@MainActor
final class SnapshotFoldController: NSObject {
    var onStatus: ((String) -> Void)?
    var onModeChanged: ((Bool) -> Void)?
    private(set) var isEnabled = false
    var isBusy: Bool { isEnabled || captureTask != nil || window != nil }
    private let sensor = LidAngleReader()
    private let log = Logger(subsystem: "com.byjtt.unfold", category: "snapshot")
    private var timer: Timer?
    private var link: CADisplayLink?
    private var captureTask: Task<Void, Never>?
    private var generation = CaptureGeneration()
    private var window: OverlayWindow?
    private var view: SnapshotFoldView?
    private var openAngle = 90.0
    private var target = 0.0
    private var progress = 0.0
    private var lastFrame = 0.0
    private var started = 0.0
    private var preview = false

    static var desktopAvailable: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any],
              session[kCGSessionOnConsoleKey as String] as? Bool == true else { return false }
        return session["CGSSessionScreenIsLocked"] as? Bool != true
    }

    func enable() {
        stop()
        guard consent() else { return }
        guard let angle = sensor.read(), angle >= 40 else {
            status("No usable lid sensor, or lid below 40°. Use Snapshot preview instead.")
            return
        }
        openAngle = angle
        isEnabled = true
        onModeChanged?(true)
        status("Lid tracking: calibrated at \(Int(angle))°. Close slightly to start; 30-second safety limit.")
        let t = Timer(timeInterval: 0.1, target: self, selector: #selector(poll), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func showPreview() {
        Self.debugLog.notice("showPreview entered")
        stop()
        guard consent() else { return }
        preview = true
        beginCapture()
    }

    static let debugLog = Logger(subsystem: "com.byjtt.unfold", category: "snapshot")

    private func consent() -> Bool {
        guard Self.desktopAvailable else { status("Snapshot unavailable: desktop session is not active."); return false }
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            status("Snapshot motion is disabled by macOS Reduce Motion."); return false
        }
        let alert = NSAlert()
        alert.messageText = "Preview your desktop as a folding snapshot?"
        alert.informativeText = "Captures the built-in display (or main display for preview). Images stay in memory until stopped. Nothing is saved or uploaded. macOS may show a recording indicator. Tracking is session-only and stops on lock, sleep or display changes."
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        guard CGPreflightScreenCaptureAccess() else {
            _ = CGRequestScreenCaptureAccess()
            status("Allow Screen Recording for Unfold in System Settings, then try again; relaunch if requested.")
            return false
        }
        return true
    }

    @objc private func poll() {
        guard Self.desktopAvailable, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            stop(message: "Snapshot stopped: session unavailable or Reduce Motion enabled."); return
        }
        guard let angle = sensor.read() else {
            stop(message: "Snapshot stopped: lid sensor read failed. Re-enable to retry."); return
        }
        target = LidMotion.progress(angle: angle, openAngle: openAngle)
        if angle >= openAngle - 1 {
            if window != nil || captureTask != nil { clearCapture() }
        } else if angle < openAngle - 3 && window == nil && captureTask == nil {
            beginCapture()
        }
    }
    private func beginCapture() {
        let screen = NSScreen.screens.first { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return false }
            return CGDisplayIsBuiltin(id) != 0
        } ?? (preview ? NSScreen.main : nil)
        guard let screen, let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else {
            stop(message: "No built-in display available for tracking."); return
        }
        generation.invalidate()
        let token = generation.value
        status("Capturing snapshot…")

        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard self.generation.accepts(token), Self.desktopAvailable, !Task.isCancelled else { return }
                guard let display = content.displays.first(where: { $0.displayID == id }) else {
                    self.stop(message: "Display disappeared before capture."); return
                }
                let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
                let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
                let config = SCStreamConfiguration()
                config.width = CGDisplayPixelsWide(id)
                config.height = CGDisplayPixelsHigh(id)
                config.showsCursor = false
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                guard self.generation.accepts(token), Self.desktopAvailable, !Task.isCancelled else { return }
                self.captureTask = nil
                self.present(image, on: screen)
            } catch {
                guard self.generation.accepts(token) else { return }
                self.stop(message: "Snapshot capture failed: \(error.localizedDescription)")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.generation.accepts(token), self.captureTask != nil else { return }
            self.stop(message: "Snapshot capture timed out. Try again.")
        }
    }

    private func present(_ image: CGImage, on screen: NSScreen) {
        let w = OverlayWindow(screen: screen)
        // Ordinary floating level, not a private lock-screen space.
        w.level = .floating
        let v = SnapshotFoldView(frame: CGRect(origin: .zero, size: screen.frame.size), image: image)
        w.contentView = v
        view = v
        window = w
        started = CACurrentMediaTime()
        lastFrame = started
        progress = 0
        w.orderFrontRegardless()
        let displayLink = screen.displayLink(target: self, selector: #selector(frame))
        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
        displayLink.add(to: .main, forMode: .common)
        link = displayLink
        status(preview ? "Snapshot preview playing (4 seconds)." : "Following lid; Stop snapshot effect is available in the menu.")
    }

    @objc private func frame() {
        let now = CACurrentMediaTime()
        guard Self.desktopAvailable, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            stop(message: "Snapshot stopped: desktop unavailable or Reduce Motion enabled."); return
        }
        guard now - lastFrame < 0.5 else {
            stop(message: "Snapshot stopped after a stalled frame clock."); return
        }
        if now - started > (preview ? 4 : 30) {
            stop(message: preview ? "Snapshot preview complete." : "Snapshot safety timeout; re-enable to continue.")
            return
        }
        let desired = preview ? LidMotion.previewProgress(seconds: now - started) : target
        progress = preview ? desired : LidMotion.smooth(current: progress, target: desired, dt: now - lastFrame)
        lastFrame = now
        view?.update(progress: progress)
    }

    private func clearCapture() {
        generation.invalidate()
        captureTask?.cancel()
        captureTask = nil
        link?.invalidate()
        link = nil
        window?.orderOut(nil)
        view?.clear()
        window?.contentView = nil
        window = nil
        view = nil
        progress = 0
    }

    func stop(message: String? = nil) {
        timer?.invalidate()
        timer = nil
        sensor.close()
        clearCapture()
        isEnabled = false
        preview = false
        onModeChanged?(false)
        if let message { status(message) }
    }

    private func status(_ text: String) {
        Self.debugLog.notice("\(text, privacy: .public)")
        onStatus?(text)
    }
}

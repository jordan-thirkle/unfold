import AppKit
import ServiceManagement

/// Launch-at-login, with the failure mode spelled out rather than swallowed.
@MainActor
enum LoginItem {

    /// `SMAppService.mainApp` needs a real bundle. Run straight from
    /// `swift run` there is no bundle identifier, and registering would throw —
    /// so the menu disables the option and says why.
    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    static var isEnabled: Bool {
        guard isAvailable else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    /// Returns a human-readable problem, or nil on success.
    static func setEnabled(_ enabled: Bool) -> String? {
        guard isAvailable else {
            return "Launch at login needs the built app — run scripts/build-app.sh, then open Unfold.app."
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return "Could not \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)"
        }
    }
}
import Foundation
import UnfoldCore

extension UnfoldChecks {

    static let presetChecks: [Check] = [
        Check(name: "Easing endpoints are exact") {
            Easing.allCases.allSatisfy { $0.value(0) == 0 && $0.value(1) == 1 }
        },

        Check(name: "Easing never goes backwards and clamps outside 0...1") {
            var ok = true
            for easing in Easing.allCases {
                var previous = easing.value(0)
                for step in 1...200 {
                    let current = easing.value(Double(step) / 200)
                    if current < previous { ok = false }
                    previous = current
                }
            }
            return ok && Easing.easeOut.value(-5) == 0 && Easing.easeOut.value(5) == 1
        },

        Check(name: "Every preset starts covered and ends clear") {
            AnimationPreset.all.allSatisfy { preset in
                let start = preset.state(at: 0)
                let end = preset.state(at: 1)
                return start.panelInset == 0
                    && start.opacity == 1
                    && end == FoldState.open
                    && end.isInvisible
            }
        },

        Check(name: "Panel travel is monotonic so the reveal never reverses") {
            AnimationPreset.all.allSatisfy { preset in
                var previous = 0.0
                for step in 0...250 {
                    let inset = preset.state(at: Double(step) / 250).panelInset
                    if inset < previous { return false }
                    previous = inset
                }
                return true
            }
        },

        Check(name: "Preset geometry clamps out-of-range progress") {
            let below = AnimationPreset.unfold.state(at: -3)
            let above = AnimationPreset.unfold.state(at: 42)
            return below == AnimationPreset.unfold.state(at: 0)
                && above == FoldState.open
        },

        Check(name: "Unknown preset ids fall back instead of failing") {
            AnimationPreset.preset(id: "does-not-exist") == AnimationPreset.fallback
                && AnimationPreset.preset(id: "lid").axis == .horizontal
        }
    ]

    static let configurationChecks: [Check] = [
        Check(name: "Configuration round-trips through JSON") {
            withTemporaryDirectory { directory in
                let store = UnfoldConfigStore(directory: directory)
                var config = UnfoldConfiguration.default
                config.presetID = "iris"
                config.openDuration = 1.2
                config.animateOnClose = false
                do {
                    try store.save(config)
                } catch {
                    return false
                }
                let loaded = store.load()
                return loaded.problem == nil
                    && loaded.configuration == config
                    && loaded.configuration.preset.id == "iris"
            }
        },

        Check(name: "A missing config file yields defaults with no error") {
            let directory = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("unfold-missing-\(UUID().uuidString)")
            let result = UnfoldConfigStore(directory: directory).load()
            return result.problem == nil && result.configuration == .default
        },

        Check(name: "A corrupt config file reports the problem instead of failing silently") {
            withTemporaryDirectory { directory in
                let store = UnfoldConfigStore(directory: directory)
                do {
                    try Data("{ not json".utf8).write(to: store.fileURL)
                } catch {
                    return false
                }
                let result = store.load()
                return result.configuration == .default && result.problem != nil
            }
        }
    ]

    /// Creates a scoped temporary directory, removes it afterwards, and
    /// reports whether the body succeeded.
    static func withTemporaryDirectory(_ body: (URL) -> Bool) -> Bool {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("unfold-checks-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return false
        }
        defer { try? FileManager.default.removeItem(at: directory) }
        return body(directory)
    }
}
import Foundation

/// User-facing settings, stored as JSON.
///
/// The store takes its directory injected so it can be tested against a
/// temporary path instead of the real Application Support folder.
public struct UnfoldConfiguration: Codable, Equatable, Sendable {
    public var presetID: String
    /// Open animation duration in seconds.
    public var openDuration: Double
    public var animateOnOpen: Bool
    /// Closing is best-effort: macOS begins clamshell sleep immediately, so
    /// this is capped short by design.
    public var animateOnClose: Bool
    public var closeDuration: Double
    /// When true, Reduce Motion turns the animation off entirely.
    public var respectReduceMotion: Bool

    public init(
        presetID: String,
        openDuration: Double,
        animateOnOpen: Bool,
        animateOnClose: Bool,
        closeDuration: Double,
        respectReduceMotion: Bool
    ) {
        self.presetID = presetID
        self.openDuration = openDuration
        self.animateOnOpen = animateOnOpen
        self.animateOnClose = animateOnClose
        self.closeDuration = closeDuration
        self.respectReduceMotion = respectReduceMotion
    }

    public static let `default` = UnfoldConfiguration(
        presetID: AnimationPreset.unfold.id,
        openDuration: 0.9,
        animateOnOpen: true,
        animateOnClose: true,
        closeDuration: 0.45,
        respectReduceMotion: true
    )

    /// Durations offered in the menu. Kept here so the menu and the tests share
    /// one list. The closing list stays short because of the sleep deadline.
    public static let openDurationChoices: [Double] = [0.6, 0.9, 1.2, 1.6]
    public static let closeDurationChoices: [Double] = [0.25, 0.45, 0.6]

    public var preset: AnimationPreset {
        AnimationPreset.preset(id: presetID)
    }
}

/// Reads and writes `UnfoldConfiguration` as pretty-printed JSON.
public struct UnfoldConfigStore: Sendable {
    public let fileURL: URL

    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("config.json")
    }

    /// Application Support/ByJTT/Unfold, created on demand.
    public static func defaultDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base
            .appendingPathComponent("ByJTT", isDirectory: true)
            .appendingPathComponent("Unfold", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Missing or unreadable config falls back to defaults, but the caller is
    /// told which happened so a corrupt file is never silently swallowed.
    public func load() -> (configuration: UnfoldConfiguration, problem: String?) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return (.default, nil)
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(UnfoldConfiguration.self, from: data)
            return (decoded, nil)
        } catch {
            return (.default, "Could not read config.json (\(error.localizedDescription)). Defaults are in use.")
        }
    }

    public func save(_ configuration: UnfoldConfiguration) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configuration)
        try data.write(to: fileURL, options: .atomic)
    }
}
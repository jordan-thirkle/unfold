import Foundation
import UnfoldCore

/// Executable assertions that do not depend on a test framework.
///
/// Why this exists rather than relying on `swift test` alone:
///
/// * XCTest was removed from the Command Line Tools in CLT 26.x.
/// * Swift Testing's macros are available, but SPM's generated runner falls
///   back to `"xctest"` unless it is told otherwise, and that branch is
///   compiled out. On a CLT-only machine `swift test` therefore builds the test
///   bundle and exits 0 **without running anything** — a silent false green.
///
/// These checks run anywhere, with or without Xcode:
///
///     swift run unfold-verify
///
/// The Swift Testing suites in `Tests/` call into this same file, so the two
/// cannot drift apart.
public enum UnfoldChecks {

    public struct Report: Sendable {
        public var passed: [String] = []
        public var failed: [String] = []

        public var isSuccess: Bool { failed.isEmpty }
        public var total: Int { passed.count + failed.count }

        /// Look up one named check. Returns nil when the name is unknown, so a
        /// typo in a test wrapper fails loudly instead of silently passing.
        public func result(named name: String) -> Bool? {
            if passed.contains(name) { return true }
            if failed.contains(name) { return false }
            return nil
        }
    }

    /// Runs every check. The first failure in a check does not stop the rest;
    /// all of them are collected so one run reports everything that is broken.
    public static func runAll() -> Report {
        var report = Report()
        for check in all {
            if check.body() {
                report.passed.append(check.name)
            } else {
                report.failed.append(check.name)
            }
        }
        return report
    }

    /// Convenience for the Swift Testing wrappers.
    public static func isPassing(_ name: String) -> Bool {
        runAll().result(named: name) ?? false
    }

    /// Every check name, in execution order. The test wrappers iterate this so
    /// no assertion is ever written twice.
    public static var checkNames: [String] {
        all.map(\.name)
    }

    struct Check: Sendable {
        let name: String
        let body: @Sendable () -> Bool
    }

    static let all: [Check] = simulationChecks + presetChecks + configurationChecks + lidMotionChecks
}
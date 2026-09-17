import Testing
import Foundation
@testable import UnfoldChecks

/// Swift Testing wrappers over the executable checks.
///
/// There are no assertions here on purpose. Every check lives in
/// `UnfoldChecks` and is run by `swift run unfold-verify`; this file only
/// reports them through `swift test` for contributors using a full Xcode
/// toolchain.
///
/// Note for anyone on a Command Line Tools-only install: `swift test` there
/// builds the bundle and exits 0 **without running these**, because XCTest was
/// removed in CLT 26.x. Use `swift run unfold-verify` — it is the authoritative
/// result. A renamed or removed check fails here rather than silently passing,
/// because `isPassing` returns false for unknown names.
@Suite("Unfold deterministic core")
struct UnfoldChecksTests {

    @Test("Verification check", arguments: UnfoldChecks.checkNames)
    func check(name: String) {
        #expect(UnfoldChecks.isPassing(name), "check failed: \(name)")
    }

    @Test("No checks are silently skipped")
    func checkCount() {
        #expect(UnfoldChecks.checkNames.count >= 15)
    }
}
import Foundation
import UnfoldChecks

/// Verification entry point that works on a Command Line Tools-only Mac.
///
///     swift run unfold-verify
///
/// Exits non-zero if any check fails, so it is usable directly in CI.
/// See `UnfoldChecks` for why this exists alongside `swift test`.

let report = UnfoldChecks.runAll()

print("Unfold verification — \(report.total) checks")
print("")

for name in report.passed {
    print("  pass  \(name)")
}
for name in report.failed {
    print("  FAIL  \(name)")
}

print("")
print("\(report.passed.count) passed, \(report.failed.count) failed")

if !report.isSuccess {
    print("")
    print("Unfold verification failed. The deterministic core is not behaving as documented.")
    exit(1)
}

print("All checks passed.")
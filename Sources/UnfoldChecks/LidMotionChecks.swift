import Foundation
import UnfoldCore

extension UnfoldChecks {
    static let lidMotionChecks: [Check] = [
        Check(name: "Lid angle maps open and closed endpoints") {
            LidMotion.progress(angle: 90, openAngle: 90) == 0 && LidMotion.progress(angle: 10, openAngle: 90) == 1
        },
        Check(name: "Lid geometry holds and retraces independent of direction") {
            let angles = [90.0, 80, 60, 30, 10]
            let forward = angles.map { LidMotion.progress(angle: $0, openAngle: 90) }
            let backward = angles.reversed().map { LidMotion.progress(angle: $0, openAngle: 90) }
            return forward == backward.reversed() && LidMotion.progress(angle: 50, openAngle: 90) == 0.5
        },
        Check(name: "Invalid angles and calibration fail safely") {
            LidMotion.progress(angle: .nan, openAngle: 90) == 0 && LidMotion.progress(angle: 10, openAngle: 0) == 0 && LidMotion.progress(angle: 200, openAngle: 90) == 0
        },
        Check(name: "Lid smoothing stays bounded through rapid reversals") {
            var x = 0.0
            for i in 0..<1000 {
                let target = i % 2 == 0 ? 1.0 : 0
                x = LidMotion.smooth(current: x, target: target, dt: 1.0 / 120)
                if !x.isFinite || x < 0 || x > 1 { return false }
            }
            return true
        },
        Check(name: "Lid smoothing ignores invalid time and holds target") {
            LidMotion.smooth(current: 0.5, target: 0.5, dt: 0.1) == 0.5 && LidMotion.smooth(current: 0.5, target: 1, dt: .nan) == 0.5
        },
        Check(name: "Snapshot preview returns to identity") {
            abs(LidMotion.previewProgress(seconds: 4)) < 1e-12 && LidMotion.previewProgress(seconds: 0) == 0 && abs(LidMotion.previewProgress(seconds: 2) - 0.82) < 1e-12
        },
        Check(name: "Cancelled capture generation rejects late completion") {
            var g = CaptureGeneration()
            let old = g.value
            g.invalidate()
            return !g.accepts(old) && g.accepts(g.value)
        }
    ]
}

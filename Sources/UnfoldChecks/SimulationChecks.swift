import Foundation
import UnfoldCore

extension UnfoldChecks {

    static let simulationChecks: [Check] = [
        Check(name: "Chunking time does not change the result") {
            var single = FoldSimulation(preset: .unfold, duration: 0.9)
            var many = FoldSimulation(preset: .unfold, duration: 0.9)
            _ = single.advance(by: 0.5)
            for _ in 0..<50 { _ = many.advance(by: 0.01) }
            return single.ticks == many.ticks
                && single.progress == many.progress
                && single.state == many.state
        },

        Check(name: "Ten thousand small steps equal one large step") {
            var stepped = FoldSimulation(preset: .lid, duration: 5)
            var whole = FoldSimulation(preset: .lid, duration: 5)
            for _ in 0..<10_000 { _ = stepped.advance(by: 0.001) }
            _ = whole.advance(by: 10.0)
            return stepped.ticks == whole.ticks && stepped.state == whole.state
        },

        Check(name: "Two identical runs agree exactly") {
            var a = FoldSimulation(preset: .iris, duration: 1.2)
            var b = FoldSimulation(preset: .iris, duration: 1.2)
            _ = a.advance(by: 0.37)
            _ = b.advance(by: 0.37)
            return a.state == b.state
        },

        Check(name: "A finished fold is exactly open and clamps progress") {
            var sim = FoldSimulation(preset: .unfold, duration: 0.6)
            for _ in 0..<200 { _ = sim.advance(by: 0.01) }
            return sim.isFinished
                && sim.progress == 1.0
                && sim.state == FoldState.open
                && sim.rawProgress == 1.0
        },

        Check(name: "Finishing is announced exactly once") {
            var sim = FoldSimulation(preset: .unfold, duration: 0.6)
            var finishedCount = 0
            for _ in 0..<200 {
                for event in sim.advance(by: 0.01) where event == .finished {
                    finishedCount += 1
                }
            }
            return finishedCount == 1
        },

        Check(name: "Starting is announced exactly once") {
            var sim = FoldSimulation(preset: .quiet, duration: 0.6)
            var startedCount = 0
            for _ in 0..<10 {
                for event in sim.advance(by: 0.05) where event == .started {
                    startedCount += 1
                }
            }
            return startedCount == 1
        },

        Check(name: "Reduce Motion completes instantly and is idempotent") {
            var sim = FoldSimulation(preset: .unfold, duration: 1.6)
            let events = sim.completeImmediately()
            let second = sim.completeImmediately()
            return events == [.started, .finished]
                && second.isEmpty
                && sim.ticks == sim.durationTicks
                && sim.state == FoldState.open
        },

        Check(name: "Hostile time deltas are ignored, not trapped") {
            var sim = FoldSimulation(preset: .unfold, duration: 0.9)
            let rejected = sim.advance(by: .nan).isEmpty
                && sim.advance(by: .infinity).isEmpty
                && sim.advance(by: -1).isEmpty
                && sim.advance(by: 0).isEmpty
            return rejected && sim.ticks == 0
        },

        Check(name: "A zero duration fold is instantaneous") {
            var sim = FoldSimulation(preset: .unfold, duration: 0)
            let events = sim.advance(by: 0.001)
            return events.contains(.finished) && sim.state == FoldState.open
        },

        Check(name: "Elapsed time depends only on completed steps") {
            var sim = FoldSimulation(preset: .lid, duration: 0.9)
            _ = sim.advance(by: 0.4)
            let expected = Double(sim.ticks) * FoldSimulation.stepSeconds
            return sim.elapsed == expected && sim.elapsed <= 0.4 + FoldSimulation.stepSeconds
        }
    ]
}
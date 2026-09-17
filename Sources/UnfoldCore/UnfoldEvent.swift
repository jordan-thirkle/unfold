import Foundation

/// Everything the simulation is allowed to tell the rest of the app.
///
/// The renderer, the menu bar and any future audio work all consume these
/// events; none of them read the simulation's internals directly.
public enum UnfoldEvent: Equatable, Sendable {
    case started
    case ticked(progress: Double)
    case finished
}
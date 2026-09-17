import AppKit
import UnfoldCore

/// A borderless, click-through window that covers one screen.
///
/// It sits above the desktop but never becomes key and never takes a click, so
/// the user can keep typing or clicking the moment the fold starts.
@MainActor
final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Draws the fold. Reads a `FoldState` and nothing else — all timing and
/// geometry decisions are made in `UnfoldCore`.
@MainActor
final class FoldOverlayView: NSView {
    var axis: FoldAxis = .vertical
    var state: FoldState = .closed {
        didSet {
            if state != oldValue {
                needsDisplay = true
            }
        }
    }

    override var isOpaque: Bool { false }

    /// By JTT palette: ink veil with a vermilion hinge highlight.
    private static let ink = NSColor(srgbRed: 0.086, green: 0.086, blue: 0.078, alpha: 1)
    private static let hinge = NSColor(srgbRed: 0.878, green: 0.282, blue: 0.153, alpha: 1)

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        guard !state.isInvisible else { return }

        let alpha = CGFloat(state.opacity)
        let inset = CGFloat(state.panelInset)

        for rect in panelRects(inset: inset) where rect.width > 0 && rect.height > 0 {
            Self.ink.withAlphaComponent(alpha).setFill()
            NSBezierPath(rect: rect).fill()
        }

        drawSeamHighlight(alpha: alpha)
    }

    /// Two panels that retreat from the hinge as `inset` goes 0 → 1.
    private func panelRects(inset: CGFloat) -> [NSRect] {
        switch axis {
        case .vertical:
            let travel = inset * bounds.midX
            let width = max(0, bounds.midX - travel)
            return [
                NSRect(x: 0, y: 0, width: width, height: bounds.height),
                NSRect(x: bounds.midX + travel, y: 0, width: width, height: bounds.height)
            ]
        case .horizontal:
            let travel = inset * bounds.midY
            let height = max(0, bounds.midY - travel)
            return [
                NSRect(x: 0, y: 0, width: bounds.width, height: height),
                NSRect(x: 0, y: bounds.midY + travel, width: bounds.width, height: height)
            ]
        }
    }

    private func drawSeamHighlight(alpha: CGFloat) {
        let glow = CGFloat(state.seamGlow)
        guard glow > 0.01 else { return }

        let bandWidth: CGFloat = 150
        let band: NSRect
        let angle: CGFloat
        switch axis {
        case .vertical:
            band = NSRect(x: bounds.midX - bandWidth / 2, y: 0, width: bandWidth, height: bounds.height)
            angle = 0
        case .horizontal:
            band = NSRect(x: 0, y: bounds.midY - bandWidth / 2, width: bounds.width, height: bandWidth)
            angle = 90
        }

        let peak = Self.hinge.withAlphaComponent(alpha * glow * 0.55)
        guard let gradient = NSGradient(colors: [.clear, peak, .clear]) else { return }
        gradient.draw(in: band, angle: angle)
    }
}
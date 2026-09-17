import AppKit
import QuartzCore
import UnfoldCore

/// Experimental bottom-hinge perspective, independent of NUEM's implementation.
/// This first milestone projects a plane, not calibrated fixed-eye compensation.
@MainActor
final class SnapshotFoldView: NSView {
    private let picture = CALayer()
    private let shade = CALayer()

    init(frame: NSRect, image: CGImage) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        picture.bounds = CGRect(origin: .zero, size: frame.size)
        picture.anchorPoint = CGPoint(x: 0.5, y: 0)
        picture.position = CGPoint(x: frame.width / 2, y: 0)
        picture.contents = image
        picture.contentsGravity = .resize
        picture.isDoubleSided = false
        layer?.addSublayer(picture)
        shade.frame = picture.bounds
        shade.backgroundColor = NSColor.black.cgColor
        picture.addSublayer(shade)
        update(progress: 0)
    }

    required init?(coder: NSCoder) { nil }

    static func transform(progress: Double, height: CGFloat) -> CATransform3D {
        let p = progress.isFinite ? min(1, max(0, progress)) : 0
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / max(1, height * 2)
        return CATransform3DRotate(perspective, CGFloat(p * 80 * .pi / 180), 1, 0, 0)
    }

    func update(progress: Double) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        picture.transform = Self.transform(progress: progress, height: bounds.height)
        shade.opacity = Float(min(0.85, max(0, progress) * 0.85))
        CATransaction.commit()
    }

    func clear() { picture.contents = nil }
}

import SwiftUI

/// A notch panel profile inspired by NotchNook:
/// - soft top corners
/// - large bottom corners
/// - short, straight side walls
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    init(topCornerRadius: CGFloat = 8, bottomCornerRadius: CGFloat = 30) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    // Keep backward compat for old single-radius call sites.
    init(bottomCornerRadius: CGFloat) {
        self.topCornerRadius = 8
        self.bottomCornerRadius = bottomCornerRadius
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let top = min(topCornerRadius, rect.height / 2, rect.width / 2)
        // Keep bottom large to shorten side walls and match NotchNook's heavier base.
        let bottom = min(bottomCornerRadius, rect.height * 0.44, rect.width / 2)

        var path = Path()

        // Start at top-left arc start.
        path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))

        // Top edge.
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))

        // Top-right convex corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + top),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )

        // Right side.
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))

        // Bottom-right convex corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottom, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )

        // Bottom edge.
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))

        // Bottom-left convex corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottom),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )

        // Left side.
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + top))

        // Top-left convex corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }
}

import SwiftUI

/// Hardware-accurate Mac notch silhouette (DynamicNotchKit / boring.notch).
/// Bounding rect includes the top "ears" that sit on the menu-bar pixels
/// immediately left and right of the camera housing. The top edge is flush
/// with the screen; bottom corners are convex; top corners are concave.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tr = max(0, min(topCornerRadius, rect.width / 4, rect.height / 2))
        let br = max(0, min(bottomCornerRadius, (rect.width - 2 * tr) / 2, rect.height - tr))

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + tr, y: rect.minY + tr),
            control: CGPoint(x: rect.minX + tr, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + tr, y: rect.maxY - br))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + tr + br, y: rect.maxY),
            control: CGPoint(x: rect.minX + tr, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - tr - br, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - tr, y: rect.maxY - br),
            control: CGPoint(x: rect.maxX - tr, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY + tr))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - tr, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

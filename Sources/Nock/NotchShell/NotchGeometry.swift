import AppKit
import Foundation

struct NotchGeometry: Equatable {
    var screenFrame: CGRect
    var visibleFrame: CGRect
    var hasNotch: Bool
    var notchSize: CGSize
    /// Exact camera-housing rect in AppKit screen coordinates (origin bottom-left).
    var notchFrame: CGRect
    var menuBarHeight: CGFloat
    var displayID: CGDirectDisplayID

    static func from(screen: NSScreen, heightOffset: CGFloat = 0) -> NotchGeometry {
        let frame = screen.frame
        let visible = screen.visibleFrame
        let menuBar = max(0, frame.maxY - visible.maxY)
        let insetTop = screen.safeAreaInsets.top
        let hasNotch = insetTop > 0
        var notchFrame = CGRect(
            x: frame.midX - 92.5,
            y: frame.maxY - 32,
            width: 185,
            height: 32
        )
        if hasNotch, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let height = max(insetTop, left.height)
            notchFrame = CGRect(
                x: left.maxX,
                y: frame.maxY - height,
                width: max(1, right.minX - left.maxX),
                height: height
            )
        } else if hasNotch {
            notchFrame = CGRect(
                x: frame.midX - 92.5,
                y: frame.maxY - insetTop,
                width: 185,
                height: insetTop
            )
        } else {
            let size = CGSize(width: 196, height: 32)
            notchFrame = CGRect(
                x: frame.midX - size.width / 2,
                y: visible.maxY - size.height - 6,
                width: size.width,
                height: size.height
            )
        }
        notchFrame.size.height = max(24, notchFrame.height + heightOffset)
        notchFrame.origin.y = (hasNotch ? frame.maxY : (visible.maxY - 6)) - notchFrame.height
        let did = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
        return NotchGeometry(
            screenFrame: frame,
            visibleFrame: visible,
            hasNotch: hasNotch,
            notchSize: notchFrame.size,
            notchFrame: notchFrame,
            menuBarHeight: menuBar,
            displayID: did
        )
    }

    static func screens(for target: NotchDisplayTarget) -> [NSScreen] {
        let all = NSScreen.screens
        switch target {
        case .all:
            return all
        case .main:
            return [NSScreen.main].compactMap { $0 }
        case .notchScreen:
            if let notched = all.first(where: { $0.safeAreaInsets.top > 0 }) {
                return [notched]
            }
            return [NSScreen.main].compactMap { $0 }
        }
    }
}

enum IslandPresentation: Equatable {
    case collapsed
    case compact
    case expanded
    case lyrics
}

/// Fixed panel large enough for the expanded island. The SwiftUI shape morphs inside it.
enum IslandPanelMetrics {
    static let size = CGSize(width: 420, height: 310)

    static func frame(in geometry: NotchGeometry) -> CGRect {
        CGRect(
            x: geometry.notchFrame.midX - size.width / 2,
            y: geometry.notchFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}

struct IslandLayout: Equatable {
    var presentation: IslandPresentation
    var geometry: NotchGeometry
    var pinned: Bool

    var topCornerRadius: CGFloat {
        switch presentation {
        case .collapsed: return 6
        case .compact: return 8
        case .expanded, .lyrics: return 16
        }
    }

    var bottomCornerRadius: CGFloat {
        switch presentation {
        case .collapsed: return geometry.hasNotch ? 10 : 16
        case .compact: return 10
        case .expanded, .lyrics: return 16
        }
    }

    /// Bounding box of the black silhouette, including ears.
    var visualSize: CGSize {
        let notch = geometry.notchSize
        let ear = topCornerRadius * 2
        switch presentation {
        case .collapsed:
            return CGSize(width: notch.width + ear, height: notch.height)
        case .compact:
            return CGSize(width: notch.width + 88, height: notch.height)
        case .expanded:
            return CGSize(width: 384, height: notch.height + 108)
        case .lyrics:
            return CGSize(width: 400, height: notch.height + 208)
        }
    }

    var cameraReservedHeight: CGFloat {
        geometry.hasNotch ? geometry.notchSize.height : 0
    }

    /// Physical camera width — used as the compact-mode center gap.
    var cameraWidth: CGFloat {
        geometry.notchSize.width
    }
}

@MainActor
final class IslandState: ObservableObject {
    @Published var presentation: IslandPresentation
    @Published var pinned: Bool
    @Published var geometry: NotchGeometry

    init(geometry: NotchGeometry, presentation: IslandPresentation = .collapsed) {
        self.geometry = geometry
        self.presentation = presentation
        self.pinned = false
    }

    var layout: IslandLayout {
        IslandLayout(presentation: presentation, geometry: geometry, pinned: pinned)
    }
}

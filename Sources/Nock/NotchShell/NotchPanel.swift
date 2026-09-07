import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    /// Expanded controls (lyrics back, transport, scrubber) need to become key.
    /// Collapsed/compact stay non-key so we don't steal focus from the front app.
    var allowsKey: Bool = false
    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        isFloatingPanel = true
        promoteAboveMenuBar()
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        animationBehavior = .none
        isReleasedWhenClosed = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        acceptsMouseMovedEvents = true
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    func promoteAboveMenuBar() {
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 2)
    }
}

final class PassThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}

final class IslandHostingView<Content: View>: NSHostingView<Content> {
    /// Island silhouette in this view's AppKit coordinates (origin bottom-left).
    var hitRectProvider: (() -> CGRect)?

    override var safeAreaInsets: NSEdgeInsets { NSEdgeInsets() }

    required init(rootView: Content) {
        super.init(rootView: rootView)
        sizingOptions = []
        if #available(macOS 14.0, *) {
            safeAreaRegions = []
        }
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let rect = hitRectProvider?() else { return super.hitTest(point) }
        if rect.insetBy(dx: -1, dy: -1).contains(point) {
            return super.hitTest(point)
        }
        return nil
    }

    override var mouseDownCanMoveWindow: Bool { false }
}

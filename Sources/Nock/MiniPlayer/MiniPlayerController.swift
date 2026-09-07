import AppKit
import SwiftUI

@MainActor
final class MiniPlayerController {
    private let playback: PlaybackStore
    private let settings: SettingsStore
    private let panel: NSPanel
    private var host: NSHostingView<MiniPlayerView>?

    init(playback: PlaybackStore, settings: SettingsStore) {
        self.playback = playback
        self.settings = settings
        panel = NSPanel(
            contentRect: NSRect(x: 80, y: 80, width: 280, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Nock"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isFloatingPanel = true
        panel.level = settings.miniPlayerAlwaysOnTop ? .floating : .normal
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let view = MiniPlayerView(playback: playback, settings: settings)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = panel.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        host = hosting
        restorePosition()
    }

    func refresh() {
        host?.rootView = MiniPlayerView(playback: playback, settings: settings)
        panel.level = settings.miniPlayerAlwaysOnTop ? .floating : .normal
        applySize()
    }

    func setVisible(_ visible: Bool) {
        if visible {
            applySize()
            panel.makeKeyAndOrderFront(nil)
        } else {
            persistPosition()
            panel.orderOut(nil)
        }
    }

    func toggle() {
        settings.miniPlayerVisible.toggle()
        setVisible(settings.miniPlayerVisible)
    }

    private func applySize() {
        let scale = settings.miniPlayerSize.scale
        let size: NSSize
        switch settings.miniPlayerStyle {
        case .vertical, .gradient:
            size = NSSize(width: 260 * scale, height: 340 * scale)
        case .horizontal:
            size = NSSize(width: 380 * scale, height: 140 * scale)
        case .minimal:
            size = NSSize(width: 280 * scale, height: 92 * scale)
        }
        var frame = panel.frame
        frame.size = size
        panel.setFrame(frame, display: true, animate: true)
    }

    private func persistPosition() {
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "miniPlayerFrame")
    }

    private func restorePosition() {
        if let raw = UserDefaults.standard.string(forKey: "miniPlayerFrame") {
            let rect = NSRectFromString(raw)
            if rect.width > 80, NSScreen.screens.contains(where: { $0.visibleFrame.intersects(rect) }) {
                panel.setFrame(rect, display: false)
                return
            }
        }
        if let screen = NSScreen.main {
            let size = panel.frame.size
            let x = screen.visibleFrame.maxX - size.width - 24
            let y = screen.visibleFrame.maxY - size.height - 48
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}

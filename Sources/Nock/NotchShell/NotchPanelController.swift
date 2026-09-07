import AppKit
import SwiftUI

@MainActor
final class NotchPanelController: NSObject {
    let screenID: CGDirectDisplayID
    private let panel = NotchPanel()
    private let playback: PlaybackStore
    private let settings: SettingsStore
    private let lyrics: LyricsStore
    private let island: IslandState
    private var hosting: IslandHostingView<AnyView>?
    private var hoverTask: Task<Void, Never>?
    private var sneakTask: Task<Void, Never>?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hiddenByUser = false
    private var isHovering = false

    init(screen: NSScreen, playback: PlaybackStore, settings: SettingsStore, lyrics: LyricsStore) {
        self.playback = playback
        self.settings = settings
        self.lyrics = lyrics
        let geometry = NotchGeometry.from(screen: screen, heightOffset: settings.notchHeightOffset)
        self.screenID = geometry.displayID
        self.island = IslandState(geometry: geometry)
        super.init()
        configure()
    }

    func show() {
        hiddenByUser = false
        if playback.isPlaying, island.presentation == .collapsed {
            withAnimation(Motion.expand) { island.presentation = .compact }
        }
        placePanel()
        panel.promoteAboveMenuBar()
        panel.orderFrontRegardless()
        panel.promoteAboveMenuBar()
    }

    func hide() {
        hiddenByUser = true
        panel.orderOut(nil)
    }

    func destroy() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        panel.orderOut(nil)
        panel.close()
    }

    func updateScreen(_ screen: NSScreen) {
        island.geometry = NotchGeometry.from(screen: screen, heightOffset: settings.notchHeightOffset)
        placePanel()
        panel.sharingType = settings.hideFromScreenCapture ? .none : .readWrite
    }

    func handleTrackChange() {
        guard settings.liveActivityOnTrackChange, playback.track != nil else { return }
        guard island.presentation == .collapsed, !island.pinned, !isHovering else { return }
        withAnimation(Motion.expand) { island.presentation = .compact }
        sneakTask?.cancel()
        sneakTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Motion.sneakPeekDuration * 1_000_000_000))
            guard let self, !Task.isCancelled, !self.island.pinned, !self.isHovering else { return }
            withAnimation(Motion.collapse) { self.island.presentation = .collapsed }
        }
    }

    func setExpanded(_ expanded: Bool) {
        withAnimation(expanded ? Motion.expand : Motion.collapse) {
            island.presentation = expanded ? .expanded : (playback.isPlaying ? .compact : .collapsed)
        }
    }

    private func configure() {
        let host = IslandHostingView(rootView: makeRoot())
        host.hitRectProvider = { [weak self, weak host] in
            guard let self, let host else { return .zero }
            let vis = self.island.layout.visualSize
            return CGRect(
                x: (host.bounds.width - vis.width) / 2,
                y: host.bounds.height - vis.height,
                width: vis.width,
                height: vis.height
            )
        }
        let container = PassThroughView(frame: .zero)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        host.autoresizingMask = [.width, .height]
        container.autoresizesSubviews = true
        container.addSubview(host)
        panel.contentView = container
        hosting = host

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor in self?.checkMouse() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .keyDown]) { [weak self] event in
            if event.type == .keyDown, event.keyCode == 53 { // escape
                Task { @MainActor in self?.collapse() }
                return nil
            }
            Task { @MainActor in self?.checkMouse() }
            return event
        }

        placePanel()
        panel.orderFrontRegardless()
        panel.promoteAboveMenuBar()
    }

    private func makeRoot() -> AnyView {
        AnyView(
            NotchRootView(
                playback: playback,
                settings: settings,
                lyrics: lyrics,
                island: island,
                onTogglePin: { [weak self] in self?.togglePin() },
                onExpand: { [weak self] in self?.expand() },
                onCollapse: { [weak self] in self?.collapse() },
                onShowLyrics: { [weak self] in self?.showLyrics() },
                onBackFromLyrics: { [weak self] in self?.hideLyrics() },
                onOpenSettings: { NotificationCenter.default.post(name: .notchOpenSettings, object: nil) },
                onHide: { [weak self] in self?.hide() },
                onSwipeX: { [weak self] delta in
                    guard let self, self.settings.swipeToSkip else { return }
                    if delta < 0 { self.playback.next() } else { self.playback.previous() }
                },
                onSwipeY: { [weak self] delta in
                    guard let self, self.settings.swipeToExpand else { return }
                    if delta < 0 {
                        if self.island.presentation == .lyrics {
                            self.hideLyrics()
                        } else {
                            self.expand()
                        }
                    } else {
                        if self.island.presentation == .lyrics {
                            self.hideLyrics()
                        } else {
                            self.collapse()
                        }
                    }
                },
                onScrollVolume: { [weak self] delta in
                    guard let self, self.settings.scrollVolume else { return }
                    self.playback.setVolume(min(1, max(0, self.playback.volume + Double(delta) * 0.015)))
                },
                onBackgroundClick: { [weak self] in self?.handleClick() }
            )
        )
    }

    private func placePanel() {
        let frame = IslandPanelMetrics.frame(in: island.geometry)
        hosting?.frame = CGRect(origin: .zero, size: frame.size)
        panel.setFrame(frame, display: true)
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
        panel.hasShadow = false
        panel.promoteAboveMenuBar()
        updateKeyPolicy()
    }

    private func handleHover(_ hovering: Bool) {
        guard settings.hoverOpenEnabled else { return }
        isHovering = hovering
        hoverTask?.cancel()
        if hovering {
            sneakTask?.cancel()
            hoverTask = Task { [weak self] in
                let delay = self?.settings.hoverDelay ?? 0.08
                try? await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
                guard let self, !Task.isCancelled, self.isHovering else { return }
                self.expand()
            }
        } else {
            hoverTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Motion.hoverExitDelay * 1_000_000_000))
                guard let self, !Task.isCancelled, !self.isHovering, !self.island.pinned else { return }
                self.collapse()
            }
        }
    }

    private func handleClick() {
        switch island.presentation {
        case .collapsed, .compact:
            expand()
        case .expanded:
            collapse()
        case .lyrics:
            hideLyrics()
        }
    }

    private func expand() {
        if island.presentation == .lyrics { return }
        withAnimation(Motion.expand) { island.presentation = .expanded }
        updateKeyPolicy()
        checkMouse()
    }

    private func collapse() {
        island.pinned = false
        withAnimation(Motion.collapse) {
            island.presentation = (playback.isPlaying && settings.liveActivityOnTrackChange) ? .compact : .collapsed
        }
        updateKeyPolicy()
        checkMouse()
    }

    private func showLyrics() {
        withAnimation(Motion.expand) { island.presentation = .lyrics }
        updateKeyPolicy()
        checkMouse()
        Task { await lyrics.load(for: playback.track) }
    }

    private func hideLyrics() {
        withAnimation(Motion.expand) { island.presentation = .expanded }
        updateKeyPolicy()
        checkMouse()
    }

    private func togglePin() {
        island.pinned.toggle()
        if island.pinned {
            if island.presentation == .collapsed || island.presentation == .compact {
                expand()
            }
        } else {
            collapse()
        }
    }

    private func updateKeyPolicy() {
        let open = island.presentation == .expanded || island.presentation == .lyrics
        panel.allowsKey = open
        if open {
            panel.makeKey()
        }
    }

    private func checkMouse() {
        let loc = NSEvent.mouseLocation
        let vis = island.layout.visualSize
        let islandRect = CGRect(
            x: panel.frame.midX - vis.width / 2,
            y: panel.frame.maxY - vis.height,
            width: vis.width,
            height: vis.height
        )
        let inside = islandRect.contains(loc) || island.geometry.notchFrame.contains(loc)
        if inside != isHovering {
            handleHover(inside)
        }
        if settings.hideInFullscreen {
            let fs = isFrontmostFullscreen()
            if fs, panel.isVisible { panel.orderOut(nil) }
            if !fs, !panel.isVisible, !hiddenByUser {
                panel.promoteAboveMenuBar()
                panel.orderFrontRegardless()
            }
        }
    }

    private func isFrontmostFullscreen() -> Bool {
        guard let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == screenID
        }) else { return false }
        if island.geometry.hasNotch {
            let notchBottom = screen.frame.maxY - screen.safeAreaInsets.top
            return abs(screen.visibleFrame.maxY - notchBottom) < 2
                && screen.visibleFrame.height >= screen.frame.height - screen.safeAreaInsets.top - 4
        }
        return abs(screen.visibleFrame.maxY - screen.frame.maxY) < 1
    }
}

extension Notification.Name {
    static let notchOpenSettings = Notification.Name("notch.openSettings")
    static let notchRebuildSurfaces = Notification.Name("notch.rebuildSurfaces")
}

import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    private let playback: PlaybackStore
    private let settings: SettingsStore
    private var item: NSStatusItem?
    private var popover = NSPopover()
    private var extraItems: [NSStatusItem] = []

    init(playback: PlaybackStore, settings: SettingsStore) {
        self.playback = playback
        self.settings = settings
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 320, height: 210)
        rebuild()
    }

    func rebuild() {
        extraItems.forEach { NSStatusBar.system.removeStatusItem($0) }
        extraItems.removeAll()
        if let item {
            NSStatusBar.system.removeStatusItem(item)
        }
        item = nil
        waveformHost = nil
        popoverInstalled = false
        guard settings.menuBarStyle != .hidden else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.item = item
        refresh()
    }

    private var popoverInstalled = false
    private var waveformHost: NSHostingView<WaveformView>?

    func refresh() {
        guard let button = item?.button else { return }
        button.toolTip = playback.track.map { "\($0.title) — \($0.artist)" } ?? "Nock"

        switch settings.menuBarStyle {
        case .hidden:
            break
        case .albumArt:
            button.subviews.forEach { $0.removeFromSuperview() }
            button.title = ""
            button.image = menuImage(playback.track?.artwork, size: 16)
            button.imagePosition = .imageOnly
        case .waveform:
            button.image = nil
            button.title = ""
            if waveformHost == nil {
                let host = NSHostingView(rootView: WaveformView(
                    isPlaying: playback.isPlaying,
                    color: settings.waveformMonochrome ? .white : playback.appearance.accent,
                    bars: 4,
                    maxHeight: 14
                ))
                host.frame = NSRect(x: 0, y: 2, width: 22, height: 16)
                host.wantsLayer = true
                host.layer?.backgroundColor = NSColor.clear.cgColor
                button.addSubview(host)
                button.setFrameSize(NSSize(width: 26, height: button.bounds.height))
                waveformHost = host
            } else {
                waveformHost?.rootView = WaveformView(
                    isPlaying: playback.isPlaying,
                    color: settings.waveformMonochrome ? .white : playback.appearance.accent,
                    bars: 4,
                    maxHeight: 14
                )
            }
        case .title:
            button.subviews.forEach { $0.removeFromSuperview() }
            waveformHost = nil
            let title = clippedTitle()
            if button.title != title {
                button.title = title
            }
            button.image = nil
        case .artAndTitle:
            button.subviews.forEach { $0.removeFromSuperview() }
            waveformHost = nil
            button.image = menuImage(playback.track?.artwork, size: 16)
            button.title = " " + clippedTitle()
            button.imagePosition = .imageLeft
        case .inlineTransport:
            if button.subviews.isEmpty {
                installInlineControls(on: button)
            }
        }

        if !popoverInstalled {
            popover.contentViewController = NSHostingController(
                rootView: MenuBarPopover(playback: playback, settings: settings)
            )
            popoverInstalled = true
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showMenu(sender)
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = item?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(withTitle: playback.isPlaying ? "Pause" : "Play", action: #selector(playPause), keyEquivalent: "")
        menu.addItem(withTitle: "Next", action: #selector(next), keyEquivalent: "")
        menu.addItem(withTitle: "Previous", action: #selector(prev), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Mini Player", action: #selector(toggleMini), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Nock", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        item?.menu = menu
        item?.button?.performClick(nil)
        item?.menu = nil
    }

    @objc private func playPause() { playback.togglePlay() }
    @objc private func next() { playback.next() }
    @objc private func prev() { playback.previous() }
    @objc private func toggleMini() {
        settings.miniPlayerVisible.toggle()
        NotificationCenter.default.post(name: .notchRebuildSurfaces, object: nil)
    }
    @objc private func openSettings() {
        NotificationCenter.default.post(name: .notchOpenSettings, object: nil)
    }
    @objc private func quit() { NSApp.terminate(nil) }

    private func clippedTitle() -> String {
        let raw = playback.track?.title ?? "Not playing"
        let limit = max(8, settings.menuBarTitleLength)
        if raw.count <= limit { return raw }
        return String(raw.prefix(limit - 1)) + "…"
    }

    private func menuImage(_ image: NSImage?, size: CGFloat) -> NSImage {
        let dest = NSImage(size: NSSize(width: size, height: size))
        dest.lockFocus()
        let rect = NSRect(origin: .zero, size: dest.size)
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).addClip()
        if let image {
            image.draw(in: rect)
        } else {
            NSColor.white.withAlphaComponent(0.2).setFill()
            rect.fill()
        }
        dest.unlockFocus()
        dest.isTemplate = false
        return dest
    }

    private func installInlineControls(on button: NSStatusBarButton) {
        let view = NSHostingView(rootView: InlineMenuBarControls(playback: playback))
        view.frame = NSRect(x: 0, y: 0, width: 72, height: 22)
        button.addSubview(view)
        button.setFrameSize(NSSize(width: 76, height: button.bounds.height))
    }
}

struct InlineMenuBarControls: View {
    @ObservedObject var playback: PlaybackStore
    var body: some View {
        HStack(spacing: 6) {
            Button(action: playback.previous) {
                Image(systemName: "backward.fill").font(.system(size: 9))
            }
            Button(action: playback.togglePlay) {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 10))
            }
            Button(action: playback.next) {
                Image(systemName: "forward.fill").font(.system(size: 9))
            }
        }
        .buttonStyle(.plain)
        .frame(width: 72, height: 18)
    }
}

struct MenuBarPopover: View {
    @ObservedObject var playback: PlaybackStore
    @ObservedObject var settings: SettingsStore
    @State private var devices: [AudioDevice] = AudioOutput.devices()

    var body: some View {
        ZStack {
            background
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    AlbumArtView(image: playback.track?.artwork, corner: 10, playing: playback.isPlaying)
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(playback.track?.title ?? "Not playing")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text(playback.track?.displayArtistLine ?? "")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        ProgressScrubber(
                            elapsed: playback.elapsed,
                            duration: playback.duration,
                            accent: playback.appearance.accent,
                            onSeek: playback.seek
                        )
                    }
                }
                TransportBar(playback: playback, settings: settings, accent: playback.appearance.accent)
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.1.fill").font(.system(size: 10)).foregroundStyle(.secondary)
                    Slider(value: Binding(get: { playback.volume }, set: { playback.setVolume($0) }))
                    Menu {
                        ForEach(devices) { device in
                            Button(device.name) { AudioOutput.setDefaultOutput(device.id) }
                        }
                    } label: {
                        Image(systemName: "hifispeaker.fill")
                            .font(.system(size: 11))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                }
            }
            .padding(14)
        }
        .frame(width: 320, height: 210)
        .onAppear { devices = AudioOutput.devices() }
    }

    @ViewBuilder
    private var background: some View {
        switch settings.popoverStyle {
        case .material:
            Rectangle().fill(.ultraThinMaterial)
        case .albumBlur:
            ZStack {
                if let art = playback.track?.artwork {
                    Image(nsImage: art).resizable().scaledToFill().blur(radius: 28).opacity(0.55)
                }
                Rectangle().fill(.ultraThinMaterial.opacity(0.85))
            }
        case .gradient:
            LinearGradient(
                colors: [playback.appearance.accent.opacity(0.55), Color.black.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

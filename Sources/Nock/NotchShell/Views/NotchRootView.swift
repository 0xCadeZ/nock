import AppKit
import SwiftUI

struct NotchRootView: View {
    @ObservedObject var playback: PlaybackStore
    @ObservedObject var settings: SettingsStore
    @ObservedObject var lyrics: LyricsStore
    @ObservedObject var island: IslandState
    var onTogglePin: () -> Void
    var onExpand: () -> Void
    var onCollapse: () -> Void
    var onShowLyrics: () -> Void
    var onBackFromLyrics: () -> Void
    var onOpenSettings: () -> Void
    var onHide: () -> Void
    var onSwipeX: (CGFloat) -> Void
    var onSwipeY: (CGFloat) -> Void
    var onScrollVolume: (CGFloat) -> Void
    var onBackgroundClick: () -> Void

    private var layout: IslandLayout { island.layout }
    private var accent: Color {
        settings.waveformMonochrome ? .white : playback.appearance.accent
    }

    var body: some View {
        ZStack(alignment: .top) {
            islandBody
        }
        .frame(width: IslandPanelMetrics.size.width, height: IslandPanelMetrics.size.height, alignment: .top)
        .ignoresSafeArea()
        .contextMenu {
            Button(island.pinned ? "Unpin" : "Pin open") { onTogglePin() }
            Button("Hide island") { onHide() }
            Divider()
            Button("Settings…") { onOpenSettings() }
            Button("Quit Nock") { NSApp.terminate(nil) }
        }
    }

    private var islandBody: some View {
        let shape = NotchShape(
            topCornerRadius: layout.topCornerRadius,
            bottomCornerRadius: layout.bottomCornerRadius
        )
        return ZStack(alignment: .top) {
            shape.fill(Color.black)
            Rectangle()
                .fill(Color.black)
                .frame(height: 1)
                .padding(.horizontal, layout.topCornerRadius)

            islandContent
                .padding(.top, 0)
                .padding(.horizontal, layout.topCornerRadius + (isOpen ? 12 : 4))
                .padding(.bottom, isOpen ? 10 : 0)
                .frame(width: layout.visualSize.width, height: layout.visualSize.height, alignment: .top)
                .opacity(contentOpacity)
                .offset(y: contentOffset)
                .animation(isOpen ? Motion.contentIn : Motion.contentOut, value: island.presentation)
        }
        .frame(width: layout.visualSize.width, height: layout.visualSize.height, alignment: .top)
        .clipShape(shape)
        .shadow(
            color: isOpen ? Color.black.opacity(0.5) : .clear,
            radius: isOpen ? 18 : 0,
            y: isOpen ? 8 : 0
        )
        .contentShape(shape)
        .simultaneousGesture(swipeGesture)
        .onTapGesture {
            if layout.presentation == .collapsed {
                onBackgroundClick()
            }
        }
        .background(ScrollWheelForwarder(onScroll: onScrollVolume))
        .animation(island.presentation == .collapsed || island.presentation == .compact ? Motion.collapse : Motion.expand, value: island.presentation)
    }

    private var contentOpacity: Double {
        layout.presentation == .collapsed ? 0 : 1
    }

    private var contentOffset: CGFloat {
        isOpen ? 0 : 0
    }

    private var isOpen: Bool {
        layout.presentation == .expanded || layout.presentation == .lyrics
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    onSwipeX(value.translation.width)
                } else {
                    onSwipeY(value.translation.height)
                }
            }
    }

    @ViewBuilder
    private var islandContent: some View {
        switch layout.presentation {
        case .collapsed:
            Color.clear
        case .compact:
            CompactIslandView(
                playback: playback,
                accent: accent,
                cameraWidth: layout.cameraWidth,
                onPlayPause: { playback.togglePlay() },
                onExpand: onExpand
            )
        case .expanded:
            ExpandedPlayerView(
                playback: playback,
                settings: settings,
                accent: accent,
                cameraHeight: layout.cameraReservedHeight,
                onShowLyrics: settings.showLyricsPage ? onShowLyrics : nil,
                onClose: onCollapse
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(y: 10)),
                removal: .opacity
            ))
        case .lyrics:
            LyricsPageView(
                playback: playback,
                lyrics: lyrics,
                accent: accent,
                cameraHeight: layout.cameraReservedHeight,
                onBack: onBackFromLyrics,
                onClose: onCollapse
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(y: 8)),
                removal: .opacity
            ))
        }
    }
}

struct CompactIslandView: View {
    @ObservedObject var playback: PlaybackStore
    var accent: Color
    var cameraWidth: CGFloat
    var onPlayPause: () -> Void
    var onExpand: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            AlbumArtView(
                image: playback.track?.artwork,
                corner: 5,
                playing: playback.isPlaying,
                hoverable: true,
                action: onPlayPause
            )
            .frame(width: 18, height: 18)
            .padding(.leading, 6)

            Spacer(minLength: 4)

            Color.clear
                .frame(width: max(120, cameraWidth - 24), height: 20)
                .contentShape(Rectangle())
                .onTapGesture(perform: onExpand)

            Spacer(minLength: 4)

            CompactWaveformButton(isPlaying: playback.isPlaying, accent: accent, action: onExpand)
                .padding(.trailing, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CompactWaveformButton: View {
    var isPlaying: Bool
    var accent: Color
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        WaveformView(isPlaying: isPlaying, color: accent, bars: 4, maxHeight: 12)
            .frame(width: 20, height: 14)
            .padding(5)
            .background(Circle().fill(Color.white.opacity(hovering ? 0.14 : 0)))
            .scaleEffect(hovering ? 1.08 : 1)
            .contentShape(Circle())
            .onHover { hovering = $0 }
            .onTapGesture(perform: action)
            .animation(Motion.icon, value: hovering)
    }
}

struct ExpandedPlayerView: View {
    @ObservedObject var playback: PlaybackStore
    @ObservedObject var settings: SettingsStore
    var accent: Color
    var cameraHeight: CGFloat
    var onShowLyrics: (() -> Void)?
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: cameraHeight)

            HStack(alignment: .center, spacing: 12) {
                AlbumArtView(
                    image: playback.track?.artwork,
                    corner: 10,
                    playing: playback.isPlaying,
                    hoverable: true,
                    action: playback.openInPlayer
                )
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(playback.track?.title ?? "Not Playing")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if playback.track?.isExplicit == true {
                            Text("E")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 3)
                                .background(Capsule().fill(Color.white.opacity(0.75)))
                        }
                        Spacer(minLength: 4)
                        if let onShowLyrics {
                            HoverIcon(systemName: "quote.closing", fontSize: 11, diameter: 22, action: onShowLyrics)
                        }
                        HoverIcon(systemName: "xmark", fontSize: 9, diameter: 22, action: onClose)
                    }
                    Text(playback.track?.displayArtistLine ?? sourceLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.48))
                        .lineLimit(1)
                    ProgressScrubber(
                        elapsed: playback.elapsed,
                        duration: playback.duration,
                        accent: accent,
                        onSeek: playback.seek
                    )
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 6)

            TransportBar(playback: playback, settings: settings, accent: accent, compact: true)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var sourceLabel: String {
        switch playback.activeSource {
        case .music: return "Apple Music"
        case .spotify: return "Spotify"
        case .system: return "Now Playing"
        default: return "Waiting for music"
        }
    }
}

/// `onTapGesture` instead of `Button` so controls work in a non-activating panel.
struct IslandChromeButton: View {
    var systemName: String
    var label: String?
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
            if let label {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .foregroundStyle(hovering ? .white : .white.opacity(0.7))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(hovering ? 0.16 : 0.08)))
        .scaleEffect(hovering ? 1.04 : 1)
        .contentShape(Capsule())
        .onHover { hovering = $0 }
        .onTapGesture(perform: action)
        .animation(Motion.icon, value: hovering)
    }
}

struct ScrollWheelForwarder: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> Catcher {
        let view = Catcher()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: Catcher, context: Context) {
        nsView.onScroll = onScroll
    }

    final class Catcher: NSView {
        var onScroll: ((CGFloat) -> Void)?
        override func scrollWheel(with event: NSEvent) {
            if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
                onScroll?(event.scrollingDeltaY)
            } else {
                super.scrollWheel(with: event)
            }
        }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

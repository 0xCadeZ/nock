import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var playback: PlaybackStore
    @ObservedObject var settings: SettingsStore
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        Group {
            switch settings.miniPlayerStyle {
            case .vertical: vertical
            case .horizontal: horizontal
            case .minimal: minimal
            case .gradient: gradient
            }
        }
        .padding(14)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if abs(value.translation.width) > abs(value.translation.height) {
                        if value.translation.width < 0 { playback.next() } else { playback.previous() }
                    }
                }
        )
    }

    private var vertical: some View {
        VStack(spacing: 12) {
            AlbumArtView(image: playback.track?.artwork, corner: 16, playing: playback.isPlaying)
                .aspectRatio(1, contentMode: .fit)
                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
            VStack(spacing: 4) {
                Text(playback.track?.title ?? "Not playing")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(playback.track?.displayArtistLine ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            ProgressScrubber(elapsed: playback.elapsed, duration: playback.duration, accent: playback.appearance.accent, onSeek: playback.seek)
            TransportBar(playback: playback, settings: settings, accent: playback.appearance.accent)
            volume
        }
    }

    private var horizontal: some View {
        HStack(spacing: 14) {
            AlbumArtView(image: playback.track?.artwork, corner: 12, playing: playback.isPlaying)
                .frame(width: 88, height: 88)
            VStack(alignment: .leading, spacing: 6) {
                Text(playback.track?.title ?? "Not playing")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(playback.track?.artist ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                ProgressScrubber(elapsed: playback.elapsed, duration: playback.duration, accent: playback.appearance.accent, onSeek: playback.seek)
                TransportBar(playback: playback, settings: settings, accent: playback.appearance.accent, compact: true)
            }
        }
    }

    private var minimal: some View {
        HStack(spacing: 10) {
            Button(action: playback.togglePlay) {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(playback.track?.title ?? "Not playing")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(playback.track?.artist ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: playback.next) {
                Image(systemName: "forward.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private var gradient: some View {
        vertical
    }

    private var volume: some View {
        HStack {
            Image(systemName: "speaker.fill").font(.system(size: 9)).foregroundStyle(.secondary)
            Slider(value: Binding(get: { playback.volume }, set: { playback.setVolume($0) }))
                .tint(playback.appearance.accent)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch settings.miniPlayerStyle {
        case .gradient:
            ZStack {
                if let art = playback.track?.artwork {
                    Image(nsImage: art).resizable().scaledToFill().blur(radius: 32).opacity(0.7)
                }
                LinearGradient(
                    colors: [playback.appearance.accent.opacity(0.45), Color.black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        case .vertical, .horizontal, .minimal:
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

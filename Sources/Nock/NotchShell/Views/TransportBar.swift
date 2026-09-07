import SwiftUI

struct TransportBar: View {
    @ObservedObject var playback: PlaybackStore
    @ObservedObject var settings: SettingsStore
    var accent: Color
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            secondary(settings.leftSecondary)
            Spacer(minLength: 0)
            HoverIcon(
                systemName: playback.isPodcast ? "gobackward.15" : "backward.fill",
                fontSize: compact ? 11 : 12,
                action: { playback.isPodcast ? playback.skipFifteen(-1) : playback.previous() }
            )
            Spacer(minLength: 0)
            HoverIcon(
                systemName: playback.isPlaying ? "pause.fill" : "play.fill",
                fontSize: compact ? 15 : 16,
                diameter: 32,
                prominent: true,
                action: playback.togglePlay
            )
            Spacer(minLength: 0)
            HoverIcon(
                systemName: playback.isPodcast ? "goforward.15" : "forward.fill",
                fontSize: compact ? 11 : 12,
                action: { playback.isPodcast ? playback.skipFifteen(1) : playback.next() }
            )
            Spacer(minLength: 0)
            secondary(settings.rightSecondary)
        }
        .frame(height: 32)
    }

    @ViewBuilder
    private func secondary(_ button: SecondaryButton) -> some View {
        switch button {
        case .shuffle:
            HoverIcon(systemName: "shuffle", fontSize: 11, active: playback.shuffle, action: playback.toggleShuffle)
        case .repeat:
            HoverIcon(
                systemName: playback.repeatMode.symbolName,
                fontSize: 11,
                active: playback.repeatMode != .off,
                action: playback.cycleRepeat
            )
        case .like:
            HoverIcon(
                systemName: playback.track?.isLiked == true ? "heart.fill" : "heart",
                fontSize: 11,
                active: playback.track?.isLiked == true,
                activeColor: .pink,
                action: playback.toggleLike
            )
        case .volume:
            HoverIcon(
                systemName: playback.volume < 0.1 ? "speaker.fill" : "speaker.wave.2.fill",
                fontSize: 11,
                active: true,
                dimColor: .white.opacity(0.45),
                action: {}
            )
        }
    }
}

struct HoverIcon: View {
    var systemName: String
    var fontSize: CGFloat = 12
    var diameter: CGFloat = 26
    var active: Bool = true
    var activeColor: Color = .white
    var dimColor: Color = Color.white.opacity(0.32)
    var prominent: Bool = false
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(iconColor)
            .frame(width: diameter, height: diameter)
            .background(
                Circle()
                    .fill(Color.white.opacity(hovering ? (prominent ? 0.18 : 0.12) : (prominent ? 0.06 : 0)))
            )
            .scaleEffect(hovering ? 1.08 : 1)
            .contentShape(Circle())
            .onHover { hovering = $0 }
            .onTapGesture(perform: action)
            .animation(Motion.icon, value: hovering)
    }

    private var iconColor: Color {
        if hovering { return .white }
        if active { return activeColor }
        return dimColor
    }
}

struct AlbumArtView: View {
    var image: NSImage?
    var corner: CGFloat
    var playing: Bool = true
    var hoverable: Bool = false
    var action: (() -> Void)?

    @State private var hovering = false

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color.white.opacity(hovering ? 0.14 : 0))
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .opacity(playing ? 1 : 0.7)
            .scaleEffect(hovering ? 1.05 : 1)
            .clipped()
            .onHover { if hoverable { hovering = $0 } }
            .onTapGesture { action?() }
            .animation(Motion.icon, value: hovering)
    }
}

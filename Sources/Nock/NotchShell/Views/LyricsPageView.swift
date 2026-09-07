import SwiftUI

struct LyricsPageView: View {
    @ObservedObject var playback: PlaybackStore
    @ObservedObject var lyrics: LyricsStore
    var accent: Color
    var cameraHeight: CGFloat
    var onBack: () -> Void
    var onClose: () -> Void

    private var current: Int {
        lyrics.currentIndex(elapsed: playback.elapsed) ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: cameraHeight)
            header
            bodyContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task(id: playback.track?.id) {
            await lyrics.load(for: playback.track)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            HoverIcon(systemName: "chevron.backward", fontSize: 11, diameter: 24, action: onBack)
            AlbumArtView(
                image: playback.track?.artwork,
                corner: 4,
                playing: playback.isPlaying
            )
            .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(playback.track?.title ?? "Lyrics")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(playback.track?.artist ?? "")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HoverIcon(systemName: "xmark", fontSize: 9, diameter: 24, action: onClose)
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var bodyContent: some View {
        if lyrics.isLoading {
            loadingState
        } else if lyrics.lines.isEmpty {
            emptyState
        } else {
            lyricsList
        }
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 8)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 3.5, height: 7 + CGFloat((sin(t * 4.2 + Double(i) * 0.9) + 1) * 5))
                    }
                }
                .frame(height: 18)
            }
            Text("Finding lyrics")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 6)
            Image(systemName: "quote.closing")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.22))
            Text(lyrics.error ?? "No lyrics")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text(playback.track.map { "\($0.title) — \($0.artist)" } ?? "")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.32))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Spacer(minLength: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
    }

    private var lyricsList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .center, spacing: 10) {
                    Color.clear.frame(height: 12)
                    ForEach(Array(lyrics.lines.enumerated()), id: \.offset) { index, line in
                        lyricRow(index: index, line: line)
                            .id(index)
                    }
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 4)
            }
            .mask(edgeFade)
            .onAppear {
                proxy.scrollTo(current, anchor: .center)
            }
            .onChange(of: current) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    proxy.scrollTo(current, anchor: .center)
                }
            }
        }
    }

    private func lyricRow(index: Int, line: LyricLine) -> some View {
        let distance = abs(index - current)
        let isCurrent = index == current
        return Text(line.text)
            .font(.system(
                size: isCurrent ? 15 : (distance == 1 ? 12.5 : 11),
                weight: isCurrent ? .semibold : .regular,
                design: .rounded
            ))
            .foregroundStyle(lineColor(distance: distance, isCurrent: isCurrent))
            .multilineTextAlignment(.center)
            .lineLimit(isCurrent ? 3 : 2)
            .frame(maxWidth: .infinity)
            .scaleEffect(isCurrent ? 1.0 : 0.98)
            .opacity(isCurrent ? 1 : (distance == 1 ? 0.85 : 1))
            .contentShape(Rectangle())
            .onTapGesture {
                guard lyrics.isSynced else { return }
                playback.seek(line.time)
            }
            .animation(Motion.icon, value: current)
    }

    private func lineColor(distance: Int, isCurrent: Bool) -> Color {
        if isCurrent { return .white }
        if distance == 1 { return Color.white.opacity(0.42) }
        if distance == 2 { return Color.white.opacity(0.22) }
        return Color.white.opacity(0.12)
    }

    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white, location: 0.08),
                .init(color: .white, location: 0.86),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

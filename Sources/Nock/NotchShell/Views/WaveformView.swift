import SwiftUI

struct WaveformView: View {
    var isPlaying: Bool
    var color: Color
    var bars: Int = 4
    var maxHeight: CGFloat = 16

    var body: some View {
        TimelineView(.animation(minimumInterval: isPlaying ? 1.0 / 30.0 : 10, paused: !isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<bars, id: \.self) { i in
                    Capsule(style: .continuous)
                        .fill(color)
                        .frame(width: 3, height: barHeight(index: i, time: t))
                }
            }
            .frame(height: maxHeight)
        }
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        guard isPlaying else { return maxHeight * [0.28, 0.55, 0.4, 0.7, 0.35][index % 5] }
        let phase = time * (2.6 + Double(index) * 0.35) + Double(index) * 0.9
        let wave = (sin(phase) + 1) / 2
        let secondary = (sin(phase * 1.7 + 0.4) + 1) / 2
        let mixed = 0.22 + 0.78 * (0.65 * wave + 0.35 * secondary)
        return max(3, maxHeight * mixed)
    }
}

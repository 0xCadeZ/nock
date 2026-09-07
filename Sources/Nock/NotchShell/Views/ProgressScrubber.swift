import SwiftUI

struct ProgressScrubber: View {
    var elapsed: TimeInterval
    var duration: TimeInterval
    var accent: Color
    var onSeek: (TimeInterval) -> Void
    var compact: Bool = false

    @State private var dragging = false
    @State private var dragProgress: Double = 0

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return dragging ? dragProgress : min(1, max(0, elapsed / duration))
    }

    var body: some View {
        HStack(spacing: 6) {
            if !compact {
                Text(Self.format(elapsed))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .monospacedDigit()
                    .frame(width: 28, alignment: .leading)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(accent)
                        .frame(width: max(3, geo.size.width * progress))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragging = true
                            dragProgress = min(1, max(0, value.location.x / max(geo.size.width, 1)))
                        }
                        .onEnded { value in
                            let p = min(1, max(0, value.location.x / max(geo.size.width, 1)))
                            dragging = false
                            onSeek(p * duration)
                        }
                )
            }
            .frame(height: 3)
            if !compact {
                Text(Self.format(max(0, duration - elapsed)))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .monospacedDigit()
                    .frame(width: 28, alignment: .trailing)
            }
        }
        .frame(height: compact ? 3 : 14)
    }

    static func format(_ t: TimeInterval) -> String {
        guard t.isFinite else { return "0:00" }
        let total = Int(max(0, t.rounded()))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}

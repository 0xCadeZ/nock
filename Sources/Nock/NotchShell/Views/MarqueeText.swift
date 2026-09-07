import SwiftUI

struct MarqueeText: View {
    var text: String
    var font: Font
    var color: Color
    var alignment: Alignment = .leading

    @State private var animate = false
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let overflow = textWidth > geo.size.width + 4
            ZStack(alignment: alignment) {
                Text(text)
                    .font(font)
                    .foregroundStyle(color)
                    .fixedSize()
                    .background(WidthReader(width: $textWidth))
                    .offset(x: overflow && animate ? -(textWidth + 28) : 0)
                    .opacity(overflow && animate ? 1 : 1)
                if overflow {
                    Text(text)
                        .font(font)
                        .foregroundStyle(color)
                        .fixedSize()
                        .offset(x: (animate ? 0 : textWidth + 28))
                }
            }
            .frame(width: geo.size.width, alignment: .leading)
            .clipped()
            .onAppear {
                containerWidth = geo.size.width
                start(overflow: textWidth > geo.size.width + 4)
            }
            .onChange(of: text) {
                animate = false
                start(overflow: textWidth > geo.size.width + 4)
            }
        }
        .frame(height: font == .body ? 20 : 16)
    }

    private func start(overflow: Bool) {
        guard overflow else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.linear(duration: max(6, textWidth / 28)).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

private struct WidthReader: View {
    @Binding var width: CGFloat
    var body: some View {
        GeometryReader { geo in
            Color.clear.preference(key: WidthKey.self, value: geo.size.width)
        }
        .onPreferenceChange(WidthKey.self) { width = $0 }
    }
}

private struct WidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

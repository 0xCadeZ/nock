import AppKit
import CoreImage
import SwiftUI

enum Palette {
    static let islandBlack = Color.black
    static let islandInk = NSColor.black
    static let onIsland = Color.white
    static let onIslandMuted = Color.white.opacity(0.62)
    static let accentFallback = Color(red: 1.0, green: 0.42, blue: 0.38)

    static func prominentColor(from image: NSImage?) -> Color {
        guard let image, let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return accentFallback
        }
        let ciImage = CIImage(cgImage: cg)
        let extent = ciImage.extent
        let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: ciImage,
                kCIInputExtentKey: CIVector(cgRect: extent)
            ]
        )
        guard let output = filter?.outputImage else { return accentFallback }

        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        var r = Double(pixel[0]) / 255
        var g = Double(pixel[1]) / 255
        var b = Double(pixel[2]) / 255
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        if maxC < 0.18 {
            r += 0.18; g += 0.18; b += 0.2
        }
        let sat = maxC - minC
        if sat < 0.12 {
            r = min(1, r * 1.25)
            g = min(1, g * 0.9)
            b = min(1, b * 0.85)
        }
        return Color(red: min(1, r * 1.15), green: min(1, g * 1.05), blue: min(1, b * 1.05))
    }
}

@MainActor
final class AppearanceStore: ObservableObject {
    @Published var accent: Color = Palette.accentFallback
    @Published private(set) var trackID: String?

    func update(for track: Track?) {
        guard track?.id != trackID || (track?.artwork != nil && accent == Palette.accentFallback) else { return }
        trackID = track?.id
        let image = track?.artwork
        Task.detached(priority: .utility) {
            let color = Palette.prominentColor(from: image)
            await MainActor.run {
                self.accent = color
            }
        }
    }
}

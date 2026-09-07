import Foundation

struct LyricLine: Identifiable, Equatable {
    var id: TimeInterval { time }
    var time: TimeInterval
    var text: String
}

enum LRCParser {
    static func parse(_ raw: String) -> [LyricLine] {
        let pattern = try! NSRegularExpression(pattern: #"\[(\d{1,2}):(\d{2}(?:\.\d+)?)\](.*)"#)
        var lines: [LyricLine] = []
        for line in raw.components(separatedBy: .newlines) {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = pattern.firstMatch(in: line, range: range),
                  let minR = Range(match.range(at: 1), in: line),
                  let secR = Range(match.range(at: 2), in: line),
                  let textR = Range(match.range(at: 3), in: line)
            else { continue }
            let minutes = Double(line[minR]) ?? 0
            let seconds = Double(line[secR]) ?? 0
            let text = line[textR].trimmingCharacters(in: .whitespaces)
            if text.isEmpty { continue }
            lines.append(LyricLine(time: minutes * 60 + seconds, text: text))
        }
        return lines.sorted { $0.time < $1.time }
    }
}

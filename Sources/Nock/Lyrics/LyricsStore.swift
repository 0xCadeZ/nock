import Foundation

@MainActor
final class LyricsStore: ObservableObject {
    @Published var lines: [LyricLine] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isSynced = false

    private var currentID: String?

    func load(for track: Track?) async {
        guard let track else {
            lines = []
            isSynced = false
            currentID = nil
            return
        }
        guard track.id != currentID else { return }
        currentID = track.id
        isLoading = true
        error = nil
        isSynced = false
        defer { isLoading = false }

        var comps = URLComponents(string: "https://lrclib.net/api/get")!
        comps.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album)
        ]
        guard let url = comps.url else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                lines = []
                error = "No lyrics"
                return
            }
            struct Payload: Decodable {
                var syncedLyrics: String?
                var plainLyrics: String?
            }
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            if let synced = payload.syncedLyrics, !synced.isEmpty {
                let parsed = LRCParser.parse(synced)
                if parsed.count >= 2 {
                    lines = parsed
                    isSynced = true
                } else {
                    lines = parsed
                    isSynced = false
                }
            } else if let plain = payload.plainLyrics {
                lines = plain.components(separatedBy: .newlines)
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    .enumerated()
                    .map { LyricLine(time: Double($0.offset) * 4, text: $0.element) }
                isSynced = false
            } else {
                lines = []
                error = "No lyrics"
            }
        } catch {
            self.error = "Couldn't load lyrics"
            lines = []
        }
    }

    func currentIndex(elapsed: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        var idx = 0
        for (i, line) in lines.enumerated() {
            if line.time <= elapsed { idx = i } else { break }
        }
        return idx
    }
}

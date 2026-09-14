import AppKit
import Foundation

/// Raw values read from a scriptable player, before they are shaped into a `Track`.
struct PlayerPayload: Equatable {
    var running: Bool?
    var available: Bool?
    var state: String?
    var title: String?
    var artist: String?
    var album: String?
    var duration: Double?
    var position: Double?
    var volume: Double?
    var shuffle: Bool?
    var repeating: String?
    var id: String?
    var loved: Bool?
    var favorited: Bool?
    var artworkUrl: String?
    var url: String?
    var mediaKind: String?
    var explicit: Bool?
}

extension PlayerPayload {
    /// Maps the shared Music/Spotify `player state` enumerator codes to a name.
    static func stateName(forCode code: String) -> String {
        switch code {
        case "kPSP": return "playing"
        case "kPSp": return "paused"
        case "kPSS": return "stopped"
        default: return code.lowercased()
        }
    }

    /// Maps Music's `song repeat` enumerator codes to a name.
    static func repeatName(forCode code: String) -> String {
        switch code {
        case "kRpO": return "off"
        case "kRp1": return "one"
        case "kAll": return "all"
        default: return "off"
        }
    }

    /// Maps Music's `media kind` enumerator codes to a name.
    static func mediaKindName(forCode code: String) -> String {
        switch code {
        case "kMdS": return "song"
        case "kVdV": return "music video"
        default: return "unknown"
        }
    }

    var isPlaying: Bool {
        (state ?? "").lowercased() == "playing"
    }

    var repeatMode: RepeatMode {
        switch (repeating ?? "").lowercased() {
        case "one", "repeatone": return .one
        case "all", "repeatall": return .all
        default: return .off
        }
    }

    var media: MediaKind {
        switch (mediaKind ?? "").lowercased() {
        case "podcast", "radio": return .podcast
        case "audiobook", "book": return .audiobook
        default: return .music
        }
    }

    func track(source: PlayerSource, artwork: NSImage? = nil) -> Track? {
        guard let title, !title.isEmpty else { return nil }
        let durationSeconds: TimeInterval
        if let duration {
            durationSeconds = duration > 10000 ? duration / 1000 : duration
        } else {
            durationSeconds = 0
        }
        return Track(
            id: id ?? "\(source.rawValue)-\(title)-\(artist ?? "")",
            title: title,
            artist: artist ?? "",
            album: album ?? "",
            duration: durationSeconds,
            artwork: artwork,
            artworkURL: artworkUrl.flatMap(URL.init(string:)),
            source: source,
            bundleIdentifier: source.bundleIdentifier,
            isLiked: favorited ?? loved ?? false,
            isExplicit: explicit ?? false,
            kind: media,
            url: url,
            contextName: nil
        )
    }
}

import AppKit
import Foundation

enum PlayerSource: String, CaseIterable, Identifiable, Codable {
    case auto
    case music
    case spotify
    case system
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .music: return "Apple Music"
        case .spotify: return "Spotify"
        case .system: return "System Now Playing"
        case .none: return "None"
        }
    }

    var bundleIdentifier: String? {
        switch self {
        case .music: return "com.apple.Music"
        case .spotify: return "com.spotify.client"
        default: return nil
        }
    }
}

enum RepeatMode: String, Codable, CaseIterable {
    case off
    case one
    case all

    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }

    var symbolName: String {
        switch self {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

enum MediaKind: String, Codable {
    case music
    case podcast
    case audiobook
    case unknown
}

struct Track: Equatable, Identifiable {
    var id: String
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var artwork: NSImage?
    var artworkURL: URL?
    var source: PlayerSource
    var bundleIdentifier: String?
    var isLiked: Bool
    var isExplicit: Bool
    var kind: MediaKind
    var url: String?
    var contextName: String?

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.artist == rhs.artist
            && lhs.album == rhs.album
            && lhs.duration == rhs.duration
            && lhs.isLiked == rhs.isLiked
            && lhs.isExplicit == rhs.isExplicit
            && lhs.artworkURL == rhs.artworkURL
            && lhs.source == rhs.source
            && (lhs.artwork != nil) == (rhs.artwork != nil)
    }

    var isPodcastLike: Bool {
        kind == .podcast || kind == .audiobook
    }

    var displayArtistLine: String {
        if album.isEmpty { return artist }
        if artist.isEmpty { return album }
        return "\(artist) — \(album)"
    }
}

struct PlayerSnapshot: Equatable {
    var track: Track?
    var isPlaying: Bool
    var elapsed: TimeInterval
    var volume: Double
    var shuffle: Bool
    var repeatMode: RepeatMode
    var timestamp: Date
    var source: PlayerSource
    var isAvailable: Bool

    static let empty = PlayerSnapshot(
        track: nil,
        isPlaying: false,
        elapsed: 0,
        volume: 0.5,
        shuffle: false,
        repeatMode: .off,
        timestamp: .distantPast,
        source: .none,
        isAvailable: false
    )

    func interpolatedElapsed(at date: Date = .init()) -> TimeInterval {
        guard isPlaying, let duration = track?.duration, duration > 0 else { return elapsed }
        let extra = date.timeIntervalSince(timestamp)
        return min(max(0, elapsed + extra), duration)
    }
}

enum PlaybackCommand {
    case togglePlay
    case play
    case pause
    case next
    case previous
    case seek(TimeInterval)
    case setVolume(Double)
    case toggleShuffle
    case cycleRepeat
    case setRepeat(RepeatMode)
    case skipFifteen(Int)
    case toggleLike
}

protocol PlayerControlling: AnyObject {
    var source: PlayerSource { get }
    func snapshot() async -> PlayerSnapshot
    func send(_ command: PlaybackCommand) async
}

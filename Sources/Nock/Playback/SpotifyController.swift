import AppKit
import Foundation

final class SpotifyController: PlayerControlling {
    static let bundleID = "com.spotify.client"

    /// Four-character codes from Spotify.sdef.
    private enum Code {
        static let eventClass = "spfy"
        static let playPause = "PlPs"
        static let play = "Play"
        static let pause = "Paus"
        static let next = "Next"
        static let previous = "Prev"
        static let playerState = "pPlS"
        static let playerPosition = "pPos"
        static let soundVolume = "pVol"
        static let shuffling = "pShu"
        static let repeating = "pRep"
        static let currentTrack = "pTrk"
        static let name = "pnam"
        static let artist = "pArt"
        static let album = "pAlb"
        static let duration = "pDur"
        static let id = "ID  "
        static let artworkURL = "aUrl"
        static let spotifyURL = "spur"
    }

    let source: PlayerSource = .spotify
    var auth: SpotifyAuth?
    private var cachedArtwork: (id: String, image: NSImage)?
    private var likedCache: [String: Bool] = [:]

    func snapshot() async -> PlayerSnapshot {
        guard let pid = RunningApps.processID(for: Self.bundleID) else {
            return PlayerSnapshot.empty
        }
        let payload: PlayerPayload
        do {
            payload = try await AppleEventClient.perform(pid: pid, Self.readPayload)
        } catch {
            logUnlessQuit(error, context: "snapshot")
            return PlayerSnapshot.empty
        }

        var track = payload.track(source: .spotify)
        if let url = track?.artworkURL {
            if cachedArtwork?.id == track?.id {
                track?.artwork = cachedArtwork?.image
            } else if let image = await ImageLoader.image(from: url) {
                cachedArtwork = (track?.id ?? url.absoluteString, image)
                track?.artwork = image
            }
        }
        if let rawID = track?.id ?? track?.url,
           let id = spotifyTrackID(from: rawID),
           let auth,
           await MainActor.run(body: { auth.isAuthorized }) {
            if let cached = likedCache[id] {
                track?.isLiked = cached
            } else if let liked = try? await auth.isSaved(trackID: id) {
                likedCache[id] = liked
                track?.isLiked = liked
            }
        }
        return PlayerSnapshot(
            track: track,
            isPlaying: payload.isPlaying,
            elapsed: payload.position ?? 0,
            volume: (payload.volume ?? 50) / 100.0,
            shuffle: payload.shuffle ?? false,
            repeatMode: payload.repeatMode,
            timestamp: Date(),
            source: .spotify,
            isAvailable: true
        )
    }

    /// Reads player and track state. Player properties are required; track
    /// properties are optional because Spotify may have nothing loaded.
    private static func readPayload(_ ae: AppleEventClient) throws -> PlayerPayload {
        let track = AppleEventClient.property(Code.currentTrack)
        return try PlayerPayload(
            running: true,
            available: true,
            state: PlayerPayload.stateName(forCode: ae.enumCode(.property(Code.playerState))),
            title: try? ae.string(.property(Code.name, of: track)),
            artist: try? ae.string(.property(Code.artist, of: track)),
            album: try? ae.string(.property(Code.album, of: track)),
            duration: try? ae.double(.property(Code.duration, of: track)),
            position: ae.double(.property(Code.playerPosition)),
            volume: ae.double(.property(Code.soundVolume)),
            shuffle: try? ae.bool(.property(Code.shuffling)),
            repeating: (try? ae.bool(.property(Code.repeating))).map { $0 ? "all" : "off" },
            id: try? ae.string(.property(Code.id, of: track)),
            artworkUrl: try? ae.string(.property(Code.artworkURL, of: track)),
            url: try? ae.string(.property(Code.spotifyURL, of: track))
        )
    }

    func send(_ command: PlaybackCommand) async {
        if case .toggleLike = command {
            await toggleLike()
            return
        }
        // Skip silently when Spotify is not running; a command must never launch it.
        guard let pid = RunningApps.processID(for: Self.bundleID) else { return }
        do {
            try await AppleEventClient.perform(pid: pid) { ae in try Self.apply(command, with: ae) }
        } catch {
            logUnlessQuit(error, context: "command")
        }
    }

    private static func apply(_ command: PlaybackCommand, with ae: AppleEventClient) throws {
        switch command {
        case .togglePlay:
            try ae.command(eventClass: Code.eventClass, eventID: Code.playPause)
        case .play:
            try ae.command(eventClass: Code.eventClass, eventID: Code.play)
        case .pause:
            try ae.command(eventClass: Code.eventClass, eventID: Code.pause)
        case .next:
            try ae.command(eventClass: Code.eventClass, eventID: Code.next)
        case .previous:
            try ae.command(eventClass: Code.eventClass, eventID: Code.previous)
        case .seek(let time):
            try ae.set(.property(Code.playerPosition), to: NSAppleEventDescriptor(double: max(0, time)))
        case .setVolume(let volume):
            try ae.set(.property(Code.soundVolume), to: NSAppleEventDescriptor(int32: Int32((volume * 100).rounded())))
        case .toggleShuffle:
            let current = try ae.bool(.property(Code.shuffling))
            try ae.set(.property(Code.shuffling), to: NSAppleEventDescriptor(boolean: !current))
        case .cycleRepeat, .setRepeat:
            let current = try ae.bool(.property(Code.repeating))
            try ae.set(.property(Code.repeating), to: NSAppleEventDescriptor(boolean: !current))
        case .skipFifteen(let direction):
            let position = try ae.double(.property(Code.playerPosition))
            let target = max(0, position + Double(direction) * 15)
            try ae.set(.property(Code.playerPosition), to: NSAppleEventDescriptor(double: target))
        case .toggleLike:
            break
        }
    }

    private func logUnlessQuit(_ error: Error, context: String) {
        if let failure = error as? AppleEventClient.Failure, failure.isProcessGone { return }
        NSLog("Spotify \(context) failed: \(error.localizedDescription)")
    }

    private func toggleLike() async {
        guard let auth, await MainActor.run(body: { auth.isAuthorized }) else { return }
        let snap = await snapshot()
        guard let raw = snap.track?.id ?? snap.track?.url, let id = spotifyTrackID(from: raw) else { return }
        let currently = likedCache[id] ?? snap.track?.isLiked ?? false
        do {
            try await auth.setSaved(trackID: id, saved: !currently)
            likedCache[id] = !currently
        } catch {
            NSLog("Spotify like failed: \(error.localizedDescription)")
        }
    }

    private func spotifyTrackID(from raw: String) -> String? {
        if raw.hasPrefix("spotify:track:") {
            return String(raw.dropFirst("spotify:track:".count))
        }
        if let url = URL(string: raw), url.host?.contains("spotify") == true {
            let parts = url.pathComponents
            if let idx = parts.firstIndex(of: "track"), parts.indices.contains(idx + 1) {
                return parts[idx + 1]
            }
        }
        if raw.count == 22 { return raw }
        return nil
    }
}

enum ImageLoader {
    static func image(from url: URL) async -> NSImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return NSImage(data: data)
        } catch {
            return nil
        }
    }
}

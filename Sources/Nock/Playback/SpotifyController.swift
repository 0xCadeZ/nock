import AppKit
import Foundation

final class SpotifyController: PlayerControlling {
    let source: PlayerSource = .spotify
    var auth: SpotifyAuth?
    private var cachedArtwork: (id: String, image: NSImage)?
    private var likedCache: [String: Bool] = [:]

    private static let snapshotScript = #"""
    function run() {
      const app = Application("Spotify");
      const result = { running: app.running(), available: true };
      if (!app.running()) return JSON.stringify(result);
      try {
        result.state = String(app.playerState());
        result.position = app.playerPosition();
        result.volume = app.soundVolume();
        try { result.shuffle = app.shuffling(); } catch (e) {}
        try { result.repeating = app.repeating() ? "all" : "off"; } catch (e) {}
        const t = app.currentTrack();
        result.title = t.name();
        result.artist = t.artist();
        result.album = t.album();
        result.duration = t.duration();
        try { result.id = t.id(); } catch (e) {}
        try { result.artworkUrl = t.artworkUrl(); } catch (e) {}
        try { result.url = t.spotifyUrl(); } catch (e) {}
      } catch (e) {
        result.error = String(e);
      }
      return JSON.stringify(result);
    }
    """#

    func snapshot() async -> PlayerSnapshot {
        guard AppleScriptBridge.isAppRunning("com.spotify.client") else {
            return PlayerSnapshot.empty
        }
        do {
            let payload = try await AppleScriptBridge.runJXAObject(Self.snapshotScript, as: ScriptTrackPayload.self)
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
        } catch {
            return PlayerSnapshot.empty
        }
    }

    func send(_ command: PlaybackCommand) async {
        let script: String
        switch command {
        case .togglePlay:
            script = "Application('Spotify').playpause();"
        case .play:
            script = "Application('Spotify').play();"
        case .pause:
            script = "Application('Spotify').pause();"
        case .next:
            script = "Application('Spotify').nextTrack();"
        case .previous:
            script = "Application('Spotify').previousTrack();"
        case .seek(let time):
            script = "Application('Spotify').playerPosition = \(max(0, time));"
        case .setVolume(let volume):
            script = "Application('Spotify').soundVolume = \(Int((volume * 100).rounded()));"
        case .toggleShuffle:
            script = "var a=Application('Spotify'); a.shuffling = !a.shuffling();"
        case .cycleRepeat, .setRepeat:
            script = "var a=Application('Spotify'); a.repeating = !a.repeating();"
        case .skipFifteen(let direction):
            script = "var a=Application('Spotify'); a.playerPosition = Math.max(0, a.playerPosition() + \(direction * 15));"
        case .toggleLike:
            await toggleLike()
            return
        }
        _ = try? await AppleScriptBridge.runJXA(script)
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

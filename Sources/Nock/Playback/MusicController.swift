import AppKit
import Foundation

final class MusicController: PlayerControlling {
    let source: PlayerSource = .music
    private var cachedArtwork: (id: String, image: NSImage)?

    private static let snapshotScript = #"""
    function run() {
      const app = Application("Music");
      const result = { running: app.running(), available: true };
      if (!app.running()) return JSON.stringify(result);
      try {
        result.state = String(app.playerState());
        result.position = app.playerPosition();
        result.volume = app.soundVolume();
        try { result.shuffle = app.shuffleEnabled(); } catch (e) {}
        try { result.repeating = String(app.songRepeat()); } catch (e) {}
        if (result.state !== "stopped") {
          const t = app.currentTrack();
          result.title = t.name();
          result.artist = t.artist();
          result.album = t.album();
          result.duration = t.duration();
          try { result.id = String(t.persistentID()); } catch (e) { result.id = t.name() + t.artist(); }
          try { result.loved = t.loved(); } catch (e) {}
          try { result.favorited = t.favorited(); } catch (e) {}
          try { result.mediaKind = String(t.mediaKind()); } catch (e) {}
        }
      } catch (e) {
        result.error = String(e);
      }
      return JSON.stringify(result);
    }
    """#

    func snapshot() async -> PlayerSnapshot {
        guard AppleScriptBridge.isAppRunning("com.apple.Music") else {
            return PlayerSnapshot.empty
        }
        do {
            let payload = try await AppleScriptBridge.runJXAObject(Self.snapshotScript, as: ScriptTrackPayload.self)
            var track = payload.track(source: .music)
            if let trackID = track?.id {
                if cachedArtwork?.id == trackID {
                    track?.artwork = cachedArtwork?.image
                } else if let art = await fetchArtwork() {
                    cachedArtwork = (trackID, art)
                    track?.artwork = art
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
                source: .music,
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
            script = "Application('Music').playpause();"
        case .play:
            script = "Application('Music').play();"
        case .pause:
            script = "Application('Music').pause();"
        case .next:
            script = "Application('Music').nextTrack();"
        case .previous:
            script = "Application('Music').previousTrack();"
        case .seek(let time):
            script = "Application('Music').playerPosition = \(max(0, time));"
        case .setVolume(let volume):
            script = "Application('Music').soundVolume = \(Int((volume * 100).rounded()));"
        case .toggleShuffle:
            script = "var a=Application('Music'); a.shuffleEnabled = !a.shuffleEnabled();"
        case .cycleRepeat:
            script = """
            var a = Application('Music');
            var r = String(a.songRepeat());
            if (r === 'off') a.songRepeat = 'all';
            else if (r === 'all') a.songRepeat = 'one';
            else a.songRepeat = 'off';
            """
        case .setRepeat(let mode):
            let value = mode == .off ? "off" : (mode == .one ? "one" : "all")
            script = "Application('Music').songRepeat = '\(value)';"
        case .skipFifteen(let direction):
            script = "var a=Application('Music'); a.playerPosition = Math.max(0, a.playerPosition() + \(direction * 15));"
        case .toggleLike:
            script = """
            var t = Application('Music').currentTrack();
            try { t.favorited = !t.favorited(); }
            catch (e) { try { t.loved = !t.loved(); } catch (e2) {} }
            """
        }
        _ = try? await AppleScriptBridge.runJXA(script)
    }

    private func fetchArtwork() async -> NSImage? {
        let script = """
        tell application "Music"
            if player state is stopped then return ""
            try
                set d to raw data of artwork 1 of current track
                return d
            on error
                return ""
            end try
        end tell
        """
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let apple = NSAppleScript(source: script)
                var error: NSDictionary?
                let result = apple?.executeAndReturnError(&error)
                if let data = result?.data, !data.isEmpty, let image = NSImage(data: data) {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

import AppKit
import Foundation

final class MusicController: PlayerControlling {
    static let bundleID = "com.apple.Music"

    /// Four-character codes from com.apple.Music.sdef.
    private enum Code {
        static let eventClass = "hook"
        static let playPause = "PlPs"
        static let play = "Play"
        static let pause = "Paus"
        static let next = "Next"
        static let previous = "Prev"
        static let playerState = "pPlS"
        static let playerPosition = "pPos"
        static let soundVolume = "pVol"
        static let shuffleEnabled = "pShE"
        static let songRepeat = "pRpt"
        static let currentTrack = "pTrk"
        static let name = "pnam"
        static let artist = "pArt"
        static let album = "pAlb"
        static let duration = "pDur"
        static let persistentID = "pPIS"
        static let favorited = "pLov"
        static let mediaKind = "pMdK"
        static let artworkClass = "cArt"
        static let rawData = "pRaw"
        static let repeatOff = "kRpO"
        static let repeatOne = "kRp1"
        static let repeatAll = "kAll"
    }

    let source: PlayerSource = .music
    private var cachedArtwork: (id: String, image: NSImage)?

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

        var track = payload.track(source: .music)
        if let trackID = track?.id {
            if cachedArtwork?.id == trackID {
                track?.artwork = cachedArtwork?.image
            } else if let art = await fetchArtwork(pid: pid) {
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
    }

    /// Reads player state, and track details only when something is loaded.
    private static func readPayload(_ ae: AppleEventClient) throws -> PlayerPayload {
        let state = PlayerPayload.stateName(forCode: try ae.enumCode(.property(Code.playerState)))
        let player = try PlayerPayload(
            running: true,
            available: true,
            state: state,
            position: ae.double(.property(Code.playerPosition)),
            volume: ae.double(.property(Code.soundVolume)),
            shuffle: try? ae.bool(.property(Code.shuffleEnabled)),
            repeating: (try? ae.enumCode(.property(Code.songRepeat))).map(PlayerPayload.repeatName(forCode:))
        )
        guard state != "stopped" else { return player }

        let track = AppleEventClient.property(Code.currentTrack)
        let name = try? ae.string(.property(Code.name, of: track))
        let artist = try? ae.string(.property(Code.artist, of: track))
        return PlayerPayload(
            running: player.running,
            available: player.available,
            state: player.state,
            title: name,
            artist: artist,
            album: try? ae.string(.property(Code.album, of: track)),
            duration: try? ae.double(.property(Code.duration, of: track)),
            position: player.position,
            volume: player.volume,
            shuffle: player.shuffle,
            repeating: player.repeating,
            id: (try? ae.string(.property(Code.persistentID, of: track))) ?? (name ?? "") + (artist ?? ""),
            favorited: try? ae.bool(.property(Code.favorited, of: track)),
            mediaKind: (try? ae.enumCode(.property(Code.mediaKind, of: track))).map(PlayerPayload.mediaKindName(forCode:))
        )
    }

    func send(_ command: PlaybackCommand) async {
        // Skip silently when Music is not running; a command must never launch it.
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
            let current = try ae.bool(.property(Code.shuffleEnabled))
            try ae.set(.property(Code.shuffleEnabled), to: NSAppleEventDescriptor(boolean: !current))
        case .cycleRepeat:
            let current = PlayerPayload.repeatName(forCode: try ae.enumCode(.property(Code.songRepeat)))
            try setRepeat(Self.nextRepeat(after: current), with: ae)
        case .setRepeat(let mode):
            try setRepeat(mode, with: ae)
        case .skipFifteen(let direction):
            let position = try ae.double(.property(Code.playerPosition))
            let target = max(0, position + Double(direction) * 15)
            try ae.set(.property(Code.playerPosition), to: NSAppleEventDescriptor(double: target))
        case .toggleLike:
            let track = AppleEventClient.property(Code.currentTrack)
            let current = try ae.bool(.property(Code.favorited, of: track))
            try ae.set(.property(Code.favorited, of: track), to: NSAppleEventDescriptor(boolean: !current))
        }
    }

    /// Music cycles off → all → one → off, matching the original JXA behaviour.
    static func nextRepeat(after name: String) -> RepeatMode {
        switch name {
        case "off": return .all
        case "all": return .one
        default: return .off
        }
    }

    private static func setRepeat(_ mode: RepeatMode, with ae: AppleEventClient) throws {
        let code: String
        switch mode {
        case .off: code = Code.repeatOff
        case .one: code = Code.repeatOne
        case .all: code = Code.repeatAll
        }
        try ae.set(.property(Code.songRepeat), to: NSAppleEventDescriptor(enumCode: fourCharCode(code)))
    }

    /// `raw data of artwork 1 of current track`, fetched by pid so it can never relaunch Music.
    private func fetchArtwork(pid: pid_t) async -> NSImage? {
        do {
            let data = try await AppleEventClient.perform(pid: pid) { ae in
                let track = AppleEventClient.property(Code.currentTrack)
                let artwork = AppleEventClient.element(Code.artworkClass, index: 1, of: track)
                return try ae.data(.property(Code.rawData, of: artwork))
            }
            return NSImage(data: data)
        } catch {
            logUnlessQuit(error, context: "artwork")
            return nil
        }
    }

    private func logUnlessQuit(_ error: Error, context: String) {
        if let failure = error as? AppleEventClient.Failure {
            if failure.isProcessGone { return }
            // No artwork / no current track is routine, not worth logging.
            if failure == .application(AppleEventClient.Failure.noSuchObject) { return }
        }
        NSLog("Music \(context) failed: \(error.localizedDescription)")
    }
}

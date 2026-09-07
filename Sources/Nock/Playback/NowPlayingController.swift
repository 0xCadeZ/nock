import AppKit
import Foundation

/// Streams system Now Playing via the bundled MediaRemote Adapter (perl + unlinked framework).
/// Falls back to a quiet empty snapshot if the adapter is missing or exits.
final class NowPlayingController: PlayerControlling {
    let source: PlayerSource = .system

    private var process: Process?
    private var latest = PlayerSnapshot.empty
    private let queue = DispatchQueue(label: "nock.nowplaying")
    private var artworkCache: (id: String, image: NSImage)?

    func start() {
        guard process == nil else { return }
        guard let script = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
              let framework = Bundle.main.privateFrameworksURL?.appendingPathComponent("MediaRemoteAdapter.framework")
                ?? Bundle.main.resourceURL?.appendingPathComponent("MediaRemoteAdapter.framework"),
              FileManager.default.fileExists(atPath: script.path)
        else {
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        proc.arguments = [script.path, framework.path, "stream", "--debounce=80"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self else { return }
            let lines = data.split(separator: 10)
            for line in lines {
                self.ingest(Data(line))
            }
        }
        proc.terminationHandler = { [weak self] _ in
            self?.process = nil
        }
        do {
            try proc.run()
            process = proc
        } catch {
            NSLog("MediaRemote adapter failed to start: \(error.localizedDescription)")
        }
    }

    func stop() {
        process?.terminate()
        process = nil
    }

    func snapshot() async -> PlayerSnapshot {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.latest)
            }
        }
    }

    func send(_ command: PlaybackCommand) async {
        let id: Int?
        var extra: [String] = []
        switch command {
        case .play: id = 0
        case .pause: id = 1
        case .togglePlay: id = 2
        case .next: id = 4
        case .previous: id = 5
        case .toggleShuffle: id = 6
        case .cycleRepeat: id = 7
        case .skipFifteen(let dir): id = dir >= 0 ? 13 : 12
        case .seek(let time):
            id = nil
            extra = ["seek", String(Int(time * 1_000_000))]
        default:
            return
        }
        invoke(id: id, extra: extra)
    }

    private func invoke(id: Int?, extra: [String]) {
        guard let script = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
              let framework = Bundle.main.privateFrameworksURL?.appendingPathComponent("MediaRemoteAdapter.framework")
                ?? Bundle.main.resourceURL?.appendingPathComponent("MediaRemoteAdapter.framework")
        else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        var args = [script.path, framework.path]
        if let id {
            args += ["send", String(id)]
        } else {
            args += extra
        }
        proc.arguments = args
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        try? proc.run()
    }

    private func ingest(_ data: Data) {
        queue.async { [weak self] in
            self?.apply(data)
        }
    }

    private func apply(_ data: Data) {
        struct Envelope: Decodable {
            var type: String?
            var diff: Bool?
            var payload: Payload?
        }
        struct Payload: Decodable {
            var bundleIdentifier: String?
            var playing: Bool?
            var title: String?
            var artist: String?
            var album: String?
            var duration: Double?
            var elapsedTime: Double?
            var timestamp: Double?
            var artworkData: String?
            var artworkMimeType: String?
            var uniqueIdentifier: String?
            var shuffleMode: Int?
            var repeatMode: Int?
            var mediaType: String?
        }
        guard let env = try? JSONDecoder().decode(Envelope.self, from: data), let payload = env.payload else { return }

        let title = payload.title ?? latest.track?.title
        guard let title, !title.isEmpty else {
            latest = .empty
            return
        }

        var artwork = latest.track?.artwork
        let id = payload.uniqueIdentifier ?? "\(payload.bundleIdentifier ?? "")-\(title)"
        if let b64 = payload.artworkData, let raw = Data(base64Encoded: b64), let image = NSImage(data: raw) {
            artwork = image
            artworkCache = (id, image)
        } else if artworkCache?.id == id {
            artwork = artworkCache?.image
        }

        let bundle = payload.bundleIdentifier ?? ""
        let mappedSource: PlayerSource
        if bundle.contains("spotify") { mappedSource = .spotify }
        else if bundle.contains("Music") || bundle == "com.apple.Music" { mappedSource = .music }
        else { mappedSource = .system }

        let track = Track(
            id: id,
            title: title,
            artist: payload.artist ?? latest.track?.artist ?? "",
            album: payload.album ?? latest.track?.album ?? "",
            duration: payload.duration ?? latest.track?.duration ?? 0,
            artwork: artwork,
            artworkURL: nil,
            source: mappedSource,
            bundleIdentifier: bundle,
            isLiked: latest.track?.isLiked ?? false,
            isExplicit: false,
            kind: (payload.mediaType ?? "").lowercased().contains("audio") && title.lowercased().contains("podcast") ? .podcast : .music,
            url: nil,
            contextName: nil
        )

        let snap = PlayerSnapshot(
            track: track,
            isPlaying: payload.playing ?? latest.isPlaying,
            elapsed: payload.elapsedTime ?? latest.elapsed,
            volume: latest.volume,
            shuffle: (payload.shuffleMode ?? 0) > 1,
            repeatMode: payload.repeatMode == 2 ? .one : (payload.repeatMode == 3 ? .all : .off),
            timestamp: Date(),
            source: mappedSource == .system ? .system : mappedSource,
            isAvailable: true
        )
        latest = snap
    }
}

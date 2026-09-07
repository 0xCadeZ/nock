import AppKit
import Foundation

enum AppleScriptBridge {
    struct ScriptError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    @discardableResult
    static func runJXA(_ source: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-l", "JavaScript", "-e", source]
                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = stdout.fileHandleForReading.readDataToEndOfFile()
                    if process.terminationStatus != 0 {
                        let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "osascript failed"
                        continuation.resume(throwing: ScriptError(message: err))
                        return
                    }
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func runJXAObject<T: Decodable>(_ source: String, as type: T.Type) async throws -> T {
        let data = try await runJXA(source)
        let trimmed = data.drop(while: { $0 == 10 || $0 == 13 || $0 == 32 })
        return try JSONDecoder().decode(T.self, from: trimmed.isEmpty ? data : Data(trimmed))
    }

    static func isAppRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    static func activate(_ bundleID: String) {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.activate()
    }
}

struct ScriptTrackPayload: Decodable {
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

extension ScriptTrackPayload {
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

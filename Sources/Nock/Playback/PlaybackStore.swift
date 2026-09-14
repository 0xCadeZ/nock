import AppKit
import Combine
import Foundation

@MainActor
final class PlaybackStore: ObservableObject {
    @Published private(set) var snapshot = PlayerSnapshot.empty
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var lastCommandDate = Date.distantPast

    let music = MusicController()
    let spotify = SpotifyController()
    let nowPlaying = NowPlayingController()
    let appearance = AppearanceStore()

    private static let playerBundleIDs: Set<String> = [MusicController.bundleID, SpotifyController.bundleID]

    private var settings: SettingsStore
    private var tick: Timer?
    private var poll: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var lastTrackID: String?
    var onTrackChange: ((Track) -> Void)?

    var track: Track? { snapshot.track }
    var isPlaying: Bool { snapshot.isPlaying }
    var duration: TimeInterval { snapshot.track?.duration ?? 0 }
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, elapsed / duration))
    }
    var volume: Double { snapshot.volume }
    var shuffle: Bool { snapshot.shuffle }
    var repeatMode: RepeatMode { snapshot.repeatMode }
    var activeSource: PlayerSource { snapshot.source }

    init(settings: SettingsStore) {
        self.settings = settings
        spotify.auth = SpotifyAuth(clientID: settings.spotifyClientID)
    }

    func start() {
        nowPlaying.start()
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        // Clear the notch as soon as a player quits instead of waiting for the next poll.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier,
                  Self.playerBundleIDs.contains(bundleID)
            else { return }
            Task { @MainActor in await self?.refresh() }
        }
        poll = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        tick = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.snapshot.isPlaying {
                    self.elapsed = self.snapshot.interpolatedElapsed()
                }
            }
        }
        RunLoop.main.add(poll!, forMode: .common)
        RunLoop.main.add(tick!, forMode: .common)
        appearance.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        Task { await refresh() }
    }

    func refresh() async {
        let preferred = settings.preferredSource
        let musicSnap = await music.snapshot()
        let spotifySnap = await spotify.snapshot()
        let systemSnap = await nowPlaying.snapshot()

        let chosen: PlayerSnapshot
        switch preferred {
        case .music:
            chosen = musicSnap.isAvailable ? musicSnap : fallback(musicSnap, spotifySnap, systemSnap)
        case .spotify:
            chosen = spotifySnap.isAvailable ? spotifySnap : fallback(spotifySnap, musicSnap, systemSnap)
        case .system:
            chosen = systemSnap.isAvailable ? systemSnap : fallback(systemSnap, musicSnap, spotifySnap)
        case .auto, .none:
            chosen = pickAuto(music: musicSnap, spotify: spotifySnap, system: systemSnap)
        }

        let previousID = lastTrackID
        snapshot = chosen
        elapsed = chosen.interpolatedElapsed()
        appearance.update(for: chosen.track)

        if let track = chosen.track, track.id != previousID {
            lastTrackID = track.id
            if previousID != nil {
                onTrackChange?(track)
            }
        } else if chosen.track == nil {
            lastTrackID = nil
        }
    }

    func send(_ command: PlaybackCommand) {
        lastCommandDate = Date()
        haptic()
        applyOptimistic(command)
        Task {
            await controller(for: snapshot.source)?.send(command)
            try? await Task.sleep(nanoseconds: 180_000_000)
            await refresh()
        }
    }

    func togglePlay() { send(.togglePlay) }
    func next() { send(.next) }
    func previous() {
        if elapsed > 3, !isPodcast {
            send(.seek(0))
        } else {
            send(.previous)
        }
    }
    func seek(_ time: TimeInterval) { send(.seek(time)) }
    func setVolume(_ value: Double) { send(.setVolume(min(1, max(0, value)))) }
    func toggleLike() { send(.toggleLike) }
    func toggleShuffle() { send(.toggleShuffle) }
    func cycleRepeat() { send(.cycleRepeat) }
    func skipFifteen(_ dir: Int) { send(.skipFifteen(dir)) }

    var isPodcast: Bool { track?.isPodcastLike == true }

    func openInPlayer() {
        if let bundle = track?.bundleIdentifier {
            RunningApps.activate(bundle)
        } else if snapshot.source == .spotify {
            RunningApps.activate(SpotifyController.bundleID)
        } else {
            RunningApps.activate(MusicController.bundleID)
        }
    }

    private func controller(for source: PlayerSource) -> PlayerControlling? {
        switch source {
        case .music: return music
        case .spotify: return spotify
        case .system: return nowPlaying
        case .auto, .none:
            if snapshot.source == .music { return music }
            if snapshot.source == .spotify { return spotify }
            return nowPlaying
        }
    }

    private func pickAuto(music: PlayerSnapshot, spotify: PlayerSnapshot, system: PlayerSnapshot) -> PlayerSnapshot {
        let playing = [music, spotify, system].filter(\.isPlaying)
        if let preferred = playing.max(by: { $0.timestamp < $1.timestamp }) {
            return preferred
        }
        if music.track != nil { return music }
        if spotify.track != nil { return spotify }
        if system.track != nil { return system }
        return .empty
    }

    private func fallback(_ first: PlayerSnapshot, _ second: PlayerSnapshot, _ third: PlayerSnapshot) -> PlayerSnapshot {
        if first.track != nil { return first }
        if second.isPlaying || second.track != nil { return second }
        if third.track != nil { return third }
        return first.isAvailable ? first : (second.isAvailable ? second : third)
    }

    private func applyOptimistic(_ command: PlaybackCommand) {
        switch command {
        case .togglePlay:
            snapshot.isPlaying.toggle()
            snapshot.timestamp = Date()
        case .play:
            snapshot.isPlaying = true
            snapshot.timestamp = Date()
        case .pause:
            snapshot.isPlaying = false
        case .setVolume(let v):
            snapshot.volume = v
        case .toggleShuffle:
            snapshot.shuffle.toggle()
        case .cycleRepeat:
            snapshot.repeatMode = snapshot.repeatMode.next
        case .toggleLike:
            snapshot.track?.isLiked.toggle()
        case .seek(let t):
            snapshot.elapsed = t
            snapshot.timestamp = Date()
            elapsed = t
        default:
            break
        }
    }

    func haptic() {
        guard settings.hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
}

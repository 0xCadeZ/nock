import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsStore()
    lazy var playback = PlaybackStore(settings: settings)
    let lyrics = LyricsStore()

    private var notchControllers: [NotchPanelController] = []
    private var menuBar: MenuBarController?
    private var miniPlayer: MiniPlayerController?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        playback.start()
        playback.onTrackChange = { [weak self] _ in
            self?.notchControllers.forEach { $0.handleTrackChange() }
        }
        HotKeyCenter.shared.bind(playback: playback)
        HotKeyCenter.shared.onToggleMini = { [weak self] in
            self?.miniPlayer?.toggle()
        }
        HotKeyCenter.shared.onToggleLive = { [weak self] in
            self?.settings.liveActivityOnTrackChange.toggle()
        }

        NotificationCenter.default.addObserver(forName: .notchOpenSettings, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.showSettings() }
        }
        NotificationCenter.default.addObserver(forName: .notchRebuildSurfaces, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.rebuildSurfaces() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.rebuildSurfaces() }
        }

        rebuildSurfaces()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.menuBar?.refresh() }
        }

        if !settings.hasCompletedOnboarding {
            showOnboarding()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func rebuildSurfaces() {
        notchControllers.forEach { $0.destroy() }
        notchControllers.removeAll()
        if settings.notchEnabled {
            for screen in NotchGeometry.screens(for: settings.displayTarget) {
                let controller = NotchPanelController(
                    screen: screen,
                    playback: playback,
                    settings: settings,
                    lyrics: lyrics
                )
                controller.show()
                notchControllers.append(controller)
            }
        }
        if menuBar == nil {
            menuBar = MenuBarController(playback: playback, settings: settings)
        } else {
            menuBar?.rebuild()
        }
        if miniPlayer == nil {
            miniPlayer = MiniPlayerController(playback: playback, settings: settings)
        }
        miniPlayer?.refresh()
        miniPlayer?.setVisible(settings.miniPlayerEnabled && settings.miniPlayerVisible)
    }

    func showSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView(
                settings: settings,
                playback: playback,
                onRebuild: { [weak self] in self?.rebuildSurfaces() }
            ))
            let window = NSWindow(contentViewController: host)
            window.title = "Nock Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 560, height: 480))
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func showOnboarding() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let view = OnboardingView(
            settings: settings,
            onAuthorizeMusic: {
                Task { _ = await self.playback.music.snapshot() }
            },
            onAuthorizeSpotify: {
                Task { _ = await self.playback.spotify.snapshot() }
            },
            onConnectSpotifyAPI: {
                self.playback.spotify.auth?.updateClientID(self.settings.spotifyClientID)
                self.playback.spotify.auth?.connect()
            },
            onDone: { [weak self] in
                self?.onboardingWindow?.close()
                NSApp.setActivationPolicy(.accessory)
                self?.rebuildSurfaces()
            }
        )
        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.title = "Welcome to Nock"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 460, height: 520))
        window.center()
        window.isReleasedWhenClosed = false
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === settingsWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

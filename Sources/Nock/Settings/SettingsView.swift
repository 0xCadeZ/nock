import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var playback: PlaybackStore
    var onRebuild: () -> Void

    var body: some View {
        TabView {
            general.tabItem { Label("General", systemImage: "gearshape") }
            notch.tabItem { Label("Notch", systemImage: "rectangle.inset.filled") }
            menuBar.tabItem { Label("Menu Bar", systemImage: "menubar.rectangle") }
            mini.tabItem { Label("Mini Player", systemImage: "rectangle.on.rectangle") }
            playbackTab.tabItem { Label("Playback", systemImage: "play.circle") }
            gestures.tabItem { Label("Gestures", systemImage: "hand.draw") }
            shortcuts.tabItem { Label("Shortcuts", systemImage: "keyboard") }
            spotify.tabItem { Label("Spotify", systemImage: "dot.radiowaves.left.and.right") }
            about.tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 460)
        .onChange(of: settings.menuBarStyle) { onRebuild() }
        .onChange(of: settings.notchEnabled) { onRebuild() }
        .onChange(of: settings.displayTarget) { onRebuild() }
        .onChange(of: settings.miniPlayerEnabled) { onRebuild() }
        .onChange(of: settings.miniPlayerStyle) { onRebuild() }
        .onChange(of: settings.miniPlayerSize) { onRebuild() }
        .onChange(of: settings.miniPlayerAlwaysOnTop) { onRebuild() }
    }

    private var general: some View {
        Form {
            Picker("Music source", selection: $settings.preferredSource) {
                ForEach(PlayerSource.allCases.filter { $0 != .none }) { Text($0.title).tag($0) }
            }
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
            Toggle("Haptic feedback", isOn: $settings.hapticsEnabled)
            Toggle("Hide from screenshots", isOn: $settings.hideFromScreenCapture)
            LabeledContent("Now playing") {
                Text(playback.track.map { "\($0.title) — \($0.artist)" } ?? "Nothing")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var notch: some View {
        Form {
            Toggle("Enable notch player", isOn: $settings.notchEnabled)
            Toggle("Hover to expand", isOn: $settings.hoverOpenEnabled)
            HStack {
                Text("Hover delay")
                Slider(value: $settings.hoverDelay, in: 0...0.8)
                Text(String(format: "%.2fs", settings.hoverDelay)).monospacedDigit().foregroundStyle(.secondary)
            }
            Toggle("Live activity on track change", isOn: $settings.liveActivityOnTrackChange)
            Picker("Show on", selection: $settings.displayTarget) {
                ForEach(NotchDisplayTarget.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Hide while fullscreen", isOn: $settings.hideInFullscreen)
            Toggle("Lyrics page", isOn: $settings.showLyricsPage)
            HStack {
                Text("Height fine-tune")
                Slider(value: $settings.notchHeightOffset, in: -6...8)
                Text(String(format: "%+.0f", settings.notchHeightOffset)).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var menuBar: some View {
        Form {
            Picker("Style", selection: $settings.menuBarStyle) {
                ForEach(MenuBarStyle.allCases) { Text($0.title).tag($0) }
            }
            Picker("Popover", selection: $settings.popoverStyle) {
                ForEach(PopoverStyle.allCases) { Text($0.title).tag($0) }
            }
            Stepper("Title length: \(settings.menuBarTitleLength)", value: $settings.menuBarTitleLength, in: 8...40)
            Toggle("Monochrome waveform", isOn: $settings.waveformMonochrome)
        }
        .formStyle(.grouped)
        .padding()
    }

    private var mini: some View {
        Form {
            Toggle("Enable mini player", isOn: $settings.miniPlayerEnabled)
            Toggle("Visible", isOn: $settings.miniPlayerVisible)
            Picker("Style", selection: $settings.miniPlayerStyle) {
                ForEach(MiniPlayerStyle.allCases) { Text($0.title).tag($0) }
            }
            Picker("Size", selection: $settings.miniPlayerSize) {
                ForEach(MiniPlayerSize.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Always on top", isOn: $settings.miniPlayerAlwaysOnTop)
            Button("Toggle mini player") {
                settings.miniPlayerVisible.toggle()
                onRebuild()
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var playbackTab: some View {
        Form {
            Picker("Left extra button", selection: $settings.leftSecondary) {
                ForEach(SecondaryButton.allCases) { Text($0.title).tag($0) }
            }
            Picker("Right extra button", selection: $settings.rightSecondary) {
                ForEach(SecondaryButton.allCases) { Text($0.title).tag($0) }
            }
            Text("Podcasts automatically swap skip for ±15 seconds.")
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }

    private var gestures: some View {
        Form {
            Toggle("Swipe left/right to skip", isOn: $settings.swipeToSkip)
            Toggle("Swipe down/up to open or close", isOn: $settings.swipeToExpand)
            Toggle("Scroll to change volume", isOn: $settings.scrollVolume)
        }
        .formStyle(.grouped)
        .padding()
    }

    private var shortcuts: some View {
        Form {
            HotKeyRecorder(title: "Play / Pause", spec: Binding(get: { HotKeyCenter.shared.playPause }, set: { HotKeyCenter.shared.playPause = $0 })) {
                HotKeyCenter.shared.reregister()
            }
            HotKeyRecorder(title: "Next", spec: Binding(get: { HotKeyCenter.shared.next }, set: { HotKeyCenter.shared.next = $0 })) {
                HotKeyCenter.shared.reregister()
            }
            HotKeyRecorder(title: "Previous", spec: Binding(get: { HotKeyCenter.shared.previous }, set: { HotKeyCenter.shared.previous = $0 })) {
                HotKeyCenter.shared.reregister()
            }
            HotKeyRecorder(title: "Favorite", spec: Binding(get: { HotKeyCenter.shared.like }, set: { HotKeyCenter.shared.like = $0 })) {
                HotKeyCenter.shared.reregister()
            }
            HotKeyRecorder(title: "Toggle mini player", spec: Binding(get: { HotKeyCenter.shared.toggleMini }, set: { HotKeyCenter.shared.toggleMini = $0 })) {
                HotKeyCenter.shared.reregister()
            }
            HotKeyRecorder(title: "Toggle live activity", spec: Binding(get: { HotKeyCenter.shared.toggleLive }, set: { HotKeyCenter.shared.toggleLive = $0 })) {
                HotKeyCenter.shared.reregister()
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var spotify: some View {
        Form {
            TextField("Client ID", text: $settings.spotifyClientID)
            Text("Redirect URI: \(SpotifyAuth.redirectURI)")
                .textSelection(.enabled)
                .foregroundStyle(.secondary)
            LabeledContent("Status") {
                Text(playback.spotify.auth?.statusText ?? "Not connected")
            }
            HStack {
                Button("Connect") {
                    playback.spotify.auth?.updateClientID(settings.spotifyClientID)
                    playback.spotify.auth?.connect()
                }
                .disabled(settings.spotifyClientID.isEmpty)
                Button("Disconnect", role: .destructive) {
                    playback.spotify.auth?.disconnect()
                }
            }
            TextField("Last.fm API key (optional)", text: $settings.lastFMAPIKey)
        }
        .formStyle(.grouped)
        .padding()
    }

    private var about: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.tv.fill")
                .font(.system(size: 42))
                .foregroundStyle(playback.appearance.accent)
            Text("nock").font(.title.weight(.semibold))
            Text("1.0.0").foregroundStyle(.secondary)
            Text("A native Dynamic Island player for Apple Music, Spotify, and anything else that’s playing.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)
            Spacer()
            Button("Quit Nock") { NSApp.terminate(nil) }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

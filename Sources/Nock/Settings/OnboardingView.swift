import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings: SettingsStore
    var onAuthorizeMusic: () -> Void
    var onAuthorizeSpotify: () -> Void
    var onConnectSpotifyAPI: () -> Void
    var onDone: () -> Void

    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color(red: 0.18, green: 0.07, blue: 0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(spacing: 16) {
                    Capsule().fill(Color.white.opacity(0.9)).frame(width: 92, height: 28)
                        .overlay(
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 4).fill(Color.orange.opacity(0.9)).frame(width: 14, height: 14)
                                WaveformView(isPlaying: true, color: .orange, bars: 4, maxHeight: 12)
                            }
                            .padding(.horizontal, 10)
                        )
                        .padding(.top, 12)
                    Spacer()
                }
            }
            .frame(height: 160)

            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if page == 1 {
                    HStack {
                        Button("Allow Apple Music") { onAuthorizeMusic() }
                        Button("Allow Spotify") { onAuthorizeSpotify() }
                    }
                    .buttonStyle(.bordered)
                }
                if page == 2 {
                    Toggle("Notch island", isOn: $settings.notchEnabled)
                    Picker("Menu bar", selection: $settings.menuBarStyle) {
                        ForEach(MenuBarStyle.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Mini player", isOn: $settings.miniPlayerEnabled)
                }
                if page == 3 {
                    TextField("Spotify Client ID (optional)", text: $settings.spotifyClientID)
                        .textFieldStyle(.roundedBorder)
                    Button("Connect Spotify likes") { onConnectSpotifyAPI() }
                        .disabled(settings.spotifyClientID.isEmpty)
                    Text("Create an app at developer.spotify.com and set the redirect URI to \(SpotifyAuth.redirectURI).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                HStack {
                    if page > 0 {
                        Button("Back") { page -= 1 }
                    }
                    Spacer()
                    Button(page == 3 ? "Get started" : "Continue") {
                        if page == 3 {
                            settings.completeOnboarding()
                            onDone()
                        } else {
                            page += 1
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
        .frame(width: 460, height: 520)
    }

    private var title: String {
        switch page {
        case 0: return "Your notch, now playing."
        case 1: return "Let Nock talk to your players"
        case 2: return "Pick your surfaces"
        default: return "Spotify extras"
        }
    }

    private var subtitle: String {
        switch page {
        case 0: return "Hover the camera housing to control Apple Music, Spotify, or anything else that’s playing — like Dynamic Island, built for macOS."
        case 1: return "macOS will ask for Automation access so Nock can read the current track and skip songs. You can change this later in System Settings."
        case 2: return "The island sits in the hardware notch. The menu bar and mini player share the same playback engine."
        default: return "Connecting the Spotify Web API unlocks likes from the island. Skip this if you only need play, pause, and skip."
        }
    }
}

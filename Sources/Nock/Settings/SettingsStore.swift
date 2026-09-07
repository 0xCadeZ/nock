import Foundation
import ServiceManagement

enum MenuBarStyle: String, CaseIterable, Identifiable, Codable {
    case hidden
    case albumArt
    case waveform
    case title
    case artAndTitle
    case inlineTransport

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hidden: return "Hidden"
        case .albumArt: return "Album art"
        case .waveform: return "Waveform"
        case .title: return "Title · artist"
        case .artAndTitle: return "Art + title"
        case .inlineTransport: return "Inline controls"
        }
    }
}

enum PopoverStyle: String, CaseIterable, Identifiable, Codable {
    case material
    case albumBlur
    case gradient

    var id: String { rawValue }

    var title: String {
        switch self {
        case .material: return "Material"
        case .albumBlur: return "Album blur"
        case .gradient: return "Gradient"
        }
    }
}

enum MiniPlayerStyle: String, CaseIterable, Identifiable, Codable {
    case vertical
    case horizontal
    case minimal
    case gradient

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vertical: return "Vertical card"
        case .horizontal: return "Horizontal"
        case .minimal: return "Minimal"
        case .gradient: return "Gradient blur"
        }
    }
}

enum MiniPlayerSize: String, CaseIterable, Identifiable, Codable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    var scale: CGFloat {
        switch self {
        case .small: return 0.82
        case .medium: return 1.0
        case .large: return 1.22
        }
    }
}

enum NotchDisplayTarget: String, CaseIterable, Identifiable, Codable {
    case notchScreen
    case main
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notchScreen: return "Notched display"
        case .main: return "Main display"
        case .all: return "All displays"
        }
    }
}

enum SecondaryButton: String, CaseIterable, Identifiable, Codable {
    case shuffle
    case `repeat`
    case like
    case volume

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shuffle: return "Shuffle"
        case .repeat: return "Repeat"
        case .like: return "Favorite"
        case .volume: return "Volume"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults
    private let cloud = NSUbiquitousKeyValueStore.default

    @Published var hasCompletedOnboarding: Bool {
        didSet { set("hasCompletedOnboarding", hasCompletedOnboarding) }
    }

    @Published var preferredSource: PlayerSource {
        didSet { set("preferredSource", preferredSource.rawValue) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            set("launchAtLogin", launchAtLogin)
            Self.updateLoginItem(launchAtLogin)
        }
    }

    @Published var hapticsEnabled: Bool {
        didSet { set("hapticsEnabled", hapticsEnabled) }
    }

    @Published var notchEnabled: Bool {
        didSet { set("notchEnabled", notchEnabled) }
    }

    @Published var hoverDelay: Double {
        didSet { set("hoverDelay", hoverDelay) }
    }

    @Published var liveActivityOnTrackChange: Bool {
        didSet { set("liveActivityOnTrackChange", liveActivityOnTrackChange) }
    }

    @Published var displayTarget: NotchDisplayTarget {
        didSet { set("displayTarget", displayTarget.rawValue) }
    }

    @Published var hideInFullscreen: Bool {
        didSet { set("hideInFullscreen", hideInFullscreen) }
    }

    @Published var notchHeightOffset: Double {
        didSet { set("notchHeightOffset", notchHeightOffset) }
    }

    @Published var showLyricsPage: Bool {
        didSet { set("showLyricsPage", showLyricsPage) }
    }

    @Published var menuBarStyle: MenuBarStyle {
        didSet { set("menuBarStyle", menuBarStyle.rawValue) }
    }

    @Published var popoverStyle: PopoverStyle {
        didSet { set("popoverStyle", popoverStyle.rawValue) }
    }

    @Published var menuBarTitleLength: Int {
        didSet { set("menuBarTitleLength", menuBarTitleLength) }
    }

    @Published var waveformMonochrome: Bool {
        didSet { set("waveformMonochrome", waveformMonochrome) }
    }

    @Published var miniPlayerEnabled: Bool {
        didSet { set("miniPlayerEnabled", miniPlayerEnabled) }
    }

    @Published var miniPlayerVisible: Bool {
        didSet { set("miniPlayerVisible", miniPlayerVisible) }
    }

    @Published var miniPlayerStyle: MiniPlayerStyle {
        didSet { set("miniPlayerStyle", miniPlayerStyle.rawValue) }
    }

    @Published var miniPlayerSize: MiniPlayerSize {
        didSet { set("miniPlayerSize", miniPlayerSize.rawValue) }
    }

    @Published var miniPlayerAlwaysOnTop: Bool {
        didSet { set("miniPlayerAlwaysOnTop", miniPlayerAlwaysOnTop) }
    }

    @Published var leftSecondary: SecondaryButton {
        didSet { set("leftSecondary", leftSecondary.rawValue) }
    }

    @Published var rightSecondary: SecondaryButton {
        didSet { set("rightSecondary", rightSecondary.rawValue) }
    }

    @Published var swipeToSkip: Bool {
        didSet { set("swipeToSkip", swipeToSkip) }
    }

    @Published var swipeToExpand: Bool {
        didSet { set("swipeToExpand", swipeToExpand) }
    }

    @Published var scrollVolume: Bool {
        didSet { set("scrollVolume", scrollVolume) }
    }

    @Published var spotifyClientID: String {
        didSet { set("spotifyClientID", spotifyClientID) }
    }

    @Published var lastFMAPIKey: String {
        didSet { set("lastFMAPIKey", lastFMAPIKey) }
    }

    @Published var lastFMSessionKey: String {
        didSet { set("lastFMSessionKey", lastFMSessionKey) }
    }

    @Published var hideFromScreenCapture: Bool {
        didSet { set("hideFromScreenCapture", hideFromScreenCapture) }
    }

    @Published var hoverOpenEnabled: Bool {
        didSet { set("hoverOpenEnabled", hoverOpenEnabled) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        preferredSource = PlayerSource(rawValue: defaults.string(forKey: "preferredSource") ?? "") ?? .auto
        launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? false
        hapticsEnabled = defaults.object(forKey: "hapticsEnabled") as? Bool ?? true
        notchEnabled = defaults.object(forKey: "notchEnabled") as? Bool ?? true
        hoverDelay = defaults.object(forKey: "hoverDelay") as? Double ?? 0.08
        liveActivityOnTrackChange = defaults.object(forKey: "liveActivityOnTrackChange") as? Bool ?? true
        displayTarget = NotchDisplayTarget(rawValue: defaults.string(forKey: "displayTarget") ?? "") ?? .notchScreen
        hideInFullscreen = defaults.object(forKey: "hideInFullscreen") as? Bool ?? false
        notchHeightOffset = defaults.object(forKey: "notchHeightOffset") as? Double ?? 0
        showLyricsPage = defaults.object(forKey: "showLyricsPage") as? Bool ?? true
        menuBarStyle = MenuBarStyle(rawValue: defaults.string(forKey: "menuBarStyle") ?? "") ?? .artAndTitle
        popoverStyle = PopoverStyle(rawValue: defaults.string(forKey: "popoverStyle") ?? "") ?? .albumBlur
        menuBarTitleLength = defaults.object(forKey: "menuBarTitleLength") as? Int ?? 22
        waveformMonochrome = defaults.bool(forKey: "waveformMonochrome")
        miniPlayerEnabled = defaults.object(forKey: "miniPlayerEnabled") as? Bool ?? true
        miniPlayerVisible = defaults.bool(forKey: "miniPlayerVisible")
        miniPlayerStyle = MiniPlayerStyle(rawValue: defaults.string(forKey: "miniPlayerStyle") ?? "") ?? .vertical
        miniPlayerSize = MiniPlayerSize(rawValue: defaults.string(forKey: "miniPlayerSize") ?? "") ?? .medium
        miniPlayerAlwaysOnTop = defaults.object(forKey: "miniPlayerAlwaysOnTop") as? Bool ?? true
        leftSecondary = SecondaryButton(rawValue: defaults.string(forKey: "leftSecondary") ?? "") ?? .shuffle
        rightSecondary = SecondaryButton(rawValue: defaults.string(forKey: "rightSecondary") ?? "") ?? .repeat
        swipeToSkip = defaults.object(forKey: "swipeToSkip") as? Bool ?? true
        swipeToExpand = defaults.object(forKey: "swipeToExpand") as? Bool ?? true
        scrollVolume = defaults.object(forKey: "scrollVolume") as? Bool ?? true
        spotifyClientID = defaults.string(forKey: "spotifyClientID") ?? ""
        lastFMAPIKey = defaults.string(forKey: "lastFMAPIKey") ?? ""
        lastFMSessionKey = defaults.string(forKey: "lastFMSessionKey") ?? ""
        hideFromScreenCapture = defaults.bool(forKey: "hideFromScreenCapture")
        hoverOpenEnabled = defaults.object(forKey: "hoverOpenEnabled") as? Bool ?? true
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    private func set(_ key: String, _ value: Any) {
        defaults.set(value, forKey: key)
        cloud.set(value, forKey: key)
    }

    static func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Nock login item: \(error.localizedDescription)")
        }
    }
}

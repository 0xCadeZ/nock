import AppKit
import Foundation
import SwiftUI

struct HotKeySpec: Equatable, Codable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags.RawValue
    var enabled: Bool

    var display: String {
        guard enabled else { return "—" }
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append(Self.name(for: keyCode))
        return parts.joined()
    }

    func matches(_ event: NSEvent) -> Bool {
        guard enabled else { return false }
        let wanted = NSEvent.ModifierFlags(rawValue: modifiers).intersection([.command, .option, .control, .shift])
        let got = event.modifierFlags.intersection([.command, .option, .control, .shift])
        return event.keyCode == keyCode && wanted == got
    }

    static func name(for keyCode: UInt16) -> String {
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
            49: "Space", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return map[keyCode] ?? "Key \(keyCode)"
    }
}

@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    var playPause = HotKeySpec(keyCode: 49, modifiers: NSEvent.ModifierFlags([.command, .option]).rawValue, enabled: true)
    var next = HotKeySpec(keyCode: 124, modifiers: NSEvent.ModifierFlags([.command, .option]).rawValue, enabled: true)
    var previous = HotKeySpec(keyCode: 123, modifiers: NSEvent.ModifierFlags([.command, .option]).rawValue, enabled: true)
    var like = HotKeySpec(keyCode: 37, modifiers: NSEvent.ModifierFlags([.command, .option]).rawValue, enabled: false)
    var toggleMini = HotKeySpec(keyCode: 46, modifiers: NSEvent.ModifierFlags([.command, .option]).rawValue, enabled: true)
    var toggleLive = HotKeySpec(keyCode: 37, modifiers: NSEvent.ModifierFlags([.command, .option, .shift]).rawValue, enabled: false)

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private weak var playback: PlaybackStore?
    var onToggleMini: (() -> Void)?
    var onToggleLive: (() -> Void)?

    func bind(playback: PlaybackStore) {
        self.playback = playback
        load()
        reregister()
    }

    func reregister() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
            return event
        }
        save()
    }

    private func handle(_ event: NSEvent) {
        if playPause.matches(event) { playback?.togglePlay() }
        else if next.matches(event) { playback?.next() }
        else if previous.matches(event) { playback?.previous() }
        else if like.matches(event) { playback?.toggleLike() }
        else if toggleMini.matches(event) { onToggleMini?() }
        else if toggleLive.matches(event) { onToggleLive?() }
    }

    private func save() {
        let map: [String: HotKeySpec] = [
            "playPause": playPause, "next": next, "previous": previous,
            "like": like, "toggleMini": toggleMini, "toggleLive": toggleLive
        ]
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: "hotkeys")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: "hotkeys"),
              let map = try? JSONDecoder().decode([String: HotKeySpec].self, from: data)
        else { return }
        playPause = map["playPause"] ?? playPause
        next = map["next"] ?? next
        previous = map["previous"] ?? previous
        like = map["like"] ?? like
        toggleMini = map["toggleMini"] ?? toggleMini
        toggleLive = map["toggleLive"] ?? toggleLive
    }
}

struct HotKeyRecorder: View {
    var title: String
    @Binding var spec: HotKeySpec
    var onChange: () -> Void
    @State private var recording = false

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: Binding(get: { spec.enabled }, set: { spec.enabled = $0; onChange() }))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            Button(recording ? "Press a key…" : spec.display) {
                recording = true
            }
            .frame(minWidth: 90)
        }
        .onAppear { install() }
        .onChange(of: recording) { _ in install() }
    }

    private func install() {
        guard recording else { return }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard recording else { return event }
            spec.keyCode = event.keyCode
            spec.modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift]).rawValue
            spec.enabled = true
            recording = false
            onChange()
            return nil
        }
    }
}

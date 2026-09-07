import CoreAudio
import Foundation

struct AudioDevice: Identifiable, Hashable {
    var id: AudioDeviceID
    var name: String
    var uid: String
}

enum AudioOutput {
    static func devices() -> [AudioDevice] {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else {
            return []
        }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else {
            return []
        }
        return ids.compactMap { id in
            guard hasOutput(id), let name = stringProperty(id, kAudioObjectPropertyName) else { return nil }
            return AudioDevice(id: id, name: name, uid: stringProperty(id, kAudioDevicePropertyDeviceUID) ?? "\(id)")
        }
    }

    static func defaultOutput() -> AudioDevice? {
        var id = AudioDeviceID()
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id) == noErr else {
            return nil
        }
        return devices().first(where: { $0.id == id })
    }

    static func setDefaultOutput(_ id: AudioDeviceID) {
        var value = id
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &value)
    }

    static var systemVolume: Float {
        get {
            guard let id = defaultOutput()?.id else { return 0.5 }
            var volume = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, &volume)
            return volume
        }
        set {
            guard let id = defaultOutput()?.id else { return }
            var volume = Float32(min(1, max(0, newValue)))
            let size = UInt32(MemoryLayout<Float32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectSetPropertyData(id, &address, 0, nil, size, &volume)
        }
    }

    private static func hasOutput(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func stringProperty(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr else { return nil }
        let ptr = UnsafeMutablePointer<CFString?>.allocate(capacity: 1)
        defer { ptr.deallocate() }
        ptr.initialize(to: nil)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, ptr)
        guard status == noErr, let cf = ptr.pointee else { return nil }
        return cf as String
    }
}

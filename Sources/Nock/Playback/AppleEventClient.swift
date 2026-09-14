import AppKit
import Foundation

/// Packs a four-character code such as `"pPlS"` into an `OSType`.
func fourCharCode(_ code: String) -> OSType {
    precondition(code.utf8.count == 4, "four-character code must be exactly 4 bytes: \(code)")
    return code.utf8.reduce(0) { ($0 << 8) | OSType($1) }
}

/// Unpacks an `OSType` back into its four-character string form.
func fourCharString(_ code: OSType) -> String {
    let bytes = (0..<4).reversed().map { UInt8((code >> (8 * $0)) & 0xFF) }
    return String(decoding: bytes, as: UTF8.self)
}

/// Minimal Apple event client that targets a running app by process id.
///
/// AppleScript, JXA and ScriptingBridge resolve their target to an app bundle and
/// relaunch it when the process is gone, even when originally bound by pid. A raw
/// Apple event addressed by pid instead fails with `procNotFound` (-600) once the
/// process exits. That property is what keeps nock from reopening a player the
/// user has just quit, so every player interaction must go through this type.
struct AppleEventClient {
    enum Failure: Error, LocalizedError, Equatable {
        case processNotFound
        case send(OSStatus)
        case application(Int32)
        case missingResult
        case unexpectedType(String)

        var errorDescription: String? {
            switch self {
            case .processNotFound: return "The target process is no longer running."
            case .send(let status): return "Apple event send failed (\(status))."
            case .application(let code): return "The target app returned error \(code)."
            case .missingResult: return "The target app returned no result."
            case .unexpectedType(let type): return "Unexpected Apple event result type \(type)."
            }
        }

        /// True when the failure just means the app has quit; callers treat it as "not running".
        var isProcessGone: Bool {
            switch self {
            case .processNotFound: return true
            case .send(let status): return status == Self.procNotFound
            default: return false
            }
        }

        static let procNotFound: OSStatus = -600
        /// errAENoSuchObject: e.g. asking for the current track when nothing is loaded.
        static let noSuchObject: Int32 = -1728
    }

    private enum Key {
        static let directObject = fourCharCode("----")
        static let errorNumber = fourCharCode("errn")
        static let data = fourCharCode("data")
        static let want = fourCharCode("want")
        static let from = fourCharCode("from")
        static let form = fourCharCode("form")
        static let seld = fourCharCode("seld")
    }

    private enum TypeCode {
        static let objectSpecifier = fourCharCode("obj ")
        static let property = fourCharCode("prop")
        static let index = fourCharCode("indx")
        static let unicodeText = fourCharCode("utxt")
        static let float64 = fourCharCode("doub")
        static let boolean = fourCharCode("bool")
        static let core = fourCharCode("core")
        static let getData = fourCharCode("getd")
        static let setData = fourCharCode("setd")
    }

    private static let queue = DispatchQueue(label: "nock.appleevents", qos: .userInitiated)

    let pid: pid_t
    var timeout: TimeInterval = 2

    // MARK: Running work off the main thread

    /// Runs `body` with a client for `pid` on a background queue. Apple event sends
    /// block until the reply arrives, so they must never run on the main thread.
    static func perform<T>(pid: pid_t, _ body: @escaping (AppleEventClient) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try body(AppleEventClient(pid: pid)))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: Object specifiers

    /// `property <code> of <container>`; a nil container means the application itself.
    static func property(_ code: String, of container: NSAppleEventDescriptor? = nil) -> NSAppleEventDescriptor {
        specifier(
            want: NSAppleEventDescriptor(typeCode: TypeCode.property),
            form: TypeCode.property,
            seld: NSAppleEventDescriptor(typeCode: fourCharCode(code)),
            container: container
        )
    }

    /// `<classCode> <index> of <container>` using 1-based indexing, as AppleScript does.
    static func element(_ classCode: String, index: Int, of container: NSAppleEventDescriptor? = nil) -> NSAppleEventDescriptor {
        specifier(
            want: NSAppleEventDescriptor(typeCode: fourCharCode(classCode)),
            form: TypeCode.index,
            seld: NSAppleEventDescriptor(int32: Int32(index)),
            container: container
        )
    }

    private static func specifier(
        want: NSAppleEventDescriptor,
        form: OSType,
        seld: NSAppleEventDescriptor,
        container: NSAppleEventDescriptor?
    ) -> NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(want, forKeyword: Key.want)
        record.setDescriptor(container ?? NSAppleEventDescriptor.null(), forKeyword: Key.from)
        record.setDescriptor(NSAppleEventDescriptor(enumCode: form), forKeyword: Key.form)
        record.setDescriptor(seld, forKeyword: Key.seld)
        return record.coerce(toDescriptorType: TypeCode.objectSpecifier) ?? record
    }

    // MARK: Events

    /// `get <specifier>`; returns the reply's direct object.
    func get(_ specifier: NSAppleEventDescriptor) throws -> NSAppleEventDescriptor {
        let event = makeEvent(eventClass: TypeCode.core, eventID: TypeCode.getData)
        event.setParam(specifier, forKeyword: Key.directObject)
        let reply = try send(event)
        guard let result = reply.paramDescriptor(forKeyword: Key.directObject) else {
            throw Failure.missingResult
        }
        return result
    }

    /// `set <specifier> to <value>`.
    func set(_ specifier: NSAppleEventDescriptor, to value: NSAppleEventDescriptor) throws {
        let event = makeEvent(eventClass: TypeCode.core, eventID: TypeCode.setData)
        event.setParam(specifier, forKeyword: Key.directObject)
        event.setParam(value, forKeyword: Key.data)
        _ = try send(event)
    }

    /// Sends a parameterless command such as Spotify's `spfy/PlPs`.
    func command(eventClass: String, eventID: String) throws {
        _ = try send(makeEvent(eventClass: fourCharCode(eventClass), eventID: fourCharCode(eventID)))
    }

    // MARK: Typed getters

    func string(_ specifier: NSAppleEventDescriptor) throws -> String {
        let result = try get(specifier)
        guard let value = result.coerce(toDescriptorType: TypeCode.unicodeText)?.stringValue else {
            throw Failure.unexpectedType(fourCharString(result.descriptorType))
        }
        return value
    }

    func double(_ specifier: NSAppleEventDescriptor) throws -> Double {
        let result = try get(specifier)
        guard let value = result.coerce(toDescriptorType: TypeCode.float64) else {
            throw Failure.unexpectedType(fourCharString(result.descriptorType))
        }
        return value.doubleValue
    }

    func bool(_ specifier: NSAppleEventDescriptor) throws -> Bool {
        let result = try get(specifier)
        guard let value = result.coerce(toDescriptorType: TypeCode.boolean) else {
            throw Failure.unexpectedType(fourCharString(result.descriptorType))
        }
        return value.booleanValue
    }

    /// Four-character enumerator code, e.g. `"kPSP"` for Music/Spotify's playing state.
    func enumCode(_ specifier: NSAppleEventDescriptor) throws -> String {
        let result = try get(specifier)
        let code = result.enumCodeValue
        guard code != 0 else { throw Failure.unexpectedType(fourCharString(result.descriptorType)) }
        return fourCharString(code)
    }

    func data(_ specifier: NSAppleEventDescriptor) throws -> Data {
        let result = try get(specifier)
        guard !result.data.isEmpty else { throw Failure.unexpectedType(fourCharString(result.descriptorType)) }
        return result.data
    }

    // MARK: Plumbing

    private func makeEvent(eventClass: OSType, eventID: OSType) -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(
            eventClass: eventClass,
            eventID: eventID,
            targetDescriptor: NSAppleEventDescriptor(processIdentifier: pid),
            returnID: Int16(kAutoGenerateReturnID),
            transactionID: Int32(kAnyTransactionID)
        )
    }

    private func send(_ event: NSAppleEventDescriptor) throws -> NSAppleEventDescriptor {
        let reply: NSAppleEventDescriptor
        do {
            reply = try event.sendEvent(options: [.waitForReply, .neverInteract], timeout: timeout)
        } catch let error as NSError {
            let status = OSStatus(truncatingIfNeeded: error.code)
            throw status == Failure.procNotFound ? Failure.processNotFound : Failure.send(status)
        }
        if let errorNumber = reply.paramDescriptor(forKeyword: Key.errorNumber)?.int32Value, errorNumber != 0 {
            throw Failure.application(errorNumber)
        }
        return reply
    }
}

/// Leading-dot sugar so call sites can write `ae.string(.property("pnam", of: track))`.
extension NSAppleEventDescriptor {
    static func property(_ code: String, of container: NSAppleEventDescriptor? = nil) -> NSAppleEventDescriptor {
        AppleEventClient.property(code, of: container)
    }

    static func element(_ classCode: String, index: Int, of container: NSAppleEventDescriptor? = nil) -> NSAppleEventDescriptor {
        AppleEventClient.element(classCode, index: index, of: container)
    }
}

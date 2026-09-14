import Foundation
import Testing
@testable import Nock

struct AppleEventClientTests {
    @Test func fourCharCodeRoundTrips() {
        #expect(fourCharString(fourCharCode("pPlS")) == "pPlS")
        #expect(fourCharString(fourCharCode("ID  ")) == "ID  ")
        #expect(fourCharCode("core") == 0x636F_7265)
    }

    @Test func propertySpecifierOfApplication() {
        let spec = AppleEventClient.property("pPlS")
        #expect(fourCharString(spec.descriptorType) == "obj ")
        #expect(spec.forKeyword(fourCharCode("want"))?.typeCodeValue == fourCharCode("prop"))
        #expect(spec.forKeyword(fourCharCode("form"))?.enumCodeValue == fourCharCode("prop"))
        #expect(spec.forKeyword(fourCharCode("seld"))?.typeCodeValue == fourCharCode("pPlS"))
        #expect(fourCharString(spec.forKeyword(fourCharCode("from"))?.descriptorType ?? 0) == "null")
    }

    @Test func elementSpecifierNestsContainer() {
        let track = AppleEventClient.property("pTrk")
        let artwork = AppleEventClient.element("cArt", index: 1, of: track)
        #expect(artwork.forKeyword(fourCharCode("want"))?.typeCodeValue == fourCharCode("cArt"))
        #expect(artwork.forKeyword(fourCharCode("form"))?.enumCodeValue == fourCharCode("indx"))
        #expect(artwork.forKeyword(fourCharCode("seld"))?.int32Value == 1)
        #expect(artwork.forKeyword(fourCharCode("from"))?.forKeyword(fourCharCode("seld"))?.typeCodeValue == fourCharCode("pTrk"))
    }

    /// The whole point of the client: an event to a dead pid fails instead of launching anything.
    @Test func deadProcessFailsWithProcessNotFound() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try process.run()
        process.waitUntilExit()
        let client = AppleEventClient(pid: process.processIdentifier, timeout: 1)
        #expect(throws: AppleEventClient.Failure.processNotFound) {
            try client.get(.property("pPlS"))
        }
    }

    @Test func processGoneClassification() {
        #expect(AppleEventClient.Failure.send(-600).isProcessGone)
        #expect(AppleEventClient.Failure.processNotFound.isProcessGone)
        #expect(!AppleEventClient.Failure.send(-1712).isProcessGone)
        #expect(!AppleEventClient.Failure.application(-1728).isProcessGone)
    }

    /// Live check against a running Spotify; skipped when it is not open.
    @Test(.enabled(if: RunningApps.processID(for: SpotifyController.bundleID) != nil))
    func readsPlayerStateFromRunningSpotify() async throws {
        let pid = try #require(RunningApps.processID(for: SpotifyController.bundleID))
        let state = try await AppleEventClient.perform(pid: pid) { ae in
            PlayerPayload.stateName(forCode: try ae.enumCode(.property("pPlS")))
        }
        #expect(["playing", "paused", "stopped"].contains(state), "unexpected state \(state)")
    }

    /// Round-trips Spotify's shuffle flag through set/get, leaving it as it was.
    /// Spotify applies property writes asynchronously (about 100 ms), hence the waits.
    @Test(.enabled(if: RunningApps.processID(for: SpotifyController.bundleID) != nil))
    func setsAndReadsShuffleOnRunningSpotify() async throws {
        let pid = try #require(RunningApps.processID(for: SpotifyController.bundleID))
        let settleTime: TimeInterval = 0.5
        let (original, flipped, restored) = try await AppleEventClient.perform(pid: pid) { ae -> (Bool, Bool, Bool) in
            let shuffling = NSAppleEventDescriptor.property("pShu")
            let original = try ae.bool(shuffling)
            try ae.set(shuffling, to: NSAppleEventDescriptor(boolean: !original))
            Thread.sleep(forTimeInterval: settleTime)
            let flipped = try ae.bool(shuffling)
            try ae.set(shuffling, to: NSAppleEventDescriptor(boolean: original))
            Thread.sleep(forTimeInterval: settleTime)
            return (original, flipped, try ae.bool(shuffling))
        }
        #expect(flipped == !original)
        #expect(restored == original)
    }
}

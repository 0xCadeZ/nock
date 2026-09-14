import Testing
@testable import Nock

struct PlayerPayloadTests {
    @Test func stateNames() {
        #expect(PlayerPayload.stateName(forCode: "kPSP") == "playing")
        #expect(PlayerPayload.stateName(forCode: "kPSp") == "paused")
        #expect(PlayerPayload.stateName(forCode: "kPSS") == "stopped")
        #expect(PlayerPayload(state: "playing").isPlaying)
        #expect(!PlayerPayload(state: "paused").isPlaying)
    }

    @Test func repeatAndMediaKindNames() {
        #expect(PlayerPayload.repeatName(forCode: "kRpO") == "off")
        #expect(PlayerPayload.repeatName(forCode: "kRp1") == "one")
        #expect(PlayerPayload.repeatName(forCode: "kAll") == "all")
        #expect(PlayerPayload(repeating: "one").repeatMode == .one)
        #expect(PlayerPayload(repeating: "all").repeatMode == .all)
        #expect(PlayerPayload(repeating: nil).repeatMode == .off)
        #expect(PlayerPayload.mediaKindName(forCode: "kMdS") == "song")
        #expect(PlayerPayload(mediaKind: "song").media == .music)
        #expect(PlayerPayload(mediaKind: "podcast").media == .podcast)
    }

    @Test func trackRequiresTitle() {
        #expect(PlayerPayload(artist: "Someone").track(source: .spotify) == nil)
        #expect(PlayerPayload(title: "").track(source: .spotify) == nil)
    }

    @Test func trackNormalisesMillisecondDurations() {
        #expect(PlayerPayload(title: "Song", duration: 213_000).track(source: .spotify)?.duration == 213)
        #expect(PlayerPayload(title: "Song", duration: 213).track(source: .music)?.duration == 213)
    }

    @Test func trackFallsBackToDerivedIDAndBundle() {
        let track = PlayerPayload(title: "Song", artist: "Band", favorited: true).track(source: .music)
        #expect(track?.id == "music-Song-Band")
        #expect(track?.bundleIdentifier == "com.apple.Music")
        #expect(track?.isLiked == true)
    }

    @Test func musicRepeatCycleOrder() {
        #expect(MusicController.nextRepeat(after: "off") == .all)
        #expect(MusicController.nextRepeat(after: "all") == .one)
        #expect(MusicController.nextRepeat(after: "one") == .off)
    }
}

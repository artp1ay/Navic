import Foundation
import Testing
@testable import navic

struct PlaybackStateTests {
    @Test func progressIsZeroWithoutPositiveDuration() {
        #expect(PlaybackState(elapsed: 30, duration: nil).progress == 0)
        #expect(PlaybackState(elapsed: 30, duration: 0).progress == 0)
        #expect(PlaybackState(elapsed: 30, duration: -1).progress == 0)
    }

    @Test func progressClampsToClosedUnitRange() {
        #expect(PlaybackState(elapsed: -15, duration: 60).progress == 0)
        #expect(PlaybackState(elapsed: 30, duration: 60).progress == 0.5)
        #expect(PlaybackState(elapsed: 90, duration: 60).progress == 1)
    }
}

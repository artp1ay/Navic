import Foundation
import Testing
@testable import navic

struct AppleMusicSnapshotTests {
    @Test func parsesFullyPopulatedPayload() throws {
        let raw = "playing|PID-1|Some Title|Some Artist|Some Album|245.5|123.25"
        let snapshot = try #require(AppleMusicSnapshot(rawString: raw))

        #expect(snapshot.playerState == .playing)
        #expect(snapshot.persistentId == "PID-1")
        #expect(snapshot.title == "Some Title")
        #expect(snapshot.artist == "Some Artist")
        #expect(snapshot.album == "Some Album")
        #expect(snapshot.duration == 245.5)
        #expect(snapshot.position == 123.25)
    }

    @Test func returnsNilWhenEverythingIsEmpty() {
        #expect(AppleMusicSnapshot(rawString: "stopped|||||||") == nil)
        #expect(AppleMusicSnapshot(rawString: "") == nil)
    }

    @Test func synthesizesIdWhenPersistentIdMissingButMetadataPresent() throws {
        let raw = "playing||Song Title|Some Artist|An Album|180|10"
        let snapshot = try #require(AppleMusicSnapshot(rawString: raw))

        #expect(snapshot.persistentId.hasPrefix("synth:"))
        #expect(snapshot.persistentId.contains("Song Title"))
        #expect(snapshot.title == "Song Title")
        #expect(snapshot.artist == "Some Artist")
    }

    @Test func synthesizedIdIsStableForTheSameTrack() throws {
        let raw = "playing||T|A|Al|180|10"
        let first = try #require(AppleMusicSnapshot(rawString: raw))
        let second = try #require(AppleMusicSnapshot(rawString: raw))

        #expect(first.persistentId == second.persistentId)
    }

    @Test func missingFieldsFallBackToUnknownOrNil() throws {
        let snapshot = try #require(AppleMusicSnapshot(rawString: "paused|PID-2|||||"))

        #expect(snapshot.playerState == .paused)
        #expect(snapshot.persistentId == "PID-2")
        #expect(snapshot.title == "Unknown")
        #expect(snapshot.artist == "Unknown")
        #expect(snapshot.album == nil)
        #expect(snapshot.duration == nil)
        #expect(snapshot.position == nil)
    }

    @Test func zeroOrNegativeDurationCollapsesToNil() throws {
        let snapshot = try #require(AppleMusicSnapshot(rawString: "playing|PID-3|T|A|Album|0|10"))
        #expect(snapshot.duration == nil)
    }

    @Test func unknownPlayerStateMapsToUnknownCase() throws {
        let snapshot = try #require(AppleMusicSnapshot(rawString: "scratching|PID-4|T|A|Al|10|0"))
        #expect(snapshot.playerState == .unknown)
    }
}

import Foundation
import AppKit

enum AppleMusicPlayerState: String {
    case stopped
    case playing
    case paused
    case fastForwarding = "fast forwarding"
    case rewinding
    case unknown
}

struct AppleMusicSnapshot: Equatable, Sendable {
    var playerState: AppleMusicPlayerState
    var persistentId: String
    var title: String
    var artist: String
    var album: String?
    var duration: TimeInterval?
    var position: TimeInterval?
}

extension AppleMusicPlayerState: Sendable {}

enum AppleMusicScriptingError: LocalizedError {
    case notInstalled
    case notAuthorized
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "The Music app isn't installed on this Mac."
        case .notAuthorized:
            return "Navic isn't allowed to control Music. Grant access in System Settings → Privacy & Security → Automation."
        case .scriptFailed(let message):
            return message
        }
    }
}

protocol AppleMusicScripting: AnyObject {
    var isMusicAppAvailable: Bool { get }
    func snapshot() async throws -> AppleMusicSnapshot?
    func artworkData() async throws -> Data?
}

extension AppleMusicSnapshot {
    /// Parses the pipe-delimited payload produced by the snapshot AppleScript.
    /// Layout: `state|persistentId|title|artist|album|duration|position`.
    /// Returns nil when Music has no current track at all; for tracks where
    /// Music doesn't expose a persistent ID (some Apple Music subscription
    /// streams), the ID is synthesised from the metadata so artwork caching
    /// and "did the track change?" diffing still work.
    init?(rawString: String) {
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed
            .split(separator: "|", maxSplits: 6, omittingEmptySubsequences: false)
            .map(String.init)
        guard parts.count == 7 else { return nil }

        let providedId = parts[1]
        let rawTitle = parts[2]
        let rawArtist = parts[3]

        guard !providedId.isEmpty || !rawTitle.isEmpty || !rawArtist.isEmpty else {
            return nil
        }

        self.playerState = AppleMusicPlayerState(rawValue: parts[0]) ?? .unknown
        let albumPart = parts[4]
        self.persistentId = providedId.isEmpty
            ? "synth:\(rawTitle)|\(rawArtist)|\(albumPart)"
            : providedId
        self.title = rawTitle.isEmpty ? "Unknown" : rawTitle
        self.artist = rawArtist.isEmpty ? "Unknown" : rawArtist
        self.album = albumPart.isEmpty ? nil : albumPart
        self.duration = Double(parts[5]).flatMap { $0 > 0 ? $0 : nil }
        self.position = Double(parts[6])
    }
}

/// Real implementation that drives Music.app via NSAppleScript.
/// Calls are serialised through a private queue because NSAppleScript itself
/// is not thread-safe and we don't want simultaneous Apple Events in flight.
final class AppleMusicScriptingBridge: AppleMusicScripting {

    private let queue = DispatchQueue(label: "navic.appleMusic.scripting")
    private let musicBundleIdentifier = "com.apple.Music"

    var isMusicAppAvailable: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: musicBundleIdentifier) != nil
    }

    private var isMusicRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == musicBundleIdentifier
        }
    }

    private static let snapshotScript = """
    tell application id "com.apple.Music"
        try
            set ps to player state
        on error
            return ""
        end try
        set stateString to "stopped"
        if ps is playing then set stateString to "playing"
        if ps is paused then set stateString to "paused"
        if ps is fast forwarding then set stateString to "fast forwarding"
        if ps is rewinding then set stateString to "rewinding"

        set pid to ""
        set tName to ""
        set tArtist to ""
        set tAlbum to ""
        set tDur to ""
        set tPos to ""

        try
            set tName to (name of current track) as string
        end try
        try
            set tArtist to (artist of current track) as string
        end try
        try
            set tAlbum to (album of current track) as string
        end try
        try
            set tDur to (duration of current track) as string
        end try
        try
            set tPos to (player position) as string
        end try
        try
            set pid to (persistent ID of current track) as string
        end try
        if pid is "" then
            try
                set pid to (database ID of current track) as string
            end try
        end if

        return stateString & "|" & pid & "|" & tName & "|" & tArtist & "|" & tAlbum & "|" & tDur & "|" & tPos
    end tell
    """

    func snapshot() async throws -> AppleMusicSnapshot? {
        guard isMusicAppAvailable else { throw AppleMusicScriptingError.notInstalled }
        guard isMusicRunning else { return nil }

        guard let raw = try await runScript(source: Self.snapshotScript) else { return nil }
        return AppleMusicSnapshot(rawString: raw)
    }

    func artworkData() async throws -> Data? {
        guard isMusicAppAvailable, isMusicRunning else { return nil }

        let tempPath = NSTemporaryDirectory().appending("navic-artwork-\(UUID().uuidString)")
        // Music transfers the artwork bytes back via Apple Events; the write
        // call runs in this process, so the file lands in our sandbox temp dir.
        let script = """
        tell application id "com.apple.Music"
            if not (exists current track) then return ""
            try
                set imgData to (data of artwork 1 of current track)
            on error
                return ""
            end try
            try
                set fileRef to open for access (POSIX file "\(tempPath)") with write permission
                set eof fileRef to 0
                write imgData to fileRef
                close access fileRef
                return "\(tempPath)"
            on error errMsg
                try
                    close access (POSIX file "\(tempPath)")
                end try
                return ""
            end try
        end tell
        """

        guard let path = try await runScript(source: script),
              !path.isEmpty else { return nil }
        defer { try? FileManager.default.removeItem(atPath: path) }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    /// Runs an AppleScript on the private serial queue and returns its
    /// `stringValue`. We extract just the queue reference before the
    /// continuation so the dispatched closure stays @Sendable-safe.
    private func runScript(source: String) async throws -> String? {
        let queue = self.queue
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                autoreleasepool {
                    guard let script = NSAppleScript(source: source) else {
                        continuation.resume(throwing: AppleMusicScriptingError.scriptFailed("Could not compile script."))
                        return
                    }
                    var errorInfo: NSDictionary?
                    let descriptor = script.executeAndReturnError(&errorInfo)
                    if let info = errorInfo {
                        let code = (info[NSAppleScript.errorNumber] as? Int) ?? 0
                        let message = (info[NSAppleScript.errorMessage] as? String) ?? "AppleScript error \(code)"
                        // -1743 errAEEventNotPermitted — user denied automation.
                        // -600  procNotFound — AE prompt was suppressed
                        //       (NSAppleEventsUsageDescription missing or
                        //       sandbox entitlement absent).
                        // -1744 / -1719 — variants of "not permitted".
                        if code == errAEEventNotPermitted || code == -1743 || code == -1744 ||
                            code == -1719 || code == -600 {
                            continuation.resume(throwing: AppleMusicScriptingError.notAuthorized)
                        } else {
                            continuation.resume(throwing: AppleMusicScriptingError.scriptFailed(message))
                        }
                        return
                    }
                    continuation.resume(returning: descriptor.stringValue)
                }
            }
        }
    }
}

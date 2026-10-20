import AppKit
import CryptoKit
import Foundation

enum MusicServiceError: LocalizedError {
    case musicNotRunning
    case automationDenied
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .musicNotRunning:
            return "Apple Music 没有运行"
        case .automationDenied:
            return "未获得 Apple Music 控制权限"
        case .scriptFailed(let message):
            return message
        }
    }
}

enum MusicService {
    // MARK: - Cache locations

    static let cacheRoot: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let root = base.appendingPathComponent("MiniPlayer", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }()

    static let artworkDirectory: URL = {
        let dir = cacheRoot.appendingPathComponent("artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func artworkFileURL(for cacheKey: String) -> URL {
        let digest = SHA256.hash(data: Data(cacheKey.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return artworkDirectory.appendingPathComponent("\(name).img")
    }

    static func cachedArtworkURL(for cacheKey: String) -> URL? {
        let url = artworkFileURL(for: cacheKey)
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize, size > 0 else {
            return nil
        }
        return url
    }

    // MARK: - Now playing

    static var musicIsRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
    }

    /// Returns nil when Music is not running. A stopped/no-track state returns an empty snapshot.
    static func snapshot() async throws -> TrackSnapshot? {
        guard musicIsRunning else { return nil }

        let script = #"""
        set separatorChar to (ASCII character 30)
        tell application "Music"
            set playbackState to player state
            if playbackState is stopped then return "stopped"
            set currentSong to current track
            return (playbackState as text) & separatorChar & (name of currentSong) & separatorChar & (artist of currentSong) & separatorChar & (album of currentSong) & separatorChar & (duration of currentSong as text) & separatorChar & (player position as text) & separatorChar & (persistent ID of currentSong) & separatorChar & (favorited of currentSong as text)
        end tell
        """#

        let output = try await runScript(script).trimmingCharacters(in: .whitespacesAndNewlines)
        if output.isEmpty || output == "stopped" {
            return TrackSnapshot(
                state: .stopped,
                name: "",
                artist: "",
                album: "",
                duration: 0,
                position: 0,
                persistentID: "",
                favorited: false
            )
        }

        let fields = output.split(separator: "\u{1E}", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 8 else {
            throw MusicServiceError.scriptFailed("Apple Music 返回了无法识别的数据")
        }

        let duration = TimeInterval(fields[4]) ?? 0
        var position = TimeInterval(fields[5]) ?? 0
        if duration > 0 {
            position = min(max(0, position), duration)
        }

        return TrackSnapshot(
            state: PlaybackState(raw: fields[0]),
            name: fields[1].trimmingCharacters(in: .whitespacesAndNewlines),
            artist: fields[2].trimmingCharacters(in: .whitespacesAndNewlines),
            album: fields[3].trimmingCharacters(in: .whitespacesAndNewlines),
            duration: max(0, duration),
            position: position,
            persistentID: fields[6],
            favorited: fields[7].lowercased() == "true"
        )
    }

    // MARK: - Controls

    static func setPlayback(_ shouldPlay: Bool) async throws {
        let script = shouldPlay
            ? #"tell application "Music" to play"#
            : #"tell application "Music" to pause"#
        _ = try await runScript(script)
    }

    static func nextTrack() async throws {
        _ = try await runScript(#"tell application "Music" to next track"#)
    }

    static func previousTrack() async throws {
        _ = try await runScript(#"tell application "Music" to previous track"#)
    }

    static func seek(to position: TimeInterval) async throws {
        let seconds = max(0, position)
        let script = "tell application \"Music\" to set player position to \(String(format: "%.3f", seconds))"
        _ = try await runScript(script)
    }

    static func setFavorited(_ value: Bool) async throws {
        let script = #"""
        tell application "Music"
            set t to current track
            set favorited of t to \#(value ? "true" : "false")
            return favorited of t as text
        end tell
        """#
        _ = try await runScript(script)
    }

    // MARK: - Lyrics fallback

    static func embeddedLyrics() async -> String? {
        guard musicIsRunning else { return nil }
        let script = #"""
        tell application "Music"
            if player state is stopped then return ""
            return lyrics of current track
        end tell
        """#
        guard let output = try? await runScript(script) else { return nil }
        let text = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || text == "missing value" { return nil }
        return text
    }

    // MARK: - Artwork

    static func fetchArtwork(for cacheKey: String) async -> URL? {
        guard musicIsRunning else { return nil }

        let destination = artworkFileURL(for: cacheKey)
        let temporary = destination.appendingPathExtension("part")
        try? FileManager.default.removeItem(at: temporary)

        let key = appleScriptEscaped(cacheKey)
        let path = appleScriptEscaped(temporary.path)
        let script = #"""
        set outPath to "\#(path)"
        tell application "Music"
            set t to current track
            if (persistent ID of t as text) is not "\#(key)" then return "STALE"
            if (count of artworks of t) > 0 then
                set d to data of artwork 1 of t
                set f to open for access (POSIX file outPath) with write permission
                set eof f to 0
                write d to f
                close access f
                return "OK"
            else
                return "NOART"
            end if
        end tell
        """#

        guard let result = try? await runScript(script).trimmingCharacters(in: .whitespacesAndNewlines),
              result == "OK" else {
            try? FileManager.default.removeItem(at: temporary)
            return nil
        }

        guard let size = (try? temporary.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size > 0 else {
            try? FileManager.default.removeItem(at: temporary)
            return nil
        }

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporary, to: destination)
            return destination
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            return nil
        }
    }

    // MARK: - Helpers

    private static func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static let scriptQueue = DispatchQueue(
        label: "com.local.musicminiplayer.applescript",
        qos: .userInitiated
    )
    private static var scriptCache: [String: NSAppleScript] = [:]

    private static func runScript(_ source: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            scriptQueue.async {
                let script: NSAppleScript
                if let cached = scriptCache[source] {
                    script = cached
                } else if let compiled = NSAppleScript(source: source) {
                    script = compiled
                    if scriptCache.count > 48 { scriptCache.removeAll(keepingCapacity: true) }
                    scriptCache[source] = compiled
                } else {
                    continuation.resume(throwing: MusicServiceError.scriptFailed("AppleScript 编译失败"))
                    return
                }

                var errorInfo: NSDictionary?
                let result = script.executeAndReturnError(&errorInfo)
                if let errorInfo {
                    let message = (errorInfo[NSAppleScript.errorMessage] as? String)
                        ?? (errorInfo[NSAppleScript.errorBriefMessage] as? String)
                        ?? "AppleScript 执行失败"
                    continuation.resume(throwing: MusicServiceError.scriptFailed(message))
                    return
                }
                continuation.resume(returning: result.stringValue ?? "")
            }
        }
    }

}

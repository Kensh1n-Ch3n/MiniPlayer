import AppKit
import Foundation

/// Reads and controls NetEase Cloud Music through a small JXA bridge around
/// MediaRemote. Direct MediaRemote calls are restricted for bundled apps on
/// recent macOS versions, while the system scripting host is allowed to read
/// the local Now Playing item.
enum NetEasePlaybackService {
    static let bundleIdentifier = "com.netease.163music"

    private static let readScript = #"""
    ObjC.import("Foundation");
    $.NSBundle.bundleWithPath("/System/Library/PrivateFrameworks/MediaRemote.framework/").load;
    const Request = $.NSClassFromString("MRNowPlayingRequest");
    const path = Request.localNowPlayingPlayerPath;
    const client = path ? path.client : null;
    const item = Request.localNowPlayingItem;
    const metadata = item ? item.metadata : null;
    function value(key) {
      if (!metadata) return null;
      try { const result = metadata.valueForKey(key); return result ? ObjC.unwrap(result) : null; } catch (_) { return null; }
    }
    JSON.stringify({
      bundleId: client ? ObjC.unwrap(client.bundleIdentifier) : null,
      title: value("title"),
      artist: value("trackArtistName"),
      album: value("albumName"),
      duration: Number(value("duration")),
      elapsedTime: Number(value("elapsedTime")),
      elapsedTimeTimestamp: Number(value("elapsedTimeTimestamp")),
      playbackRate: Number(value("playbackRate"))
    });
    """#

    private static func commandScript(_ command: Int) -> String {
        #"""
        ObjC.import("Foundation");
        $.NSBundle.bundleWithPath("/System/Library/PrivateFrameworks/MediaRemote.framework/").load;
        const Request = $.NSClassFromString("MRNowPlayingRequest");
        const path = Request.localNowPlayingPlayerPath;
        const req = Request.alloc.initWithPlayerPath(path);
        req.sendCommandOptionsQueueCompletion(\#(command), $(), null, function() {});
        "ok";
        """#
    }

    private static var likedTrackKeys: Set<String> = []

    private struct Payload: Decodable {
        let bundleId: String?
        let title: String?
        let artist: String?
        let album: String?
        let duration: Double?
        let elapsedTime: Double?
        let elapsedTimeTimestamp: Double?
        let playbackRate: Double?
    }

    static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    static func snapshot() async -> TrackSnapshot? {
        guard isRunning,
              let output = await runJavaScript(readScript),
              let data = output.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.bundleId == bundleIdentifier,
              let title = payload.title,
              !title.isEmpty else {
            return nil
        }

        let duration = max(0, payload.duration ?? 0)
        var position = max(0, payload.elapsedTime ?? 0)
        let rate = payload.playbackRate ?? 0
        if rate > 0, let timestamp = payload.elapsedTimeTimestamp, timestamp > 0 {
            let unixTimestamp = timestamp + 978_307_200
            position += max(0, Date().timeIntervalSince1970 - unixTimestamp) * rate
        }
        if duration > 0 { position = min(position, duration) }

        let key = "netease|\(title)|\(payload.artist ?? "")|\(Int(duration.rounded()))"
        return TrackSnapshot(
            state: rate > 0 ? .playing : .paused,
            name: title,
            artist: payload.artist ?? "",
            album: payload.album ?? "",
            duration: duration,
            position: position,
            persistentID: key,
            favorited: likedTrackKeys.contains(key)
        )
    }

    static func setPlayback(_ shouldPlay: Bool) async {
        _ = await runJavaScript(commandScript(shouldPlay ? 0 : 1))
    }

    static func nextTrack() async {
        _ = await runJavaScript(commandScript(4))
    }

    static func previousTrack() async {
        _ = await runJavaScript(commandScript(5))
    }

    static func setLiked(_ liked: Bool, track: TrackSnapshot) async {
        if liked {
            likedTrackKeys.insert(track.cacheKey)
        } else {
            likedTrackKeys.remove(track.cacheKey)
        }
        // kMRLikeTrack. NetEase's Now Playing surface supports this command on
        // clients that publish the media command set.
        _ = await runJavaScript(commandScript(106))
    }

    static func artworkURL(for track: TrackSnapshot) async -> URL? {
        if let cached = MusicService.cachedArtworkURL(for: track.cacheKey) {
            return cached
        }

        let query = [track.name, track.artist].filter { !$0.isEmpty }.joined(separator: " ")
        guard let queryData = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://music.163.com/api/cloudsearch/pc?s=\(queryData)&type=1&limit=1") else {
            return nil
        }

        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")

        struct SearchResponse: Decodable {
            struct Result: Decodable { let songs: [Song]? }
            struct Song: Decodable { let al: Album? }
            struct Album: Decodable { let picUrl: String? }
            let result: Result?
        }

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let response = try? JSONDecoder().decode(SearchResponse.self, from: data),
              let picture = response.result?.songs?.first?.al?.picUrl,
              let pictureURL = URL(string: picture.replacingOccurrences(of: "http://", with: "https://")),
              let (imageData, _) = try? await URLSession.shared.data(from: pictureURL),
              !imageData.isEmpty else {
            return nil
        }

        let destination = MusicService.artworkFileURL(for: track.cacheKey)
        do {
            try imageData.write(to: destination, options: .atomic)
            return destination
        } catch {
            return nil
        }
    }

    private static func runJavaScript(_ source: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                    process.arguments = ["-l", "JavaScript", "-e", source]
                    let output = Pipe()
                    let error = Pipe()
                    process.standardOutput = output
                    process.standardError = error
                    try process.run()
                    let data = output.fileHandleForReading.readDataToEndOfFile()
                    _ = error.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    guard process.terminationStatus == 0 else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let text = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

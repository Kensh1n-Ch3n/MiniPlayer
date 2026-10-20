import AppKit
import Foundation

enum PlaybackSource: String, Sendable {
    case appleMusic
    case netEaseMusic

    var bundleIdentifier: String {
        switch self {
        case .appleMusic: return "com.apple.Music"
        case .netEaseMusic: return "com.netease.163music"
        }
    }

    var displayName: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .netEaseMusic: return "网易云音乐"
        }
    }
}

struct PlaybackResult {
    let snapshot: TrackSnapshot?
    let source: PlaybackSource
}

enum PlaybackService {
    static func fetch() async throws -> PlaybackResult {
        // Check Apple Music first when it is running. While it is playing it is
        // the active player, so we can skip the comparatively expensive NetEase
        // scripting bridge. NetEase is queried when Apple Music is paused,
        // stopped, or absent.
        if MusicService.musicIsRunning {
            let apple = try await MusicService.snapshot()
            if let apple, apple.state == .playing {
                return PlaybackResult(snapshot: apple, source: .appleMusic)
            }
            if let netEase = await NetEasePlaybackService.snapshot() {
                return PlaybackResult(snapshot: netEase, source: .netEaseMusic)
            }
            return PlaybackResult(snapshot: apple, source: .appleMusic)
        }

        if let netEase = await NetEasePlaybackService.snapshot() {
            return PlaybackResult(snapshot: netEase, source: .netEaseMusic)
        }

        return PlaybackResult(snapshot: nil, source: .appleMusic)
    }

    static func artworkURL(for track: TrackSnapshot, source: PlaybackSource) async -> URL? {
        switch source {
        case .appleMusic:
            if let url = await MusicService.fetchArtwork(for: track.cacheKey) {
                return url
            }
            // Some Apple Music tracks expose no artwork through AppleScript.
            // Reuse the online artwork search as a visual fallback.
            return await NetEasePlaybackService.artworkURL(for: track)
        case .netEaseMusic:
            return await NetEasePlaybackService.artworkURL(for: track)
        }
    }

    static func setPlayback(_ shouldPlay: Bool, source: PlaybackSource) async throws {
        switch source {
        case .appleMusic:
            try await MusicService.setPlayback(shouldPlay)
        case .netEaseMusic:
            await NetEasePlaybackService.setPlayback(shouldPlay)
        }
    }

    static func nextTrack(source: PlaybackSource) async throws {
        switch source {
        case .appleMusic:
            try await MusicService.nextTrack()
        case .netEaseMusic:
            await NetEasePlaybackService.nextTrack()
        }
    }

    static func previousTrack(source: PlaybackSource) async throws {
        switch source {
        case .appleMusic:
            try await MusicService.previousTrack()
        case .netEaseMusic:
            await NetEasePlaybackService.previousTrack()
        }
    }

    static func seek(to position: TimeInterval, source: PlaybackSource) async throws {
        switch source {
        case .appleMusic:
            try await MusicService.seek(to: position)
        case .netEaseMusic:
            break
        }
    }

    static func setFavorited(_ value: Bool, source: PlaybackSource, track: TrackSnapshot) async throws {
        switch source {
        case .appleMusic:
            try await MusicService.setFavorited(value)
        case .netEaseMusic:
            await NetEasePlaybackService.setLiked(value, track: track)
        }
    }
}

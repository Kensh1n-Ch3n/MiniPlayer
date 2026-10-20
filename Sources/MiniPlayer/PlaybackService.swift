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
        if let snapshot = await NetEasePlaybackService.snapshot() {
            return PlaybackResult(snapshot: snapshot, source: .netEaseMusic)
        }

        if MusicService.musicIsRunning {
            let snapshot = try await MusicService.snapshot()
            return PlaybackResult(snapshot: snapshot, source: .appleMusic)
        }

        return PlaybackResult(snapshot: nil, source: .appleMusic)
    }

    static func artworkURL(for track: TrackSnapshot, source: PlaybackSource) async -> URL? {
        switch source {
        case .appleMusic:
            return await MusicService.fetchArtwork(for: track.cacheKey)
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

    static func setFavorited(_ value: Bool, source: PlaybackSource) async throws {
        switch source {
        case .appleMusic:
            try await MusicService.setFavorited(value)
        case .netEaseMusic:
            break
        }
    }
}

import Foundation

enum PlaybackState: String, Sendable {
    case playing
    case paused
    case stopped

    init(raw: String) {
        switch raw.lowercased() {
        case "playing": self = .playing
        case "paused": self = .paused
        default: self = .stopped
        }
    }
}

struct TrackSnapshot: Equatable, Sendable {
    var state: PlaybackState
    var name: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var position: TimeInterval
    var persistentID: String
    var favorited: Bool

    var isEmpty: Bool {
        state == .stopped || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Stable identity for artwork / lyrics caches.
    var cacheKey: String {
        if !persistentID.isEmpty {
            return persistentID
        }
        return "\(artist)|\(name)|\(Int(duration.rounded()))"
    }

    var isPlaying: Bool { state == .playing }
}

struct LyricLine: Identifiable, Equatable, Codable, Sendable {
    var id: Int
    var time: TimeInterval
    var text: String
}

struct Lyrics: Equatable, Codable, Sendable {
    var lines: [LyricLine]
    var isSynced: Bool
    var isEstimated: Bool
    var source: String

    /// Last line whose timestamp is not later than `position`.
    func index(at position: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        if position < lines[0].time { return nil }

        var low = 0
        var high = lines.count - 1
        var answer = 0
        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= position {
                answer = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return answer
    }
}

import Foundation

/// Keeps the on-disk artwork and lyric caches bounded. The app only keeps the
/// current track's image and lyrics in memory, so this is purely disk hygiene.
enum CachePruner {
    private static let maxArtworkBytes: Int64 = 160 * 1024 * 1024
    private static let maxLyricsBytes: Int64 = 32 * 1024 * 1024
    private static let maxAge: TimeInterval = 30 * 24 * 60 * 60

    static func pruneInBackground() {
        Task.detached(priority: .utility) {
            prune(
                MusicService.artworkDirectory,
                maximumBytes: maxArtworkBytes,
                removingExtensions: ["img", "part"]
            )
            prune(
                MusicService.cacheRoot.appendingPathComponent("lyrics", isDirectory: true),
                maximumBytes: maxLyricsBytes,
                removingExtensions: ["json"]
            )
        }
    }

    private static func prune(
        _ directory: URL,
        maximumBytes: Int64,
        removingExtensions: Set<String>
    ) {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let now = Date()
        var files: [(url: URL, size: Int64, date: Date)] = []
        for url in urls {
            guard removingExtensions.contains(url.pathExtension),
                  let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true else {
                continue
            }
            let date = values.contentModificationDate ?? .distantPast
            let size = Int64(values.fileSize ?? 0)
            if now.timeIntervalSince(date) > maxAge {
                try? FileManager.default.removeItem(at: url)
                continue
            }
            files.append((url, size, date))
        }

        var total = files.reduce(Int64(0)) { $0 + $1.size }
        guard total > maximumBytes else { return }
        for file in files.sorted(by: { $0.date < $1.date }) {
            guard total > maximumBytes else { break }
            try? FileManager.default.removeItem(at: file.url)
            total -= file.size
        }
    }
}

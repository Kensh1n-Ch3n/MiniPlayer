import CryptoKit
import Foundation

enum LyricsService {
    private struct LRCLIBTrack: Decodable {
        let id: Int?
        let trackName: String
        let artistName: String
        let albumName: String?
        let duration: TimeInterval
        let instrumental: Bool?
        let plainLyrics: String?
        let syncedLyrics: String?
    }

    private struct CacheEntry: Codable {
        let savedAt: Date
        let lyrics: Lyrics
    }

    private static let cacheVersion = 6

    private static let cacheDirectory: URL = {
        let dir = MusicService.cacheRoot.appendingPathComponent("lyrics", isDirectory: true)
        let defaults = UserDefaults.standard
        if defaults.integer(forKey: "lyricsCacheVersion") < cacheVersion {
            try? FileManager.default.removeItem(at: dir)
            defaults.set(cacheVersion, forKey: "lyricsCacheVersion")
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let cacheLifetime: TimeInterval = 60 * 60 * 24 * 30

    // MARK: - Public entry point

    static func cachedLyrics(for track: TrackSnapshot) -> Lyrics? {
        let url = cacheFileURL(for: track)
        guard let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: data),
              Date().timeIntervalSince(entry.savedAt) < cacheLifetime else {
            return nil
        }
        return simplified(entry.lyrics)
    }

    static func fetch(for track: TrackSnapshot) async -> Lyrics? {
        if let cached = cachedLyrics(for: track) {
            return cached
        }

        // Apple Music's own cached TTML has Apple's line timings, so this is
        // the best source when it is available for the current track.
        if let apple = await waitForAppleMusicLyrics(for: track) {
            save(apple, for: track)
            return apple
        }

        let online = await fetchOnline(for: track)

        // Prefer real timed lyrics over a guessed timeline.
        if let online, !online.isEstimated {
            save(online, for: track)
            return online
        }

        // LRCLIB often has only plain text for Chinese songs. NetEase provides
        // real LRC timestamps and is therefore a better source for offset 0.
        if let netease = await NetEaseLyricsService.fetch(for: track) {
            save(netease, for: track)
            return netease
        }

        if let online {
            save(online, for: track)
            return online
        }

        if let embedded = await MusicService.embeddedLyrics() {
            if let synced = parseLRC(embedded), synced.lines.count > 1 {
                var result = synced
                result.source = "Apple Music 内嵌歌词"
                save(result, for: track)
                return result
            }
            if let estimated = estimatedLyrics(
                from: embedded,
                duration: track.duration,
                source: "Apple Music 内嵌歌词 · 时间为估算"
            ) {
                save(estimated, for: track)
                return estimated
            }
        }

        return nil
    }

    /// Music often writes the lyrics response just after the track changes.
    /// Give it a moment before falling back to a third-party lyric source.
    private static func waitForAppleMusicLyrics(for track: TrackSnapshot) async -> Lyrics? {
        if let immediate = await AppleMusicLyricsCache.fetch(for: track) {
            return immediate
        }
        for _ in 0..<2 {
            try? await Task.sleep(nanoseconds: 600_000_000)
            if let lyrics = await AppleMusicLyricsCache.fetch(for: track) {
                return lyrics
            }
        }
        return nil
    }

    // MARK: - LRCLIB

    private static func fetchOnline(for track: TrackSnapshot) async -> Lyrics? {
        let title = cleanedTitle(track.name)
        guard !title.isEmpty else { return nil }

        if let exactURL = exactURL(title: title, artist: track.artist),
           let exact: LRCLIBTrack = await fetchJSON(exactURL),
           score(exact, for: track) < 36,
           let lyrics = lyrics(from: exact, track: track) {
            return lyrics
        }

        let query = [title, track.artist].filter { !$0.isEmpty }.joined(separator: " ")
        guard var components = URLComponents(string: "https://lrclib.net/api/search") else { return nil }
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components.url,
              let results: [LRCLIBTrack] = await fetchJSON(url),
              !results.isEmpty else {
            return nil
        }

        let withSynced = results.filter { !($0.syncedLyrics ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let pool = withSynced.isEmpty ? results : withSynced
        let best = pool.min { score($0, for: track) < score($1, for: track) }
        guard let best, score(best, for: track) < 36 else { return nil }
        return lyrics(from: best, track: track)
    }

    private static func exactURL(title: String, artist: String) -> URL? {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        var items = [URLQueryItem(name: "track_name", value: title)]
        if !artist.isEmpty {
            items.append(URLQueryItem(name: "artist_name", value: artist))
        }
        components?.queryItems = items
        return components?.url
    }

    private static func fetchJSON<T: Decodable>(_ url: URL) async -> T? {
        var request = URLRequest(url: url, timeoutInterval: 13)
        request.httpMethod = "GET"
        request.setValue("MiniPlayer/1.0.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return nil
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    private static func lyrics(from item: LRCLIBTrack, track: TrackSnapshot) -> Lyrics? {
        if let syncedText = item.syncedLyrics,
           let parsed = parseLRC(syncedText),
           !parsed.lines.isEmpty {
            return parsed
        }

        if let plain = item.plainLyrics,
           let estimated = estimatedLyrics(from: plain, duration: track.duration, source: "LRCLIB · 非同步歌词") {
            return estimated
        }

        return nil
    }

    private static func score(_ candidate: LRCLIBTrack, for track: TrackSnapshot) -> Double {
        let candidateTitle = normalized(candidate.trackName)
        let targetTitle = normalized(track.name)
        guard candidateTitle == targetTitle
            || candidateTitle.contains(targetTitle)
            || targetTitle.contains(candidateTitle) else {
            return 1000
        }

        let candidateArtist = normalized(candidate.artistName)
        let targetArtist = normalized(track.artist)
        guard candidateArtist == targetArtist
            || candidateArtist.contains(targetArtist)
            || targetArtist.contains(candidateArtist) else {
            return 1000
        }

        if abs(candidate.duration - track.duration) > 30 {
            return 1000
        }

        let titleDistance = candidateTitle == targetTitle ? 0.0 : 2.0
        let artistDistance = candidateArtist == targetArtist ? 0.0 : 2.0
        return titleDistance + artistDistance + min(abs(candidate.duration - track.duration), 30) / 6
    }

    // MARK: - LRC parsing

    static func parseLRC(_ raw: String) -> Lyrics? {
        let timestampPattern = #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#
        let offsetPattern = #"\[offset:\s*([+-]?\d+)\s*\]"#
        guard let timestampRegex = try? NSRegularExpression(pattern: timestampPattern),
              let offsetRegex = try? NSRegularExpression(pattern: offsetPattern, options: [.caseInsensitive]) else {
            return nil
        }

        var offsetMilliseconds = 0.0
        var entries: [(time: TimeInterval, text: String)] = []

        for rawLine in raw.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let nsLine = line as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)

            if let offsetMatch = offsetRegex.firstMatch(in: line, range: fullRange),
               offsetMatch.numberOfRanges > 1 {
                let value = nsLine.substring(with: offsetMatch.range(at: 1))
                offsetMilliseconds = Double(value) ?? 0
                continue
            }

            let matches = timestampRegex.matches(in: line, range: fullRange)
            guard !matches.isEmpty else { continue }

            var text = timestampRegex.stringByReplacingMatches(
                in: line,
                range: fullRange,
                withTemplate: ""
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { text = "♪" }
            text = simplifiedChinese(text)

            for match in matches {
                guard match.numberOfRanges >= 3,
                      let minutes = Double(nsLine.substring(with: match.range(at: 1))),
                      let seconds = Double(nsLine.substring(with: match.range(at: 2))) else {
                    continue
                }

                var fraction = 0.0
                if match.range(at: 3).location != NSNotFound {
                    let rawFraction = nsLine.substring(with: match.range(at: 3))
                    if let value = Double(rawFraction) {
                        fraction = value / pow(10, Double(rawFraction.count))
                    }
                }

                var time = minutes * 60 + seconds + fraction + offsetMilliseconds / 1000
                if time < 0 { time = 0 }
                entries.append((time, text))
            }
        }

        guard !entries.isEmpty else { return nil }

        entries.sort { lhs, rhs in
            if abs(lhs.time - rhs.time) < 0.001 {
                return lhs.text < rhs.text
            }
            return lhs.time < rhs.time
        }

        // Some LRC files place a translation on a second line with the same timestamp.
        // Merge those into one lyric line so they can be displayed together.
        var merged: [(time: TimeInterval, text: String)] = []
        for entry in entries {
            if let last = merged.last, abs(last.time - entry.time) < 0.02 {
                let lastText = last.text
                if entry.text != "♪" && !lastText.contains(entry.text) {
                    merged[merged.count - 1].text = lastText + "\n" + entry.text
                }
            } else {
                merged.append(entry)
            }
        }

        if let first = merged.first, first.time > 1.0 {
            merged.insert((0, "♪"), at: 0)
        }

        let lines = merged.enumerated().map { index, entry in
            LyricLine(id: index, time: entry.time, text: entry.text)
        }
        guard !lines.isEmpty else { return nil }

        return Lyrics(lines: lines, isSynced: true, isEstimated: false, source: "LRCLIB")
    }

    // MARK: - Fallback

    private static func estimatedLyrics(from plain: String, duration: TimeInterval, source: String) -> Lyrics? {
        let rawLines = plain.components(separatedBy: .newlines)
            .map { simplifiedChinese($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.isEmpty }
        guard !rawLines.isEmpty else { return nil }

        let totalDuration = duration > 20 ? duration : 210
        let start = min(2.0, totalDuration * 0.02)
        let end = max(start + 1, totalDuration - 2)
        let step = (end - start) / Double(rawLines.count)

        let lines = rawLines.enumerated().map { index, text in
            LyricLine(id: index, time: start + Double(index) * step, text: text)
        }
        return Lyrics(lines: lines, isSynced: true, isEstimated: true, source: source)
    }

    // MARK: - Caching

    private static func cacheFileURL(for track: TrackSnapshot) -> URL {
        let key = "\(track.cacheKey)|\(track.name)|\(track.artist)|\(Int(track.duration.rounded()))"
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent("\(name).json")
    }

    private static func simplified(_ lyrics: Lyrics) -> Lyrics {
        var copy = lyrics
        copy.lines = lyrics.lines.map { line in
            var converted = line
            converted.text = simplifiedChinese(line.text)
            return converted
        }
        return copy
    }

    /// Use Apple/NetEase translations only for non-Latin originals.
    /// English songs should keep their English lyrics.
    static func shouldUseTranslation(original: String, translation: String) -> Bool {
        guard !translation.isEmpty else { return false }
        guard !containsLatinLetters(original) else { return false }
        return containsCJK(translation)
    }

    static func containsLatinLetters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x41...0x5A).contains(scalar.value) || (0x61...0x7A).contains(scalar.value)
        }
    }

    static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3400...0x4DBF).contains(scalar.value)
                || (0x4E00...0x9FFF).contains(scalar.value)
                || (0x3040...0x30FF).contains(scalar.value)
                || (0xAC00...0xD7AF).contains(scalar.value)
        }
    }

    static func simplifiedChinese(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        let mutable = NSMutableString(string: text)
        CFStringTransform(mutable, nil, "Traditional-Simplified" as CFString, false)
        return mutable as String
    }

    private static func save(_ lyrics: Lyrics, for track: TrackSnapshot) {
        let entry = CacheEntry(savedAt: Date(), lyrics: lyrics)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: cacheFileURL(for: track), options: .atomic)
    }

    // MARK: - Text helpers

    private static func cleanedTitle(_ raw: String) -> String {
        var value = raw
        value = value.replacingOccurrences(
            of: #"[\(（\[【《][^\)）\]】》]*[\)）\]】》]"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\s+[-–—]\s+.*$"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"[-–—]\s*$"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\s+-\s+.*$"#,
            with: "",
            options: .regularExpression
        )
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalized(_ raw: String) -> String {
        var value = raw.lowercased()
        value = value.replacingOccurrences(
            of: #"[\(（\[【《][^\)）\]】》]*[\)）\]】》]"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\b(feat|ft)\.?\s+.*$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        let allowed = CharacterSet.alphanumerics
        let scalars = value.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(scalars))
    }
}

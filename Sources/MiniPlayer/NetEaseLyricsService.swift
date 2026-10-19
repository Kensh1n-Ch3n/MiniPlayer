import Foundation

/// Fallback synced-lyrics source for tracks that LRCLIB only has as plain text.
/// NetEase's public lyric endpoint returns real LRC timestamps, which is what
/// makes offset 0 line up with the music.
enum NetEaseLyricsService {
    private struct SearchResponse: Decodable {
        let result: SearchResult?
    }

    private struct SearchResult: Decodable {
        let songs: [Song]?
    }

    private struct Song: Decodable {
        let id: Int
        let name: String
        let artists: [Artist]?
        let album: Album?
        let duration: Double?
    }

    private struct Artist: Decodable {
        let name: String?
    }

    private struct Album: Decodable {
        let name: String?
    }

    private struct LyricResponse: Decodable {
        let lrc: Lyric?
        let tlyric: Lyric?
    }

    private struct Lyric: Decodable {
        let lyric: String?
    }

    static func fetch(for track: TrackSnapshot) async -> Lyrics? {
        let title = cleanedTitle(track.name)
        guard !title.isEmpty else { return nil }

        let query = [title, track.artist].filter { !$0.isEmpty }.joined(separator: " ")
        guard let song = await search(query: query, for: track) else { return nil }
        guard let lyricText = await fetchLyricText(songID: song.id),
              let parsed = LyricsService.parseLRC(lyricText) else {
            return nil
        }

        var lines = parsed.lines.filter { !isCredit($0.text) }
        guard !lines.isEmpty else { return nil }

        if let translationText = await fetchTranslationText(songID: song.id),
           let translation = LyricsService.parseLRC(translationText) {
            merge(translation: translation, into: &lines)
        }

        lines = lines.enumerated().map { index, line in
            LyricLine(id: index, time: line.time, text: line.text)
        }

        return Lyrics(
            lines: lines,
            isSynced: true,
            isEstimated: false,
            source: "网易云音乐"
        )
    }

    // MARK: - API

    private static func search(query: String, for track: TrackSnapshot) async -> Song? {
        guard var components = URLComponents(string: "https://music.163.com/api/search/get/web") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "s", value: query),
            URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "offset", value: "0")
        ]
        guard let url = components.url,
              let response: SearchResponse = await fetchJSON(url),
              let songs = response.result?.songs,
              !songs.isEmpty else {
            return nil
        }

        let best = songs.min { score($0, for: track) < score($1, for: track) }
        guard let best, score(best, for: track) < 36 else { return nil }
        return best
    }

    private static func fetchLyricText(songID: Int) async -> String? {
        guard let text = await fetchLyricPayload(songID: songID)?.lrc?.lyric,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }

    private static func fetchTranslationText(songID: Int) async -> String? {
        guard let text = await fetchLyricPayload(songID: songID)?.tlyric?.lyric,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }

    private static func fetchLyricPayload(songID: Int) async -> LyricResponse? {
        guard let url = URL(string: "https://music.163.com/api/song/lyric?id=\(songID)&lv=1&kv=1&tv=-1") else {
            return nil
        }
        return await fetchJSON(url)
    }

    private static func fetchJSON<T: Decodable>(_ url: URL) async -> T? {
        var request = URLRequest(url: url, timeoutInterval: 13)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Origin")
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

    // MARK: - Matching

    private static func score(_ candidate: Song, for track: TrackSnapshot) -> Double {
        let candidateTitle = normalized(candidate.name)
        let targetTitle = normalized(track.name)
        guard candidateTitle == targetTitle
            || candidateTitle.contains(targetTitle)
            || targetTitle.contains(candidateTitle) else {
            return 1000
        }

        let candidateArtist = normalized(candidate.artists?.compactMap(\.name).joined(separator: " ") ?? "")
        let targetArtist = normalized(track.artist)
        guard candidateArtist == targetArtist
            || candidateArtist.contains(targetArtist)
            || targetArtist.contains(candidateArtist) else {
            return 1000
        }

        if let duration = candidate.duration,
           abs(duration / 1000 - track.duration) > 30 {
            return 1000
        }

        let titleDistance = candidateTitle == targetTitle ? 0.0 : 2.0
        let artistDistance = candidateArtist == targetArtist ? 0.0 : 2.0
        let durationDistance = candidate.duration.map { min(abs($0 / 1000 - track.duration), 30) / 6 } ?? 0
        return titleDistance + artistDistance + durationDistance
    }

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
        return value.unicodeScalars
            .filter { allowed.contains($0) }
            .map(String.init)
            .joined()
    }

    // MARK: - Cleanup

    private static let creditRegex = try! NSRegularExpression(
        pattern: #"^\s*(作词|作曲|编曲|制作人|制作|监制|录音|混音|母带|吉他|贝斯|鼓|键盘|和声|弦乐|出品|发行|OP|SP|词|曲)\s*[:：]"#,
        options: [.caseInsensitive]
    )

    private static func isCredit(_ text: String) -> Bool {
        let nsText = text as NSString
        return creditRegex.firstMatch(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ) != nil
    }

    private static func merge(translation: Lyrics, into lines: inout [LyricLine]) {
        var byTime: [Int: String] = [:]
        for line in translation.lines {
            byTime[Int((line.time * 10).rounded())] = line.text
        }

        for index in lines.indices {
            let key = Int((lines[index].time * 10).rounded())
            guard let translated = byTime[key],
                  !translated.isEmpty,
                  translated != lines[index].text,
                  LyricsService.shouldUseTranslation(
                      original: lines[index].text,
                      translation: translated
                  ) else {
                continue
            }
            lines[index].text += "\n" + translated
        }
    }
}

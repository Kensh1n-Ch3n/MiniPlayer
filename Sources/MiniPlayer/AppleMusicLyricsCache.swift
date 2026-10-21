import Foundation

/// Reads Apple Music's own line-synced lyrics out of its local HTTP cache.
///
/// When Music loads a track's lyrics it stores the catalog response (including
/// the official TTML timing data) under `~/Library/Caches/com.apple.Music`.
/// Using those timings gives us Apple's own line boundaries, so offset 0 lines
/// up with the audio without depending on NetEase.
enum AppleMusicLyricsCache {
    private struct Candidate {
        let title: String
        let artist: String
        let duration: TimeInterval
        let ttml: String
    }

    static func fetch(for track: TrackSnapshot) async -> Lyrics? {
        await Task.detached(priority: .utility) {
            let candidates = loadCandidates()
            guard !candidates.isEmpty else { return nil }

            let best = candidates.min { score($0, for: track) < score($1, for: track) }
            guard let best, score(best, for: track) < 36 else { return nil }
            return parseTTML(best.ttml)
        }.value
    }

    // MARK: - Cache scan

    private static func cacheDirectories() -> [URL] {
        var dirs: [URL] = []
        if let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            dirs.append(cacheRoot.appendingPathComponent("com.apple.Music/fsCachedData", isDirectory: true))
        }
        let container = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.apple.Music/Data/Library/Caches/com.apple.Music/fsCachedData", isDirectory: true)
        dirs.append(container)
        return dirs
    }

    private static func loadCandidates() -> [Candidate] {
        let fm = FileManager.default
        var files: [URL] = []

        for dir in cacheDirectories() {
            let urls = (try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            files.append(contentsOf: urls)
        }

        files.sort { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }

        let marker = Data("ttmlLocalizations".utf8)
        var candidates: [Candidate] = []

        for file in files.prefix(400) {
            guard let values = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize,
                  size > 300,
                  size < 8_000_000,
                  let data = try? Data(contentsOf: file),
                  data.range(of: marker) != nil,
                  let object = try? JSONSerialization.jsonObject(with: data) else {
                continue
            }
            collectCandidates(from: object, into: &candidates)
        }

        return candidates
    }

    private static func collectCandidates(from object: Any, into candidates: inout [Candidate]) {
        if let dictionary = object as? [String: Any] {
            if let attributes = dictionary["attributes"] as? [String: Any],
               let name = attributes["name"] as? String,
               let artist = attributes["artistName"] as? String,
               let ttml = extractTTML(from: dictionary),
               !ttml.isEmpty {
                let duration = (attributes["durationInMillis"] as? NSNumber)?.doubleValue ?? 0
                candidates.append(Candidate(
                    title: name,
                    artist: artist,
                    duration: duration / 1000,
                    ttml: ttml
                ))
            }

            for value in dictionary.values {
                collectCandidates(from: value, into: &candidates)
            }
        } else if let array = object as? [Any] {
            for value in array {
                collectCandidates(from: value, into: &candidates)
            }
        }
    }

    private static func extractTTML(from object: [String: Any]) -> String? {
        guard let relationships = object["relationships"] as? [String: Any],
              let syllable = relationships["syllable-lyrics"] as? [String: Any],
              let data = syllable["data"] as? [Any] else {
            return nil
        }

        for item in data {
            guard let item = item as? [String: Any],
                  let attributes = item["attributes"] as? [String: Any],
                  let ttml = attributes["ttmlLocalizations"] as? String else {
                continue
            }
            return ttml
        }
        return nil
    }

    // MARK: - Matching

    private static func score(_ candidate: Candidate, for track: TrackSnapshot) -> Double {
        let candidateTitle = normalized(candidate.title)
        let targetTitle = normalized(track.name)
        guard candidateTitle == targetTitle
            || candidateTitle.contains(targetTitle)
            || targetTitle.contains(candidateTitle) else {
            return 1000
        }

        let candidateArtist = normalized(candidate.artist)
        let targetArtist = normalized(track.artist)
        guard candidateArtist == targetArtist
            || candidateArtist.contains(targetArtist)
            || targetArtist.contains(candidateArtist) else {
            return 1000
        }

        if candidate.duration > 0,
           abs(candidate.duration - track.duration) > 30 {
            return 1000
        }

        let titleDistance = candidateTitle == targetTitle ? 0.0 : 2.0
        let artistDistance = candidateArtist == targetArtist ? 0.0 : 2.0
        let durationDistance = candidate.duration > 0
            ? min(abs(candidate.duration - track.duration), 30) / 6
            : 0
        return titleDistance + artistDistance + durationDistance
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

    // MARK: - TTML

    private static func parseTTML(_ text: String) -> Lyrics? {
        guard let data = text.data(using: .utf8) else { return nil }
        let parser = XMLParser(data: data)
        let delegate = TTMLDelegate()
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true
        guard parser.parse() else { return nil }
        guard !delegate.lines.isEmpty else { return nil }

        let mapped: [LyricLine] = delegate.lines
            .sorted { $0.time < $1.time }
            .compactMap { line in
            let translated = line.key.flatMap { delegate.translations[$0] }
            let raw: String
            if let translated,
               LyricsService.shouldUseTranslation(original: line.text, translation: translated) {
                raw = translated
            } else {
                raw = line.text
            }
            let value = LyricsService.simplifiedChinese(raw)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            return LyricLine(id: 0, time: max(0, line.time), text: value)
        }
        guard mapped.count > 1 else { return nil }

        let lines = mapped.enumerated().map { index, line in
            LyricLine(id: index, time: line.time, text: line.text)
        }
        return Lyrics(lines: lines, isSynced: true, isEstimated: false, source: "Apple Music 官方歌词")
    }

    private struct ParsedLine {
        let time: TimeInterval
        let key: String?
        let text: String
    }

    private final class TTMLDelegate: NSObject, XMLParserDelegate {
        var lines: [ParsedLine] = []
        var translations: [String: String] = [:]

        private var currentLineBeginning: TimeInterval?
        private var currentLineKey: String?
        private var currentLineText = ""
        private var inLine = false

        private var inTranslationContainer = false
        private var inTranslationText = false
        private var translationKey: String?
        private var translationText = ""

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            switch elementName {
            case "p":
                inLine = true
                currentLineBeginning = Self.parseTime(attributeDict["begin"])
                currentLineKey = attributeDict["itunes:key"] ?? attributeDict["key"]
                currentLineText = ""
            case "translation":
                inTranslationContainer = true
            case "text":
                if inTranslationContainer, let key = attributeDict["for"] {
                    inTranslationText = true
                    translationKey = key
                    translationText = ""
                }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if inTranslationText {
                translationText += string
            } else if inLine {
                currentLineText += string
            }
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            switch elementName {
            case "p":
                if let beginning = currentLineBeginning {
                    let text = currentLineText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty || currentLineKey != nil {
                        lines.append(ParsedLine(
                            time: beginning,
                            key: currentLineKey,
                            text: text
                        ))
                    }
                }
                inLine = false
                currentLineBeginning = nil
                currentLineKey = nil
                currentLineText = ""
            case "translation":
                inTranslationContainer = false
            case "text":
                if inTranslationText, let key = translationKey {
                    translations[key] = translationText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                inTranslationText = false
                translationKey = nil
                translationText = ""
            default:
                break
            }
        }

        private static func parseTime(_ raw: String?) -> TimeInterval? {
            guard let raw, !raw.isEmpty else { return nil }
            if raw.contains(":") {
                let parts = raw.split(separator: ":").map(String.init)
                if parts.count == 3,
                   let hours = Double(parts[0]),
                   let minutes = Double(parts[1]),
                   let seconds = Double(parts[2]) {
                    return hours * 3600 + minutes * 60 + seconds
                }
                if parts.count == 2,
                   let minutes = Double(parts[0]),
                   let seconds = Double(parts[1]) {
                    return minutes * 60 + seconds
                }
            }
            return Double(raw)
        }
    }
}

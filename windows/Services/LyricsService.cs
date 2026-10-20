using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace MiniPlayerWin.Services;

public sealed class LyricsService
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(12) };
    private readonly Dictionary<string, LyricsDocument?> _cache = new();

    private static readonly Regex TimeTag = new(
        @"\[(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?\]",
        RegexOptions.Compiled);

    public async Task<LyricsDocument?> FetchAsync(TrackInfo track)
    {
        if (!track.HasTrack) return null;
        var key = $"{track.Title}|{track.Artist}|{track.SourceAppId}";
        if (_cache.TryGetValue(key, out var cached)) return cached;

        LyricsDocument? lyrics = null;
        try
        {
            lyrics = await FetchNetEaseAsync(track);
        }
        catch
        {
            lyrics = null;
        }

        _cache[key] = lyrics;
        return lyrics;
    }

    private static async Task<LyricsDocument?> FetchLrclibAsync(TrackInfo track)
    {
        var query = Uri.EscapeDataString($"{track.Title} {track.Artist}");
        using var response = await Http.GetAsync($"https://lrclib.net/api/search?q={query}");
        if (!response.IsSuccessStatusCode) return null;
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        if (json.RootElement.ValueKind != JsonValueKind.Array) return null;

        foreach (var item in json.RootElement.EnumerateArray())
        {
            if (!item.TryGetProperty("syncedLyrics", out var synced)) continue;
            var text = synced.GetString();
            if (string.IsNullOrWhiteSpace(text)) continue;
            var lines = ParseLrc(text);
            if (lines.Count > 0) return new LyricsDocument { Lines = lines, Source = "LRCLIB" };
        }
        return null;
    }

    private static async Task<LyricsDocument?> FetchNetEaseAsync(TrackInfo track)
    {
        var query = Uri.EscapeDataString($"{track.Title} {track.Artist}");
        using var searchResponse = await Http.GetAsync(
            $"https://music.163.com/api/cloudsearch/pc?s={query}&type=1&limit=5");
        if (!searchResponse.IsSuccessStatusCode) return null;
        using var search = JsonDocument.Parse(await searchResponse.Content.ReadAsStringAsync());
        if (!search.RootElement.TryGetProperty("result", out var result)
            || !result.TryGetProperty("songs", out var songs)
            || songs.GetArrayLength() == 0)
        {
            return null;
        }

        var song = songs[0];
        if (!song.TryGetProperty("id", out var idValue)) return null;
        var id = idValue.GetInt64();
        using var lyricResponse = await Http.GetAsync(
            $"https://music.163.com/api/song/lyric?id={id}&lv=1&kv=1&tv=-1");
        if (!lyricResponse.IsSuccessStatusCode) return null;
        using var lyricJson = JsonDocument.Parse(await lyricResponse.Content.ReadAsStringAsync());
        if (!lyricJson.RootElement.TryGetProperty("lrc", out var lrc)
            || !lrc.TryGetProperty("lyric", out var lyricText)) return null;
        var text = lyricText.GetString();
        if (string.IsNullOrWhiteSpace(text)) return null;
        var lines = ParseLrc(text);
        return lines.Count > 0 ? new LyricsDocument { Lines = lines, Source = "网易云音乐" } : null;
    }

    public static List<LyricLine> ParseLrc(string text)
    {
        var result = new List<LyricLine>();
        foreach (var rawLine in text.Replace("\r", "").Split('\n'))
        {
            var tags = TimeTag.Matches(rawLine);
            if (tags.Count == 0) continue;
            var content = TimeTag.Replace(rawLine, "").Trim();
            if (string.IsNullOrWhiteSpace(content)) continue;
            foreach (Match tag in tags)
            {
                var minutes = int.Parse(tag.Groups[1].Value);
                var seconds = int.Parse(tag.Groups[2].Value);
                var fractionText = tag.Groups[3].Success ? tag.Groups[3].Value : "0";
                var fraction = int.Parse(fractionText.PadRight(3, '0')[..3]);
                var time = TimeSpan.FromMinutes(minutes)
                    + TimeSpan.FromSeconds(seconds)
                    + TimeSpan.FromMilliseconds(fraction);
                result.Add(new LyricLine(time, content));
            }
        }
        return result.OrderBy(l => l.Time).ToList();
    }
}

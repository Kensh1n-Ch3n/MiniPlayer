using Avalonia.Media.Imaging;

namespace MiniPlayerWin;

public sealed record TrackInfo(
    string Title,
    string Artist,
    string Album,
    string SourceAppId,
    TimeSpan Position,
    TimeSpan Duration,
    bool IsPlaying,
    Bitmap? Artwork)
{
    public bool HasTrack => !string.IsNullOrWhiteSpace(Title);
    public string SourceName => SourceAppId.Contains("cloudmusic", StringComparison.OrdinalIgnoreCase)
        || SourceAppId.Contains("netease", StringComparison.OrdinalIgnoreCase)
        ? "网易云音乐"
        : SourceAppId.Contains("Apple", StringComparison.OrdinalIgnoreCase)
            ? "Apple Music"
            : "音乐";
}

public sealed record LyricLine(TimeSpan Time, string Text);

public sealed class LyricsDocument
{
    public required IReadOnlyList<LyricLine> Lines { get; init; }
    public required string Source { get; init; }

    public int IndexAt(TimeSpan position)
    {
        if (Lines.Count == 0) return -1;
        var low = 0;
        var high = Lines.Count - 1;
        var answer = 0;
        while (low <= high)
        {
            var mid = (low + high) / 2;
            if (Lines[mid].Time <= position)
            {
                answer = mid;
                low = mid + 1;
            }
            else
            {
                high = mid - 1;
            }
        }
        return answer;
    }
}

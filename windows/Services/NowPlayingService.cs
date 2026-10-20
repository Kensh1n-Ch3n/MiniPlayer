using System;
using System.IO;
using System.Threading.Tasks;
using Avalonia.Media.Imaging;
using Avalonia.Threading;
using Windows.Media.Control;

namespace MiniPlayerWin.Services;

public sealed class NowPlayingService : IDisposable
{
    private readonly DispatcherTimer _timer;
    private GlobalSystemMediaTransportControlsSessionManager? _manager;
    private TrackInfo _current = Empty;
    private string _artKey = "";
    private bool _started;

    public static TrackInfo Empty { get; } = new("", "", "", "", TimeSpan.Zero, TimeSpan.Zero, false, null);

    public TrackInfo Current => _current;
    public event Action<TrackInfo>? Updated;

    public NowPlayingService()
    {
        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        _timer.Tick += async (_, _) => await RefreshAsync();
    }

    public async Task StartAsync()
    {
        if (_started) return;
        _started = true;
        try
        {
            _manager = await GlobalSystemMediaTransportControlsSessionManager.RequestAsync();
        }
        catch
        {
            _manager = null;
        }
        _timer.Start();
        await RefreshAsync();
    }

    public async Task RefreshAsync()
    {
        try
        {
            var session = _manager?.GetCurrentSession();
            if (session is null || !IsNetEaseSession(session))
            {
                Publish(Empty);
                return;
            }

            var props = await session.TryGetMediaPropertiesAsync();
            var playback = session.GetPlaybackInfo();
            var timeline = session.GetTimelineProperties();
            var isPlaying = playback.PlaybackStatus
                == GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing;

            var artwork = await LoadArtworkAsync(props, $"{props.Title}|{props.Artist}");
            _current = new TrackInfo(
                props.Title ?? "",
                props.Artist ?? "",
                props.AlbumTitle ?? "",
                session.SourceAppUserModelId ?? "",
                timeline.Position,
                timeline.EndTime - timeline.StartTime,
                isPlaying,
                artwork);
            Publish(_current);
        }
        catch
        {
            Publish(Empty);
        }
    }

    private static bool IsNetEaseSession(GlobalSystemMediaTransportControlsSession session)
    {
        var id = (session.SourceAppUserModelId ?? "").ToLowerInvariant();
        return id.Contains("cloudmusic")
            || id.Contains("netease")
            || id.Contains("163music");
    }

    private async Task<Bitmap?> LoadArtworkAsync(
        GlobalSystemMediaTransportControlsSessionMediaProperties props,
        string key)
    {
        if (props.Thumbnail is null) return null;
        if (key == _artKey) return _current.Artwork;

        try
        {
            using var stream = await props.Thumbnail.OpenReadAsync();
            var bytes = new byte[stream.Size];
            using var reader = new Windows.Storage.Streams.DataReader(stream);
            await reader.LoadAsync((uint)bytes.Length);
            reader.ReadBytes(bytes);
            using var memory = new MemoryStream(bytes);
            var bitmap = new Bitmap(memory);
            _artKey = key;
            return bitmap;
        }
        catch
        {
            return null;
        }
    }

    private void Publish(TrackInfo info)
    {
        if (info == _current && info.Title == _current.Title) return;
        _current = info;
        Updated?.Invoke(info);
    }

    public async Task TogglePlayPauseAsync()
    {
        var session = _manager?.GetCurrentSession();
        if (session is not null) await session.TryTogglePlayPauseAsync();
        await RefreshAsync();
    }

    public async Task NextAsync()
    {
        var session = _manager?.GetCurrentSession();
        if (session is not null) await session.TrySkipNextAsync();
        await RefreshAsync();
    }

    public async Task PreviousAsync()
    {
        var session = _manager?.GetCurrentSession();
        if (session is not null) await session.TrySkipPreviousAsync();
        await RefreshAsync();
    }

    public async Task SeekAsync(TimeSpan position)
    {
        var session = _manager?.GetCurrentSession();
        if (session is not null)
        {
            await session.TryChangePlaybackPositionAsync(position.Ticks);
        }
        await RefreshAsync();
    }

    public void Dispose()
    {
        _timer.Stop();
    }
}

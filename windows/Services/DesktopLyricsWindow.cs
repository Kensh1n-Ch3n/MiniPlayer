using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Threading;

namespace MiniPlayerWin.Services;

public sealed class DesktopLyricsWindow : Window
{
    private readonly TextBlock _text;
    private readonly NowPlayingService _player;
    private LyricsDocument? _lyrics;
    private DispatcherTimer? _timer;

    public DesktopLyricsWindow(NowPlayingService player)
    {
        _player = player;
        SystemDecorations = SystemDecorations.None;
        CanResize = false;
        ShowInTaskbar = false;
        Topmost = true;
        Background = Brushes.Transparent;
        Width = 1000;
        Height = 120;
        WindowStartupLocation = WindowStartupLocation.Manual;
        TransparencyLevelHint = new[] { WindowTransparencyLevel.Transparent };

        _text = new TextBlock
        {
            Text = "",
            FontSize = 30,
            FontWeight = FontWeight.Bold,
            Foreground = Brushes.White,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            TextAlignment = TextAlignment.Center,
            Effect = new DropShadowEffect
            {
                BlurRadius = 7,
                Color = Colors.Black,
                OffsetX = 0,
                OffsetY = 2,
                Opacity = 0.85
            }
        };
        Content = new Grid
        {
            Background = Brushes.Transparent,
            Children = { _text }
        };
        Opened += (_, _) => Reposition();
    }

    public void SetLyrics(LyricsDocument? lyrics)
    {
        _lyrics = lyrics;
        UpdateLine();
    }

    public void Start()
    {
        _timer ??= new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(250) };
        _timer.Tick += (_, _) => UpdateLine();
        _timer.Start();
        Show();
        Reposition();
    }

    public void Stop()
    {
        _timer?.Stop();
        Hide();
    }

    private void UpdateLine()
    {
        if (_lyrics is null || _lyrics.Lines.Count == 0)
        {
            _text.Text = "";
            return;
        }
        var index = _lyrics.IndexAt(_player.Current.Position);
        if (index < 0) index = 0;
        _text.Text = _lyrics.Lines[index].Text;
    }

    private void Reposition()
    {
        if (!IsVisible) return;
        var screen = Screens.Primary ?? Screens.All.FirstOrDefault();
        if (screen is null) return;
        Position = new PixelPoint(
            screen.WorkingArea.X + (screen.WorkingArea.Width - (int)Width) / 2,
            screen.WorkingArea.Bottom - (int)Height - 80);
    }
}

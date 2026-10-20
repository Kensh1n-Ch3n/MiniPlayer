using System;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform;
using Avalonia.Threading;
using Avalonia.VisualTree;
using MiniPlayerWin.Services;

namespace MiniPlayerWin.Views;

public sealed class MainWindow : Window
{
    private readonly NowPlayingService _player = new();
    private readonly LyricsService _lyricsService = new();
    private readonly DesktopLyricsWindow _desktopLyrics;

    private readonly Border _card;
    private readonly Panel _fullPanel;
    private readonly Panel _miniPanel;
    private readonly Image _fullArt = new();
    private readonly Image _miniArt = new();
    private readonly TextBlock _fullTitle = new();
    private readonly TextBlock _fullSubtitle = new();
    private readonly TextBlock _miniTitle = new();
    private readonly TextBlock _miniSubtitle = new();
    private readonly TextBlock _fullSource = new();
    private readonly TextBlock _fullElapsed = new();
    private readonly TextBlock _fullRemaining = new();
    private readonly Slider _progress = new();
    private readonly ProgressBar _miniProgress = new();
    private Button _fullPlay = new();
    private Button _miniPlay = new();

    private TrayIcon? _tray;
    private bool _mini;
    private bool _updatingProgress;
    private bool _lyricsVisible;
    private bool _reallyClose;
    private string _lyricsKey = "";
    private LyricsDocument? _lyrics;
    private TrackInfo _track = NowPlayingService.Empty;

    public MainWindow()
    {
        Title = "音乐小窗 · 网易云";
        SystemDecorations = SystemDecorations.None;
        CanResize = false;
        Topmost = true;
        ShowInTaskbar = false;
        Background = Brushes.Transparent;
        Width = 368;
        Height = 210;
        WindowStartupLocation = WindowStartupLocation.Manual;
        TransparencyLevelHint = new[]
        {
            WindowTransparencyLevel.AcrylicBlur,
            WindowTransparencyLevel.Blur,
            WindowTransparencyLevel.Transparent
        };

        _desktopLyrics = new DesktopLyricsWindow(_player);

        _card = new Border
        {
            Margin = new Thickness(8),
            CornerRadius = new CornerRadius(28),
            BorderThickness = new Thickness(1),
            BorderBrush = new SolidColorBrush(Color.Parse("#6AFFFFFF")),
            Background = new LinearGradientBrush
            {
                StartPoint = RelativePoint.TopLeft,
                EndPoint = RelativePoint.BottomRight,
                GradientStops =
                {
                    new GradientStop(Color.Parse("#C8FFFFFF"), 0),
                    new GradientStop(Color.Parse("#3A7FB6D8"), 0.18),
                    new GradientStop(Color.Parse("#CB121820"), 0.55),
                    new GradientStop(Color.Parse("#D01A2B3A"), 1)
                }
            },
            ClipToBounds = true
        };

        _fullPanel = BuildFullPanel();
        _miniPanel = BuildMiniPanel();
        _miniPanel.IsVisible = false;
        var glassOverlay = new Border
        {
            CornerRadius = new CornerRadius(27),
            Margin = new Thickness(1),
            BorderThickness = new Thickness(1),
            BorderBrush = new SolidColorBrush(Color.Parse("#40FFFFFF")),
            Background = new LinearGradientBrush
            {
                StartPoint = RelativePoint.TopLeft,
                EndPoint = RelativePoint.BottomRight,
                GradientStops =
                {
                    new GradientStop(Color.Parse("#22FFFFFF"), 0),
                    new GradientStop(Color.Parse("#00FFFFFF"), 0.42),
                    new GradientStop(Color.Parse("#1640B8FF"), 1)
                }
            },
            IsHitTestVisible = false
        };
        _card.Child = new Grid { Children = { _fullPanel, _miniPanel, glassOverlay } };
        _card.PointerPressed += OnDragSurfacePressed;
        _card.DoubleTapped += OnCardDoubleTapped;
        Content = _card;

        _desktopLyrics.SetLyrics(null);
        Opened += OnOpened;
        Closing += OnClosing;
        _player.Updated += OnPlayerUpdated;
        CreateTray();
        ApplyMode(false);
        PositionNearTopRight();
    }

    private Panel BuildFullPanel()
    {
        var artBorder = new Border
        {
            Width = 62,
            Height = 62,
            CornerRadius = new CornerRadius(16),
            ClipToBounds = true,
            Background = new SolidColorBrush(Color.Parse("#261E2A32")),
            Child = _fullArt
        };
        _fullArt.Stretch = Stretch.UniformToFill;

        _fullTitle.FontSize = 17;
        _fullTitle.FontWeight = FontWeight.SemiBold;
        _fullTitle.Foreground = Brushes.White;
        _fullTitle.TextTrimming = TextTrimming.CharacterEllipsis;

        _fullSubtitle.FontSize = 11.5;
        _fullSubtitle.Foreground = new SolidColorBrush(Color.Parse("#B8FFFFFF"));
        _fullSubtitle.TextTrimming = TextTrimming.CharacterEllipsis;

        _fullSource.FontSize = 10;
        _fullSource.Foreground = new SolidColorBrush(Color.Parse("#8AFFFFFF"));

        var info = new StackPanel
        {
            Spacing = 2,
            VerticalAlignment = VerticalAlignment.Center,
            Children = { _fullTitle, _fullSubtitle, _fullSource }
        };

        var header = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("62,12,*,Auto"),
            Children = { artBorder, info }
        };
        Grid.SetColumn(info, 2);

        var bars = new TextBlock
        {
            Text = "▮▮▮",
            FontSize = 17,
            Foreground = new SolidColorBrush(Color.Parse("#D9FFFFFF")),
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(10, 0, 0, 0)
        };
        Grid.SetColumn(bars, 3);
        header.Children.Add(bars);

        _fullElapsed.FontSize = 10.5;
        _fullElapsed.Foreground = Brushes.White;
        _fullElapsed.VerticalAlignment = VerticalAlignment.Center;
        _fullRemaining.FontSize = 10.5;
        _fullRemaining.Foreground = new SolidColorBrush(Color.Parse("#B8FFFFFF"));
        _fullRemaining.VerticalAlignment = VerticalAlignment.Center;

        _progress.Minimum = 0;
        _progress.Maximum = 1;
        _progress.Value = 0;
        _progress.Height = 18;
        _progress.VerticalAlignment = VerticalAlignment.Center;
        _progress.IsEnabled = false;
        _progress.PointerReleased += OnProgressReleased;

        var progressGrid = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("36,*,36"),
            Height = 18,
            Children = { _fullElapsed, _progress, _fullRemaining }
        };
        Grid.SetColumn(_progress, 1);
        Grid.SetColumn(_fullRemaining, 2);

        var controls = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto"),
            Margin = new Thickness(0, 4, 0, 0)
        };
        var favorite = MakeIconButton("☆", "收藏");
        favorite.IsEnabled = false;

        var fullPlay = MakeIconButton("▶", "播放 / 暂停", () => _ = _player.TogglePlayPauseAsync(), 25);
        _fullPlay = fullPlay;
        var transport = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 18,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            Children =
            {
                MakeIconButton("⏮", "上一首", () => _ = _player.PreviousAsync(), 22),
                fullPlay,
                MakeIconButton("⏭", "下一首", () => _ = _player.NextAsync(), 22)
            }
        };

        var right = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 2,
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Center,
            Children =
            {
                MakeIconButton("❝", "桌面歌词", ToggleLyrics),
                MakeIconButton("✕", "退出", CloseOrHide)
            }
        };

        controls.Children.Add(favorite);
        controls.Children.Add(transport);
        controls.Children.Add(right);
        Grid.SetColumn(transport, 1);
        Grid.SetColumn(right, 2);


        return new StackPanel
        {
            Margin = new Thickness(16, 14, 16, 12),
            Spacing = 13,
            Children = { header, progressGrid, controls }
        };
    }

    private Panel BuildMiniPanel()
    {
        _miniArt.Width = 32;
        _miniArt.Height = 32;
        _miniArt.Stretch = Stretch.UniformToFill;
        var miniArt = new Border
        {
            Width = 32,
            Height = 32,
            CornerRadius = new CornerRadius(16),
            ClipToBounds = true,
            Background = new SolidColorBrush(Color.Parse("#261E2A32")),
            Child = _miniArt
        };

        _miniTitle.FontSize = 12.5;
        _miniTitle.FontWeight = FontWeight.SemiBold;
        _miniTitle.Foreground = Brushes.White;
        _miniTitle.TextTrimming = TextTrimming.CharacterEllipsis;
        _miniSubtitle.FontSize = 9.5;
        _miniSubtitle.Foreground = new SolidColorBrush(Color.Parse("#B8FFFFFF"));
        _miniSubtitle.TextTrimming = TextTrimming.CharacterEllipsis;
        var text = new StackPanel
        {
            Spacing = 1,
            VerticalAlignment = VerticalAlignment.Center,
            Children = { _miniTitle, _miniSubtitle }
        };

        var miniPlay = MakeIconButton("▶", "播放 / 暂停", () => _ = _player.TogglePlayPauseAsync(), 17);
        _miniPlay = miniPlay;
        var transport = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 3,
            VerticalAlignment = VerticalAlignment.Center,
            Children =
            {
                MakeIconButton("⏮", "上一首", () => _ = _player.PreviousAsync(), 15),
                miniPlay,
                MakeIconButton("⏭", "下一首", () => _ = _player.NextAsync(), 15),
                MakeIconButton("❝", "桌面歌词", ToggleLyrics, 15)
            }
        };

        _miniProgress.Minimum = 0;
        _miniProgress.Maximum = 1;
        _miniProgress.Height = 2;
        _miniProgress.Margin = new Thickness(48, 0, 18, 6);
        _miniProgress.VerticalAlignment = VerticalAlignment.Bottom;
        _miniProgress.HorizontalAlignment = HorizontalAlignment.Stretch;

        var grid = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("32,6,*,Auto"),
            Margin = new Thickness(12, 9, 10, 8),
            Children = { miniArt, text, transport }
        };
        Grid.SetColumn(text, 2);
        Grid.SetColumn(transport, 3);

        return new Grid { Children = { grid, _miniProgress } };
    }

    private static Button MakeIconButton(string glyph, string help, Action? action = null, double size = 17)
    {
        var button = new Button
        {
            Content = new TextBlock
            {
                Text = glyph,
                FontSize = size,
                FontWeight = FontWeight.SemiBold,
                Foreground = Brushes.White,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            },
            Background = Brushes.Transparent,
            BorderThickness = new Thickness(0),
            Padding = new Thickness(6),
            Focusable = false
        };
        ToolTip.SetTip(button, help);
        if (action is not null) button.Click += (_, _) => action();
        return button;
    }

    private void OnOpened(object? sender, EventArgs e)
    {
        GlassWindow.Apply(this);
        PositionNearTopRight();
        _ = InitializePlayerAsync();
    }

    private async Task InitializePlayerAsync()
    {
        await _player.StartAsync();
        await RefreshTrackAsync(_player.Current);
    }

    private void OnPlayerUpdated(TrackInfo info)
    {
        Dispatcher.UIThread.Post(() => _ = RefreshTrackAsync(info));
    }

    private async Task RefreshTrackAsync(TrackInfo info)
    {
        _track = info;
        var hasTrack = info.HasTrack;
        _fullTitle.Text = hasTrack ? info.Title : "未在播放";
        _fullSubtitle.Text = hasTrack ? info.Artist : "打开网易云音乐播放歌曲";
        _fullSource.Text = hasTrack ? "网易云音乐" : "";
        _miniTitle.Text = _fullTitle.Text;
        _miniSubtitle.Text = _fullSubtitle.Text;
        _fullArt.Source = info.Artwork;
        _miniArt.Source = info.Artwork;
        _progress.IsEnabled = hasTrack && info.Duration > TimeSpan.Zero;
        _miniProgress.Value = Fraction(info);
        _fullRemaining.Text = hasTrack && info.Duration > TimeSpan.Zero
            ? $"-{Format(info.Duration - info.Position)}"
            : "";

        if (hasTrack)
        {
            _updatingProgress = true;
            _progress.Value = Fraction(info);
            _fullElapsed.Text = Format(info.Position);
            _updatingProgress = false;
        }
        else
        {
            _fullElapsed.Text = "0:00";
        }

        var playGlyph = info.IsPlaying ? "❚❚" : "▶";
        SetButtonGlyph(_fullPlay, playGlyph);
        SetButtonGlyph(_miniPlay, playGlyph);

        var key = $"{info.Title}|{info.Artist}";
        if (key != _lyricsKey)
        {
            _lyricsKey = key;
            _lyrics = null;
            _desktopLyrics.SetLyrics(null);
            if (hasTrack)
            {
                var fetched = await _lyricsService.FetchAsync(info);
                if (_lyricsKey == key)
                {
                    _lyrics = fetched;
                    _desktopLyrics.SetLyrics(fetched);
                }
            }
        }
    }

    private static void SetButtonGlyph(Button button, string glyph)
    {
        if (button.Content is TextBlock text) text.Text = glyph;
    }

    private static double Fraction(TrackInfo info)
    {
        if (info.Duration <= TimeSpan.Zero) return 0;
        return Math.Clamp(info.Position.TotalSeconds / info.Duration.TotalSeconds, 0, 1);
    }

    private static string Format(TimeSpan time)
    {
        var seconds = Math.Max(0, (int)time.TotalSeconds);
        return $"{seconds / 60}:{seconds % 60:00}";
    }

    private void OnProgressReleased(object? sender, PointerReleasedEventArgs e)
    {
        if (_updatingProgress || _track.Duration <= TimeSpan.Zero) return;
        _ = _player.SeekAsync(_track.Duration * _progress.Value);
    }

    private void OnDragSurfacePressed(object? sender, PointerPressedEventArgs e)
    {
        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
        {
            var source = e.Source as Visual;
            while (source is not null and not Button)
            {
                source = source.GetVisualParent();
            }
            if (source is Button) return;
            BeginMoveDrag(e);
        }
    }

    private void OnCardDoubleTapped(object? sender, TappedEventArgs e)
    {
        if (e.Source is Visual visual)
        {
            Visual? source = visual;
            while (source is not null and not Button)
            {
                source = source.GetVisualParent();
            }
            if (source is Button) return;
        }
        ApplyMode(!_mini);
    }

    private void ApplyMode(bool mini)
    {
        _mini = mini;
        _fullPanel.IsVisible = !mini;
        _miniPanel.IsVisible = mini;
        Width = mini ? 316 : 368;
        Height = mini ? 72 : 210;
        PositionNearTopRight();
    }

    private void ToggleLyrics()
    {
        _lyricsVisible = !_lyricsVisible;
        if (_lyricsVisible)
        {
            _desktopLyrics.SetLyrics(_lyrics);
            _desktopLyrics.Start();
        }
        else
        {
            _desktopLyrics.Stop();
        }
    }

    private void CloseOrHide()
    {
        if (_reallyClose) Close();
        else Hide();
    }

    private void PositionNearTopRight()
    {
        var screen = Screens.Primary ?? Screens.All[0];
        if (screen is null) return;
        Position = new PixelPoint(
            screen.WorkingArea.Right - (int)Width - 24,
            screen.WorkingArea.Y + 24);
    }

    private void OnClosing(object? sender, WindowClosingEventArgs e)
    {
        if (_reallyClose) return;
        e.Cancel = true;
        Hide();
    }

    private void CreateTray()
    {
        try
        {
            var icon = new WindowIcon(AssetLoader.Open(new Uri("avares://MiniPlayerWin/Assets/app.ico")));
            var menu = new NativeMenu();
            var show = new NativeMenuItem("显示 / 隐藏播放器");
            show.Click += (_, _) => ToggleVisible();
            var full = new NativeMenuItem("完整播放器");
            full.Click += (_, _) => { Show(); ApplyMode(false); };
            var mini = new NativeMenuItem("迷你模式");
            mini.Click += (_, _) => { Show(); ApplyMode(true); };
            var lyrics = new NativeMenuItem("显示 / 隐藏桌面歌词");
            lyrics.Click += (_, _) => ToggleLyrics();
            var quit = new NativeMenuItem("退出音乐小窗");
            quit.Click += (_, _) => { _reallyClose = true; Close(); };

            menu.Items.Add(show);
            menu.Items.Add(full);
            menu.Items.Add(mini);
            menu.Items.Add(new NativeMenuItemSeparator());
            menu.Items.Add(lyrics);
            menu.Items.Add(new NativeMenuItemSeparator());
            menu.Items.Add(quit);

            _tray = new TrayIcon
            {
                Icon = icon,
                ToolTipText = "音乐小窗 · 网易云音乐",
                Menu = menu
            };
            _tray.Clicked += (_, _) => ToggleVisible();
        }
        catch
        {
            _tray = null;
        }
    }

    private void ToggleVisible()
    {
        if (IsVisible) Hide(); else Show();
    }
}

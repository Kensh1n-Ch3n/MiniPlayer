using System;
using System.Runtime.InteropServices;
using Avalonia.Controls;

namespace MiniPlayerWin.Services;

/// <summary>Applies Windows 11 DWM acrylic / rounded-corner styling to a window.</summary>
public static class GlassWindow
{
    private const int DwmwaUseImmersiveDarkMode = 20;
    private const int DwmwaWindowCornerPreference = 33;
    private const int DwmwaSystemBackdropType = 38;

    [DllImport("dwmapi.dll", PreserveSig = true)]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

    public static void Apply(Window window)
    {
        if (!OperatingSystem.IsWindows()) return;
        var handle = window.TryGetPlatformHandle()?.Handle ?? IntPtr.Zero;
        if (handle == IntPtr.Zero) return;

        TrySet(handle, DwmwaUseImmersiveDarkMode, 1);
        TrySet(handle, DwmwaWindowCornerPreference, 2); // DWMWCP_ROUND
        TrySet(handle, DwmwaSystemBackdropType, 3);     // DWMSBT_TRANSIENTWINDOW (acrylic)
    }

    private static void TrySet(IntPtr hwnd, int attribute, int value)
    {
        try { _ = DwmSetWindowAttribute(hwnd, attribute, ref value, sizeof(int)); }
        catch { }
    }
}

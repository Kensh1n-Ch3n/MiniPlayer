from PIL import Image, ImageDraw, ImageFilter
import math
import os
import subprocess
import tempfile

SIZE = 1024
SCALE = 4
S = SIZE * SCALE


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def make_icon():
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    pad = int(74 * SCALE)
    w = int(876 * SCALE)
    radius = int(212 * SCALE)

    # Background gradient.
    bg = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    px = bg.load()
    top = (20, 15, 17)
    mid = (56, 23, 18)
    bottom = (231, 94, 32)
    for y in range(w):
        t = y / (w - 1)
        if t < 0.62:
            color = lerp(top, mid, t / 0.62)
        else:
            color = lerp(mid, bottom, (t - 0.62) / 0.38)
        for x in range(w):
            px[x, y] = color + (255,)

    # Warm sun glow near the bottom.
    glow = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy, r = int(w * 0.54), int(w * 0.79), int(w * 0.42)
    for i in range(r, 0, -1):
        t = i / r
        alpha = int(145 * (1 - t) ** 2)
        gd.ellipse((cx - i, cy - i, cx + i, cy + i), fill=(255, 138, 61, alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(int(14 * SCALE)))
    bg = Image.alpha_composite(bg, glow)

    # Thin horizon line.
    hz = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hz)
    y = int(w * 0.66)
    hd.line((int(w * 0.08), y, int(w * 0.92), y), fill=(255, 215, 175, 70), width=max(1, int(2 * SCALE)))
    bg = Image.alpha_composite(bg, hz)

    # White waveform.
    bars = [0.32, 0.54, 0.82, 0.60, 0.38]
    bar_w = int(48 * SCALE)
    gap = int(27 * SCALE)
    total = len(bars) * bar_w + (len(bars) - 1) * gap
    start_x = (w - total) // 2
    base_y = int(w * 0.55)
    max_h = int(w * 0.38)

    overlay = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for i, frac in enumerate(bars):
        h = int(max_h * frac)
        x0 = start_x + i * (bar_w + gap)
        y0 = base_y - h // 2
        od.rounded_rectangle(
            (x0, y0, x0 + bar_w, y0 + h),
            radius=bar_w // 2,
            fill=(255, 255, 255, 243),
        )
    # Slight soft glow under the bars.
    glow2 = overlay.filter(ImageFilter.GaussianBlur(int(8 * SCALE)))
    overlay = Image.alpha_composite(glow2, overlay)
    bg = Image.alpha_composite(bg, overlay)

    # Inner top highlight.
    highlight = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    hld = ImageDraw.Draw(highlight)
    hld.rounded_rectangle(
        (int(10 * SCALE), int(10 * SCALE), w - int(10 * SCALE), w - int(10 * SCALE)),
        radius=radius - int(8 * SCALE),
        outline=(255, 255, 255, 80),
        width=max(1, int(2 * SCALE)),
    )
    bg = Image.alpha_composite(bg, highlight)

    # Mask and place on canvas.
    mask = rounded_mask(w, radius)
    bg.putalpha(mask)
    canvas.alpha_composite(bg, (pad, pad))

    # Subtle soft shadow.
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        (pad + int(8 * SCALE), pad + int(18 * SCALE), pad + w + int(8 * SCALE), pad + w + int(18 * SCALE)),
        radius=radius,
        fill=(0, 0, 0, 90),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(20 * SCALE)))
    canvas = Image.alpha_composite(shadow, canvas)

    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def write_iconset(icon, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    specs = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    for name, size in specs:
        icon.resize((size, size), Image.LANCZOS).save(os.path.join(output_dir, name))


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    resources = os.path.join(root, "Resources")
    os.makedirs(resources, exist_ok=True)
    icon = make_icon()
    icon.save(os.path.join(resources, "AppIcon-1024.png"))

    with tempfile.TemporaryDirectory() as tmp:
        iconset = os.path.join(tmp, "AppIcon.iconset")
        write_iconset(icon, iconset)
        icns = os.path.join(resources, "AppIcon.icns")
        subprocess.run(["iconutil", "-c", "icns", iconset, "-o", icns], check=True)
        print("Wrote", icns)


if __name__ == "__main__":
    main()

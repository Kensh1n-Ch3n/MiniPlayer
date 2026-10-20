from PIL import Image, ImageDraw, ImageFilter
import os
import subprocess
import tempfile

SIZE = 1024
SS = 2
S = SIZE * SS


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=radius, fill=255
    )
    return mask


def make_icon():
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    pad = int(74 * SS)
    w = int(876 * SS)
    radius = int(212 * SS)

    # Bright sky-blue to mint gradient.
    bg = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    px = bg.load()
    stops = [
        (0.00, (128, 229, 255)),
        (0.42, (84, 212, 255)),
        (0.74, (63, 198, 233)),
        (1.00, (47, 203, 172)),
    ]
    for y in range(w):
        t = y / (w - 1)
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t0 <= t <= t1:
                f = (t - t0) / (t1 - t0)
                color = lerp(c0, c1, f)
                break
        for x in range(w):
            px[x, y] = color + (255,)

    # Soft white and mint light pools.
    glow = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)

    def pool(cx, cy, r, color, alpha):
        for i in range(r, 0, -1):
            a = int(alpha * (1 - i / r) ** 2)
            gd.ellipse((cx - i, cy - i, cx + i, cy + i), fill=color + (a,))

    pool(int(w * 0.24), int(w * 0.15), int(w * 0.62), (255, 255, 255), 95)
    pool(int(w * 0.82), int(w * 0.88), int(w * 0.48), (86, 245, 207), 75)
    glow = glow.filter(ImageFilter.GaussianBlur(int(18 * SS)))
    bg = Image.alpha_composite(bg, glow)

    # Diagonal glass sheen.
    sheen = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sheen)
    sd.polygon(
        [(0, 0), (int(w * 0.60), 0), (int(w * 0.17), w), (0, w)],
        fill=(255, 255, 255, 30),
    )
    sheen = sheen.filter(ImageFilter.GaussianBlur(int(32 * SS)))
    bg = Image.alpha_composite(bg, sheen)

    # White equalizer bars with a soft deep-blue shadow for legibility.
    bars = [0.32, 0.54, 0.82, 0.60, 0.38]
    bar_w = int(46 * SS)
    gap = int(28 * SS)
    total = len(bars) * bar_w + (len(bars) - 1) * gap
    start_x = (w - total) // 2
    base_y = int(w * 0.53)
    max_h = int(w * 0.37)

    shapes = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    sh = ImageDraw.Draw(shapes)
    for i, frac in enumerate(bars):
        h = int(max_h * frac)
        x0 = start_x + i * (bar_w + gap)
        y0 = base_y - h // 2
        sh.rounded_rectangle(
            (x0, y0, x0 + bar_w, y0 + h), radius=bar_w // 2, fill=(255, 255, 255, 248)
        )

    bar_shadow = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    bsd = ImageDraw.Draw(bar_shadow)
    for i, frac in enumerate(bars):
        h = int(max_h * frac)
        x0 = start_x + i * (bar_w + gap)
        y0 = base_y - h // 2
        bsd.rounded_rectangle(
            (x0 + int(2 * SS), y0 + int(7 * SS), x0 + bar_w + int(2 * SS), y0 + h + int(7 * SS)),
            radius=bar_w // 2,
            fill=(8, 74, 120, 55),
        )
    bar_shadow = bar_shadow.filter(ImageFilter.GaussianBlur(int(8 * SS)))
    bg = Image.alpha_composite(bg, bar_shadow)
    bg = Image.alpha_composite(bg, shapes)

    # Fine inner rim.
    rim = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim)
    rd.rounded_rectangle(
        (int(9 * SS), int(9 * SS), w - int(9 * SS), w - int(9 * SS)),
        radius=radius - int(8 * SS),
        outline=(255, 255, 255, 115),
        width=max(1, int(2 * SS)),
    )
    bg = Image.alpha_composite(bg, rim)

    bg.putalpha(rounded_mask(w, radius))
    canvas.alpha_composite(bg, (pad, pad))

    # Soft outer shadow.
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shd = ImageDraw.Draw(shadow)
    shd.rounded_rectangle(
        (pad + int(7 * SS), pad + int(17 * SS), pad + w + int(7 * SS), pad + w + int(17 * SS)),
        radius=radius,
        fill=(0, 0, 0, 70),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(20 * SS)))
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
    icon = make_icon()
    icon.save(os.path.join(resources, "AppIcon-1024.png"))
    with tempfile.TemporaryDirectory() as tmp:
        iconset = os.path.join(tmp, "AppIcon.iconset")
        write_iconset(icon, iconset)
        subprocess.run(
            ["iconutil", "-c", "icns", iconset, "-o", os.path.join(resources, "AppIcon.icns")],
            check=True,
        )
    print("Wrote", os.path.join(resources, "AppIcon.icns"))


if __name__ == "__main__":
    main()

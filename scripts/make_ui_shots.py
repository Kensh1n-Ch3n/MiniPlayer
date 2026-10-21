from PIL import Image, ImageDraw, ImageFilter, ImageOps
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BG_PATH = os.path.join(ROOT, "docs", "landscape-bg.jpg")


def background(size):
    bg = Image.open(BG_PATH).convert("RGB")
    bg = ImageOps.fit(bg, size, method=Image.LANCZOS)
    bg = bg.filter(ImageFilter.GaussianBlur(14))
    canvas = bg.convert("RGBA")

    # Cool vignette / depth so the light glass separates from the wallpaper.
    overlay = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    w, h = size
    for y in range(h):
        t = y / max(1, h - 1)
        alpha = int(38 + 54 * t)
        draw.line((0, y, w, y), fill=(2, 12, 26, alpha))
    canvas = Image.alpha_composite(canvas, overlay)

    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((w * 0.16, h * 0.08, w * 0.88, h * 0.92), fill=(120, 225, 255, 32))
    glow = glow.filter(ImageFilter.GaussianBlur(90))
    return Image.alpha_composite(canvas, glow)


def paste_card(canvas, card, center, width, shadow_alpha=105):
    height = int(width * card.height / card.width)
    card = card.resize((width, height), Image.LANCZOS)
    alpha = card.getchannel("A")

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer = Image.new("RGBA", card.size, (0, 0, 0, shadow_alpha))
    layer.putalpha(alpha)
    x = int(center[0] - width / 2)
    y = int(center[1] - height / 2)
    shadow.alpha_composite(layer, (x, y + 24))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(card, (x, y))
    return canvas


def make_full():
    size = (1200, 680)
    canvas = background(size)
    card = Image.open(os.path.join(ROOT, "docs", "widget-card.png")).convert("RGBA")
    canvas = paste_card(canvas, card, (600, 330), 760)
    canvas.convert("RGB").save(os.path.join(ROOT, "docs", "ui-full.png"), quality=95)
    print("wrote docs/ui-full.png")


def make_mini():
    capsule = Image.open(os.path.join(ROOT, "docs", "widget-mini-card.png")).convert("RGBA")

    size = (1200, 420)
    canvas = background(size)
    canvas = paste_card(canvas, capsule, (600, 200), 620, shadow_alpha=95)
    canvas.convert("RGB").save(os.path.join(ROOT, "docs", "ui-mini.png"), quality=95)
    print("wrote docs/ui-mini.png")


def make_lyrics():
    # A taller, calmer desktop-lyric crop from the same Tahoe capture.
    src = Image.open(os.path.join(ROOT, "docs", "lyrics-source.png")).convert("RGB")
    crop = src.resize((1200, 300), Image.LANCZOS)
    crop.save(os.path.join(ROOT, "docs", "ui-lyrics.png"), quality=95)
    print("wrote docs/ui-lyrics.png")


if __name__ == "__main__":
    make_full()
    make_mini()
    make_lyrics()

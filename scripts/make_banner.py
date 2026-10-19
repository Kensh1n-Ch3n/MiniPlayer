from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math, random, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 1400, 480
S = 2
canvas = Image.new("RGB", (W * S, H * S), (9, 12, 24))
draw = ImageDraw.Draw(canvas)

# Vertical gradient
top = (10, 15, 32)
bottom = (28, 20, 45)
for y in range(H * S):
    t = y / (H * S - 1)
    color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    draw.line((0, y, W * S, y), fill=color)

# Soft glows
glow = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
def radial(cx, cy, r, color, strength):
    for i in range(r, 0, -1):
        a = int(strength * (1 - i / r) ** 2)
        gd.ellipse((cx - i, cy - i, cx + i, cy + i), fill=color + (a,))
radial(int(W * S * 0.83), int(H * S * 0.20), int(360 * S), (255, 126, 48), 90)
radial(int(W * S * 0.20), int(H * S * 0.95), int(420 * S), (113, 61, 255), 55)
radial(int(W * S * 0.55), int(H * S * 0.45), int(260 * S), (57, 146, 255), 32)
glow = glow.filter(ImageFilter.GaussianBlur(48 * S))
canvas = Image.alpha_composite(canvas.convert("RGBA"), glow)

# Sparse stars
rnd = random.Random(7)
for _ in range(90):
    x = rnd.randrange(W * S)
    y = rnd.randrange(int(H * S * 0.75))
    r = rnd.choice([1, 1, 1, 2]) * S
    alpha = rnd.randrange(30, 120)
    star = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(star)
    sd.ellipse((x - r, y - r, x + r, y + r), fill=(220, 235, 255, alpha))
    canvas = Image.alpha_composite(canvas, star)

# App icon
icon = Image.open(os.path.join(ROOT, "Resources", "AppIcon-1024.png")).convert("RGBA")
icon = icon.resize((172 * S, 172 * S), Image.LANCZOS)
# rounded mask for icon
mask = Image.new("L", icon.size, 0)
md = ImageDraw.Draw(mask)
md.rounded_rectangle((0, 0, icon.size[0] - 1, icon.size[1] - 1), radius=38 * S, fill=255)
icon.putalpha(mask)
canvas.alpha_composite(icon, (88 * S, 130 * S))

# Fonts
font_path = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
title_font = ImageFont.truetype(font_path, 72 * S)
sub_font = ImageFont.truetype(font_path, 28 * S)
tag_font = ImageFont.truetype(font_path, 20 * S)
small_font = ImageFont.truetype(font_path, 17 * S)

draw = ImageDraw.Draw(canvas)
draw.text((300 * S, 118 * S), "音乐小窗", font=title_font, fill=(255, 255, 255, 255))
draw.text((302 * S, 220 * S), "MiniPlayer for Apple Music", font=sub_font, fill=(193, 205, 224, 255))

# Tag pill
pill_text = "Liquid Glass  ·  桌面歌词  ·  0 偏置对齐"
bbox = draw.textbbox((0, 0), pill_text, font=tag_font)
pw = bbox[2] - bbox[0]
ph = bbox[3] - bbox[1]
pill = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
pd = ImageDraw.Draw(pill)
pd.rounded_rectangle(
    (300 * S, 278 * S, 300 * S + pw + 38 * S, 278 * S + ph + 22 * S),
    radius=14 * S,
    fill=(255, 255, 255, 20),
    outline=(255, 255, 255, 42),
    width=1 * S,
)
canvas = Image.alpha_composite(canvas, pill)
draw = ImageDraw.Draw(canvas)
draw.text((319 * S, 286 * S), pill_text, font=tag_font, fill=(204, 218, 240, 255))
draw.text((302 * S, 350 * S), "Native glass · Apple Music lyrics · Always on top", font=small_font, fill=(126, 142, 168, 255))

# Widget product shot (cropped to the card edge, transparent corners)
shot = Image.open(os.path.join(ROOT, "docs", "widget-card.png")).convert("RGBA")
shot = shot.resize((560 * S, int(560 * S * shot.height / shot.width)), Image.LANCZOS)
x0 = 800 * S
y0 = int((H * S - shot.height) / 2)

# Soft shadow behind the floating card
shadow = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.rounded_rectangle(
    (x0 + 14 * S, y0 + 22 * S, x0 + shot.size[0] + 14 * S, y0 + shot.size[1] + 22 * S),
    radius=55 * S,
    fill=(0, 0, 0, 125),
)
shadow = shadow.filter(ImageFilter.GaussianBlur(22 * S))
canvas = Image.alpha_composite(canvas, shadow)
canvas.alpha_composite(shot, (x0, y0))

out = canvas.convert("RGB").resize((W, H), Image.LANCZOS)
out.save(os.path.join(ROOT, "docs", "banner.png"), quality=95)
print("wrote", os.path.join(ROOT, "docs", "banner.png"))

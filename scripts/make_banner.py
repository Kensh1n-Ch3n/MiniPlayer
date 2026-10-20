from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 1400, 480
S = 2

# Local landscape wallpaper as the hero background
bg = Image.open(os.path.join(ROOT, "docs", "landscape-bg.jpg")).convert("RGB")
bg = ImageOps.fit(bg, (W * S, H * S), method=Image.LANCZOS)
canvas = bg.convert("RGBA")

# Left-side dark gradient so the white typography stays readable
shade = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
sd = ImageDraw.Draw(shade)
for x in range(W * S):
    t = x / (W * S)
    alpha = int(228 * max(0.0, (0.76 - t) / 0.76) ** 1.02)
    sd.line((x, 0, x, H * S), fill=(8, 12, 16, alpha))
canvas = Image.alpha_composite(canvas, shade)

# App icon, cropped to its rounded-square edge before placing it in the banner
icon = Image.open(os.path.join(ROOT, "Resources", "AppIcon-1024.png")).convert("RGBA")
bbox = icon.getbbox()
if bbox:
    icon = icon.crop(bbox)
icon = icon.resize((184 * S, 184 * S), Image.LANCZOS)
canvas.alpha_composite(icon, (80 * S, 124 * S))

# Fonts
font_path = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
title_font = ImageFont.truetype(font_path, 72 * S)
sub_font = ImageFont.truetype(font_path, 28 * S)
tag_font = ImageFont.truetype(font_path, 20 * S)
small_font = ImageFont.truetype(font_path, 17 * S)

draw = ImageDraw.Draw(canvas)
draw.text((300 * S, 118 * S), "音乐小窗", font=title_font, fill=(255, 255, 255, 255))
draw.text((302 * S, 220 * S), "MiniPlayer for Apple Music", font=sub_font, fill=(225, 233, 242, 255))

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
draw.text((319 * S, 286 * S), pill_text, font=tag_font, fill=(232, 238, 246, 255))
draw.text((302 * S, 350 * S), "Native glass · Apple Music lyrics · Always on top", font=small_font, fill=(206, 216, 228, 255))

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

from PIL import Image, ImageDraw, ImageFilter
import random, math

W, H = 2940, 1912
S = 1
img = Image.new("RGB", (W, H), (7, 10, 22))
draw = ImageDraw.Draw(img)

top = (6, 9, 20)
bottom = (24, 18, 43)
for y in range(H):
    t = y / (H - 1)
    c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    draw.line((0, y, W, y), fill=c)

glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
def radial(cx, cy, r, color, strength):
    for i in range(r, 0, -1):
        a = int(strength * (1 - i / r) ** 2)
        gd.ellipse((cx - i, cy - i, cx + i, cy + i), fill=color + (a,))
radial(int(W * 0.82), int(H * 0.18), 700, (255, 120, 48), 80)
radial(int(W * 0.18), int(H * 0.85), 900, (92, 56, 240), 55)
radial(int(W * 0.55), int(H * 0.45), 600, (43, 129, 230), 28)
glow = glow.filter(ImageFilter.GaussianBlur(90))
img = Image.alpha_composite(img.convert("RGBA"), glow)

rnd = random.Random(21)
star_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
sd = ImageDraw.Draw(star_layer)
for _ in range(260):
    x = rnd.randrange(W)
    y = rnd.randrange(H)
    r = rnd.choice([1, 1, 1, 2, 2, 3])
    alpha = rnd.randrange(35, 170)
    sd.ellipse((x - r, y - r, x + r, y + r), fill=(225, 238, 255, alpha))
# a few bright stars with soft glow
for _ in range(7):
    x = rnd.randrange(W)
    y = rnd.randrange(H)
    r = rnd.randrange(30, 70)
    g = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd2 = ImageDraw.Draw(g)
    for rr in range(r, 0, -1):
        a = int(55 * (1 - rr / r) ** 2)
        gd2.ellipse((x - rr, y - rr, x + rr, y + rr), fill=(190, 230, 255, a))
    star_layer = Image.alpha_composite(star_layer, g)
    sd = ImageDraw.Draw(star_layer)
    sd.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(255, 255, 255, 230))

img = Image.alpha_composite(img, star_layer).convert("RGB")
img.save("/tmp/starfield-wallpaper.jpg", quality=94)
print("wrote /tmp/starfield-wallpaper.jpg", img.size)

"""Draws the launcher icon: a white water drop with a wave line on the app's
navy-into-cyan hero gradient, and writes every Android and iOS size.

Run from the project root:  python tool/make_icon.py
"""
import math
import os
import glob

from PIL import Image, ImageDraw

S = 1024
NAVY, BLUE, CYAN = (10, 35, 80), (15, 91, 181), (34, 180, 230)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background():
    img = Image.new("RGB", (S, S))
    px = img.load()
    for y in range(S):
        for x in range(S):
            t = (x + y) / (2 * S)  # diagonal from the top-left corner
            px[x, y] = lerp(NAVY, BLUE, t / 0.55) if t < 0.55 else lerp(BLUE, CYAN, (t - 0.55) / 0.45)
    return img


def drop_mask(scale=1.0):
    """A teardrop: a circle plus the triangle from its tip to the two points
    where lines from the tip touch the circle, so the sides meet it smoothly."""
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    cx, cy = S / 2, S * 0.60
    r = S * 0.25 * scale
    tip = cy - S * 0.43 * scale
    dist = cy - tip
    phi = math.acos(r / dist)  # angle at the centre between "up" and a tangent point
    left = (cx - r * math.sin(phi), cy - r * math.cos(phi))
    right = (cx + r * math.sin(phi), cy - r * math.cos(phi))
    d.polygon([(cx, tip), left, right], fill=255)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    return m


def render(rounded):
    img = background().convert("RGBA")
    white = Image.new("RGBA", (S, S), (255, 255, 255, 255))
    img.paste(white, (0, 0), drop_mask())
    # A wave across the lower drop, in the gradient colour, reads as water.
    wave = Image.new("L", (S, S), 0)
    wd = ImageDraw.Draw(wave)
    base = S * 0.66
    pts = [(x, base + S * 0.022 * math.sin(x / S * 2 * math.pi * 2.2)) for x in range(0, S + 1, 4)]
    wd.polygon(pts + [(S, S), (0, S)], fill=255)
    inner = Image.composite(wave, Image.new("L", (S, S), 0), drop_mask(0.80))
    fill = background().convert("RGBA")
    img.paste(fill, (0, 0), inner.point(lambda v: int(v * 0.85)))
    if rounded:
        mask = Image.new("L", (S, S), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=S * 0.22, fill=255)
        img.putalpha(mask)
    return img


def main():
    android = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    art = render(rounded=True)
    for density, size in android.items():
        out = f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
        art.resize((size, size), Image.LANCZOS).save(out)

    # iOS masks the corners itself and rejects alpha, so a full square.
    square = render(rounded=False).convert("RGB")
    for path in glob.glob("ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png"):
        with Image.open(path) as existing:
            size = existing.size
        square.resize(size, Image.LANCZOS).save(path)
    square.resize((512, 512), Image.LANCZOS).save("assets/icon.png")
    print("icons written")


if __name__ == "__main__":
    main()

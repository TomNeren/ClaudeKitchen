"""Generates the app icon (light, dark, tinted) into App/Sources/Assets.xcassets/AppIcon.appiconset.

Run from the repository root: python3 App/Tools/make_app_icon.py (needs Pillow).
"""

import json
import math
import os

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT = "App/Sources/Assets.xcassets/AppIcon.appiconset"
CREAM = (0xF4, 0xEF, 0xE6)
TERRACOTTA = (0xE5, 0x8A, 0x5C)


def gradient(top, bottom):
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        t = y / (SIZE - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(SIZE):
            px[x, y] = c
    return img


def herb_glow(img, strength):
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).ellipse((-200, 560, 560, 1320), fill=150)
    mask = mask.filter(ImageFilter.GaussianBlur(160)).point(lambda v: int(v * strength))
    return Image.composite(Image.new("RGB", (SIZE, SIZE), (0x5C, 0x71, 0x48)), img, mask)


def pot(draw, color):
    draw.chord((212, 380, 812, 900), start=0, end=180, fill=color)
    draw.rounded_rectangle((180, 560, 844, 612), radius=26, fill=color)
    draw.rounded_rectangle((120, 575, 200, 605), radius=15, fill=color)
    draw.rounded_rectangle((824, 575, 904, 605), radius=15, fill=color)
    for i, x0 in enumerate((392, 512, 632)):
        points = [
            (x0 + 28 * math.sin(k / 160 * 2 * math.pi + i * 0.6), 470 - k * 1.6) for k in range(0, 161, 4)
        ]
        draw.line(points, fill=color, width=34, joint="curve")
        for px, py in (points[0], points[-1]):
            draw.ellipse((px - 17, py - 17, px + 17, py + 17), fill=color)


def main():
    os.makedirs(OUT, exist_ok=True)
    light = herb_glow(gradient((0xD0, 0x6C, 0x3E), (0x9A, 0x42, 0x1E)), 0.55)
    pot(ImageDraw.Draw(light), CREAM)
    light.save(f"{OUT}/AppIcon.png")

    # Dark: the pot in terracotta on the app's dark cream, as the dark-mode palette does.
    dark = herb_glow(gradient((0x2A, 0x25, 0x1E), (0x18, 0x15, 0x11)), 0.35)
    pot(ImageDraw.Draw(dark), TERRACOTTA)
    dark.save(f"{OUT}/AppIcon-Dark.png")

    # Tinted: white artwork on black; the system applies the tint.
    tinted = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    pot(ImageDraw.Draw(tinted), (255, 255, 255))
    tinted.convert("L").save(f"{OUT}/AppIcon-Tinted.png")

    entry = {"idiom": "universal", "platform": "ios", "size": "1024x1024"}
    contents = {
        "images": [
            {**entry, "filename": "AppIcon.png"},
            {**entry, "filename": "AppIcon-Dark.png", "appearances": [{"appearance": "luminosity", "value": "dark"}]},
            {**entry, "filename": "AppIcon-Tinted.png", "appearances": [{"appearance": "luminosity", "value": "tinted"}]},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with open(f"{OUT}/Contents.json", "w") as handle:
        json.dump(contents, handle, indent=2)


if __name__ == "__main__":
    main()

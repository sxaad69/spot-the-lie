#!/usr/bin/env python3
"""SPOT THE LIE — C1 thumbnail: DAILY marker must be readable (gate condition).
Also generates the project icon (assets/base/icon.png) from the same layout.
"""
import os

from PIL import Image, ImageDraw, ImageFont

base = "/opt/games/spot-the-lie/assets/base/room-study.webp"


def font(sz):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]:
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


def make(w, h, title_sz, daily_sz, out):
    im = Image.open(base).convert("RGB").resize((w, h))
    d = ImageDraw.Draw(im)
    band_y = int(h * 0.78)
    d.rectangle([0, band_y, w, h], fill=(16, 19, 27))
    f_title = font(title_sz)
    f_daily = font(daily_sz)
    d.text((int(w * 0.035), band_y + int(h * 0.02)), "SPOT THE LIE", font=f_title,
           fill=(232, 235, 242))
    # gold DAILY badge
    bw = int(d.textlength("DAILY", font=f_daily)) + 28
    bh = daily_sz + 16
    bx, by = w - bw - int(w * 0.03), band_y + int(h * 0.015)
    d.rounded_rectangle([bx, by, bx + bw, by + bh], 6, fill=(224, 168, 63))
    tw = d.textlength("DAILY", font=f_daily)
    d.text((bx + (bw - tw) / 2, by + 8), "DAILY", font=f_daily, fill=(20, 22, 30))
    im.save(out)
    print("wrote", out)


make(576, 324, 34, 22, "/tmp/stl-thumb.png")
make(256, 256, 40, 24, "/opt/games/spot-the-lie/assets/base/icon.png")

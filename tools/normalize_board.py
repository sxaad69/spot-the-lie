#!/usr/bin/env python3
"""SPOT THE LIE — base painting normalizer v2 (lighter touch).
v1's hard palette-lock + edge pass crushed detail. v2 keeps the AI render
largely intact and only:
- crops to board aspect + resizes
- mild denoise blur
- gentle saturation reduction toward muted noir
- slight contrast lift in shadows so objects stay readable
Deterministic.
"""
import os
import sys

from PIL import Image, ImageFilter, ImageEnhance

RAW = "/tmp/stl-raw"
OUT = "/opt/games/spot-the-lie/assets/base"
os.makedirs(OUT, exist_ok=True)

BOARD_W, BOARD_H = 576, 648


def normalize(path_in, path_out):
    im = Image.open(path_in).convert("RGB")
    tw, th = BOARD_W, BOARD_H
    scale = max(tw / im.width, th / im.height)
    nw, nh = round(im.width * scale), round(im.height * scale)
    im = im.resize((nw, nh), Image.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    im = im.crop((left, top, left + tw, top + th))

    im = im.filter(ImageFilter.GaussianBlur(0.6))
    # muted noir: desaturate a bit, cool the tone slightly
    im = ImageEnhance.Color(im).enhance(0.55)
    r, g, b = im.split()
    b = b.point(lambda v: min(255, int(v * 1.06)))
    g = g.point(lambda v: int(v * 0.99))
    im = Image.merge("RGB", (r, g, b))
    # keep shadows readable (objects must survive at game scale)
    im = ImageEnhance.Brightness(im).enhance(1.12)
    im = ImageEnhance.Contrast(im).enhance(1.05)
    im.save(path_out, "WEBP", quality=86, method=6)


def main():
    only = sys.argv[1:] if len(sys.argv) > 1 else None
    for fn in sorted(os.listdir(RAW)):
        if not fn.endswith(".jpg"):
            continue
        sid = fn[:-4]
        if only and sid not in only:
            continue
        out = os.path.join(OUT, f"{sid}.webp")
        normalize(os.path.join(RAW, fn), out)
        print(f"[ok] {sid} -> {out} {os.path.getsize(out)} bytes")


if __name__ == "__main__":
    main()

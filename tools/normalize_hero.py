#!/usr/bin/env python3
"""SET-PIECE MASTER — hero asset normalizer (adaptive-key version).

Turns pollinations raw JPEGs into the locked-palette, uniform-outline WebP kit.

Palette lock (spec §5.1 + feeler):
  PITCH      #1B6B3A  (deep pitch green)
  LINES      #F5F5F5  (white pitch lines)
  KIT_RED    #E63946
  KIT_BLUE   #26547C
  GOLD       #FFD166  (floodlight gold)
  STANDS     #0d1b2a  (dark stands / night navy)
  STANDS_DK  #07131f  (darker navy)
  SKIN       #f2b8a0  (warm skin tone accent)

Keying is ADAPTIVE: the background color is estimated from the image corners
(median), because pollinations renders "pure white/black background" requests
as mid-grey tones. Pixels near the corner-median background are keyed to
transparent with a feather band; JPEG edge artifacts are absorbed by the band.

Silhouette sprites (keeper, wall): key bg -> alpha, tint STANDS, uniform dark
outline. Bright-on-dark (ball, net): key bg -> alpha. Full-color pieces
(backdrop, crowd, celebration): palette-quantized, no alpha.

Deterministic: fixed seeds upstream, fixed tolerances here.
"""
import os
from PIL import Image, ImageFilter, ImageChops

RAW = "/tmp/hero-raw"
OUT = "/opt/games/set-piece-master/assets/hero"

PALETTE = {
    "PITCH":     (0x1B, 0x6B, 0x3A),
    "LINES":     (0xF5, 0xF5, 0xF5),
    "KIT_RED":   (0xE6, 0x39, 0x46),
    "KIT_BLUE":  (0x26, 0x54, 0x7C),
    "GOLD":      (0xFF, 0xD1, 0x66),
    "STANDS":    (0x0d, 0x1b, 0x2a),
    "STANDS_DK": (0x07, 0x13, 0x1f),
    "SKIN":      (0xf2, 0xb8, 0xa0),
    "WHITE":     (0xff, 0xff, 0xff),
    "BLACK":     (0x00, 0x00, 0x00),
}

def otsu_threshold(im):
    """Otsu's method on luminance histogram -> threshold separating dark figure from bg."""
    im = im.convert("L")
    hist = im.histogram()
    total = im.size[0] * im.size[1]
    sum_all = sum(i * h for i, h in enumerate(hist))
    sum_b, w_b = 0, 0
    best_t, best_var = 0, -1
    for t in range(256):
        w_b += hist[t]
        if w_b == 0:
            continue
        w_f = total - w_b
        if w_f == 0:
            break
        sum_b += t * hist[t]
        m_b = sum_b / w_b
        m_f = (sum_all - sum_b) / w_f
        var = w_b * w_f * (m_b - m_f) ** 2
        if var > best_var:
            best_var, best_t = var, t
    return best_t

def key_bg(im, feather=18, dark_bg=False):
    """Adaptive background key via Otsu luminance threshold.

    dark_bg=False (default): dark figure on lighter background -> pixels
    brighter than threshold are background, keyed transparent.
    dark_bg=True: bright figure on dark background -> pixels darker than
    threshold are background, keyed transparent. The feather band absorbs
    JPEG edge artifacts. Robust to mixed corner backgrounds."""
    im = im.convert("RGBA")
    t = otsu_threshold(im)
    px = im.load()
    w, h = im.size
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    opx = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            if dark_bg:
                # bright figure on dark bg: dark pixels are background
                if lum <= t - feather:
                    alpha = 0
                elif lum <= t:
                    alpha = int(255 * (lum - (t - feather)) / feather)
                else:
                    alpha = 255
            else:
                if lum >= t + feather:
                    alpha = 0
                elif lum >= t:
                    alpha = int(255 * (t + feather - lum) / feather)
                else:
                    alpha = 255
            opx[x, y] = (r, g, b, alpha)
    return out

def tint_silhouette(im, color=PALETTE["STANDS"]):
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    opx = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            opx[x, y] = (color[0], color[1], color[2], a)
    return out

def add_outline(im, color=PALETTE["STANDS_DK"], width=4):
    im = im.convert("RGBA")
    alpha = im.split()[3]
    expanded = alpha.filter(ImageFilter.MaxFilter(2 * width + 1))
    ring = ImageChops.subtract(expanded, alpha)
    ring = ring.point(lambda v: 255 if v > 0 else 0)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(color + (255,), (0, 0), ring)
    return Image.alpha_composite(out, im)

def nearest_palette(rgb, include):
    best, bd = None, 1e9
    for name in include:
        c = PALETTE[name]
        d = (c[0]-rgb[0])**2 + (c[1]-rgb[1])**2 + (c[2]-rgb[2])**2
        if d < bd:
            bd, best = d, c
    return best

def quantize_palette(im, include):
    im = im.convert("RGB")
    px = im.load()
    w, h = im.size
    out = Image.new("RGB", im.size)
    opx = out.load()
    for y in range(h):
        for x in range(w):
            opx[x, y] = nearest_palette(px[x, y], include)
    return out

def fit(im, w, h, bg=(0, 0, 0, 0)):
    im = im.convert("RGBA")
    im.thumbnail((w, h), Image.LANCZOS)
    canvas = Image.new("RGBA", (w, h), bg)
    canvas.paste(im, ((w - im.size[0]) // 2, (h - im.size[1]) // 2), im)
    return canvas

def save_webp(im, path, quality=82):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, "WEBP", quality=quality, method=6)
    return os.path.getsize(path)

def load(name):
    p = os.path.join(RAW, name)
    if not os.path.exists(p):
        print(f"MISSING {name}")
        return None
    return Image.open(p).convert("RGB")

report = []

def main():
    # 1. Backdrop
    im = load("backdrop.jpg")
    if im:
        im = quantize_palette(im, ("PITCH", "LINES", "KIT_RED", "KIT_BLUE", "GOLD", "STANDS", "STANDS_DK", "SKIN", "WHITE", "BLACK"))
        im = im.resize((1024, 576), Image.LANCZOS)
        report.append(("stadium-backdrop.webp", "1024x576", save_webp(im, os.path.join(OUT, "stadium-backdrop.webp"))))

    # 2. Keeper sheet: 4 poses -> 2x2 512x512
    poses = ["rest", "lean-left", "lean-right", "dive"]
    frames = []
    for pose in poses:
        im = load(f"keeper-{pose}.jpg")
        if im is None:
            continue
        im = key_bg(im)
        im = tint_silhouette(im, PALETTE["STANDS"])
        im = add_outline(im, PALETTE["STANDS_DK"], 4)
        im = fit(im, 256, 256)
        frames.append(im)
    if len(frames) == 4:
        sheet = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        for i, fr in enumerate(frames):
            sheet.paste(fr, ((i % 2) * 256, (i // 2) * 256), fr)
        report.append(("keeper-sheet.webp", "512x512 (2x2)", save_webp(sheet, os.path.join(OUT, "keeper-sheet.webp"))))
        for i, fr in enumerate(frames):
            save_webp(fr, os.path.join(OUT, f"keeper-{poses[i]}.webp"))
    else:
        print("keeper frames missing:", len(frames))

    # 3. Wall defenders
    for name, outn in [("wall-defender.jpg", "wall-defender.webp"),
                       ("wall-defender-2.jpg", "wall-defender-2.webp")]:
        im = load(name)
        if im is None:
            continue
        im = key_bg(im)
        im = tint_silhouette(im, PALETTE["STANDS"])
        im = add_outline(im, PALETTE["STANDS_DK"], 4)
        im = fit(im, 256, 256)
        report.append((outn, "256x256", save_webp(im, os.path.join(OUT, outn))))

    # 4. Ball: bright ball on dark bg -> key bg, quantize, KEEP alpha
    im = load("ball.jpg")
    if im:
        keyed = key_bg(im, dark_bg=True)
        alpha = keyed.split()[3]
        rgb = quantize_palette(keyed, ("WHITE", "BLACK", "GOLD", "STANDS_DK"))
        rgb.putalpha(alpha)
        rgb = fit(rgb, 128, 128)
        report.append(("ball.webp", "128x128", save_webp(rgb, os.path.join(OUT, "ball.webp"))))

    # 5. Crowd strip
    im = load("crowd-strip.jpg")
    if im:
        im = quantize_palette(im, ("PITCH", "LINES", "KIT_RED", "KIT_BLUE", "GOLD", "STANDS", "STANDS_DK", "SKIN", "WHITE", "BLACK"))
        im = im.resize((1024, 256), Image.LANCZOS)
        report.append(("crowd-strip.webp", "1024x256", save_webp(im, os.path.join(OUT, "crowd-strip.webp"))))

    # 6. Goal net: net on dark bg -> key bg, alpha
    im = load("goal-net.jpg")
    if im:
        keyed = key_bg(im, dark_bg=True)
        keyed = fit(keyed, 512, 512)
        report.append(("goal-net.webp", "512x512", save_webp(keyed, os.path.join(OUT, "goal-net.webp"))))

    # 7. Celebration
    im = load("celebration.jpg")
    if im:
        im = quantize_palette(im, ("PITCH", "LINES", "KIT_RED", "KIT_BLUE", "GOLD", "STANDS", "STANDS_DK", "SKIN", "WHITE", "BLACK"))
        im = im.resize((1024, 576), Image.LANCZOS)
        report.append(("celebration.webp", "1024x576", save_webp(im, os.path.join(OUT, "celebration.webp"))))

    print("--- normalize report ---")
    total = 0
    for name, dims, sz in report:
        total += sz
        print(f"{name}: {dims}  {sz/1024:.1f} KB")
    print(f"TOTAL hero: {total/1024:.1f} KB")

if __name__ == "__main__":
    main()

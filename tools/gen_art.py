#!/usr/bin/env python3
"""SPOT THE LIE — AI base painting generator (pollinations.ai, keyless).
LEGAL PIN: AI-generated scenes ONLY — zero licensed/stock photos in the pipeline.
Flat-noir style-lock prompt family; fixed seeds per painting (deterministic
regeneration). Output: /tmp/stl-raw/<id>.jpg
"""
import os
import sys
import time
import urllib.request

RAW = "/tmp/stl-raw"
os.makedirs(RAW, exist_ok=True)

STYLE = ("flat%20noir%20vector%20illustration%2C%20many%20distinct%20objects%2C"
         "%20muted%20desaturated%20blue-grey%20palette%20with%20one%20warm%20accent%2C"
         "%20clean%20flat%20shapes%2C%20minimal%20shading%2C%20children%27s%20book%20style%2C"
         "%20rich%20detailed%20scene%2C%20no%20text")

SCENES = [
    # (id, theme words)
    ("room-study",    "cozy%20study%20room%2C%20desk%2C%20bookshelves%2C%20lamps%2C%20papers%2C%20clock"),
    ("room-kitchen",  "old%20kitchen%2C%20pots%2C%20jars%2C%20stove%2C%20shelves%2C%20hanging%20utensils"),
    ("room-attic",    "cluttered%20attic%20workshop%2C%20crates%2C%20ropes%2C%20lanterns%2C%20tools%2C%20barrels%2C%20skylight"),
    ("room-bedroom",  "vintage%20bedroom%2C%20dresser%2C%20mirror%2C%20frames%2C%20toys%2C%20curtains"),
    ("market-street", "busy%20street%20market%2C%20fruit%20stalls%2C%20baskets%2C%20awnings%2C%20crates"),
    ("market-fish",   "harbor%20fish%20market%2C%20barrels%2C%20crates%2C%20nets%2C%20boats%2C%20lanterns"),
    ("market-spice",  "spice%20bazaar%2C%20sacks%2C%20jars%2C%20scales%2C%20rugs%2C%20hanging%20goods"),
    ("street-corner", "rainy%20city%20corner%2C%20lamppost%2C%20bench%2C%20signs%2C%20mailbox%2C%20cats%2C%20windows"),
    ("street-alley",  "narrow%20alley%2C%20fire%20escapes%2C%20pipes%2C%20bins%2C%20posters%20without%20words%2C%20boxes"),
    ("street-station","small%20train%20station%20platform%2C%20benches%2C%20clock%2C%20luggage%2C%20signals"),
    ("space-station", "retro%20space%20station%20interior%2C%20consoles%2C%20levers%2C%20portholes%2C%20plants%2C%20screens%20without%20text"),
    ("space-lab",     "moon%20laboratory%2C%20tanks%2C%20tubes%2C%20robots%2C%20panels%2C%20tools%2C%20specimens"),
]


def main():
    only = sys.argv[1:] if len(sys.argv) > 1 else None
    for i, (sid, scene) in enumerate(SCENES):
        if only and sid not in only:
            continue
        out = os.path.join(RAW, f"{sid}.jpg")
        if os.path.exists(out) and os.path.getsize(out) > 20000:
            print(f"[skip] {sid}")
            continue
        url = (f"https://image.pollinations.ai/prompt/{scene}%2C{STYLE}"
               f"?width=768&height=864&seed={1000 + i * 37}&nologo=true")
        for attempt in range(3):
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=90) as r:
                    data = r.read()
                if len(data) < 20000:
                    raise ValueError(f"too small: {len(data)}")
                with open(out, "wb") as f:
                    f.write(data)
                print(f"[ok] {sid} {len(data)} bytes")
                break
            except Exception as e:
                print(f"[retry {attempt+1}] {sid}: {e}")
                time.sleep(4)
        time.sleep(1.5)


if __name__ == "__main__":
    main()

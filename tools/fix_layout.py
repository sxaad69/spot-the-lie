#!/usr/bin/env python3
"""Rewrite scenes/main.tscn with absolute-rect positioning (no anchors system):
every Control gets layout_mode=0 + explicit offset_* rect. Deterministic, simple,
and immune to container-layout quirks in headless/web exports.
"""
import re

P = '/opt/games/spot-the-lie/scenes/main.tscn'
s = open(P).read()

# 1. strip every anchors_*/layout_mode line from Control node blocks
lines = s.split('\n')
out = []
block = []


def flush(block):
    body = [l for l in block if not re.match(r'(layout_mode|anchors_preset|anchor_\w+) *=', l)]
    out.extend(body)


for ln in lines:
    if ln.startswith('[') and block:
        flush(block)
        block = [ln]
    else:
        block.append(ln)
flush(block)
s = '\n'.join(out)

# 2. per-node explicit rects (game is 1280x720)
RECTS = {
    '"Background"': (0, 0, 1280, 720),
    '"Title"': (20, 8, 1260, 44),
    '"Hud"': (20, 648, 1260, 684),
    '"Actions"': (240, 690, 1040, 722),
    '"Banner"': (340, 250, 940, 360),
    '"Menu"': (0, 0, 1280, 720),
    '"Center"': (0, 0, 1280, 720),
}

lines = s.split('\n')
out = []
cur_name = None


def emit(block, name):
    if name in RECTS and not any(l.startswith('offset_left') for l in block):
        x1, y1, x2, y2 = RECTS[name]
        block.append(f'layout_mode = 0')
        block.append(f'offset_left = {x1}.0')
        block.append(f'offset_top = {y1}.0')
        block.append(f'offset_right = {x2}.0')
        block.append(f'offset_bottom = {y2}.0')
    out.extend(block)


for ln in lines:
    m = re.match(r'\[node name="([^"]+)"', ln)
    if m:
        if cur_name is not None:
            pass
        # flush previous block lazily below
    # collect blocks first
blocks = []
block = []
for ln in lines:
    if ln.startswith('[node'):
        if block:
            blocks.append(block)
        block = [ln]
    else:
        block.append(ln)
if block:
    blocks.append(block)

out_blocks = []
for b in blocks:
    m = re.match(r'\[node name="([^"]+)"', b[0])
    name = m.group(1) if m else None
    if name in RECTS and not any(l.startswith('layout_mode') for l in b):
        x1, y1, x2, y2 = RECTS[name]
        b = b + ['layout_mode = 0',
                 f'offset_left = {float(x1)}',
                 f'offset_top = {float(y1)}',
                 f'offset_right = {float(x2)}',
                 f'offset_bottom = {float(y2)}']
    out_blocks.append('\n'.join(b))

open(P, 'w').write('\n'.join(out_blocks) + '\n')
print('rewritten; blocks:', len(blocks))

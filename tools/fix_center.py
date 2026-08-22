#!/usr/bin/env python3
"""Fix Board node: it's Node2D but its parent Main is a Control — reparent
Board as child of root Window? Simpler: make Main draw the board itself.
Change: Board stays Node2D but we ensure z-order and that Menu (Control)
is drawn above. The real issue may be that Menu was invisible because
Main Control had zero size => children with layout_mode=0 absolute rects
should still render... Actually Control with size 0 still renders children.
The screenshot shows board panels WITHOUT shapes -> Board._draw ran
(setup called) but scene empty? probe said scene_size=14 after press.
Wait: boot shot showed empty panels = Board._draw drew panel bg only,
i.e. setup() never ran at boot (menu visible=true, no board). That's fine!
Menu should cover it though. Menu rect set to full screen with layout_mode=0...
but Center inside Menu kept old anchors? fix_layout stripped anchors from ALL
nodes including containers' children, leaving them at default position (0,0)
with size 0 => PanelContainer collapsed => nothing visible.
"""
import re

P = '/opt/games/spot-the-lie/scenes/main.tscn'
s = open(P).read()
# give Center back full-rect via offsets (it's a CenterContainer under Menu which is full-screen)
if '[node name="Center" type="CenterContainer" parent="Menu"]' in s:
    s = s.replace('[node name="Center" type="CenterContainer" parent="Menu"]',
        '[node name="Center" type="CenterContainer" parent="Menu"]\n'
        'layout_mode = 0\noffset_left = 0.0\noffset_top = 0.0\n'
        'offset_right = 1280.0\noffset_bottom = 720.0')
open(P, 'w').write(s)
print('center fixed')

"""P5-26 missing models: trap_tripwire_sprung, prop_scarecrow_field, prop_window_glow. Blender-built, no outside source (D-151).

  sh tools/blender/run.sh tools/blender/build_p5_26.py [-- name ...]

Conventions as build_p5_15.py / build_p5_12.py: 1 unit = 1 m, Blender FRONT +Y (Godot -Z), origin at the base, vertex colour
"Col", mat_flat_lit except the window pane (mat_emissive_warm, doc 07 s7). trap_tripwire (set), tool_hoe, tool_whistle, the clue
decals, prop_road_lamp and animal_crow (idle = perched) already exist and are not rebuilt.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_phase4 as B  # noqa: E402
from build_phase4 import BRASS, IRON, MAT_WARM, WOOD2, Part  # noqa: E402

STRAW, SACK, CLOTH, CLOTH2, PATCH = "#B8A25A", "#B59F78", "#5E5240", "#463D2F", "#7A5A3A"


def tripwire_sprung():
    # Same footprint as trap_tripwire (posts 2.9 m apart along Y, 0.8 m high). The cord is snapped: one end still on the
    # -Y ring and hanging to the ground, the other trailing from the +Y ring; the bells lie in the dirt.
    p = Part("Posts")
    for y in (-1.45, 1.45):
        p.between((0, y, 0), (0, y, 0.8), 0.04, 0.032, WOOD2, seg=6)
        p.cyl(0.08, 0.08, 0.03, (0, y, 0.015), "#46321F", seg=6)
        p.cyl(0.044, 0.044, 0.02, (0, y, 0.36), IRON, seg=6)
    p.done()
    w = Part("Wire", (0, 0, 0.36))
    cord = "#8A7448"
    w.between((0, -1.45, 0.36), (0.05, -0.9, 0.12), 0.008, 0.008, cord, seg=3)  # slack run to the ground
    w.between((0.05, -0.9, 0.12), (0.2, -0.45, 0.012), 0.008, 0.008, cord, seg=3)
    w.between((0, 1.45, 0.36), (-0.04, 1.1, 0.2), 0.008, 0.008, cord, seg=3)  # short stub dangling
    w.between((-0.04, 1.1, 0.2), (-0.12, 0.8, 0.012), 0.008, 0.008, cord, seg=3)
    w.done()
    b = Part("Bells", (0, 0.4, 0.0))
    for k, (y, x, r) in enumerate(((0.3, -0.06, 1.2), (0.45, 0.07, 1.7), (0.6, -0.02, 0.6))):
        b.cyl(0.012, 0.03, 0.045, (x, y, 0.028), BRASS, rot=(math.pi / 2 + 0.2, 0, r), seg=6)  # on its side
        b.ball((0.008, 0.008, 0.008), (x + 0.03, y, 0.012), IRON, seg=4, rings=3)
    b.done()


def scarecrow_field():
    # 0.8 x 0.8 x 2: the farm's start scarecrow (doc 04 s7). Weathered, plain, no face to speak of: faded brown coat on a
    # cross pole, sack head with two stitched X eyes, battered hat, one arm sagging. Reads as a scarecrow at 30 m, which
    # is the point (doc 01 "The scarecrow moved"); the player scarecrow is the blue smiling one.
    p = Part("Scarecrow")
    p.between((0, 0, 0), (0, 0, 1.95), 0.05, 0.04, WOOD2, seg=6)
    p.cyl(0.13, 0.13, 0.04, (0, 0, 0.02), WOOD2, seg=6)
    p.between((-0.36, 0, 1.45), (0.36, 0, 1.45), 0.035, 0.035, WOOD2, seg=6)
    p.cyl(0.24, 0.15, 0.66, (0, 0, 1.12), CLOTH, seg=8)  # coat
    p.cyl(0.25, 0.24, 0.05, (0, 0, 0.8), CLOTH2, seg=8)
    for i in range(7):  # ragged hem
        a = i * math.tau / 7 + 0.3
        p.box((0.07, 0.02, 0.12 + 0.04 * (i % 3)), (0.245 * math.cos(a), 0.245 * math.sin(a), 0.74), CLOTH2, rot=(0, 0, a + math.pi / 2))
    p.box((0.16, 0.02, 0.14), (-0.08, 0.2, 1.2), PATCH)
    p.between((-0.15, 0, 1.45), (-0.34, 0, 1.45), 0.07, 0.06, CLOTH, seg=6)  # left sleeve along the crossbar
    p.between((0.15, 0, 1.45), (0.3, 0, 1.45), 0.07, 0.06, CLOTH, seg=6)  # right sleeve sagging
    p.between((0.3, 0, 1.45), (0.36, 0.0, 1.22), 0.06, 0.05, CLOTH, seg=6)
    for k in range(4):  # straw cuffs
        p.between((-0.34, 0, 1.45), (-0.43, 0.05 * (k - 1.5), 1.4 - 0.03 * k), 0.012, 0.004, STRAW, seg=3)
        p.between((0.36, 0, 1.22), (0.38 + 0.01 * k, 0.04 * (k - 1.5), 1.1), 0.012, 0.004, STRAW, seg=3)
    p.ball((0.17, 0.17, 0.2), (0, 0, 1.72), SACK, seg=10, rings=6)  # sack head
    p.ball((0.05, 0.05, 0.04), (0, 0, 1.94), "#9A8660", seg=5, rings=3)
    for sx in (-1, 1):  # stitched X eyes
        for r in (math.pi / 4, -math.pi / 4):
            p.box((0.055, 0.012, 0.012), (sx * 0.07, 0.165, 1.76), "#2A2018", rot=(0, r, 0))
    p.box((0.1, 0.012, 0.012), (0, 0.165, 1.66), "#2A2018")  # stitched mouth line
    p.cyl(0.36, 0.26, 0.03, (0, 0, 1.89), "#4E4636", seg=10)  # hat brim, drooped
    p.cyl(0.17, 0.13, 0.16, (0, 0, 1.98), "#4E4636", seg=8)
    p.cyl(0.175, 0.17, 0.03, (0, 0, 1.91), "#7A5A3A", seg=8)
    for i in range(5):  # straw from the collar
        p.between((0, 0.1, 1.56), ((i - 2) * 0.05, 0.16, 1.5), 0.01, 0.003, STRAW, seg=3)
    p.done()


def window_glow():
    # 1 x 0.05 x 1 (doc 07 s11): a warm emissive pane, not a light. Origin at the pane centre; the mullions stand proud of both faces, so
    # the card reads the same from either side. Scale to the window; the dark mullions are a separate flat surface so the card is not a blank square.
    g = Part("Glow")
    g.box((0.94, 0.02, 0.94), (0, 0, 0), "#FFB45A", mat=MAT_WARM)
    g.done()
    m = Part("Mullion")
    m.box((0.05, 0.04, 0.94), (0, 0, 0), "#2A2D2F")
    m.box((0.94, 0.04, 0.05), (0, 0, 0), "#2A2D2F")
    m.done()


MODELS = [
    ("trap_tripwire_sprung", tripwire_sprung, "mid"),
    ("prop_scarecrow_field", scarecrow_field, "large"),
    ("prop_window_glow", window_glow, "small"),
]

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for nm, fn, cls in MODELS:
        if not only or nm in only:
            B.build(nm, fn, cls)

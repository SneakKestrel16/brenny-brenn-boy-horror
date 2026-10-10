"""P5-15 missing models (D-151, D-159): traps, pegboard, hoe, shovel, fuel can, whistle. Blender-built, no outside source.

  sh tools/blender/run.sh tools/blender/build_p5_15.py [-- name ...]

Same conventions as build_p5_12.py (helpers reused): 1 unit = 1 m, model FRONT is +Y in Blender (glTF/Godot -Z), origin at the
base, flat colour in vertex colour layer "Col", material mat_flat_lit only (nothing here glows, doc 07 s3).
Bear trap jaws are their own nodes (JawL, JawR) pivoted on the hinge pins; open and closed share the same parts, only the jaw
angle differs, so game code can swap the model or rotate the jaws (about the local Z axis in Godot: JawR +125 deg, JawL -125 deg).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_phase4 as B  # noqa: E402
from build_phase4 import BRASS, IRON, WOOD, WOOD2, Part, empty  # noqa: E402
from build_p5_12 import arc, tube  # noqa: E402

STEEL, STEEL2, RUST, DIRT, DIRT2, DIRT3 = "#6B6F72", "#55595C", "#8A5A3A", "#5A4129", "#6E4D33", "#46321F"
STALK, STALK2, DRYLEAF, PAINT = "#B09A4E", "#8A7A3A", "#9A9A55", "#E8DCC0"
JAW_CLOSED = math.radians(125)  # jaw rotation from flat-open to meeting over the pan (checked: tips meet at x 0)
HX, HZ, JU, JV = 0.1, 0.04, 0.18, 0.2  # hinge x, hinge height, jaw reach outward, jaw half-length along Y


# ---------------------------------------------------------------- bear trap
def jaw_pt(s, u, v, a):
    """A point of the jaw at reach u (outward from the hinge) and along-hinge v, with the jaw rotated a radians up and over."""
    return (s * (HX + u * math.cos(a)), v, HZ + u * math.sin(a))


def bear(state):
    a = JAW_CLOSED if state != "open" else 0.0
    base = Part("Base")
    base.box((0.26, 0.42, 0.03), (0, 0, 0.015), STEEL2)  # plate
    base.box((0.04, 0.42, 0.06), (-HX, 0, 0.03), STEEL2)  # hinge blocks under the pins
    base.box((0.04, 0.42, 0.06), (HX, 0, 0.03), STEEL2)
    for s in (-1, 1):
        base.cyl(0.012, 0.012, 0.46, (s * HX, 0, HZ), IRON, rot=(math.pi / 2, 0, 0), seg=6)  # hinge pins
        arc(base, (s * 0.07, 0, 0.03), 0.17, 0.35, math.pi - 0.35, 4, STEEL, plane="yz", rad=0.011, seg=3)  # leaf spring, bowed up
    for k in range(3):  # chain from the back of the plate to a stake ring
        base.box((0.03, 0.02, 0.012), (0, -0.25 - k * 0.025, 0.01), IRON, rot=(0, 0, 0.0 if k % 2 else 0.3))
    tube(base, 0.05, 0.03, 0.012, (0, -0.34, 0.008), IRON, seg=8)  # stake ring, so the open trap is about 0.6 deep
    if state == "item":  # carried: a rope sling over the closed jaws
        arc(base, (0, 0, 0.19), 0.1, 0.0, math.pi, 6, "#8A7448", plane="xz", rad=0.012, seg=3)
    base.done()
    pan = Part("Pan", (0, 0, 0.03))
    pan.cyl(0.07, 0.07, 0.03 if state == "open" else 0.012, (0, 0, 0.045 if state == "open" else 0.036), RUST, seg=8)
    pan.done()
    for s, nm in ((-1, "JawL"), (1, "JawR")):
        j = Part(nm, (s * HX, 0, HZ))
        pts = [jaw_pt(s, 0, -JV, a)] + [jaw_pt(s, JU * math.cos(t), JV * math.sin(t), a)
                                        for t in [math.radians(x) for x in range(-90, 91, 30)]]
        j.between(jaw_pt(s, 0, -JV, a), jaw_pt(s, 0, JV, a), 0.013, 0.013, STEEL, seg=4)  # hinge bar
        for p0, p1 in zip(pts[1:], pts[2:]):
            j.between(p0, p1, 0.012, 0.012, STEEL, seg=4)
        for t in range(-60, 61, 30):  # teeth point in towards the middle of the D, in the jaw plane
            tr = math.radians(t)
            j.between(jaw_pt(s, JU * math.cos(tr), JV * math.sin(tr), a), jaw_pt(s, JU * 0.55 * math.cos(tr), JV * 0.55 * math.sin(tr), a),
                      0.011, 0.002, STEEL2, seg=3)
        j.done()


# ---------------------------------------------------------------- pit
def pit_cover():
    # 1.5 x 1.5 x 0.1: loose stalks and dirt laid over the hole (a clue only when you look: dirt a shade too fresh)
    p = Part("PitCover")
    p.cyl(0.74, 0.76, 0.04, (0, 0, 0.02), DIRT2, seg=10)  # dirt skin
    p.ball((0.4, 0.3, 0.03), (0.15, -0.1, 0.05), DIRT, seg=6, rings=3)  # fresher patch
    p.ball((0.25, 0.2, 0.025), (-0.35, 0.3, 0.05), DIRT3, seg=6, rings=3)
    for i in range(8):  # stalks laid across, slightly different angles and heights
        a = i * 0.4 - 1.3
        p.between((-0.7 * math.cos(a) - 0.08 * i + 0.3, -0.7 * math.sin(a) * 0.5, 0.05 + 0.006 * (i % 3)),
                  (0.7 * math.cos(a) - 0.08 * i + 0.3, 0.7 * math.sin(a) * 0.5, 0.06 + 0.006 * (i % 2)), 0.016, 0.012,
                  STALK if i % 2 else STALK2, seg=4)
    for i in range(5):  # leaves
        p.box((0.28, 0.07, 0.008), (-0.4 + 0.2 * i, -0.4 + 0.18 * (i % 3), 0.07), DRYLEAF, rot=(0, 0.1, 0.5 + i))
    p.done()


def pit_open():
    # 1.5 wide x 1.5 deep: a square shaft below the ground plane (z < 0), a raised dirt lip at ground level.
    # The walls are boxes so the inside faces are real faces (no back-face culling trouble).
    p = Part("Pit")
    for sx in (-1, 1):
        p.box((0.1, 1.1, 1.5), (sx * 0.5, 0, -0.75), DIRT2)
        p.box((1.1, 0.1, 1.5), (0, sx * 0.5, -0.75), DIRT)
    p.box((1.1, 1.1, 0.06), (0, 0, -1.47), DIRT3)  # floor
    for sx in (-1, 1):  # lip: four ragged mounds, 0.12 high, out to 1.5 overall
        p.box((0.28, 1.5, 0.12), (sx * 0.61, 0, 0.06), DIRT2, rot=(0, 0, sx * 0.04))
        p.box((0.94, 0.28, 0.12), (0, sx * 0.61, 0.06), DIRT, rot=(0, 0, sx * 0.03))
    for i in range(6):  # roots and a snapped stalk poking from the wall
        a = i * 1.05
        p.between((0.54 * math.cos(a), 0.54 * math.sin(a), -0.3 - 0.12 * i), (0.4 * math.cos(a), 0.4 * math.sin(a), -0.36 - 0.12 * i),
                  0.014, 0.006, STALK2 if i % 2 else "#4A3322", seg=3)
    p.done()
    m = Part("Mouth")  # dark soil disc across the opening at ground level, so the hole reads from above (like TrapArt.pit's disc)
    m.cyl(0.52, 0.52, 0.01, (0, 0, 0.01), "#14100E", seg=12)
    m.done()


# ---------------------------------------------------------------- tripwire, dirt decal, bent stalks, glint
def tripwire():
    # 0.1 x 3 x 0.8: two posts 3 m apart along Y with a taut cord at ankle height and a cluster of brass bells
    p = Part("Posts")
    for y in (-1.45, 1.45):
        p.between((0, y, 0), (0, y, 0.8), 0.04, 0.032, WOOD2, seg=6)
        p.cyl(0.08, 0.08, 0.03, (0, y, 0.015), "#46321F", seg=6)  # packed dirt at the foot
        p.cyl(0.044, 0.044, 0.02, (0, y, 0.36), IRON, seg=6)  # cord ring
    p.done()
    w = Part("Wire", (0, 0, 0.36))
    w.between((0, -1.45, 0.36), (0, 1.45, 0.36), 0.008, 0.008, "#8A7448", seg=3)
    w.done()
    b = Part("Bells", (0, 0.4, 0.36))
    for k, y in enumerate((0.3, 0.45, 0.6)):
        b.between((0, y, 0.36), (0, y, 0.33), 0.004, 0.004, IRON, seg=3)
        b.cyl(0.012, 0.03, 0.045, (0, y, 0.305), BRASS, seg=6)
        b.ball((0.008, 0.008, 0.008), (0, y, 0.28), IRON, seg=4, rings=3)
    b.done()


def dirt_decal():
    # 1 x 1 x 0.02 fresh turned earth: low irregular mound, darker clods
    p = Part("Dirt")
    p.cyl(0.5, 0.46, 0.02, (0, 0, 0.01), DIRT3, seg=10)
    for i in range(7):
        a = i * 0.9
        p.ball((0.14, 0.11, 0.012), (0.27 * math.cos(a), 0.27 * math.sin(a), 0.016), DIRT if i % 2 else DIRT2, rot=(0, 0, a), seg=5, rings=3)
    p.ball((0.2, 0.17, 0.014), (0.0, 0.0, 0.016), DIRT, seg=6, rings=3)
    p.done()


def bent_stalks():
    # 1.5 x 1 x 2.4: a cluster of corn stalks, three snapped and bent over the path (the trail a creature or a trapper leaves)
    p = Part("Stalks")
    spots = [(-0.6, 0.2, 0), (-0.35, -0.3, 0), (-0.05, 0.3, 1), (0.25, -0.2, 1), (0.5, 0.25, 0), (0.6, -0.15, 1), (0.1, 0.0, 2)]
    for i, (x, y, bend) in enumerate(spots):
        top = 2.4 - 0.15 * (i % 3)
        if bend == 0:  # upright
            pts = [(x, y, 0), (x + 0.02, y, top * 0.5), (x + 0.04, y, top)]
        else:  # snapped at 1.3 m and folded towards the path
            d = -1 if i % 2 else 1
            pts = [(x, y, 0), (x + 0.02, y, 1.3), (x + d * 0.25, y + 0.05, 1.7), (x + d * 0.4, y + 0.08, 1.35)]
        for p0, p1 in zip(pts, pts[1:]):
            p.between(p0, p1, 0.022, 0.018, STALK2 if i % 2 else STALK, seg=4)
        for k, z in enumerate((0.6, 1.0)):  # leaf blades off the lower stalk
            s = 1 if (i + k) % 2 else -1
            p.box((0.3, 0.06, 0.01), (x + s * 0.15, y, z + 0.15), DRYLEAF if k else STALK, rot=(0, -s * 0.5, 0))
        if bend == 0:
            p.ball((0.03, 0.03, 0.09), (x + 0.07, y, top * 0.62), STALK2, seg=5, rings=4)  # an ear
    p.done()


def glint():
    # a metal glint card, 0.2 across: a four-point star of thin pale steel standing on its edge. Not emissive (nothing glows, doc 07 s3).
    p = Part("Glint")
    p.box((0.2, 0.004, 0.02), (0, 0, 0.1), "#D2D8DC")
    p.box((0.02, 0.004, 0.2), (0, 0, 0.1), "#D2D8DC")
    p.box((0.12, 0.004, 0.02), (0, 0, 0.1), "#EEF2F4", rot=(0, math.pi / 4, 0))
    p.box((0.12, 0.004, 0.02), (0, 0, 0.1), "#EEF2F4", rot=(0, -math.pi / 4, 0))
    p.done()


# ---------------------------------------------------------------- pegboard
N_SLOTS = 5  # data/season.json pegboard_bear_slots (doc 02 A.1)
SLOT_PITCH = 0.32


def pegboard():
    # 1.6 x 0.1 x 1.2, back plane on y 0, origin at the bottom centre. Front +Y. Painted outlines: shovel, hoe, 5 bear traps.
    p = Part("Board")
    p.box((1.6, 0.04, 1.2), (0, 0.02, 0.6), "#8A7448")  # panel
    for z in (0.03, 1.17):
        p.box((1.6, 0.06, 0.06), (0, 0.03, z), WOOD2)  # frame top and bottom
    for x in (-0.77, 0.77):
        p.box((0.06, 0.06, 1.2), (x, 0.03, 0.6), WOOD2)
    for i in range(7):  # sparse peg holes, 4 rows
        for j in range(3):
            p.box((0.02, 0.004, 0.02), (-0.6 + i * 0.2, 0.041, 0.62 + j * 0.2 + (0.1 if i % 2 else 0)), "#2A2018")
    p.done()
    o = Part("Outlines")  # painted white-ish, 2 mm proud
    for i in range(N_SLOTS):  # bear trap outline: a 0.3 ring and the two springs
        x = (i - (N_SLOTS - 1) / 2) * SLOT_PITCH
        tube(o, 0.095, 0.083, 0.004, (x, 0.042, 0.3), PAINT, rot=(math.pi / 2, 0, 0), seg=10)
        o.box((0.02, 0.004, 0.1), (x, 0.042, 0.3), PAINT)
    for x in (-0.35, 0.35):  # head-only outlines (the tools hang by the head, handle below the board): hoe left, shovel right
        o.box((0.012, 0.004, 0.3), (x, 0.042, 0.99), PAINT)
        o.box((0.12 if x < 0 else 0.1, 0.004, 0.012), (x, 0.042, 1.12), PAINT)
        o.box((0.012, 0.004, 0.1), (x - (0.05 if x < 0 else 0.0), 0.042, 1.07), PAINT)
        o.box((0.1, 0.004, 0.012), (x, 0.042, 0.84), PAINT)
    o.done()
    pg = Part("Pegs")
    for i in range(N_SLOTS):
        x = (i - (N_SLOTS - 1) / 2) * SLOT_PITCH
        pg.between((x, 0.04, 0.43), (x, 0.09, 0.43), 0.01, 0.01, IRON, seg=4)
        pg.between((x, 0.09, 0.43), (x, 0.09, 0.455), 0.01, 0.01, IRON, seg=4)  # up-turn so the trap stays on
    for x in (-0.35, 0.35):  # two pegs per long tool, at 0.8 and 0.5 m
        for z in (0.5, 0.9):
            pg.between((x - 0.07, 0.04, z), (x - 0.07, 0.095, z), 0.011, 0.011, IRON, seg=4)
            pg.between((x + 0.07, 0.04, z), (x + 0.07, 0.095, z), 0.011, 0.011, IRON, seg=4)
    pg.done()
    for i in range(N_SLOTS):  # a hung bear trap sits flat on the board: its centre is this node, local -Z of the game node faces out
        empty("Hook%d" % (i + 1), ((i - (N_SLOTS - 1) / 2) * SLOT_PITCH, 0.05, 0.3))
    empty("HoeHook", (-0.35, 0.05, 0.7))
    empty("ShovelHook", (0.35, 0.05, 0.7))


# ---------------------------------------------------------------- tools
def hoe():
    # 0.15 x 0.05 x 1.4, standing on the handle foot: ash handle, iron ferrule, bent neck, flat blade pulled towards +Y
    p = Part("Hoe")
    p.between((0, 0, 0), (0, 0, 1.27), 0.02, 0.017, WOOD, seg=6)
    p.cyl(0.021, 0.021, 0.015, (0, 0, 0.01), "#46321F", seg=6)  # worn foot
    p.cyl(0.026, 0.026, 0.08, (0, 0, 1.3), IRON, seg=6)  # ferrule
    p.between((0, 0, 1.33), (0, 0.012, 1.37), 0.012, 0.01, IRON, seg=4)  # neck
    p.box((0.15, 0.006, 0.12), (0, 0.022, 1.32), STEEL, rot=(-0.3, 0, 0))  # blade
    p.box((0.15, 0.008, 0.02), (0, 0.03, 1.265), STEEL2, rot=(-0.3, 0, 0))  # sharp edge
    p.box((0.04, 0.016, 0.03), (0, 0.016, 1.378), IRON)  # blade tang
    p.done()


def shovel():
    # 0.2 x 0.05 x 1.3, standing on the blade tip: spade, socket, wooden shaft, D handle
    p = Part("Shovel")
    p.box((0.18, 0.008, 0.07), (0, 0.006, 0.16), STEEL, rot=(0.05, 0, 0))
    p.box((0.2, 0.01, 0.1), (0, 0.004, 0.09), STEEL, rot=(0.0, 0, 0))
    p.box((0.13, 0.01, 0.06), (0, 0.004, 0.022), STEEL, rot=(0, 0, 0))
    p.box((0.07, 0.01, 0.03), (0, 0.004, 0.005), STEEL2)  # tip
    p.cyl(0.028, 0.02, 0.1, (0, 0.006, 0.3), IRON, seg=6)  # socket
    p.between((0, 0.006, 0.32), (0, 0.006, 1.18), 0.021, 0.018, WOOD, seg=6)  # shaft
    p.between((-0.07, 0.006, 1.16), (0.07, 0.006, 1.16), 0.017, 0.017, WOOD2, seg=5)  # D grip, crossbar
    for s in (-1, 1):
        p.between((s * 0.07, 0.006, 1.16), (s * 0.07, 0.006, 1.3), 0.017, 0.017, WOOD2, seg=5)
    p.between((-0.07, 0.006, 1.3), (0.07, 0.006, 1.3), 0.017, 0.017, WOOD2, seg=5)
    p.cyl(0.026, 0.026, 0.03, (0, 0.006, 1.16), IRON, seg=6)  # collar
    p.done()


def fuel_can():
    # 0.3 x 0.15 x 0.35 jerry can: pressed red body, three-bar handle, offset spout with cap, X embossing
    RED, RED2 = "#A83A22", "#8A2E1A"
    p = Part("FuelCan")
    p.box((0.3, 0.15, 0.3), (0, 0, 0.15), RED)
    p.box((0.304, 0.154, 0.02), (0, 0, 0.01), RED2)  # base lip
    p.box((0.304, 0.154, 0.02), (0, 0, 0.29), RED2)  # shoulder
    for sy in (-1, 1):  # raised X on each broad side
        for sg in (-1, 1):
            p.box((0.012, 0.004, 0.3), (0, sy * 0.076, 0.15), RED2, rot=(0, sg * 0.75, 0))
    p.box((0.304, 0.154, 0.012), (0, 0, 0.15), RED2)  # waist rib
    for x in (-0.08, 0.08):  # handle posts and bar
        p.box((0.025, 0.04, 0.05), (-0.05 if x < 0 else 0.05, 0, 0.325), RED2)
    p.box((0.18, 0.04, 0.025), (0, 0, 0.345), RED2)
    p.cyl(0.026, 0.026, 0.05, (-0.1, 0, 0.325), RED, seg=8)  # spout neck
    p.cyl(0.032, 0.032, 0.02, (-0.1, 0, 0.345), "#C9A02A", seg=8)  # cap
    p.cyl(0.012, 0.012, 0.01, (-0.1, 0, 0.352), IRON, seg=6)  # cap nub
    p.box((0.1, 0.004, 0.06), (0.05, 0.077, 0.2), "#E8DCC0")  # stencil panel
    p.box((0.06, 0.005, 0.012), (0.05, 0.079, 0.215), "#2A2018")
    p.done()


def whistle():
    # 0.08 x 0.03 x 0.03: a brass pea-less whistle lying on its side, mouthpiece to +X, window, lanyard ring
    p = Part("Whistle")
    p.cyl(0.012, 0.012, 0.05, (-0.012, 0, 0.014), BRASS, rot=(0, math.pi / 2, 0), seg=8)  # barrel
    p.between((0.013, 0, 0.012), (0.04, 0, 0.012), 0.009, 0.006, BRASS, seg=6)  # mouthpiece, tapers
    p.box((0.014, 0.012, 0.01), (0.0, 0, 0.027), "#9A7F2C")  # labium block
    p.box((0.008, 0.01, 0.004), (0.008, 0, 0.029), "#1E1B1A")  # window
    p.cyl(0.013, 0.013, 0.012, (-0.037, 0, 0.014), "#9A7F2C", rot=(0, math.pi / 2, 0), seg=8)  # end cap
    tube(p, 0.008, 0.005, 0.003, (-0.045, 0, 0.012), IRON, rot=(math.pi / 2, 0, 0), seg=6)  # lanyard ring
    p.done()


MODELS = [
    ("trap_bear_open", lambda: bear("open"), "mid"),
    ("trap_bear_closed", lambda: bear("closed"), "mid"),
    ("trap_bear_item", lambda: bear("item"), "mid"),
    ("trap_pit_cover", pit_cover, "mid"),
    ("trap_pit_open", pit_open, "mid"),
    ("trap_tripwire", tripwire, "mid"),
    ("trap_fresh_dirt_decal", dirt_decal, "mid"),
    ("trap_bent_stalks", bent_stalks, "mid"),
    ("trap_glint", glint, "small"),
    ("prop_pegboard", pegboard, "large"),
    ("tool_hoe", hoe, "small"),
    ("tool_shovel", shovel, "small"),
    ("tool_fuel_can", fuel_can, "small"),
    ("tool_whistle", whistle, "small"),
]

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for nm, fn, cls in MODELS:
        if not only or nm in only:
            B.build(nm, fn, cls)

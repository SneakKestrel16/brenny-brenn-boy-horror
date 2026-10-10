"""P5-12 overall model upgrade (D-151): Blender-built detail, no outside source.

  sh tools/blender/run.sh tools/blender/build_p5_12.py [-- name ...]

Reuses the build_phase4.py helpers (Part, materials, export) and the build_p4_40.py builders it does not replace, so the
conventions are unchanged: 1 unit = 1 m, model FRONT is +Y in Blender (glTF/Godot -Z, CONTRACTS s4), origin at the base,
flat colour in vertex colour layer "Col", file names and node names the P4-16 ones. build_phase4.py and build_p4_40.py
skip the names in SUPERSEDED_P5; they are built only here.

Rebuilt here: char_farmer (skinned, rigged, 9 animations, tint slots), the small tools, the cart (wheels as their own
nodes, round rims), the shipping crate, the player scarecrow, the cart pumpkin slots, the creature scarecrow (level
arms) and its smear hull.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_phase4 as B  # noqa: E402
import build_p4_40 as P  # noqa: E402
from build_phase4 import BRASS, DARK, IRON, MAT_EMBER, MAT_FLAT, MAT_WARM, WOOD, WOOD2, Part, empty  # noqa: E402

MAT_OVER, MAT_SLEEVE = 3, 4  # farmer only: tintable overalls, Taint-ready sleeves and hands
SUPERSEDED_P5 = {"char_farmer", "tool_watering_can", "tool_watering_can_quiet", "tool_walkie_talkie", "tool_walkie_battery",
                 "tool_flare_gun", "tool_shed_lock", "tool_scrap", "tool_seed_packet_turnip", "tool_seed_packet_pumpkin",
                 "tool_seed_packet_moonflower", "prop_cart", "prop_shipping_crate", "prop_scarecrow_player",
                 "prop_cart_pumpkin_slot", "prop_cart_pumpkin_slot_bitten", "creature_scarecrow", "creature_smear_scarecrow"}
ROPE, STRAW, CLOTH = "#8A7448", "#C9B26A", "#B8AE98"


def tube(p, r_out, r_in, width, centre, col, rot=(0, 0, 0), seg=16, mat=MAT_FLAT):
    """A flat ring (wheel rim, tyre, collar) on local Z, width along Z, open in the middle."""
    bm = p.bm
    rings = []
    for z in (-width / 2, width / 2):
        for r in (r_out, r_in):
            rings.append([bm.verts.new((r * math.cos(i * math.tau / seg), r * math.sin(i * math.tau / seg), z)) for i in range(seg)])
    (fo, fi, bo, bi) = rings
    faces = []
    for i in range(seg):
        j = (i + 1) % seg
        faces += [bm.faces.new((fo[i], fo[j], bo[j], bo[i])), bm.faces.new((fi[j], fi[i], bi[i], bi[j])),
                  bm.faces.new((fo[j], fo[i], fi[i], fi[j])), bm.faces.new((bo[i], bo[j], bi[j], bi[i]))]
    verts = [v for ring in rings for v in ring]
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    p._xf(verts, centre, rot, (1, 1, 1))
    p._fin(verts, col, mat)


def arc(p, centre, r, a0, a1, n, col, plane="xz", rad=0.01, seg=4, mat=MAT_FLAT):
    """Polyline arc of thin cylinders (bails, shackles, handles). plane xz or yz; angle 0 along the first axis."""
    pts = []
    for i in range(n + 1):
        a = a0 + (a1 - a0) * i / n
        c, s = r * math.cos(a), r * math.sin(a)
        pts.append((centre[0] + c, centre[1], centre[2] + s) if plane == "xz" else (centre[0], centre[1] + c, centre[2] + s))
    for a, b in zip(pts, pts[1:]):
        p.between(a, b, rad, rad, col, seg=seg, mat=mat)


# ---------------------------------------------------------------- tools (doc 07 s11.3 sizes)
def watering_can(quiet=False):
    # 0.4 x 0.2 x 0.3: ribbed round body, long spout with a rose, top handle and back grip, open top
    BLUE = "#4F7A9A" if not quiet else "#6B7C8A"
    BLUE2 = "#3E6480" if not quiet else "#566672"
    p = Part("Can")
    p.cyl(0.1, 0.092, 0.2, (0, -0.1, 0.1), BLUE, seg=8)
    p.cyl(0.1, 0.1, 0.012, (0, -0.1, 0.05), BLUE2, seg=8)  # rolled rib
    p.cyl(0.1, 0.1, 0.016, (0, -0.1, 0.19), BLUE2, seg=8)  # top rim
    p.cyl(0.08, 0.08, 0.004, (0, -0.1, 0.19), "#26343E", seg=8)  # dark water in the mouth
    p.between((0, -0.03, 0.06), (0, 0.12, 0.235), 0.03, 0.018, BLUE, seg=5)  # spout
    p.between((0, 0.12, 0.235), (0, 0.15, 0.255), 0.032, 0.045, BRASS if not quiet else "#8A8277", seg=6)  # rose, flares out
    p.cyl(0.045, 0.045, 0.008, (0, 0.157, 0.26), "#2A2D2F", rot=(-0.7, 0, 0), seg=6)  # rose face
    arc(p, (0, -0.105, 0.2), 0.09, 0.15, math.pi - 0.15, 4, IRON, plane="yz", rad=0.014, seg=3)  # top handle
    p.between((0, -0.196, 0.04), (0, -0.196, 0.19), 0.013, 0.013, IRON, seg=3)  # back grip
    if quiet:  # cloth wrap round the body and a cord
        p.cyl(0.103, 0.103, 0.1, (0, -0.1, 0.1), CLOTH, seg=8)
        p.cyl(0.105, 0.105, 0.012, (0, -0.1, 0.13), "#6B4A2F", seg=8)
        p.between((0, 0.0, 0.14), (0, 0.13, 0.226), 0.034, 0.024, CLOTH, seg=5)
    p.done()


def walkie():
    # 0.08 x 0.04 x 0.2: olive handset, whip antenna, speaker slots, screen, dial, push-to-talk, belt clip
    OL, OL2 = "#3C4A3A", "#2E3A2C"
    p = Part("Walkie")
    p.box((0.08, 0.04, 0.14), (0, 0, 0.07), OL)
    p.box((0.086, 0.044, 0.02), (0, 0, 0.13), OL2)  # shoulder
    p.box((0.086, 0.044, 0.014), (0, 0, 0.012), OL2)  # foot
    for k in range(4):  # speaker slots
        p.box((0.05, 0.004, 0.006), (0, 0.021, 0.025 + k * 0.012), "#1E1B1A")
    p.box((0.05, 0.004, 0.034), (0, 0.021, 0.095), "#6E8A7A")  # screen
    p.box((0.044, 0.002, 0.026), (0, 0.0235, 0.095), "#26343E")
    p.cyl(0.011, 0.011, 0.02, (-0.022, 0, 0.152), "#9A3B2B", seg=6)  # dial
    p.cyl(0.008, 0.008, 0.02, (0.012, 0, 0.152), IRON, seg=6)  # volume knob
    p.box((0.012, 0.012, 0.04), (-0.046, 0.0, 0.1), "#9A3B2B")  # push-to-talk on the side
    p.box((0.03, 0.006, 0.07), (0, -0.023, 0.07), IRON)  # belt clip
    p.cyl(0.011, 0.007, 0.012, (0.025, 0, 0.16), IRON, seg=6)  # antenna base
    p.between((0.025, 0, 0.166), (0.03, 0, 0.2), 0.006, 0.0035, IRON, seg=5)
    p.done()


def walkie_battery():
    p = Part("Battery")
    p.box((0.04, 0.02, 0.064), (0, 0, 0.032), "#C9A02A")
    p.box((0.042, 0.022, 0.012), (0, 0, 0.006), "#2E2A24")  # base cap
    p.box((0.042, 0.022, 0.012), (0, 0, 0.06), "#2E2A24")  # top cap
    p.box((0.03, 0.002, 0.02), (0, 0.011, 0.034), "#E8DCC0")  # label
    p.box((0.012, 0.002, 0.008), (0, 0.012, 0.034), "#9A3B2B")
    p.cyl(0.009, 0.009, 0.01, (0, 0, 0.071), IRON, seg=6)  # terminal
    p.box((0.01, 0.003, 0.006), (0.012, 0.011, 0.056), "#6B6F72")  # contact tab
    p.done()


def flare_gun():
    # 0.25 long (Y) x 0.05 wide x 0.18 high, grip bottom on z 0: fat orange barrel, wooden grip, trigger guard, hammer
    OR, OR2 = "#B8451F", "#8E3216"
    p = Part("FlareGun")
    p.cyl(0.026, 0.026, 0.19, (0, 0.03, 0.152), OR, rot=(math.pi / 2, 0, 0), seg=10)  # barrel, flare bore
    p.cyl(0.03, 0.03, 0.02, (0, 0.115, 0.152), IRON, rot=(math.pi / 2, 0, 0), seg=10)  # muzzle ring
    p.cyl(0.018, 0.018, 0.004, (0, 0.126, 0.152), "#1E1B1A", rot=(math.pi / 2, 0, 0), seg=8)  # bore
    p.box((0.036, 0.1, 0.044), (0, -0.03, 0.128), OR2)  # frame under the barrel
    p.box((0.032, 0.05, 0.12), (0, -0.075, 0.06), "#4A3322")  # grip
    p.box((0.036, 0.056, 0.014), (0, -0.075, 0.007), IRON)  # butt cap
    p.box((0.038, 0.012, 0.1), (0, -0.103, 0.06), "#3A2A1C")  # grip back strap
    p.box((0.014, 0.03, 0.026), (0, -0.098, 0.18 - 0.013), IRON)  # hammer
    p.box((0.014, 0.012, 0.02), (0, -0.112, 0.168), IRON)
    p.box((0.01, 0.01, 0.03), (0, 0.0, 0.098), IRON)  # trigger
    p.box((0.012, 0.045, 0.01), (0, 0.016, 0.082), IRON)  # trigger guard bottom
    p.box((0.012, 0.01, 0.03), (0, 0.04, 0.096), IRON)  # guard front
    p.box((0.016, 0.03, 0.008), (0, 0.04, 0.178), "#1E1B1A")  # sight
    p.done()


def shed_lock():
    # 0.1 x 0.05 x 0.15 brass padlock: body, round shackle, keyhole, corner rivets
    p = Part("Lock")
    p.box((0.1, 0.05, 0.08), (0, 0, 0.04), "#B89A3A")
    p.box((0.1, 0.052, 0.012), (0, 0, 0.074), "#9A7F2C")  # top band
    p.box((0.1, 0.052, 0.012), (0, 0, 0.006), "#9A7F2C")  # bottom band
    p.cyl(0.011, 0.011, 0.004, (0, 0.025, 0.045), "#1E1B1A", rot=(math.pi / 2, 0, 0), seg=8)  # keyhole
    p.box((0.006, 0.004, 0.022), (0, 0.025, 0.03), "#1E1B1A")
    for sx in (-1, 1):
        for z in (0.02, 0.06):
            p.ball((0.006, 0.003, 0.006), (sx * 0.04, 0.023, z), "#D2B15A", seg=4, rings=3)  # rivets
        p.box((0.014, 0.014, 0.036), (sx * 0.035, 0, 0.098), IRON)  # shackle legs
    arc(p, (0, 0, 0.108), 0.035, 0.0, math.pi, 6, IRON, rad=0.0085, seg=5)  # shackle; top at 0.15
    p.done()


def scrap():
    # 0.15 x 0.1 x 0.05 scrap pile: bent plate, gear, bolt, pipe offcut
    p = Part("Scrap")
    p.box((0.12, 0.08, 0.008), (-0.01, 0, 0.004), "#6B6F72", rot=(0, 0, 0.3))
    p.box((0.07, 0.05, 0.008), (-0.03, 0.01, 0.012), "#8A5A3A", rot=(0.15, 0.2, -0.4))  # bent rusty plate
    p.cyl(0.032, 0.032, 0.012, (0.04, -0.01, 0.022), "#55595C", seg=10)  # gear body
    for i in range(8):
        a = i * math.tau / 8
        p.box((0.014, 0.012, 0.012), (0.04 + 0.036 * math.cos(a), -0.01 + 0.036 * math.sin(a), 0.022), "#55595C", rot=(0, 0, a))
    p.cyl(0.01, 0.01, 0.014, (0.04, -0.01, 0.03), "#2A2D2F", seg=6)  # gear hub
    p.cyl(0.011, 0.011, 0.05, (-0.045, 0.025, 0.02), "#6B6F72", rot=(0, 1.3, 0.4), seg=6)  # pipe offcut
    p.cyl(0.007, 0.007, 0.04, (0.0, 0.03, 0.012), "#8A8277", rot=(math.pi / 2, 0, 0.7), seg=5)  # bolt shank
    p.cyl(0.013, 0.013, 0.008, (0.02, 0.042, 0.012), "#8A8277", rot=(math.pi / 2, 0, 0.7), seg=6)  # bolt head
    p.done()


def seed_packet(col, kind):
    # 0.1 x 0.01 x 0.15: folded paper envelope, crimped top, colour band, one drawn crop on the front (+Y)
    p = Part("Packet")
    p.box((0.1, 0.007, 0.15), (0, 0, 0.075), "#E8DCC0")
    p.ball((0.04, 0.0045, 0.06), (0, 0, 0.06), "#E8DCC0", seg=6, rings=4)  # the seeds make it pillow
    for i in range(10):  # crimp teeth on the top edge
        p.box((0.006, 0.009, 0.01), (-0.045 + i * 0.01, 0, 0.146), "#D8C9A8" if i % 2 else "#E8DCC0")
    p.box((0.1, 0.0085, 0.036), (0, 0, 0.126), col)  # colour band
    p.box((0.07, 0.0095, 0.006), (0, 0, 0.098), "#2A2018")  # name line
    if kind == "turnip":
        p.ball((0.022, 0.003, 0.022), (0, 0.0045, 0.055), col, seg=7, rings=4)
        p.cyl(0.005, 0.002, 0.03, (0, 0.0045, 0.088), "#4F7A32", seg=4)
    elif kind == "pumpkin":
        p.ball((0.026, 0.003, 0.022), (0, 0.0045, 0.055), col, seg=8, rings=4)
        p.box((0.006, 0.003, 0.012), (0, 0.005, 0.082), "#4F5A2B")
    else:
        for k in range(5):  # moonflower petals
            a = k * math.tau / 5
            p.ball((0.009, 0.002, 0.014), (0.014 * math.cos(a), 0.0045, 0.058 + 0.014 * math.sin(a)), col, rot=(0, a, 0), seg=4, rings=2)
        p.ball((0.007, 0.003, 0.007), (0, 0.0048, 0.058), "#E8D3A0", seg=5, rings=3)
    p.box((0.05, 0.0095, 0.005), (0, 0, 0.025), "#9A8350")  # weight stamp
    p.done()


# ---------------------------------------------------------------- cart: wheels are their own nodes (WheelL, WheelR)
WHEEL_C = (-0.2, 0.55)  # y, z of the axle, unchanged from P4-16


def wheel_part(name, cx):
    cy, cz = WHEEL_C
    p = Part(name, (cx, cy, cz))
    tube(p, 0.47, 0.4, 0.09, (cx, cy, cz), WOOD2, rot=(0, math.pi / 2, 0), seg=16)  # felloe
    tube(p, 0.545, 0.47, 0.07, (cx, cy, cz), IRON, rot=(0, math.pi / 2, 0), seg=16)  # iron tyre, bottom at z 0.005
    for i in range(8):  # spokes, tapering to the rim
        a = i * math.tau / 8 + 0.2
        p.between((cx, cy + 0.07 * math.cos(a), cz + 0.07 * math.sin(a)), (cx, cy + 0.42 * math.cos(a), cz + 0.42 * math.sin(a)), 0.03, 0.022,
                  WOOD, seg=4)
    p.cyl(0.095, 0.095, 0.16, (cx, cy, cz), IRON, rot=(0, math.pi / 2, 0), seg=8)  # hub
    p.cyl(0.05, 0.05, 0.2, (cx, cy, cz), "#2A2D2F", rot=(0, math.pi / 2, 0), seg=6)  # axle cap
    p.done()


def cart():
    p = Part("Cart")
    for i in range(5):  # deck slats
        p.box((0.24, 2.36, 0.05), (-0.5 + i * 0.25, 0.0, 0.615), WOOD if i % 2 == 0 else "#6E4D33")
    for sx in (-1, 1):
        p.box((0.08, 2.4, 0.08), (sx * 0.5, 0.0, 0.55), WOOD2)  # under-frame beams
    for y in (-0.9, 0.0, 0.9):
        p.box((1.3, 0.08, 0.06), (0, y, 0.54), WOOD2)
    for sx in (-1, 1):
        for k, z in enumerate((0.7, 0.8, 0.9)):  # side planks, gaps between
            p.box((0.05, 2.36, 0.095), (sx * 0.62, 0.0, z), WOOD2 if k % 2 == 0 else "#6A4A32")
        for y in (-1.1, -0.37, 0.37, 1.1):  # stakes
            p.box((0.07, 0.07, 0.36), (sx * 0.65, y, 0.8), WOOD2)
        p.box((0.09, 2.42, 0.04), (sx * 0.62, 0.0, 0.975), "#6E4D33")  # top rail
    p.cyl(0.04, 0.04, 1.5, (0, -0.2, 0.55), IRON, rot=(0, math.pi / 2, 0), seg=6)  # axle
    for y in (-1.17, 1.17):  # end boards
        for k, z in enumerate((0.7, 0.8, 0.9)):
            p.box((1.24, 0.05, 0.095), (0, y, z), WOOD2 if k % 2 == 0 else "#6A4A32")
    for sx in (-1, 1):  # iron corner straps
        for y in (-1.17, 1.17):
            p.box((0.04, 0.04, 0.3), (sx * 0.62, y, 0.8), IRON)
    p.between((0, 1.2, 0.6), (0, 1.5, 0.45), 0.05, 0.04, WOOD2, seg=5)  # tongue
    p.box((0.5, 0.05, 0.05), (0, 1.46, 0.46), WOOD2)  # yoke bar
    for sx in (-1, 1):  # push handle at the back
        p.between((sx * 0.55, -1.2, 0.7), (sx * 0.55, -1.45, 1.05), 0.035, 0.03, WOOD2, seg=5)
    p.between((-0.55, -1.45, 1.05), (0.55, -1.45, 1.05), 0.035, 0.035, WOOD2, seg=5)
    p.between((0.58, 1.1, 0.64), (0.58, 1.1, 1.65), 0.04, 0.035, WOOD2, seg=5)  # lantern post
    p.between((0.58, 1.1, 1.65), (0.3, 1.1, 1.72), 0.03, 0.03, WOOD2, seg=5)  # arm
    p.between((0.58, 1.1, 1.3), (0.58, 0.9, 0.9), 0.025, 0.02, WOOD2, seg=4)  # brace
    p.box((0.05, 0.05, 0.05), (0.3, 1.1, 1.7), IRON)  # hook
    p.done()
    wheel_part("WheelL", -0.7)
    wheel_part("WheelR", 0.7)
    empty("LanternSocket", (0.3, 1.1, 1.72))
    empty("PumpkinSlot", (0, 0, 0.64))


# ---------------------------------------------------------------- slot, crate, player scarecrow
def slot(bitten):
    p = Part("Slot")
    p.cyl(0.75, 0.75, 0.04, (0, 0, 0.02), WOOD2, seg=12)
    for i in range(4):  # floor boards
        p.box((1.2, 0.3, 0.012), (0, -0.45 + i * 0.3, 0.046), WOOD if i % 2 == 0 else "#6E4D33")
    n = 12
    for i in range(n):  # stave ring, each plank leans in a little
        a = i * math.tau / n
        broken = bitten and i in (2, 3, 4)
        hh = 0.13 + 0.03 * (i % 2) if broken else 0.3
        col = WOOD if i % 2 == 0 else "#6A4A32"
        p.box((0.19, 0.04, hh), (0.7 * math.cos(a), 0.7 * math.sin(a), 0.04 + hh / 2), col,
              rot=(0.5 if broken else -0.05, 0, a + math.pi / 2))
        if broken:  # splinter teeth on the broken stave
            p.box((0.05, 0.03, 0.06), (0.7 * math.cos(a), 0.7 * math.sin(a), 0.04 + hh + 0.02), "#A88A5A", rot=(0.7, 0.2, a + math.pi / 2))
    p.cyl(0.74, 0.74, 0.03, (0, 0, 0.2), IRON, seg=12)  # iron band
    p.ball((0.45, 0.45, 0.04), (0, 0, 0.07), STRAW, seg=8, rings=3)  # straw bed
    for i in range(8):
        a = i * math.tau / 8
        p.between((0.2 * math.cos(a), 0.2 * math.sin(a), 0.07), (0.5 * math.cos(a + 0.4), 0.5 * math.sin(a + 0.4), 0.11), 0.012, 0.004, STRAW, seg=3)
    p.done()


def crate():
    # 2 x 1 x 1.2: slatted shipping crate, corner posts, open lid with a price card, rope handles, stencil
    p = Part("Crate")
    for i in range(4):  # long sides, planks
        for sy in (-1, 1):
            p.box((1.9, 0.04, 0.2), (0, sy * 0.48, 0.12 + i * 0.22), "#8A7448" if i % 2 == 0 else "#7A6840")
    for sx in (-1, 1):  # short sides
        for i in range(4):
            p.box((0.04, 0.92, 0.2), (sx * 0.93, 0, 0.12 + i * 0.22), "#8A7448" if i % 2 else "#7A6840")
        for sy in (-1, 1):  # corner posts
            p.box((0.1, 0.1, 0.98), (sx * 0.95, sy * 0.48, 0.49), WOOD2)
    p.box((1.9, 0.9, 0.04), (0, 0, 0.04), WOOD2)  # floor
    for sy in (-1, 1):
        p.box((2.02, 0.07, 0.07), (0, sy * 0.48, 0.96), WOOD2)  # top rails
        p.box((0.05, 0.05, 0.05), (-0.45, sy * 0.51, 0.55), IRON)  # nails
        p.box((0.05, 0.05, 0.05), (0.45, sy * 0.51, 0.55), IRON)
    for sx in (-1, 1):
        p.box((0.07, 0.9, 0.07), (sx * 0.95, 0, 0.96), WOOD2)
    p.box((1.2, 0.02, 0.4), (0, 0.5, 0.52), "#E8DCC0")  # stencil panel
    p.box((0.7, 0.025, 0.07), (0, 0.51, 0.6), "#9A3B2B")
    p.box((0.45, 0.025, 0.05), (0, 0.51, 0.46), "#2A2018")
    for sx in (-1, 1):  # rope handles
        arc(p, (sx * 0.96, 0, 0.8), 0.1, 0.0, math.pi, 5, ROPE, plane="yz", rad=0.016, seg=4)
    for i in range(3):  # loose lid planks resting across the open top, one askew
        p.box((0.4, 0.8, 0.04), (-0.55 + i * 0.55, 0.0, 1.02), "#8A7448" if i % 2 == 0 else "#7A6840", rot=(0.0, 0.0, 0.18 if i == 1 else 0.0))
    p.box((0.4, 0.015, 0.25), (0.6, 0.545, 0.84), "#E8DCC0", rot=(-0.1, 0, 0.05))  # price card tacked to the front
    p.done()


def scarecrow_player():
    # 0.8 x 0.8 x 2: friendly stake scarecrow, patched blue shirt, burlap face with a smile, straw hat with a flower
    p = Part("Scarecrow")
    p.between((0, 0, 0), (0, 0, 1.9), 0.05, 0.04, WOOD2, seg=6)
    p.cyl(0.14, 0.14, 0.04, (0, 0, 0.02), WOOD2, seg=6)  # foot block
    p.between((-0.32, 0, 1.45), (0.32, 0, 1.45), 0.035, 0.035, WOOD2, seg=6)
    p.cyl(0.26, 0.15, 0.7, (0, 0, 1.15), "#3C5A7A", seg=8)  # shirt
    p.cyl(0.27, 0.26, 0.05, (0, 0, 0.82), "#2F4A66", seg=8)  # hem
    for i in range(6):  # ragged hem
        a = i * math.tau / 6 + 0.2
        p.box((0.08, 0.02, 0.1 + 0.03 * (i % 2)), (0.265 * math.cos(a), 0.265 * math.sin(a), 0.77), "#2F4A66", rot=(0, 0, a + math.pi / 2))
    p.box((0.14, 0.02, 0.14), (0.1, 0.19, 1.1), "#C9A02A")  # patches
    p.box((0.1, 0.02, 0.1), (-0.1, 0.2, 1.3), "#9A3B2B")
    for sx in (-1, 1):  # sleeves along the crossbar and straw cuffs
        p.between((sx * 0.14, 0, 1.45), (sx * 0.3, 0, 1.45), 0.07, 0.06, "#3C5A7A", seg=6)
        for k in range(4):
            p.between((sx * 0.3, 0, 1.45), (sx * (0.39 + 0.005 * (k % 2)), 0.05 * (k - 1.5), 1.38 - 0.03 * k), 0.012, 0.004, STRAW, seg=3)
    p.ball((0.17, 0.17, 0.19), (0, 0, 1.72), "#C9A86A", seg=10, rings=6)  # sack head
    p.ball((0.05, 0.05, 0.04), (0, 0, 1.92), "#B09050", seg=5, rings=3)  # tied top
    for sx in (-1, 1):
        p.ball((0.025, 0.02, 0.025), (sx * 0.07, 0.15, 1.76), "#222222", seg=5, rings=4)
        p.box((0.03, 0.012, 0.01), (sx * 0.07, 0.16, 1.8), "#222222", rot=(0, 0, sx * 0.2))  # brows
    p.ball((0.015, 0.012, 0.015), (0, 0.17, 1.72), "#B09050", seg=4, rings=3)  # nose
    for i in range(5):  # smile
        x = (i - 2) * 0.03
        p.box((0.014, 0.014, 0.012), (x, 0.162, 1.65 - 0.012 * (2 - abs(i - 2))), "#222222")
    p.box((0.2, 0.2, 0.04), (0, 0.05, 1.5), "#9A3B2B", rot=(0, 0.5, 0))  # neckerchief
    p.cyl(0.4, 0.3, 0.03, (0, 0, 1.88), "#D2B15A", seg=12)  # hat brim
    p.cyl(0.17, 0.12, 0.14, (0, 0, 1.96), "#D2B15A", seg=8)
    p.cyl(0.175, 0.17, 0.035, (0, 0, 1.9), "#9A3B2B", seg=8)  # hatband
    p.ball((0.04, 0.04, 0.025), (0.14, 0.1, 1.95), "#E8B83A", seg=6, rings=3)  # flower
    p.ball((0.015, 0.015, 0.015), (0.14, 0.1, 1.965), "#8A5A1F", seg=4, rings=3)
    for i in range(5):  # straw from the collar
        p.between((0, 0.1, 1.56), ((i - 2) * 0.05, 0.16, 1.5), 0.01, 0.003, STRAW, seg=3)
    p.done()


# ---------------------------------------------------------------- creature scarecrow: level arms (QA P4-19 nit)
def scarecrow_lvl():
    t = Part("Torso", (0, 0, 0.7))
    t.cyl(0.4, 0.17, 0.95, (0, 0, 1.17), "#3B3226", seg=8)  # coat
    t.cyl(0.4, 0.4, 0.04, (0, 0, 0.72), "#2A2218", seg=8)
    for i in range(12):  # ragged hem tatters
        a = i * math.tau / 12
        h = 0.18 + 0.14 * ((i * 7) % 3)
        t.box((0.1, 0.02, h), (0.4 * math.cos(a), 0.4 * math.sin(a), 0.7 - h / 2 + 0.03), "#2F281D", rot=(0, 0, a + math.pi / 2))
    t.box((0.18, 0.02, 0.18), (0.1, 0.2, 1.3), "#5A4A2E")  # patch
    t.box((0.14, 0.02, 0.14), (-0.14, 0.2, 1.0), "#6A5A3C")
    t.between((0, -0.14, 0.7), (0, -0.14, 1.78), 0.035, 0.03, "#5C402A", seg=5)  # stake through the back
    t.box((1.0, 0.04, 0.05), (0, -0.14, 1.52), "#5C402A")  # crossbar behind the coat, the level cross
    for i in range(5):  # straw from the collar
        t.between((0, 0.05, 1.62), ((i - 2) * 0.09, 0.2, 1.52), 0.014, 0.004, STRAW, seg=3)
    t.done()
    for s, nm in ((-1, "ArmL"), (1, "ArmR")):
        sh, ha = (s * 0.2, 0.0, 1.5), (s * 0.5, 0.06, 1.5)  # level: the sleeve runs along the crossbar
        a = Part(nm, sh)
        a.between(sh, ha, 0.1, 0.075, "#3B3226", seg=6)
        for k in range(4):  # sleeve rags hanging below the arm
            m = Vector(sh).lerp(Vector(ha), 0.3 + 0.2 * k)
            a.box((0.06, 0.02, 0.16 + 0.04 * (k % 2)), (m.x, m.y, m.z - 0.12), "#2F281D")
        for k in range(6):  # straw bundle at the cuff
            a.between(ha, (ha[0] + s * 0.03 * (k % 3), ha[1] + 0.06 + 0.015 * k, ha[2] - 0.2 - 0.02 * (k % 2)), 0.014, 0.004, STRAW, seg=3)
        a.done()
    for s, nm in ((-1, "LegL"), (1, "LegR")):
        l = Part(nm, (s * 0.1, 0, 0.75))
        l.between((s * 0.1, 0, 0.75), (s * 0.12, 0.03, 0.05), 0.055, 0.035, "#4A3C28", seg=5)
        l.box((0.1, 0.2, 0.05), (s * 0.12, 0.08, 0.025), "#2A2218")  # boot
        l.done()


def scarecrow_body_lvl():
    scarecrow_lvl()
    B._head_part(B.scarecrow_head, "Head", (0, 0, 1.68), False)


# ---------------------------------------------------------------- farmer (rig, animations, tint slots)
SKIN, HAIR, SHIRT, BOOT = "#C9A07A", "#5A4029", "#9A3B2B", "#4A3322"
OV, OV2, OV3 = "#EDEDED", "#C4C4C4", "#D6D6D6"  # overalls: light grey in the vertex colour, the game multiplies the tint in


def extra_materials():
    """mat_farmer_overalls (tintable: set albedo_color per player) and mat_farmer_sleeves (hands and sleeves: Taint)."""
    for name in ("mat_farmer_overalls", "mat_farmer_sleeves"):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.clear()
        out_n = nt.nodes.new("ShaderNodeOutputMaterial")
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        col = nt.nodes.new("ShaderNodeVertexColor")
        col.layer_name = "Col"
        nt.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 1.0
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Specular IOR Level"].default_value = 0.0
        nt.links.new(bsdf.outputs["BSDF"], out_n.inputs["Surface"])
        B.Ctx.mats.append(m)


def farmer_parts():
    t = Part("Torso", (0, 0, 1.0))
    t.ball((0.215, 0.125, 0.13), (0, 0, 1.02), OV, seg=10, rings=6, mat=MAT_OVER)  # hips
    t.box((0.4, 0.22, 0.3), (0, 0, 1.2), OV, mat=MAT_OVER)  # waist
    t.ball((0.2, 0.115, 0.1), (0, 0.01, 1.3), OV3, seg=10, rings=4, mat=MAT_OVER)  # soft belly
    t.box((0.42, 0.24, 0.26), (0, 0, 1.42), SHIRT)  # chest in the shirt
    t.ball((0.22, 0.13, 0.08), (0, 0, 1.54), SHIRT, seg=10, rings=4)  # rounded shoulders line
    t.box((0.26, 0.02, 0.28), (0, 0.115, 1.22), OV3, mat=MAT_OVER)  # bib front
    t.box((0.1, 0.02, 0.08), (0, 0.13, 1.19), OV2, mat=MAT_OVER)  # bib pocket
    t.box((0.11, 0.012, 0.012), (0, 0.142, 1.234), OV, mat=MAT_OVER)  # pocket flap
    t.box((0.4, 0.23, 0.04), (0, 0, 1.31), OV2, mat=MAT_OVER)  # seam band
    t.box((0.4, 0.235, 0.03), (0, 0, 1.12), "#3A3A3A")  # belt line low on the hips
    t.box((0.03, 0.02, 0.03), (0, 0.12, 1.12), BRASS)  # belt buckle
    for sx in (-1, 1):
        t.box((0.05, 0.25, 0.04), (sx * 0.11, 0.0, 1.5), OV, mat=MAT_OVER)  # straps over the shoulder
        t.box((0.05, 0.02, 0.2), (sx * 0.11, 0.115, 1.43), OV, mat=MAT_OVER)  # strap down the front
        t.box((0.05, 0.02, 0.2), (sx * 0.11, -0.115, 1.43), OV, mat=MAT_OVER)  # and the back
        t.ball((0.018, 0.012, 0.018), (sx * 0.11, 0.128, 1.34), BRASS, seg=5, rings=3)  # buttons
        t.box((0.14, 0.02, 0.1), (sx * 0.16, 0.115, 1.0), OV2, mat=MAT_OVER)  # hip pockets
        t.box((0.14, 0.02, 0.1), (sx * 0.1, -0.12, 1.0), OV2, mat=MAT_OVER)  # back pockets
    t.cyl(0.055, 0.06, 0.09, (0, 0, 1.6), SKIN, seg=8)  # neck
    t.ball((0.2, 0.105, 0.05), (0, 0, 1.56), SHIRT, seg=8, rings=3)  # collar
    t.box((0.1, 0.04, 0.02), (0, 0.09, 1.575), "#7A2E22", rot=(0.5, 0, 0))  # collar point
    t.done()

    h = Part("Head", (0, 0, 1.55))
    h.ball((0.15, 0.16, 0.17), (0, 0, 1.62), SKIN, seg=12, rings=8)
    h.ball((0.1, 0.1, 0.07), (0, 0.045, 1.55), SKIN, seg=8, rings=4)  # jaw and chin
    h.ball((0.03, 0.04, 0.035), (0, 0.155, 1.6), "#B88A66", seg=6, rings=4)  # nose
    h.ball((0.158, 0.15, 0.13), (0, -0.03, 1.67), HAIR, seg=12, rings=6)  # hair, back and sides
    h.box((0.2, 0.03, 0.05), (0, 0.13, 1.77), HAIR, rot=(0.35, 0, 0))  # fringe
    h.box((0.06, 0.03, 0.05), (-0.09, 0.12, 1.75), HAIR, rot=(0.3, 0, 0.5))  # side lock
    for sx in (-1, 1):
        h.ball((0.018, 0.012, 0.022), (sx * 0.06, 0.145, 1.65), "#1E1B1A", seg=5, rings=4)  # eyes
        h.box((0.05, 0.01, 0.012), (sx * 0.06, 0.15, 1.69), HAIR, rot=(0, 0, sx * 0.1))  # brows
        h.ball((0.02, 0.03, 0.04), (sx * 0.15, 0.0, 1.62), "#B88A66", seg=6, rings=4)  # ears
        h.ball((0.025, 0.012, 0.018), (sx * 0.075, 0.135, 1.59), "#D89A80", seg=5, rings=3)  # cheeks
    h.box((0.07, 0.01, 0.01), (0, 0.15, 1.54), "#8A5A3A")  # mouth
    h.done()

    for s, nm in ((-1, "ArmL"), (1, "ArmR")):
        sh, el, wr = (s * 0.23, 0.0, 1.5), (s * 0.25, 0.02, 1.22), (s * 0.25, 0.1, 0.96)
        a = Part(nm, sh)
        a.ball((0.075, 0.075, 0.075), sh, SHIRT, seg=8, rings=5, mat=MAT_SLEEVE)  # shoulder
        a.between(sh, el, 0.062, 0.054, SHIRT, seg=8, mat=MAT_SLEEVE).between(el, wr, 0.054, 0.046, SHIRT, seg=8, mat=MAT_SLEEVE)
        a.ball((0.055, 0.055, 0.055), el, SHIRT, seg=6, rings=4, mat=MAT_SLEEVE)  # elbow
        a.cyl(0.052, 0.05, 0.035, (wr[0], wr[1] - 0.005, wr[2] + 0.04), "#7A2E22", seg=8, mat=MAT_SLEEVE)  # rolled cuff
        a.ball((0.045, 0.05, 0.058), (wr[0], wr[1] + 0.015, wr[2] - 0.05), SKIN, seg=8, rings=5, mat=MAT_SLEEVE)  # hand
        a.ball((0.018, 0.03, 0.022), (wr[0] - s * 0.04, wr[1] + 0.04, wr[2] - 0.03), SKIN, rot=(0, 0, s * 0.5), seg=5, rings=3, mat=MAT_SLEEVE)  # thumb
        a.box((0.07, 0.03, 0.04), (wr[0], wr[1] + 0.03, wr[2] - 0.095), SKIN, mat=MAT_SLEEVE)  # fingers
        a.done()

    for s, nm in ((-1, "LegL"), (1, "LegR")):
        hip, kn, an = (s * 0.1, 0.0, 0.98), (s * 0.1, 0.02, 0.5), (s * 0.1, 0.0, 0.09)
        l = Part(nm, hip)
        l.between(hip, kn, 0.095, 0.078, OV, seg=8, mat=MAT_OVER).between(kn, an, 0.078, 0.064, OV, seg=8, mat=MAT_OVER)
        l.ball((0.08, 0.075, 0.07), kn, OV, seg=6, rings=4, mat=MAT_OVER)  # knee
        l.box((0.1, 0.02, 0.08), (s * 0.1, 0.06, 0.55), OV2, mat=MAT_OVER)  # knee patch
        l.cyl(0.075, 0.075, 0.045, (s * 0.1, 0.0, 0.16), OV2, seg=8, mat=MAT_OVER)  # rolled cuff
        l.box((0.12, 0.28, 0.1), (s * 0.1, 0.06, 0.05), BOOT)  # boot
        l.box((0.126, 0.285, 0.02), (s * 0.1, 0.06, 0.01), "#2A1E14")  # sole
        l.box((0.13, 0.1, 0.07), (s * 0.1, 0.13, 0.04), "#2E2218")  # toe cap
        l.cyl(0.075, 0.078, 0.04, (s * 0.1, 0.0, 0.12), "#2E2218", seg=8)  # boot top
        for k in range(3):  # laces
            l.box((0.06, 0.012, 0.008), (s * 0.1, 0.1 + 0.0 * k, 0.1 + 0.0 * k), "#C8C0A8") if False else None
        l.box((0.07, 0.01, 0.01), (s * 0.1, 0.075, 0.105), "#C8C0A8")
        l.box((0.07, 0.01, 0.01), (s * 0.1, 0.1, 0.095), "#C8C0A8")
        l.done()


def sstep(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


BONES = {  # name: (head, tail, parent)
    "hips": ((0, 0, 0.98), (0, 0, 1.1), None),
    "spine": ((0, 0, 1.1), (0, 0, 1.45), "hips"),
    "head": ((0, 0, 1.5), (0, 0, 1.78), "spine"),
    "hat": ((0, 0, 1.74), (0, 0, 1.84), "head"),  # attach the role hat here (BoneAttachment3D); hat.glb origin is its band bottom
    "arm_l": ((-0.23, 0, 1.5), (-0.25, 0.02, 1.22), "spine"),
    "forearm_l": ((-0.25, 0.02, 1.22), (-0.25, 0.1, 0.9), "arm_l"),
    "arm_r": ((0.23, 0, 1.5), (0.25, 0.02, 1.22), "spine"),
    "forearm_r": ((0.25, 0.02, 1.22), (0.25, 0.1, 0.9), "arm_r"),
    "thigh_l": ((-0.1, 0, 0.98), (-0.1, 0.02, 0.5), "hips"),
    "shin_l": ((-0.1, 0.02, 0.5), (-0.1, 0, 0.05), "thigh_l"),
    "thigh_r": ((0.1, 0, 0.98), (0.1, 0.02, 0.5), "hips"),
    "shin_r": ((0.1, 0.02, 0.5), (0.1, 0, 0.05), "thigh_r"),
}


def make_armature():
    ad = bpy.data.armatures.new("Armature")
    ob = bpy.data.objects.new("Armature", ad)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for nm, (hd, tl, _) in BONES.items():
        b = ad.edit_bones.new(nm)
        b.head, b.tail, b.roll = hd, tl, 0.0
    for nm, (_, _, par) in BONES.items():
        if par:
            ad.edit_bones[nm].parent = ad.edit_bones[par]
            ad.edit_bones[nm].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    B.Ctx.objs.append(ob)
    return ob


def weights(ob, arm):
    n = ob.name
    side = "l" if n.endswith("L") else "r"
    for v in ob.data.vertices:
        z = v.co.z + ob.location.z
        if n == "Torso":
            t = sstep((z - 1.1) / 0.14)
            w = {"hips": 1 - t, "spine": t}
        elif n == "Head":
            w = {"head": 1.0}
        elif n.startswith("Arm"):
            t = sstep((1.28 - z) / 0.12)
            w = {"arm_" + side: 1 - t, "forearm_" + side: t}
        else:
            t = sstep((0.56 - z) / 0.12)
            w = {"thigh_" + side: 1 - t, "shin_" + side: t}
        for bone, wt in w.items():
            if wt > 1e-4:
                g = ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
                g.add([v.index], wt, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


FPS = 24
D = math.radians


def tracks_walk(run=False):
    n = 16 if run else 24
    amp, flex, arm_amp, lean, bob = (40, 70, 55, -9, 0.06) if run else (22, 45, 24, -2, 0.045)
    t = {}
    for f in range(0, n + 1, 2 if run else 3):
        ph = f / n * math.tau
        for s, side in ((0, "l"), (math.pi, "r")):
            c, sn = math.cos(ph + s), math.sin(ph + s)
            t.setdefault("thigh_" + side, {})[f] = (amp * c, 0, 0)
            t.setdefault("shin_" + side, {})[f] = (-(8 + flex * max(0.0, -sn)), 0, 0)
            t.setdefault("arm_" + side, {})[f] = (-arm_amp * c, 0, 3 if side == "l" else -3)
            t.setdefault("forearm_" + side, {})[f] = ((50 if run else 18) - (25 if run else 10) * c * (1 if side == "l" else -1) * -1 * -1, 0, 0)
        t.setdefault("hips", {})[f] = (0, 0, 4 * math.sin(ph) * (1.5 if run else 1), (0, -bob * math.cos(ph) ** 2, 0))
        t.setdefault("spine", {})[f] = (lean, 0, -3 * math.sin(ph) * (2 if run else 1))
        t.setdefault("head", {})[f] = (-lean * 0.6, 0, 0)
    return n, t


def tracks_idle():
    t, n = {}, 48
    for f in (0, 12, 24, 36, 48):
        ph = f / n * math.tau
        b = math.sin(ph)
        t.setdefault("spine", {})[f] = (-0.8 * b, 0, 0)
        t.setdefault("head", {})[f] = (0.6 * b, 0, 1.5 * math.sin(ph + 1.0) * 0.0)
        t.setdefault("arm_l", {})[f] = (-2 * b, 0, 3)
        t.setdefault("arm_r", {})[f] = (-2 * b, 0, -3)
        t.setdefault("forearm_l", {})[f] = (6 + 1.5 * b, 0, 0)
        t.setdefault("forearm_r", {})[f] = (6 + 1.5 * b, 0, 0)
        t.setdefault("hips", {})[f] = (0, 0, 1.2 * math.sin(ph), (0, -0.004 * (1 + math.cos(2 * ph)), 0))
    return n, t


def tracks_crouch():
    t, n = {}, 48
    for f in (0, 12, 24, 36, 48):
        b = math.sin(f / n * math.tau)
        t["hips"] = t.get("hips", {})
        t["hips"][f] = (0, 0, 0, (0, -0.4 - 0.004 * b, 0.27))
        for side in "lr":
            t.setdefault("thigh_" + side, {})[f] = (68, 0, 0)
            t.setdefault("shin_" + side, {})[f] = (-105, 0, 0)
        t.setdefault("spine", {})[f] = (-26 - 1.0 * b, 0, 0)
        t.setdefault("head", {})[f] = (22 + 1.0 * b, 0, 0)
        t.setdefault("arm_l", {})[f] = (22, 0, 4)
        t.setdefault("arm_r", {})[f] = (22, 0, -4)
        t.setdefault("forearm_l", {})[f] = (30, 0, 0)
        t.setdefault("forearm_r", {})[f] = (30, 0, 0)
    return n, t


def hold(frames, vals):
    return {f: v for f, v in zip(frames, vals)}


def tracks_interact():  # right hand reaches out, presses, comes back
    F = (0, 5, 9, 12, 20)
    t = {
        "arm_r": hold(F, [(0, 0, -3), (62, 0, -8), (78, 0, -8), (72, 0, -8), (0, 0, -3)]),
        "forearm_r": hold(F, [(6, 0, 0), (25, 0, 0), (12, 0, 0), (20, 0, 0), (6, 0, 0)]),
        "spine": hold(F, [(0, 0, 0), (-8, 0, -4), (-12, 0, -4), (-10, 0, -4), (0, 0, 0)]),
        "head": hold(F, [(0, 0, 0), (8, 0, 0), (10, 0, 0), (8, 0, 0), (0, 0, 0)]),
        "hips": hold(F, [(0, 0, 0, (0, 0, 0)), (0, 0, 0, (0, -0.02, 0)), (0, 0, 0, (0, -0.03, 0)), (0, 0, 0, (0, -0.02, 0)), (0, 0, 0, (0, 0, 0))]),
    }
    return 20, t


def tracks_wave():
    F = (0, 6, 10, 14, 18, 22, 26, 30, 38)
    sw = [-22, -52, -22, -52, -22, -52, -22, -52, -22]  # forearm swing
    t = {
        "arm_r": hold(F, [(0, 0, -3), (0, 0, -105), (0, 0, -112), (0, 0, -112), (0, 0, -112), (0, 0, -112), (0, 0, -112), (0, 0, -105), (0, 0, -3)]),
        "forearm_r": hold(F, [(6, 0, 0), (0, 0, sw[1] * 0.4), (0, 0, sw[2]), (0, 0, sw[3]), (0, 0, sw[4]), (0, 0, sw[5]), (0, 0, sw[6]), (0, 0, -20), (6, 0, 0)]),
        "head": hold(F, [(0, 0, 0), (0, 0, -4), (0, 0, -6), (0, 0, -6), (0, 0, -6), (0, 0, -6), (0, 0, -6), (0, 0, -3), (0, 0, 0)]),
        "spine": hold(F, [(0, 0, 0), (0, 0, 2), (0, 0, 3), (0, 0, 3), (0, 0, 3), (0, 0, 3), (0, 0, 3), (0, 0, 2), (0, 0, 0)]),
    }
    return 38, t


def tracks_point():
    F = (0, 7, 12, 22, 30)
    t = {
        "arm_r": hold(F, [(0, 0, -3), (80, 0, -10), (88, 0, -8), (88, 0, -8), (0, 0, -3)]),
        "forearm_r": hold(F, [(6, 0, 0), (4, 0, 0), (2, 0, 0), (2, 0, 0), (6, 0, 0)]),
        "spine": hold(F, [(0, 0, 0), (-3, 0, -5), (-3, 0, -6), (-3, 0, -6), (0, 0, 0)]),
        "head": hold(F, [(0, 0, 0), (2, 0, 0), (3, 0, 0), (3, 0, 0), (0, 0, 0)]),
    }
    return 30, t


def tracks_shrug():
    F = (0, 8, 14, 22, 30)
    t = {}
    for side, sg in (("l", 1), ("r", -1)):  # +z swings left limbs outward, -z right
        t["arm_" + side] = hold(F, [(0, 0, 3 * sg), (14, 0, 38 * sg), (14, 0, 42 * sg), (14, 0, 42 * sg), (0, 0, 3 * sg)])
        t["forearm_" + side] = hold(F, [(6, 0, 0), (62, 0, 0), (66, 0, 0), (66, 0, 0), (6, 0, 0)])
    t["head"] = hold(F, [(0, 0, 0), (-4, 0, 8), (-6, 0, 10), (-6, 0, 10), (0, 0, 0)])
    t["spine"] = hold(F, [(0, 0, 0), (2, 0, 0), (3, 0, 0), (3, 0, 0), (0, 0, 0)])
    return 30, t


def tracks_scream():
    F = (0, 4, 8, 12, 16, 20, 24, 28, 32, 40)
    t = {
        "head": hold(F, [(0, 0, 0), (-8, 0, 0), (26, 0, 0), (28, 0, 3), (28, 0, -3), (28, 0, 3), (28, 0, -3), (26, 0, 0), (10, 0, 0), (0, 0, 0)]),
        "spine": hold(F, [(0, 0, 0), (-6, 0, 0), (10, 0, 0), (12, 0, 0), (12, 0, 0), (12, 0, 0), (12, 0, 0), (10, 0, 0), (4, 0, 0), (0, 0, 0)]),
        "hips": hold(F, [(0, 0, 0, (0, 0, 0))] * 10),
    }
    for side, sg in (("l", 1), ("r", -1)):
        t["arm_" + side] = hold(F, [(0, 0, 3 * sg), (20, 0, 10 * sg), (-10, 0, 80 * sg), (-10, 0, 85 * sg), (-10, 0, 78 * sg), (-10, 0, 85 * sg), (-10, 0, 78 * sg),
                                    (-10, 0, 80 * sg), (4, 0, 20 * sg), (0, 0, 3 * sg)])
        t["forearm_" + side] = hold(F, [(6, 0, 0), (40, 0, 0), (30, 0, 0), (30, 0, 0), (30, 0, 0), (30, 0, 0), (30, 0, 0), (30, 0, 0), (20, 0, 0), (6, 0, 0)])
        t["thigh_" + side] = hold(F, [(0, 0, 0), (-4, 0, 0), (-8, 0, 0), (-8, 0, 0), (-8, 0, 0), (-8, 0, 0), (-8, 0, 0), (-8, 0, 0), (-3, 0, 0), (0, 0, 0)])
    return 40, t


ANIMS = {"idle": tracks_idle, "walk": lambda: tracks_walk(False), "run": lambda: tracks_walk(True), "crouch": tracks_crouch,
         "interact": tracks_interact, "wave": tracks_wave, "point": tracks_point, "shrug": tracks_shrug, "scream": tracks_scream}
# Loop on import: idle, walk, run, crouch. The rest are one-shots that start and end at the rest pose.
LOOPING = ("idle", "walk", "run", "crouch")


def make_actions(arm):
    ad = arm.animation_data_create()
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    for name, fn in ANIMS.items():
        n, tr = fn()
        act = bpy.data.actions.new(name)
        ad.action = act
        for pb in arm.pose.bones:  # back to rest before keying
            pb.rotation_euler = (0, 0, 0)
            pb.location = (0, 0, 0)
        for bone, frames in tr.items():
            pb = arm.pose.bones[bone]
            for f, v in sorted(frames.items()):
                pb.rotation_euler = (D(v[0]), D(v[1]), D(v[2]))
                pb.keyframe_insert("rotation_euler", frame=f + 1)
                if len(v) > 3:
                    pb.location = v[3]
                    pb.keyframe_insert("location", frame=f + 1)
        slot0 = ad.action_slot if hasattr(ad, "action_slot") else None
        trk = ad.nla_tracks.new()
        trk.name = name
        strip = trk.strips.new(name, 1, act)
        if slot0 is not None and hasattr(strip, "action_slot"):
            strip.action_slot = slot0
        ad.action = None


def build_farmer(name="char_farmer"):
    B.reset()
    B.Ctx.jitter = 0.0
    extra_materials()
    farmer_parts()
    arm = make_armature()
    for ob in list(B.Ctx.objs):
        if ob.type == "MESH":
            weights(ob, arm)
    bpy.context.view_layer.objects.active = arm
    make_actions(arm)
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    tris, lo, hi = 0, Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for ob in B.Ctx.objs:
        if ob.type != "MESH":
            continue
        ob.data.calc_loop_triangles()
        tris += len(ob.data.loop_triangles)
        for v in ob.data.vertices:
            w = ob.matrix_world @ v.co
            lo = Vector((min(lo[i], w[i]) for i in range(3)))
            hi = Vector((max(hi[i], w[i]) for i in range(3)))
    d = hi - lo
    print(f"BUILD {name}: {tris} tris (farmer 4000 {'ok' if tris <= 4000 else 'OVER BUDGET'}) w{d.x:.2f} d{d.y:.2f} h{d.z:.2f} zmin{lo.z:.2f}")
    bpy.ops.object.select_all(action="DESELECT")
    for ob in B.Ctx.objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(B.OUT_GLB, name + ".glb"), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=False, export_materials="EXPORT", export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_skins=True, export_def_bones=False, export_optimize_animation_size=False,
                              export_force_sampling=True, export_frame_range=False)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(B.OUT_BLEND, name + ".blend"), compress=True)
    return tris


# ---------------------------------------------------------------- registry
MODELS = [
    ("tool_watering_can", watering_can, "small"),
    ("tool_watering_can_quiet", lambda: watering_can(True), "small"),
    ("tool_walkie_talkie", walkie, "small"),
    ("tool_walkie_battery", walkie_battery, "small"),
    ("tool_flare_gun", flare_gun, "small"),
    ("tool_shed_lock", shed_lock, "small"),
    ("tool_scrap", scrap, "small"),
    ("tool_seed_packet_turnip", lambda: seed_packet("#CFC3D8", "turnip"), "small"),
    ("tool_seed_packet_pumpkin", lambda: seed_packet("#C8761F", "pumpkin"), "small"),
    ("tool_seed_packet_moonflower", lambda: seed_packet("#7FE6D8", "moon"), "small"),
    ("prop_cart", cart, "large"),
    ("prop_cart_pumpkin_slot", lambda: slot(False), "mid"),
    ("prop_cart_pumpkin_slot_bitten", lambda: slot(True), "mid"),
    ("prop_shipping_crate", crate, "large"),
    ("prop_scarecrow_player", scarecrow_player, "large"),
    ("creature_scarecrow", scarecrow_body_lvl, "creature"),
    ("creature_smear_scarecrow", lambda: (scarecrow_body_lvl(), B.hull_of("Smear")), "creature"),
]

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for nm, fn, cls in MODELS:
        if not only or nm in only:
            B.build(nm, fn, cls)
    if not only or "char_farmer" in only:
        build_farmer()

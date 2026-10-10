"""P5-14 missing models, buildings group (Q-266, D-159): barn, shed, farmhouse, well, fences, gates, doors.

  sh tools/blender/run.sh tools/blender/build_p5_14.py [-- name ...]

Same conventions as build_p5_12.py (1 unit = 1 m, model FRONT is +Y in Blender = glTF/Godot -Z, vertex colour layer
"Col", material mat_flat_lit, node names = Part names). Blender (x, y, z) is Godot (x, -z, y), so a building whose
interior runs Godot -Z from its door (barn, farmhouse) has its door on the -Y face and its interior at +Y, and the
shed (interior Godot +Z) has its door on the +Y face and its interior at -Y.

Sizes come from the gray-box in game/world/build_farm.py (building(), props, pen, GateN/S posts), measured, not
from the doc 07 table alone: wall boxes are 0.3 thick and centred on the footprint lines, the door gap is 3 m wide
and open to the full wall height, wall heights are barn 5, farmhouse 4, shed 3. Doc 07 s11 total heights (9, 7, 3.2)
are met by the roof. Interior pieces hug the walls: the gray-box has no interior collision, so nothing here may
stand in the walkable floor below head height.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_phase4 as B  # noqa: E402
from build_phase4 import Ctx, BRASS, IRON, WOOD, WOOD2, Part, empty  # noqa: E402
from build_p5_12 import STRAW, tube  # noqa: E402

RED, RED2, TRIM, GREY, GREY2 = "#9A3B2B", "#7F2F22", "#D8CDB4", "#8A8277", "#6F695F"
ROOF, ROOF2, STONE, FLOOR, FLOOR2 = "#4A4D52", "#3C3F44", "#6B6F72", "#6B5A44", "#5E4E3A"
CREAM, CREAM2, BRICK, TEAL, GLASS = "#D1C7A8", "#BDB391", "#8A4A3A", "#4E6B5A", "#26343E"
HAY = "#C9B26A"
SUPERSEDED_P5_14 = set()


# ---------------------------------------------------------------- helpers
def bx(p, xs, ys, zs, col):
    """Box from extents (lo, hi) on each axis."""
    return p.box((xs[1] - xs[0], ys[1] - ys[0], zs[1] - zs[0]), ((xs[0] + xs[1]) / 2, (ys[0] + ys[1]) / 2, (zs[0] + zs[1]) / 2), col)


def beam(p, a, b, w, col):
    return p.between(a, b, w, w, col, seg=4)


def prism(p, pts, axis, c, th, col):
    """Flat polygon (u, v) extruded th thick, centred on c along `axis`. axis y: profile in (x, z); axis x: profile in (y, z)."""
    bm = p.bm
    rings = []
    for off in (-th / 2, th / 2):
        ring = []
        for u, v in pts:
            co = (u, c + off, v) if axis == "y" else (c + off, u, v)
            ring.append(bm.verts.new(co))
        rings.append(ring)
    n = len(pts)
    faces = [bm.faces.new(rings[0]), bm.faces.new(rings[1][::-1])]
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    verts = [v for r in rings for v in r]
    p._fin(verts, col, B.MAT_FLAT)


def panel(p, axis, a, b, th, e0, e1, col):
    """Thin roof panel along the profile line a -> b, extruded e0..e1. axis y: extent along y, profile (x, z);
    axis x: extent along x, profile (y, z)."""
    (u0, v0), (u1, v1) = a, b
    L = math.hypot(u1 - u0, v1 - v0)
    mid_u, mid_v, mid_e = (u0 + u1) / 2, (v0 + v1) / 2, (e0 + e1) / 2
    if axis == "y":
        p.box((L, e1 - e0, th), (mid_u, mid_e, mid_v), col, rot=(0, -math.atan2(v1 - v0, u1 - u0), 0))
    else:
        p.box((e1 - e0, L, th), (mid_e, mid_u, mid_v), col, rot=(math.atan2(v1 - v0, u1 - u0), 0, 0))


def window(p, wall_axis, c, along, z, w, h, sgn, trim=TRIM, shutters=None):
    """Window on a wall whose centre line is wall_axis=c (x or y), at position `along` on the other axis.
    Dark pane through the wall, trim on the outside (sgn = +1 outward is +axis). Returns the glow-card position."""
    def at(a, o, zz):  # a along the wall, o offset from the wall line (outward positive)
        return (c + sgn * o, a, zz) if wall_axis == "x" else (a, c + sgn * o, zz)

    def sz(sa, so, sh):
        return (so, sa, sh) if wall_axis == "x" else (sa, so, sh)
    p.box(sz(w, 0.34, h), at(along, 0, z), GLASS)
    for dz in (-h / 2, h / 2):
        p.box(sz(w + 0.16, 0.08, 0.08), at(along, 0.17, z + dz), trim)
    for da in (-w / 2, w / 2):
        p.box(sz(0.08, 0.08, h + 0.08), at(along + da, 0.17, z), trim)
    p.box(sz(0.04, 0.08, h), at(along, 0.17, z), trim)  # mullion
    p.box(sz(w, 0.08, 0.04), at(along, 0.17, z), trim)
    if shutters:
        for da in (-1, 1):
            p.box(sz(w * 0.5, 0.05, h), at(along + da * (w / 2 + w * 0.3), 0.14, z), shutters)
    out = (0, 1) if wall_axis == "y" else (1, 0)  # outward is sgn along the wall's normal axis
    return at(along, 0.2, z), math.atan2(sgn * out[0], -sgn * out[1])  # card faces Blender -Y (Godot +Z) at yaw 0


# ---------------------------------------------------------------- barn (16 x 20, walls 5, ridge 9)
def barn():
    X, Y, WH, DW, DH = 8.0, 20.0, 5.0, 1.5, 3.4  # half width, depth, wall height, half door gap, door opening height
    E, K, R = (8.45, 4.85), (5.4, 7.3), (0.0, 8.94)  # gambrel profile (x, z): eave, knee, ridge
    w = Part("Walls")
    for sx in (-1, 1):  # side walls
        bx(w, (sx * X - 0.15, sx * X + 0.15), (-0.15, Y + 0.15), (0, WH), RED)
        bx(w, sorted((sx * (X + 0.15), sx * (X + 0.21))), (-0.2, Y + 0.2), (0, 0.45), STONE)  # foundation skirt
        for y in [0.5 + i * 1.0 for i in range(20)]:  # board battens
            bx(w, sorted((sx * (X + 0.15), sx * (X + 0.19))), (y - 0.05, y + 0.05), (0.45, WH - 0.1), RED2)
    for sx in (-1, 1):  # front wall, two pieces and the door header
        bx(w, sorted((sx * DW, sx * (X + 0.15))), (-0.15, 0.15), (0, WH), RED)
        bx(w, sorted((sx * DW, sx * (X + 0.15))), (-0.21, -0.15), (0, 0.45), STONE)
        for x in [DW + 0.3 + i * 0.9 for i in range(7)]:
            bx(w, (sx * x - 0.05, sx * x + 0.05), (-0.19, -0.15), (0.45, WH - 0.1), RED2)
    bx(w, (-DW, DW), (-0.15, 0.15), (DH, WH), RED)
    for x in (-1.2, -0.6, 0, 0.6, 1.2):
        bx(w, (x - 0.05, x + 0.05), (-0.19, -0.15), (DH, WH - 0.1), RED2)
    bx(w, (-X - 0.15, X + 0.15), (Y - 0.15, Y + 0.15), (0, WH), RED)  # back wall
    bx(w, (-X - 0.2, X + 0.2), (Y + 0.15, Y + 0.21), (0, 0.45), STONE)
    for x in [-7.5 + i * 1.0 for i in range(16)]:
        bx(w, (x - 0.05, x + 0.05), (Y + 0.15, Y + 0.19), (0.45, WH - 0.1), RED2)
    gable = [(-X, WH), (X, WH), (5.3, 7.2), (0.0, 8.8), (-5.3, 7.2)]
    prism(w, gable, "y", 0.0, 0.3, RED)  # front gable fill
    prism(w, gable, "y", Y, 0.3, RED)  # back gable fill
    for yy, s in ((-0.17, -1), (Y + 0.17, 1)):  # gable battens
        for x in (-4.5, -3, -1.5, 0, 1.5, 3, 4.5):
            top = 8.8 - abs(x) * 0.32 - 0.1
            bx(w, (x - 0.05, x + 0.05), sorted((yy, yy + s * 0.04)), (WH + 0.05, top), RED2)
    for sx in (-1, 1):  # corner boards
        for y0 in (0, Y):
            bx(w, (sx * X - 0.2 + sx * 0.0 - 0.0, sx * X + 0.2) if sx > 0 else (sx * X - 0.2, sx * X + 0.2), (y0 - 0.2, y0 + 0.2), (0, WH), TRIM)
    for sx in (-1, 1):  # door trim: jambs, lintel, sliding rail with brackets
        bx(w, sorted((sx * 1.5, sx * 1.72)), (-0.3, 0.15), (0, DH + 0.2), TRIM)
    bx(w, (-1.72, 1.72), (-0.3, 0.15), (DH, DH + 0.2), TRIM)
    bx(w, (-2.4, 2.4), (-0.4, -0.3), (DH + 0.3, DH + 0.4), IRON)  # sliding rail
    for x in (-2.2, -0.8, 0.8, 2.2):
        bx(w, (x - 0.04, x + 0.04), (-0.4, -0.15), (DH + 0.2, DH + 0.4), IRON)
    # hayloft door in the front gable, hoist beam above it
    bx(w, (-0.7, 0.7), (-0.2, 0.15), (6.0, 7.2), GLASS)
    for dz in (6.0, 7.2):
        bx(w, (-0.82, 0.82), (-0.28, -0.15), (dz - 0.06, dz + 0.06), TRIM)
    for dx in (-0.7, 0.7):
        bx(w, (dx - 0.06, dx + 0.06), (-0.28, -0.15), (6.0, 7.2), TRIM)
    bx(w, (-0.08, 0.08), (-1.0, -0.1), (8.0, 8.16), WOOD2)  # hoist beam
    glows = []
    for sx in (-1, 1):  # four high side windows
        for y in (7.0, 13.0):
            glows.append(window(w, "x", sx * X, y, 3.1, 0.9, 1.1, sx))
    for x in (-5.5, 5.5):  # two ground-level front windows with shutters
        glows.append(window(w, "y", 0.0, x, 2.0, 0.9, 1.1, -1, shutters=RED2))
    w.done()

    r = Part("Roof")
    for sx in (-1, 1):
        panel(r, "y", (sx * E[0], E[1]), (sx * K[0], K[1]), 0.14, -0.45, Y + 0.45, ROOF)
        panel(r, "y", (sx * K[0], K[1]), (sx * R[0], R[1]), 0.14, -0.45, Y + 0.45, ROOF)
    bx(r, (-0.25, 0.25), (-0.45, Y + 0.45), (R[1] - 0.04, R[1] + 0.1), ROOF2)  # ridge cap
    for sx in (-1, 1):  # trim along the eaves
        bx(r, sorted((sx * 8.3, sx * 8.6)), (-0.45, Y + 0.45), (4.78, 4.92), TRIM)
    r.done()

    i = Part("Interior")
    for k in range(10):
        bx(i, (-7.85 + k * 1.57, -7.85 + (k + 1) * 1.57 - 0.03), (0.1, Y - 0.1), (0, 0.03), FLOOR if k % 2 else FLOOR2)
    for y in (1.5, 5.5, 9.5, 13.5, 17.5):  # trusses: tie beam, knee braces, rafters under both slopes
        bx(i, (-X, X), (y - 0.1, y + 0.1), (4.75, 4.95), WOOD2)
        for sx in (-1, 1):
            beam(i, (sx * 7.8, y, 4.7), (sx * 6.2, y, 5.7), 0.07, WOOD)
        for sx in (-1, 1):
            i.between((sx * 8.3, y, 4.75), (sx * 5.4, y, 7.2), 0.08, 0.08, WOOD2, seg=4)
            i.between((sx * 5.4, y, 7.2), (0.0, y, 8.78), 0.08, 0.08, WOOD2, seg=4)
        i.between((0.0, y, 4.95), (0.0, y, 8.7), 0.06, 0.06, WOOD, seg=4)  # king post
    for sx in (-1, 1):  # long purlins at the knee and eave plates
        bx(i, sorted((sx * 5.2, sx * 5.5)), (0, Y), (7.1, 7.3), WOOD2)
        bx(i, sorted((sx * 7.7, sx * 7.85)), (0, Y), (4.7, 5.0), WOOD2)
    # hayloft over the back 4 m, deck at 3.6, held by the walls and two wall posts
    bx(i, (-7.85, 7.85), (16.0, 19.85), (3.5, 3.62), FLOOR2)
    for sx in (-1, 1):
        bx(i, sorted((sx * 7.6, sx * 7.85)), (15.9, 16.1), (0, 3.5), WOOD2)  # post against the side wall
    bx(i, (-7.85, 7.85), (15.9, 16.1), (3.4, 3.5), WOOD2)  # front beam
    bx(i, (-7.85, 7.85), (15.92, 15.98), (3.62, 4.4), WOOD)  # rail
    for sx, y, z in ((-1, 18.8, 3.62), (1, 19.0, 3.62), (-1, 18.8, 4.12), (-1, 17.4, 3.62)):  # hay bales on the loft
        bx(i, sorted((sx * 7.0, sx * 5.8)), (y - 0.5, y + 0.5), (z, z + 0.5), HAY)
    for z in (0.4, 0.8, 1.2, 1.6, 2.0, 2.4, 2.8, 3.2):  # ladder up the east wall to the loft
        bx(i, (7.5, 7.84), (15.0, 15.8), (z, z + 0.04), WOOD)
    for y in (15.0, 15.8):
        bx(i, (7.5, 7.84), (y - 0.03, y + 0.03), (0, 3.7), WOOD2)
    for y0, z0 in ((19.3, 0.0), (18.2, 0.0), (19.3, 0.5)):  # hay stack, back-west corner
        bx(i, (-7.85, -6.65), (y0 - 0.5, y0 + 0.5), (z0, z0 + 0.5), HAY)
    for y0 in (2.0, 3.2):  # crates along the east wall by the door
        bx(i, (6.9, 7.85), (y0, y0 + 0.9), (0, 0.8), WOOD)
        bx(i, (6.88, 7.0), (y0, y0 + 0.9), (0.35, 0.45), WOOD2)
    i.cyl(0.35, 0.33, 0.9, (-7.3, 4.0, 0.45), WOOD2, seg=8)  # barrels against the west wall
    i.cyl(0.35, 0.33, 0.9, (-7.3, 5.0, 0.45), WOOD, seg=8)
    for z in (0.25, 0.65):
        i.cyl(0.36, 0.36, 0.04, (-7.3, 4.0, z), IRON, seg=8)
    i.done()
    empty("Door", (0, 0, 0))
    for k, (g, yaw) in enumerate(glows, 1):
        empty(f"WindowGlow_{k}", g)
        Ctx.objs[-1].rotation_euler.z = yaw
    empty("PorchLightMount", (2.0, -0.2, 3.0))
    empty("BarnLanternHook", (-5, 17, 2.4))


# ---------------------------------------------------------------- farmhouse (12 x 10, walls 4, ridge 7)
def farmhouse():
    X, Y, WH, DW, DH = 6.0, 10.0, 4.0, 1.5, 2.7
    RZ = 6.6
    w = Part("Walls")
    for sx in (-1, 1):  # gable-end walls (x = +-6), full length
        bx(w, (sx * X - 0.15, sx * X + 0.15), (-0.15, Y + 0.15), (0, WH), CREAM)
        prism(w, [(0.0, WH), (Y, WH), (Y / 2, RZ - 0.15)], "x", sx * X, 0.3, CREAM)
        bx(w, sorted((sx * (X + 0.15), sx * (X + 0.21))), (-0.2, Y + 0.2), (0, 0.4), STONE)
        for y in [0.5 + k * 1.0 for k in range(10)]:  # clapboard lines
            bx(w, sorted((sx * (X + 0.15), sx * (X + 0.18))), (y - 0.02, y + 0.02), (0.4, WH), CREAM2)
    for sx in (-1, 1):  # front wall, two pieces and the door header
        bx(w, sorted((sx * DW, sx * (X + 0.15))), (-0.15, 0.15), (0, WH), CREAM)
        bx(w, sorted((sx * DW, sx * (X + 0.15))), (-0.2, -0.15), (0, 0.4), STONE)
        for z in [0.7 + k * 0.3 for k in range(11)]:
            bx(w, sorted((sx * DW, sx * (X + 0.15))), (-0.18, -0.15), (z - 0.015, z + 0.015), CREAM2)
    bx(w, (-DW, DW), (-0.15, 0.15), (DH, WH), CREAM)
    bx(w, (-X - 0.15, X + 0.15), (Y - 0.15, Y + 0.15), (0, WH), CREAM)  # back wall
    bx(w, (-X - 0.2, X + 0.2), (Y + 0.15, Y + 0.2), (0, 0.4), STONE)
    for z in [0.7 + k * 0.3 for k in range(11)]:
        bx(w, (-X, X), (Y + 0.15, Y + 0.18), (z - 0.015, z + 0.015), CREAM2)
    for sx in (-1, 1):  # corner boards
        for y0 in (0, Y):
            bx(w, (sx * X - 0.2, sx * X + 0.2), (y0 - 0.2, y0 + 0.2), (0, WH), TRIM)
    for sx in (-1, 1):  # door trim
        bx(w, sorted((sx * 1.5, sx * 1.7)), (-0.25, 0.15), (0, DH + 0.2), TRIM)
    bx(w, (-1.7, 1.7), (-0.25, 0.15), (DH, DH + 0.2), TRIM)
    glows = []
    for x in (-4.2, -2.9, 2.9, 4.2):  # front windows, shutters on the outer pair
        glows.append(window(w, "y", 0.0, x, 2.0, 0.8, 1.3, -1, shutters=TEAL if abs(x) > 3.5 else None))
    for x in (-3.0, 3.0):
        glows.append(window(w, "y", Y, x, 2.0, 0.8, 1.3, 1))
    for sx in (-1, 1):
        for y in (3.0, 7.0):
            glows.append(window(w, "x", sx * X, y, 2.0, 0.8, 1.3, sx))
    # chimney on the east gable, brick, taller than the eave but under 7 m
    bx(w, (X + 0.15, X + 1.15), (4.4, 5.6), (0, 7.0), BRICK)
    bx(w, (X + 0.1, X + 1.2), (4.35, 5.65), (6.7, 7.0), STONE)
    for z in (0.8, 1.6, 2.4, 3.2, 4.0, 4.8, 5.6):
        bx(w, (X + 0.15, X + 1.17), (4.38, 5.62), (z, z + 0.04), "#6E3A2E")
    # porch: deck, two posts outside the 3 m gap, a lean-to roof
    bx(w, (-2.2, 2.2), (-2.3, -0.15), (0, 0.04), WOOD2)
    for k in range(5):
        bx(w, (-2.15 + k * 0.86, -2.15 + (k + 1) * 0.86 - 0.04), (-2.28, -0.17), (0.04, 0.05), WOOD)
    for sx in (-1, 1):
        bx(w, (sx * 2.0 - 0.07, sx * 2.0 + 0.07), (-2.2, -2.06), (0.04, 3.1), TRIM)
        w.between((sx * 2.0, -2.13, 2.6), (sx * 2.0, -1.55, 3.1), 0.05, 0.05, TRIM, seg=4)
    bx(w, (-2.2, 2.2), (-2.3, -2.0), (3.0, 3.1), TRIM)  # porch beam
    w.done()

    r = Part("Roof")
    ra, rb = ((-0.55, WH - 0.15), (Y / 2, RZ)), ((Y + 0.55, WH - 0.15), (Y / 2, RZ))
    for (a, b) in (ra, rb):
        panel(r, "x", a, b, 0.14, -X - 0.5, X + 0.5, ROOF)
    bx(r, (-X - 0.5, X + 0.5), (Y / 2 - 0.2, Y / 2 + 0.2), (RZ - 0.03, RZ + 0.09), ROOF2)  # ridge cap
    panel(r, "x", (-2.45, 3.0), (-0.1, 3.5), 0.1, -2.4, 2.4, ROOF)
    r.done()
    i = Part("Interior")
    for k in range(6):  # floor boards
        bx(i, (-X + 0.15 + k * 1.95, -X + 0.15 + (k + 1) * 1.95 - 0.03), (0.1, Y - 0.1), (0, 0.03), FLOOR if k % 2 else FLOOR2)
    for y in (1.8, 4.0, 6.2, 8.4):  # ceiling beams
        bx(i, (-X, X), (y - 0.1, y + 0.1), (3.85, 4.0), WOOD2)
    # hearth against the east wall (the chimney breast), table and chairs against the back, bed against the west
    bx(i, (X - 1.2, X - 0.15), (4.2, 5.8), (0, 1.3), BRICK)
    bx(i, (X - 1.15, X - 0.14), (4.55, 5.45), (0.1, 0.9), "#1A1412")  # firebox, dark
    bx(i, (X - 1.3, X - 0.1), (4.1, 5.9), (1.3, 1.4), WOOD2)  # mantel
    bx(i, (-1.6, 0.0), (Y - 1.4, Y - 0.2), (0.7, 0.78), WOOD)  # table top against the back wall
    for sx in (-1.5, -0.1):
        for yy in (Y - 1.35, Y - 0.25):
            bx(i, (sx - 0.04, sx + 0.04), (yy - 0.04, yy + 0.04), (0, 0.7), WOOD2)
    bx(i, (-X + 0.15, -X + 1.2), (1.0, 2.1), (0, 0.45), WOOD)  # bed frame against the west wall
    bx(i, (-X + 0.2, -X + 1.15), (1.05, 2.05), (0.45, 0.6), CREAM2)
    bx(i, (-X + 0.2, -X + 0.7), (1.05, 1.45), (0.6, 0.7), TRIM)  # pillow
    bx(i, (-X + 0.15, -X + 0.7), (7.6, 9.0), (0, 1.8), WOOD2)  # cabinet against the west wall
    bx(i, (-X + 0.7, -X + 0.74), (7.7, 8.28), (0.2, 1.7), WOOD)
    bx(i, (-X + 0.7, -X + 0.74), (8.32, 8.9), (0.2, 1.7), WOOD)
    i.done()
    empty("Door", (0, 0, 0))
    for k, (g, yaw) in enumerate(glows, 1):
        empty(f"WindowGlow_{k}", g)
        Ctx.objs[-1].rotation_euler.z = yaw
    empty("PorchLightMount", (1.85, -0.2, 2.5))


# ---------------------------------------------------------------- tool shed (6 x 5, walls 3, roof to 3.3)
def shed():
    X, Y, WH, DW, DH = 3.0, 5.0, 3.0, 1.5, 2.6  # interior runs to -Y; door on the +Y face
    w = Part("Walls")
    for sx in (-1, 1):
        bx(w, (sx * X - 0.15, sx * X + 0.15), (-Y - 0.15, 0.15), (0, 3.2), GREY)
        for y in [-0.4 - k * 0.5 for k in range(10)]:
            bx(w, sorted((sx * (X + 0.15), sx * (X + 0.18))), (y - 0.01, y + 0.01), (0, 3.15), GREY2)
        bx(w, sorted((sx * (X + 0.15), sx * (X + 0.2))), (-Y - 0.2, 0.2), (0, 0.3), STONE)
        bx(w, sorted((sx * DW, sx * (X + 0.15))), (-0.15, 0.15), (0, 3.2), GREY)
        for x in [DW + 0.3 + k * 0.5 for k in range(3)]:
            bx(w, (sx * x - 0.02, sx * x + 0.02), (0.15, 0.18), (0.3, 3.15), GREY2)
        bx(w, sorted((sx * DW, sx * (X + 0.15))), (0.15, 0.2), (0, 0.3), STONE)
    bx(w, (-DW, DW), (-0.15, 0.15), (DH, 3.2), GREY)
    bx(w, (-X - 0.15, X + 0.15), (-Y - 0.15, -Y + 0.15), (0, 3.2), GREY)
    for x in [-2.75 + k * 0.5 for k in range(12)]:
        bx(w, (x - 0.02, x + 0.02), (-Y - 0.18, -Y - 0.15), (0, 3.15), GREY2)
    for sx in (-1, 1):  # door trim
        bx(w, sorted((sx * 1.5, sx * 1.68)), (-0.1, 0.25), (0, DH + 0.15), "#B8AE98")
    bx(w, (-1.68, 1.68), (-0.1, 0.25), (DH, DH + 0.15), "#B8AE98")
    glows = []
    for sx in (-1, 1):
        glows.append(window(w, "x", sx * X, -2.5, 1.9, 0.7, 0.7, sx, trim="#B8AE98"))
    w.done()
    r = Part("Roof")
    panel(r, "x", (0.55, 3.2), (-Y - 0.55, 3.38), 0.12, -X - 0.4, X + 0.4, "#5A4A3A")  # pent roof rising to the back
    bx(r, (-X - 0.4, X + 0.4), (0.4, 0.58), (3.1, 3.3), "#B8AE98")  # fascia over the door
    r.done()
    i = Part("Interior")
    for k in range(6):
        bx(i, (-X + 0.15 + k * 0.95, -X + 0.15 + (k + 1) * 0.95 - 0.03), (-Y + 0.1, -0.1), (0, 0.03), FLOOR if k % 2 else FLOOR2)
    for sx in (-1, 1):  # shelves hugging the side walls
        for z in (0.5, 1.1, 1.7, 2.3):
            bx(i, sorted((sx * (X - 0.15), sx * (X - 0.5))), (-4.6, -0.2 - 1.6), (z, z + 0.04), WOOD)
        for y in (-4.6, -3.2, -1.8):
            bx(i, sorted((sx * (X - 0.15), sx * (X - 0.5))), (y - 0.03, y + 0.03), (0, 2.34), WOOD2)
    bx(i, (-X + 0.6, X - 0.6), (-Y + 0.15, -Y + 0.9), (0.8, 0.86), WOOD)  # workbench along the back wall
    for sx in (-1, 1):
        bx(i, (sx * 2.0 - 0.04, sx * 2.0 + 0.04), (-Y + 0.2, -Y + 0.85), (0, 0.8), WOOD2)
    i.done()
    empty("Door", (0, 0, 0))
    empty("Pegboard", (0, -4.5, 1.5))  # gray-box marker position; prop_pegboard (P5-15) is placed here
    for k, (g, yaw) in enumerate(glows, 1):
        empty(f"WindowGlow_{k}", g)
        Ctx.objs[-1].rotation_euler.z = yaw


# ---------------------------------------------------------------- doors: double leaf, 3 m (the gray-box gap), pivots at the jambs
def leaf_geometry(name, kind, sgn, h):
    """One leaf of width 1.49, hinge at local x=0 (pivot at the jamb), extending to +sgn*1.49."""
    W = 1.49
    pt = Part(name, (sgn * 1.5, 0, 0))
    def xs(a, b):
        return sorted((sgn * (1.5 - a), sgn * (1.5 - b)))
    if kind == "barn":
        for k in range(6):  # planks
            pt.box((W / 6 - 0.01, 0.1, h), (sgn * (1.5 - (k + 0.5) * W / 6), 0, h / 2), GREY if k % 2 else "#7A746A")
        for side in (-1, 1):  # frame and Z brace on both faces
            bx(pt, xs(0, W), (side * 0.06 - 0.02, side * 0.06 + 0.02), (0, 0.14), TRIM)
            bx(pt, xs(0, W), (side * 0.06 - 0.02, side * 0.06 + 0.02), (h - 0.14, h), TRIM)
            bx(pt, xs(0, 0.14), (side * 0.06 - 0.02, side * 0.06 + 0.02), (0, h), TRIM)
            bx(pt, xs(W - 0.14, W), (side * 0.06 - 0.02, side * 0.06 + 0.02), (0, h), TRIM)
            a, b = (sgn * 1.36, side * 0.06, 0.14), (sgn * (1.5 - W + 0.14), side * 0.06, h - 0.14)
            beam(pt, a, b, 0.05, TRIM)
        for z in (0.5, h - 0.5):  # iron strap hinges
            bx(pt, xs(0, 0.7), (-0.075, 0.075), (z - 0.05, z + 0.05), IRON)
        bx(pt, xs(W - 0.3, W - 0.2), (-0.1, 0.1), (1.0, 1.5), IRON)  # pull handle
    elif kind == "shed":
        for k in range(5):
            pt.box((W / 5 - 0.01, 0.08, h), (sgn * (1.5 - (k + 0.5) * W / 5), 0, h / 2), "#7A6A56" if k % 2 else "#6A5A48")
        for side in (-1, 1):
            for z in (0.35, h - 0.35):
                bx(pt, xs(0, W), (side * 0.05 - 0.02, side * 0.05 + 0.02), (z - 0.07, z + 0.07), WOOD2)
            beam(pt, (sgn * 1.45, side * 0.05, 0.4), (sgn * (1.5 - W + 0.05), side * 0.05, h - 0.4), 0.04, WOOD2)
        for z in (0.35, h - 0.35):
            bx(pt, xs(0, 0.6), (-0.07, 0.07), (z - 0.04, z + 0.04), IRON)
        bx(pt, xs(W - 0.1, W), (-0.08, 0.08), (1.0, 1.4), IRON)  # handle
    else:  # farmhouse: panelled, upper glass
        pt.box((W - 0.02, 0.08, h), (sgn * (1.5 - W / 2), 0, h / 2), "#6E4A32")
        for side in (-1, 1):
            for z0, z1 in ((0.2, 1.1), (1.25, h - 0.2)):
                bx(pt, xs(0.15, W - 0.15), (side * 0.05 - 0.015, side * 0.05 + 0.015), (z0, z1), "#8A6446")
            bx(pt, xs(0.3, W - 0.3), (side * 0.06 - 0.015, side * 0.06 + 0.015), (1.55, h - 0.45), GLASS)
            bx(pt, xs(W / 2 - 0.02, W / 2 + 0.02), (side * 0.065 - 0.015, side * 0.065 + 0.015), (1.55, h - 0.45), "#6E4A32")
        pt.ball((0.04, 0.04, 0.04), (sgn * (1.5 - W + 0.12), 0.07, 1.05), BRASS, seg=6, rings=4)  # knobs both faces
        pt.ball((0.04, 0.04, 0.04), (sgn * (1.5 - W + 0.12), -0.07, 1.05), BRASS, seg=6, rings=4)
    return pt


def door(kind, h):
    # origin: the threshold centre at the wall's centre line; two leaves hinged at x +-1.5, full gap 3.0
    for sgn, nm in ((-1, "LeafL"), (1, "LeafR")):
        pt = leaf_geometry(nm, kind, sgn, h)
        # leaf parts are built in model space relative to the threshold; done() subtracts the jamb pivot
        pt.done()
    if kind == "shed":
        empty("LockSocket", (0.0, 0.0, 1.2))


# ---------------------------------------------------------------- well (2 m across, 2.2 tall)
def well():
    p = Part("Well")
    tube(p, 1.0, 0.72, 1.0, (0, 0, 0.5), "#8A8780", seg=12)  # stone ring, collision is 2 x 2 x 1
    for z in (0.33, 0.66):
        tube(p, 1.005, 1.0, 0.03, (0, 0, z), "#6B6F72", seg=12)
    tube(p, 1.04, 0.68, 0.08, (0, 0, 1.0), "#7A7770", seg=12)  # cap stones
    p.cyl(0.72, 0.72, 0.02, (0, 0, 0.4), GLASS, seg=12)  # water, dark
    for sx in (-1, 1):  # posts, crossbeam, little gable roof
        p.box((0.14, 0.14, 1.15), (sx * 0.85, 0, 1.55), WOOD2)
        p.between((sx * 0.85, 0, 1.2), (sx * 0.5, 0, 1.7), 0.04, 0.04, WOOD, seg=4)
    p.box((1.95, 0.16, 0.14), (0, 0, 2.0), WOOD2)  # beam, windlass height
    p.cyl(0.09, 0.09, 1.0, (0, 0, 1.85), WOOD, rot=(0, math.pi / 2, 0), seg=8)  # windlass drum
    p.between((0.5, 0, 1.85), (0.75, 0, 1.85), 0.025, 0.025, IRON, seg=4)
    p.between((0.75, 0, 1.85), (0.75, 0.1, 1.55), 0.015, 0.015, IRON, seg=4)  # crank
    panel(p, "y", (-1.2, 1.95), (0.0, 2.2), 0.06, -0.55, 0.55, "#5A4A3A")
    panel(p, "y", (1.2, 1.95), (0.0, 2.2), 0.06, -0.55, 0.55, "#5A4A3A")
    p.between((0.0, 0.0, 1.8), (0.0, 0.0, 1.0), 0.012, 0.012, "#8A7448", seg=3)  # rope
    p.cyl(0.14, 0.12, 0.2, (0, 0, 0.9), WOOD2, seg=8)  # bucket
    p.cyl(0.145, 0.145, 0.02, (0, 0, 0.96), IRON, seg=8)
    p.done()


# ---------------------------------------------------------------- fences and gates (width along X, pivots on the base)
def rail_fence(p, x0, x1, h, rails, post_w=0.12, th=0.1):
    for x in (x0, x1):
        p.box((post_w, th, h), (x, 0, h / 2), WOOD2)
        p.box((post_w + 0.02, th + 0.02, 0.04), (x, 0, h + 0.02), "#6A4A32")
    for z in rails:
        bx(p, (x0, x1), (-0.04, 0.04), (z - 0.045, z + 0.045), WOOD)


def fence_segment():
    p = Part("Fence")
    rail_fence(p, -1.44, 1.44, 1.2, (0.35, 0.7, 1.05))
    p.done()


def fence_gate():
    # 2 m total: posts at +-0.94, leaf hinged at the west post (pivot at its inner face)
    f = Part("Frame")
    for x in (-0.94, 0.94):
        f.box((0.12, 0.12, 1.25), (x, 0, 0.625), WOOD2)
        f.box((0.14, 0.14, 0.04), (x, 0, 1.27), "#6A4A32")
    f.done()
    hx = -0.88
    lf = Part("Leaf", (hx, 0, 0))
    bx(lf, (-0.88, 0.88), (-0.035, 0.035), (0.12, 0.2), WOOD)
    bx(lf, (-0.88, 0.88), (-0.035, 0.035), (0.55, 0.63), WOOD)
    bx(lf, (-0.88, 0.88), (-0.035, 0.035), (0.95, 1.03), WOOD)
    for x in (-0.84, 0.84):
        bx(lf, (x - 0.04, x + 0.04), (-0.035, 0.035), (0.1, 1.05), WOOD2)
    beam(lf, (-0.8, 0.0, 0.2), (0.8, 0.0, 0.95), 0.03, WOOD2)
    for z in (0.16, 0.99):
        bx(lf, (-0.88, -0.6), (-0.045, 0.045), (z - 0.03, z + 0.03), IRON)  # hinge straps
    lf.done()
    empty("Latch", (0.85, 0.0, 0.9))


def farm_gate():
    # 6 m between post centres (the gray-box GatePostN/S), posts 0.3 square, 2.2 tall; two leaves meeting at the middle
    f = Part("Frame")
    for x in (-3.0, 3.0):
        f.box((0.3, 0.3, 2.2), (x, 0, 1.1), WOOD2)
        f.box((0.38, 0.38, 0.08), (x, 0, 2.24), "#6A4A32")
        f.box((0.4, 0.4, 0.3), (x, 0, 0.15), STONE)
    f.done()
    for sgn, nm in ((-1, "LeafL"), (1, "LeafR")):
        hx = sgn * 2.85
        lf = Part(nm, (hx, 0, 0))
        x0, x1 = sorted((sgn * 2.85, sgn * 0.02))
        for z in (0.35, 0.8, 1.25, 1.7, 2.1):
            bx(lf, (x0, x1), (-0.05, 0.05), (z - 0.07, z + 0.07), WOOD)
        for x in (sgn * 2.8, sgn * 1.45, sgn * 0.08):
            bx(lf, sorted((x - 0.07, x + 0.07)), (-0.08, 0.08), (0.2, 2.2), WOOD2)
        beam(lf, (sgn * 2.8, 0.0, 0.3), (sgn * 0.08, 0.0, 2.05), 0.05, WOOD2)
        for z in (0.45, 1.85):
            bx(lf, sorted((sgn * 2.85, sgn * 2.0)), (-0.09, 0.09), (z - 0.05, z + 0.05), IRON)
        lf.done()
    empty("Latch", (0.0, 0.0, 1.1))


MODELS = [
    ("bldg_barn", barn, "bldg"),
    ("bldg_shed", shed, "bldg"),
    ("bldg_farmhouse", farmhouse, "bldg"),
    ("prop_well", well, "large"),
    ("prop_fence_segment", fence_segment, "large"),
    ("prop_fence_gate", fence_gate, "large"),
    ("prop_farm_gate", farm_gate, "large"),
    ("prop_door_barn", lambda: door("barn", 3.3), "large"),
    ("prop_door_shed", lambda: door("shed", 2.5), "large"),
    ("prop_door_farmhouse", lambda: door("farmhouse", 2.6), "large"),
]

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for nm, fn, cls in MODELS:
        if not only or nm in only:
            B.build(nm, fn, cls)

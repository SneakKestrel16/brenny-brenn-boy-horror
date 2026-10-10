"""P5-32 better crop models (CEO STOP 6): turnip, pumpkin and moonflower, every stage. Blender-built, no outside source.

  sh tools/blender/run.sh tools/blender/build_p5_32.py [-- name ...]

Rebuilds the 17 crop files of build_p5_16.py under the same names, node name ("Crop"), origin (base on the plot soil,
centred) and materials, so no code changes. Corn stays as built by build_p5_16.py (MultiMesh, perf budget, doc 07 s10.1).
New over P5-16: folded, curved, graded leaves; lobed pumpkin leaves; ribbed pumpkin fruit with a ridged stem, flowers
and tendrils; layered moonflower petals with stamens; turnip petioles and shoulder collar. Class "mid" (800 tris).
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_p5_16 as C  # noqa: E402
import build_phase4 as B  # noqa: E402
from build_phase4 import Part  # noqa: E402

MAT_MOON, MAT_TAINT = C.MAT_MOON, C.MAT_TAINT
poly = C.poly
LEAF, LEAF2, STEM = "#5F8A3A", "#4F7A32", "#3F5A2A"
STEM_L = "#7FA04A"  # pale young stem
BULB, BULB_TOP, BULB_COLLAR = "#EDE6F0", "#9A5FB0", "#6E3F86"
PETIOLE = "#8FB060"
DEAD, DEAD2, ROT, ROT2 = "#A89A5A", "#8A7C46", "#4A3A2A", "#2E241A"
PUMP, PUMP_D, PUMP_G, PUMP_GD = "#E0821F", "#B25E14", "#9CAA3E", "#6F8A2E"
FLOWER = "#F2C230"
MOON, MOON_HI, MOON_BUD = "#7FE6D8", "#5FB8AC", "#6FA89E"
TAINT, TAINT2, TAINT3 = "#0A0710", "#3A1F4A", "#5A2F72"


def shade(c, f):
    v = [int(c[i:i + 2], 16) for i in (1, 3, 5)]
    return "#%02X%02X%02X" % tuple(max(0, min(255, int(x * f))) for x in v)


def _dir(yaw, pit):
    return Vector((-math.sin(yaw) * math.cos(pit), math.cos(yaw) * math.cos(pit), math.sin(pit)))


# (station t along the blade, half-width factor): "wavy" has a lobed edge like a turnip leaf
PROF = {
    "smooth": ([0, .3, .6, .85], [.3, .85, 1.0, .6]),
    "wavy": ([0, .22, .42, .65, .85], [.2, .8, .55, .85, .45]),
    "lance": ([0, .3, .6, .85], [.25, .7, .65, .3]),
}


def leaf(p, base, yaw, L, W, pitch, col, droop=0.0, mat=0, prof="smooth", fold=0.14):
    """Curved, trough-folded blade: strip of stations, midrib lowered, graded dark base to light tip, left half darker.
    yaw 0 = +Y, pitch rises, tips bend down by 0.3 + 5*droop rad (negative droop curls the tip up less)."""
    ts, ws = PROF[prof]
    bend = max(0.0, 0.3 + droop * 5)
    side = Vector((math.cos(yaw), math.sin(yaw), 0))
    pos, prev_t, st = Vector(base), 0.0, []
    for t, w in zip(ts, ws):
        pos = pos + _dir(yaw, pitch - bend * (prev_t + t) / 2) * (L * (t - prev_t))
        d = _dir(yaw, pitch - bend * t)
        up = side.cross(d).normalized()
        half = side * (W * w / 2)
        st.append((pos - half, pos - up * (fold * W * w), pos + half, t))
        prev_t = t
    tip = pos + _dir(yaw, pitch - bend) * (L * (1 - prev_t))
    c = col

    def g(t, f=1.0):
        return shade(c, (0.72 + 0.4 * t) * f)

    for a, b in zip(st, st[1:]):
        poly(p, [a[0], a[1], b[1], b[0]], [g(a[3], .86), g(a[3], .72), g(b[3], .72), g(b[3], .86)], mat)
        poly(p, [a[1], a[2], b[2], b[1]], [g(a[3], .72), g(a[3], 1.0), g(b[3], 1.0), g(b[3], .72)], mat)
    z = st[-1]
    poly(p, [z[1], z[2], tip], [g(z[3], .72), g(z[3], 1.0), g(1.0, 1.1)], mat)
    poly(p, [z[0], z[1], tip], [g(z[3], .86), g(z[3], .72), g(1.0, 1.1)], mat)
    return tip


def leaves(p, base, n, L, W, pitch, col, droop=0.0, phase=0.0, mat=0, prof="smooth", fold=0.14):
    for i in range(n):
        leaf(p, base, phase + i * math.tau / n, L, W, pitch, col if isinstance(col, str) else col[i % len(col)], droop, mat, prof, fold)


def lobed(p, c, yaw, R, col, tilt=0.15, droop=0.0, n=5):
    """Palmate pumpkin leaf: fan of 2n tris round c, alternating lobe tips and notches, open at the back where the
    petiole joins; the outer rim droops. Centre dark, tips light."""
    c = Vector(c)
    pts = []
    for k in range(2 * n + 1):
        rel = -2.3 + 4.6 * k / (2 * n)
        r = R if k % 2 == 0 else R * 0.72
        a = yaw + rel
        z = c.z + tilt * r * math.cos(rel) - droop * (r / R) ** 2 * R * 0.5
        pts.append(c + Vector((-math.sin(a) * r, math.cos(a) * r, 0)) + Vector((0, 0, z - c.z)))
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        f = 1.0 if i % 2 == 0 else 0.86
        poly(p, [c, a, b], [shade(col, 0.66 * f), shade(col, 1.08 * f), shade(col, 1.08 * f)])


def rib_ball(p, r, h, cz, col, col_d, ribs=8, depth=0.14, dimple=0.8, seg_rings=6):
    """Pumpkin / squash body: 2*ribs segments, alternating ridge and valley, top pole pressed in."""
    v = bmesh.ops.create_uvsphere(p.bm, u_segments=ribs * 2, v_segments=seg_rings, radius=1.0)["verts"]
    for x in v:
        th = math.atan2(x.co.y, x.co.x)
        k = 1.0 + depth * math.cos(ribs * th)
        if abs(x.co.x) < 1e-5 and abs(x.co.y) < 1e-5:
            if x.co.z > 0:
                x.co.z *= dimple
        else:
            x.co.x *= k
            x.co.y *= k
    p._xf(v, (0, 0, cz), (0, 0, 0), (r, r, h))
    p._fin(v, col, 0)
    faces = dict.fromkeys(f for x in v for f in x.link_faces)
    for f in faces:
        cen = f.calc_center_median()
        valley = math.cos(ribs * math.atan2(cen.y, cen.x)) < 0
        top = (cen.z - cz) / h
        for l in f.loops:
            l[p.lay] = B.srgb(shade(col_d if valley else col, 0.85 + 0.2 * max(0.0, top)))


def curved_stem(p, pts, r0, r1, col, seg=5):
    n = len(pts) - 1
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        p.between(a, b, r0 + (r1 - r0) * i / n, r0 + (r1 - r0) * (i + 1) / n, col, seg=seg)


# ---------------------------------------------------------------- turnip (up to 0.4 high, doc 07 s11.5)
def bulb(p, r, top=BULB_TOP, low=BULB, collar=BULB_COLLAR, cz=None):
    """Round turnip: white lower half, purple shoulder, dark collar ring where the leaves leave."""
    cz = r * 0.6 if cz is None else cz
    p.ball((r, r, r * 0.95), (0, 0, cz), low, seg=10, rings=6)
    p.dome((r * 1.04, r * 1.04, r * 0.98), (0, 0, cz), top, seg=10, rings=6)
    p.cyl(r * 0.5, r * 0.34, r * 0.22, (0, 0, cz + r * 0.88), collar, seg=8)


def turnip_leaves(p, z0, n, L, W, pitch, cols, droop, petiole=0.0, col_p=PETIOLE):
    for i in range(n):
        yaw = i * math.tau / n + 0.3 * (i % 2)
        base = Vector((0, 0, z0))
        if petiole:
            top = base + _dir(yaw, pitch + 0.15) * petiole
            p.between(base, top, 0.011, 0.007, col_p, seg=4)
            base = top
        leaf(p, base, yaw, L, W, pitch, cols[i % len(cols)], droop, prof="wavy")


def turnip(stage):
    p = Part("Crop")
    if stage == 0:  # seedling: two cotyledons, first true leaf
        leaves(p, (0, 0, 0.03), 2, 0.085, 0.05, 0.8, LEAF, droop=0.01, phase=0.4)
        p.between((0, 0, 0), (0, 0, 0.035), 0.007, 0.005, PETIOLE, seg=4)
        leaf(p, (0, 0, 0.035), 1.9, 0.05, 0.03, 1.1, LEAF2)
    elif stage == 1:  # rosette of five small leaves on short stalks
        p.between((0, 0, 0), (0, 0, 0.04), 0.014, 0.01, PETIOLE, seg=5)
        turnip_leaves(p, 0.03, 5, 0.14, 0.075, 0.85, [LEAF, LEAF2], 0.02, petiole=0.04)
    elif stage == 2:  # bulb shoulder breaking the soil, ten leaves
        bulb(p, 0.055)
        turnip_leaves(p, 0.075, 7, 0.22, 0.09, 0.95, [LEAF, LEAF2], 0.025, petiole=0.07)
    elif stage == 3:  # harvest: fat bulb, full leafy crown
        bulb(p, 0.095)
        turnip_leaves(p, 0.15, 8, 0.22, 0.11, 0.95, [LEAF, LEAF2, "#6A9A40"], 0.04, petiole=0.06)
        p.ball((0.012, 0.012, 0.012), (0, 0, 0.0), BULB, seg=4, rings=3)  # root tip peeking under the bulb
    elif stage == "wilted":  # bulb pale, leaves yellow and flopped on the soil
        bulb(p, 0.085, top="#9A8AA0", low="#BDB4BA", collar="#6A5A70")
        turnip_leaves(p, 0.12, 7, 0.28, 0.1, 0.35, [DEAD, DEAD2], 0.1, petiole=0.07, col_p="#8A7C46")
    else:  # rotten: dark slumped bulb with a soft split, brown limp leaves, spoil spots
        p.ball((0.11, 0.11, 0.065), (0, 0, 0.04), ROT, seg=10, rings=6)
        p.ball((0.055, 0.05, 0.03), (0.045, 0.035, 0.092), ROT2, seg=6, rings=4)
        p.ball((0.04, 0.04, 0.02), (-0.06, -0.03, 0.085), "#5A6040", seg=6, rings=4)
        turnip_leaves(p, 0.08, 6, 0.26, 0.09, 0.15, [ROT2, ROT], 0.1)
    p.done()


# ---------------------------------------------------------------- pumpkin (up to 0.8 high)
def flower(p, c, r, yaw=0.0, n=5):
    c = Vector(c)
    for i in range(n):
        leaf(p, c, yaw + i * math.tau / n, r, r * 0.7, 0.55, FLOWER, droop=0.0, fold=0.3)
    p.ball((r * 0.18,) * 3, c + Vector((0, 0, r * 0.1)), "#D8A010", seg=5, rings=3)


def pumpkin_fruit(p, r, h, col, col_d, stem_col=STEM, cz=None, ribs=8, bent=0.0):
    cz = h if cz is None else cz
    rib_ball(p, r, h, cz, col, col_d, ribs=ribs)
    top = Vector((0, 0, cz + h * 0.82))
    pts = [top, top + Vector((bent * 0.3, 0, h * 0.25)), top + Vector((bent, 0.01, h * 0.45))]
    curved_stem(p, pts, r * 0.16, r * 0.1, stem_col, seg=5)
    p.cyl(r * 0.2, r * 0.14, h * 0.1, top + Vector((0, 0, h * 0.04)), shade(stem_col, 0.8), seg=5)  # woody flare


def pvine(p, a, n, step, R, col=STEM, leafcol=LEAF, h=0.2, drop=0.0, tendril=True, tilt=0.15):
    """Vine crawling out at angle a with a petioled lobed leaf at every node."""
    prev = Vector((0.04 * math.cos(a), 0.04 * math.sin(a), 0.04))
    for k in range(1, n + 1):
        aa = a + 0.3 * math.sin(k * 1.3 + a)
        nxt = prev + Vector((math.cos(aa), math.sin(aa), 0)) * step
        nxt.z = 0.03 + 0.005 * k
        p.between(prev, nxt, 0.017, 0.013, col, seg=5)
        top = nxt + Vector((0, 0, h * (0.75 + 0.25 * (k % 2))))
        p.between(nxt, top, 0.011, 0.008, col, seg=4)
        lobed(p, top, aa - math.pi / 2 + (0.8 if k % 2 else -0.8), R * 1.3, leafcol if k % 2 else shade(leafcol, 0.9), tilt=tilt, droop=drop)
        if tendril and k == n:
            q = nxt + Vector((-math.sin(aa), math.cos(aa), 0)) * 0.05 + Vector((0, 0, 0.05))
            p.between(nxt, q, 0.006, 0.004, shade(col, 1.2), seg=3)
            p.between(q, q + Vector((math.cos(aa), math.sin(aa), 0)) * 0.03 + Vector((0, 0, -0.025)), 0.004, 0.003, shade(col, 1.2), seg=3)
        prev = nxt
    return prev


def pumpkin_crop(stage):
    p = Part("Crop")
    if stage == 0:  # two oval cotyledons and a tiny first leaf
        leaves(p, (0, 0, 0.04), 2, 0.12, 0.06, 0.75, LEAF, droop=0.01, phase=0.5)
        p.between((0, 0, 0), (0, 0, 0.045), 0.009, 0.006, PETIOLE, seg=4)
        lobed(p, (0, 0, 0.1), 2.4, 0.045, LEAF2, tilt=0.3, n=3)
    elif stage == 1:  # crown with three vines and lobed leaves, first yellow flower
        p.between((0, 0, 0), (0, 0, 0.1), 0.02, 0.014, STEM, seg=5)
        for a in (0.4, 2.5, 4.4):
            pvine(p, a, 2, 0.13, 0.12, h=0.08)
        flower(p, (0.12 * math.cos(1.4), 0.12 * math.sin(1.4), 0.07), 0.05, 1.4)
    elif stage == 2:  # green fruit 0.35 m wide, vines, flower
        pumpkin_fruit(p, 0.14, 0.11, PUMP_G, PUMP_GD, bent=0.03)
        for a in (0.4, 2.3, 4.2):
            pvine(p, a, 2, 0.2, 0.17, h=0.1)
        flower(p, (0.22 * math.cos(1.2), 0.22 * math.sin(1.2), 0.16), 0.055, 1.2)
    elif stage == 3:  # ripe orange fruit, ridged stem, big leaves rising to 0.8 m
        pumpkin_fruit(p, 0.24, 0.19, PUMP, PUMP_D, stem_col="#5A6A2E", bent=0.05)
        for a in (0.3, 2.0, 3.6, 5.0):
            pvine(p, a, 2, 0.26, 0.2, h=0.13)
        for sgn, (x, y) in ((1, (0.22, 0.2)), (-1, (-0.2, 0.22))):
            top = Vector((x + 0.04 * sgn, y + 0.04, 0.62 if sgn > 0 else 0.55))
            curved_stem(p, [Vector((x, y, 0)), Vector((x + 0.01 * sgn, y + 0.02, top.z * 0.5)), top], 0.02, 0.012, STEM)
            lobed(p, top, 0.7 * sgn, 0.24, LEAF if sgn > 0 else LEAF2, tilt=0.3, n=4)
    elif stage == "wilted":  # sagging fruit, yellow-brown vines and flopped leaves
        pumpkin_fruit(p, 0.21, 0.15, "#C89850", "#A87A3A", stem_col="#7A6A38", bent=0.06)
        for a in (0.3, 2.0, 3.6, 5.0):
            pvine(p, a, 2, 0.24, 0.19, col="#6A5C34", leafcol=DEAD, h=0.1, drop=0.35, tilt=0.0)
    else:  # rotten: collapsed, dark, mouldy
        rib_ball(p, 0.27, 0.09, 0.07, ROT, ROT2, depth=0.12, dimple=0.9)
        p.ball((0.12, 0.1, 0.05), (0.14, 0.08, 0.14), ROT2, seg=6, rings=4)
        p.ball((0.07, 0.07, 0.03), (-0.1, 0.05, 0.14), "#5A6040", seg=6, rings=4)
        p.box((0.04, 0.04, 0.09), (-0.06, 0, 0.17), ROT2, rot=(0, 0.5, 0))
        for a in (0.5, 3.0, 4.6):
            pvine(p, a, 2, 0.22, 0.16, col=ROT2, leafcol=ROT, h=0.06, drop=0.4, tilt=0.0, tendril=False)
    p.done()


# ---------------------------------------------------------------- moonflower (up to 0.6 high; the only crop that glows)
def bend_stem(p, h, col=STEM, lean=0.0, n=4, r0=0.016, r1=0.011):
    pts = [Vector((lean * (i / n) ** 2, 0.012 * math.sin(i * 1.7), h * i / n)) for i in range(n + 1)]
    curved_stem(p, pts, r0, r1, col, seg=5)
    return pts


def stem_leaves(p, pts, zs, L, W, pitch, col, droop=0.0):
    for i, z in enumerate(zs):
        base = Vector((0, 0, z))
        for q in pts:
            if q.z >= z:
                base = Vector((q.x * z / max(q.z, 1e-6), q.y, z))
                break
        leaf(p, base, i * 2.4, L, W, pitch, col, droop, prof="lance")


def moonflower(stage):
    p = Part("Crop")
    if stage == 0:  # two cotyledons and the first pair of true leaves
        leaves(p, (0, 0, 0.04), 2, 0.09, 0.045, 0.7, LEAF, droop=0.01, phase=0.3, prof="lance")
        p.between((0, 0, 0), (0, 0, 0.1), 0.008, 0.005, STEM_L, seg=4)
        leaves(p, (0, 0, 0.09), 2, 0.07, 0.04, 1.0, LEAF2, phase=1.6, prof="lance")
    elif stage == 1:  # tall stem, leaves up the stem, closed bud wrapped in sepals (does not glow yet)
        pts = bend_stem(p, 0.32)
        stem_leaves(p, pts, (0.06, 0.12, 0.2), 0.15, 0.06, 0.7, LEAF, droop=0.01)
        top = pts[-1]
        p.ball((0.036, 0.036, 0.07), top + Vector((0, 0, 0.05)), MOON_BUD, seg=6, rings=4)
        for i in range(4):
            leaf(p, top, i * math.tau / 4 + 0.4, 0.1, 0.045, 1.25, LEAF2, droop=-0.04, fold=0.3)
    elif stage == 2:  # open bloom: two petal rings round a bright disc and stamens, steady glow (doc 07 s2, s7)
        pts = bend_stem(p, 0.4)
        stem_leaves(p, pts, (0.06, 0.15, 0.26), 0.17, 0.065, 0.65, LEAF, droop=0.01)
        top = pts[-1]
        for i in range(5):  # green calyx under the bloom
            leaf(p, top, i * math.tau / 5 + 0.3, 0.06, 0.03, 0.4, LEAF2)
        t0 = top + Vector((0, 0, 0.01))
        for i in range(8):
            leaf(p, t0, i * math.tau / 8, 0.15, 0.085, 0.95, MOON, droop=0.02, mat=MAT_MOON, fold=0.25)
        for i in range(6):
            leaf(p, t0 + Vector((0, 0, 0.02)), i * math.tau / 6 + 0.26, 0.11, 0.07, 1.25, MOON_HI, droop=0.0, mat=MAT_MOON, fold=0.25)
        p.ball((0.032, 0.032, 0.022), t0 + Vector((0, 0, 0.03)), MOON_HI, seg=6, rings=4, mat=MAT_MOON)
        for i in range(6):
            a = i * math.tau / 6
            tip = t0 + Vector((0.025 * math.cos(a), 0.025 * math.sin(a), 0.09))
            p.between(t0 + Vector((0, 0, 0.03)), tip, 0.004, 0.003, MOON_HI, seg=3, mat=MAT_MOON)
            p.ball((0.007,) * 3, tip, MOON, seg=4, rings=3, mat=MAT_MOON)
    elif stage == "wilted":  # grey, bowed over, petals hanging
        pts = bend_stem(p, 0.36, col="#5A5A4A", lean=0.2, r0=0.014, r1=0.01)
        stem_leaves(p, pts, (0.06, 0.14, 0.24), 0.17, 0.06, 0.2, "#6A6A58", droop=0.08)
        top = pts[-1]
        for i in range(7):
            leaf(p, top, i * math.tau / 7, 0.13, 0.075, -0.4, "#7A7A6A", droop=0.03, fold=0.3)
        p.ball((0.02,) * 3, top, "#4A4A3C", seg=5, rings=3)
    else:  # taint: oil-black bloom with purple sheen, drips and tendrils on the soil, nothing glows
        pts = bend_stem(p, 0.42, col=TAINT, lean=0.06, r0=0.02, r1=0.012)
        top = pts[-1]
        for i in range(9):
            col = TAINT if i % 2 else TAINT2
            leaf(p, top, i * math.tau / 9, 0.19, 0.08, 0.35 + 0.3 * (i % 2), col if i % 3 else TAINT3, droop=0.02,
                 mat=MAT_TAINT, prof="wavy", fold=0.3)
        p.ball((0.05, 0.05, 0.05), top + Vector((0, 0, 0.05)), TAINT2, seg=6, rings=4, mat=MAT_TAINT)
        for i, z in enumerate((0.1, 0.2, 0.3)):  # oil beads running down the stem
            p.ball((0.014, 0.014, 0.022), (0.02 * math.cos(i * 2.1), 0.02 * math.sin(i * 2.1), z), TAINT3, seg=5, rings=3, mat=MAT_TAINT)
        for i in range(5):  # tendrils creeping on the soil, two bent segments
            a = i * math.tau / 5 + 0.4
            m = (0.12 * math.cos(a), 0.12 * math.sin(a), 0.02)
            e = (0.24 * math.cos(a + 0.4), 0.24 * math.sin(a + 0.4), 0.012)
            p.between((0, 0, 0.01), m, 0.014, 0.008, TAINT, seg=3, mat=MAT_TAINT)
            p.between(m, e, 0.008, 0.003, TAINT, seg=3, mat=MAT_TAINT)
        leaves(p, (0, 0, 0.08), 3, 0.15, 0.05, 0.1, TAINT2, droop=0.06, phase=0.5, mat=MAT_TAINT, prof="lance")
        p.between((0, 0, 0), top, 0.02, 0.012, TAINT, seg=4, mat=MAT_TAINT)
    p.done()


def _wrap(fn, *a):
    def go():
        C.extra_materials()
        fn(*a)
    return go


MODELS = (
    [(f"crop_turnip_stage{i}", _wrap(turnip, i), "mid") for i in range(4)]
    + [("crop_turnip_wilted", _wrap(turnip, "wilted"), "mid"), ("crop_turnip_rotten", _wrap(turnip, "rotten"), "mid")]
    + [(f"crop_pumpkin_stage{i}", _wrap(pumpkin_crop, i), "mid") for i in range(4)]
    + [("crop_pumpkin_wilted", _wrap(pumpkin_crop, "wilted"), "mid"), ("crop_pumpkin_rotten", _wrap(pumpkin_crop, "rotten"), "mid")]
    + [(f"crop_moonflower_stage{i}", _wrap(moonflower, i), "mid") for i in range(3)]
    + [("crop_moonflower_wilted", _wrap(moonflower, "wilted"), "mid"), ("crop_moonflower_taint", _wrap(moonflower, "taint"), "mid")]
)

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for nm, fn, cls in MODELS:
        if not only or nm in only:
            B.build(nm, fn, cls)

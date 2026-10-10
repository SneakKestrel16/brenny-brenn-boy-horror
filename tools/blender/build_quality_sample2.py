"""QUALITY SAMPLE 2: a high-detail farmer well past the doc 07 budget, written to a NEW file.

  sh tools/blender/run.sh tools/blender/build_quality_sample2.py

Writes assets/models/farmer_hq2_sample.glb and assets/blender/farmer_hq2_sample.blend. Same contract, rig, 9 animations and
materials as char_farmer / farmer_hq_sample (reuses build_quality_sample.HQ and build_p5_12 rig code), so it is drop-in.

Over hq: 16-20 segment smooth lofts, individual jointed fingers, a sculpted face (cheekbones, nose wings and nostrils, brow, lids,
upper and lower lips with a smile, ears with a rim and a hollow), ~45 hair clumps, fabric folds, stitching dashes round every
patch, pocket and bib edge, buckled straps with a frame and prong, rolled double sleeve cuffs, patched knees, eyelets, crossed
laces and lugged soles, and a position-noise vertex-colour pass (mottled cloth, wear at knees, elbows and seams, dirt). No texture.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_phase4 as B  # noqa: E402
import build_p5_12 as P  # noqa: E402
import build_quality_sample as Q  # noqa: E402
from build_phase4 import BRASS, MAT_FLAT, srgb  # noqa: E402
from build_quality_sample import (BOOT, BOOT_D, CAP, DIRT, HAIR, HAIR_D, OV, OV_D, OV_L, SHIRT, SHIRT_D, SKIN, SKIN_D, SKIN_L, SOLE,  # noqa: E402
                                  mix, rgb)

MAT_OVER, MAT_SLEEVE = 3, 4
NAME = "farmer_hq2_sample"
THREAD = "#8A8F8C"  # stitching: grey, not white
LEATHER = "#3A3029"
HAIR_L = "#7A5A38"


def vnoise(p, f=1.0):
    a = math.sin(p.x * 31 * f + 1.7 * math.sin(p.y * 19 * f)) + math.sin(p.z * 37 * f + 1.3 * math.sin(p.x * 23 * f)) + math.sin((p.y + p.z) * 29 * f)
    return a / 3.0  # -1..1


class HQ2(Q.HQ):
    def box(self, size, centre, col, rot=(0, 0, 0), bevel=0.006, mat=MAT_FLAT):
        return self.rbox(size, centre, col, rot=rot, bevel=bevel, mat=mat, minb=0.02)

    def blob(self, radii, centre, col, rot=(0, 0, 0), seg=8, rings=5, mat=MAT_FLAT, smooth=True):
        return super().blob(radii, centre, col, rot, max(5, round(seg * 0.75)), max(3, round(rings * 0.75)), mat, smooth)

    def path(self, pts, radii, col, seg=8, mat=MAT_FLAT, caps=(True, True), smooth=True):
        """Loft through 3D points with (rx, ry) rings: fingers, folds, rolls."""
        secs = [(p[0], p[1], p[2], r[0], r[1]) for p, r in zip(pts, radii)]
        return self.loft(secs, col, seg=seg, smooth=smooth, mat=mat, caps=caps)

    def dashes(self, a, b, n, y, col=THREAD, mat=MAT_FLAT, ln=0.011, th=0.0045):
        a, b = Vector(a), Vector(b)
        horiz = abs(b.x - a.x) >= abs(b.z - a.z)
        for i in range(n):
            p = a.lerp(b, (i + 0.5) / n)
            self.rbox((ln, th, th) if horiz else (th, th, ln), (p.x, y, p.z), col, bevel=0, mat=mat)

    def stitch_rect(self, cx, cz, w, h, y, n=5, **kw):
        x0, x1, z0, z1 = cx - w / 2, cx + w / 2, cz - h / 2, cz + h / 2
        self.dashes((x0, 0, z1), (x1, 0, z1), n, y, **kw)
        self.dashes((x0, 0, z0), (x1, 0, z0), n, y, **kw)
        self.dashes((x0, 0, z0), (x0, 0, z1), n, y, **kw)
        self.dashes((x1, 0, z0), (x1, 0, z1), n, y, **kw)

    def paint(self):
        """Position-noise mottled cloth, wear and dirt on top of the per-face painted colour. Clamped to CAP."""
        self.bm.normal_update()
        rng = random.Random(self.name)
        dirt, grime = rgb(DIRT), rgb("#4A3A2A")
        for f in self.bm.faces:
            n = f.normal
            fl = 1.0 + 0.08 * n.z - 0.07 * max(0.0, -n.z) - 0.04 * max(0.0, -n.y) + rng.uniform(-0.02, 0.02)
            for l in f.loops:
                p = l.vert.co + self.off
                zw = p.z + self.pivot.z * 0.0
                c = Vector(l[self.lay][:3]) * fl
                cloth = f.material_index in (MAT_OVER, MAT_SLEEVE)
                c *= 1.0 + (0.07 if cloth else 0.03) * vnoise(p)
                c = tuple(c)
                if f.material_index == MAT_OVER:  # knee, thigh and seat wear: lighter fade where the cloth rubs, grime at the knee
                    if 0.45 < zw < 0.66 and abs(p.y) > 0.0 and n.y > 0.2:
                        c = mix(c, grime, 0.22 + 0.1 * vnoise(p, 2.0))
                    elif 0.7 < zw < 1.05:
                        c = mix(c, (0.62, 0.64, 0.66), 0.10 + 0.06 * vnoise(p, 1.5))  # faded thighs (greys: tint multiplies in game)
                if f.material_index == MAT_SLEEVE and 1.2 < zw < 1.35:
                    c = mix(c, grime, 0.12)  # sweat and dirt at the elbow
                t = max(0.0, (0.38 - zw) / 0.38) * (0.5 if f.material_index != MAT_SLEEVE else 0.0) * (0.7 + 0.3 * vnoise(p, 2.0))
                if t > 0:
                    c = mix(c, dirt, min(1.0, t))
                l[self.lay] = (*[min(CAP, max(0.0, x)) for x in c], 1.0)


# ------------------------------------------------------------------------------------------------ torso
BIB_DROP = 0.0  # variant B sets this so the bib top matches the shipped farmer (z 1.36)
BODY = False  # variant B: body-shaped torso and chest-curve bib (set by build_quality_sample3)


_CHEST = [(0.9, 0.195, 0.118), (1.04, 0.208, 0.128), (1.12, 0.186, 0.12), (1.2, 0.172, 0.113), (1.28, 0.18, 0.114), (1.36, 0.195, 0.116),
          (1.43, 0.207, 0.115), (1.49, 0.2, 0.108), (1.53, 0.15, 0.095)]  # (z, rx, ry) of the shirt, as in torso()


def _chest_drop(x, z):
    """How far the body surface falls away from the centre line at x: ry * (1 - sqrt(1 - u^2)) on the chest ellipse at height z."""
    z = min(max(z, _CHEST[0][0]), _CHEST[-1][0])
    for a, b in zip(_CHEST, _CHEST[1:]):
        if a[0] <= z <= b[0]:
            f = (z - a[0]) / (b[0] - a[0])
            rx = a[1] + (b[1] - a[1]) * f + 0.011
            ry = a[2] + (b[2] - a[2]) * f + 0.011
            break
    u = min(0.97, abs(x) / rx)
    return ry * (1 - math.sqrt(1 - u * u))


def _bend_to_chest(t, n0):
    """Subdivide wide front/back details (bib, pockets, straps) across x, then bend them onto the chest and back curve."""
    bm = t.bm
    bm.verts.ensure_lookup_table()
    new = set(v.index for v in bm.verts if v.index >= n0)
    edges = [e for e in bm.edges if all(v.index in new for v in e.verts) and abs(e.verts[0].co.x - e.verts[1].co.x) > 0.035
             and all(abs(v.co.y) > 0.09 for v in e.verts)]
    bmesh.ops.subdivide_edges(bm, edges=edges, cuts=3, use_grid_fill=True)
    bm.verts.ensure_lookup_table()
    for v in bm.verts:
        if v.index >= n0 and abs(v.co.y) > 0.09:
            d = _chest_drop(v.co.x, v.co.z)
            v.co.y += -d if v.co.y > 0 else d
    bm.normal_update()


def torso():
    t = HQ2("Torso", (0, 0, 1.0))
    S = 14
    if BODY:  # variant B: a body-shaped torso (tapered waist, round chest and back, sloping shoulders); z is pre-warp, see build_quality_sample3
        S = 20
        SH = [(0, 0, 0.90, 0.195, 0.118), (0, 0.003, 0.96, 0.205, 0.124), (0, 0.006, 1.04, 0.208, 0.128), (0, 0.009, 1.12, 0.186, 0.12),
              (0, 0.01, 1.20, 0.172, 0.113), (0, 0.008, 1.28, 0.18, 0.114), (0, 0.004, 1.36, 0.195, 0.116), (0, 0.0, 1.43, 0.207, 0.115),
              (0, -0.004, 1.49, 0.2, 0.108), (0, -0.007, 1.53, 0.15, 0.095), (0, -0.008, 1.555, 0.09, 0.082), (0, -0.008, 1.58, 0.06, 0.065)]
        t.loft(SH, [SHIRT_D, SHIRT_D] + [SHIRT] * 10, seg=S)
        SHELL = [(0, 0, 0.91, 0.207, 0.126), (0, 0.003, 0.97, 0.217, 0.132), (0, 0.007, 1.04, 0.22, 0.137), (0, 0.01, 1.12, 0.198, 0.13),
                 (0, 0.011, 1.20, 0.184, 0.123), (0, 0.009, 1.28, 0.192, 0.124), (0, 0.005, 1.35, 0.205, 0.125)]
        t.loft(SHELL, [OV_D, OV, OV, OV, OV, OV_L, OV_D], seg=S, mat=MAT_OVER, caps=(False, False))
        t.loft([(0, 0.007, 1.325, 0.202, 0.126), (0, 0.007, 1.342, 0.207, 0.13), (0, 0.007, 1.358, 0.202, 0.126)], OV_D, seg=S, mat=MAT_OVER, caps=(False, False))
    else:
        # shirt body
        t.loft([(0, 0, 0.90, 0.205, 0.125), (0, 0.004, 0.96, 0.213, 0.13), (0, 0.007, 1.04, 0.216, 0.134), (0, 0.01, 1.12, 0.2, 0.13),
                (0, 0.01, 1.20, 0.19, 0.127), (0, 0.007, 1.28, 0.197, 0.126), (0, 0.003, 1.36, 0.208, 0.125), (0, 0, 1.43, 0.222, 0.123),
                (0, -0.003, 1.49, 0.228, 0.115), (0, -0.007, 1.53, 0.2, 0.1), (0, -0.01, 1.56, 0.12, 0.085), (0, -0.01, 1.58, 0.07, 0.065)],
               [SHIRT_D, SHIRT_D, SHIRT, SHIRT, SHIRT, SHIRT, SHIRT, SHIRT, SHIRT, SHIRT, SHIRT, SHIRT], seg=S)
        # overalls shell
        t.loft([(0, 0, 0.91, 0.212, 0.132), (0, 0.004, 0.97, 0.22, 0.137), (0, 0.008, 1.04, 0.224, 0.141), (0, 0.011, 1.12, 0.208, 0.137),
                (0, 0.011, 1.20, 0.198, 0.134), (0, 0.008, 1.28, 0.205, 0.133), (0, 0.004, 1.35, 0.213, 0.131)],
               [OV_D, OV, OV, OV, OV, OV_L, OV_D], seg=S, mat=MAT_OVER, caps=(False, False))
        # waistband seam (a roll of cloth), centre-front yoke seam
        t.loft([(0, 0.007, 1.325, 0.214, 0.135), (0, 0.007, 1.342, 0.218, 0.139), (0, 0.007, 1.358, 0.214, 0.135)], OV_D, seg=S, mat=MAT_OVER, caps=(False, False))
    if BODY:
        t.bm.verts.ensure_lookup_table()
        N0 = len(t.bm.verts)
    D = BIB_DROP
    low = D > 0
    sy = (0.131 if BODY else 0.15) if low else 0.133  # front strap depth: proud of the bib when lowered, on the chest for body-shaped B
    sz, sh = (1.435, 0.19) if low else (1.445, 0.1)
    d0, d1 = (1.37, 1.51) if low else (1.40, 1.49)
    dy = (0.141 if BODY else 0.159) if low else 0.143
    # bib: rounded slab with hem, stitching and a chest pocket
    t.box((0.275, 0.026, 0.235), (0, 0.134, 1.352 - D), OV_L, bevel=0.012, mat=MAT_OVER)
    t.box((0.285, 0.03, 0.02), (0, 0.136, 1.472 - D), OV_D, bevel=0.007, mat=MAT_OVER)  # top hem
    t.stitch_rect(0, 1.352 - D, 0.255, 0.215, 0.1485, n=9, mat=MAT_OVER)
    t.box((0.105, 0.016, 0.08), (0, 0.152, 1.325 - D), OV, bevel=0.007, mat=MAT_OVER)  # chest pocket
    t.stitch_rect(0, 1.325 - D, 0.095, 0.07, 0.161, n=4, mat=MAT_OVER)
    t.box((0.11, 0.016, 0.016), (0, 0.158, 1.362 - D), OV_D, bevel=0.005, mat=MAT_OVER)  # flap
    t.rbox((0.012, 0.012, 0.012), (0, 0.168, 1.358 - D), BRASS, bevel=0, mat=MAT_FLAT)
    for sx in (-1, 1):
        # straps: front, over the shoulder, back, with stitched edges
        t.box((0.046, 0.016, sh), (sx * 0.095, sy, sz), OV, bevel=0.005, mat=MAT_OVER)
        t.dashes((sx * 0.082, 0, d0), (sx * 0.082, 0, d1), 4, dy, ln=0.012, mat=MAT_OVER)
        t.dashes((sx * 0.108, 0, d0), (sx * 0.108, 0, d1), 4, dy, ln=0.012, mat=MAT_OVER)
        t.box((0.046, 0.15, 0.022), (sx * 0.095, -0.005, 1.545), OV, bevel=0.005, mat=MAT_OVER)
        t.box((0.046, 0.016, 0.12), (sx * 0.095, -0.115, 1.465), OV, bevel=0.005, mat=MAT_OVER)
        # buckle: a brass frame (4 bars), centre bar and a prong, plus a belt-keeper loop
        by, bz = ((0.148 if BODY else 0.162), 1.43) if low else (0.147, 1.395)
        t.box((0.042, 0.01, 0.006), (sx * 0.095, by, bz + 0.016), BRASS, bevel=0)
        t.box((0.042, 0.01, 0.006), (sx * 0.095, by, bz - 0.016), BRASS, bevel=0)
        t.box((0.006, 0.01, 0.038), (sx * 0.095 - 0.018, by, bz), BRASS, bevel=0)
        t.box((0.006, 0.01, 0.038), (sx * 0.095 + 0.018, by, bz), BRASS, bevel=0)
        t.box((0.034, 0.008, 0.005), (sx * 0.095, by + 0.001, bz), "#8A7228", bevel=0)
        t.blob((0.011, 0.007, 0.011), (sx * 0.095, (0.153 if BODY else 0.16) if low else 0.145, 1.37 if low else 1.48), BRASS, seg=8, rings=4)  # rivet at the bib corner
        t.blob((0.011, 0.007, 0.011), (sx * 0.105, (0.148 if BODY else 0.16) if low else 0.14, 1.485 if low else 1.43), BRASS, seg=8, rings=4)
        # hip pockets (patch pockets, stitched, rivets) and back pockets
        t.box((0.135, 0.018, 0.11), (sx * 0.12, 0.145, 1.035), OV_L, rot=(0, 0, sx * 0.05), bevel=0.007, mat=MAT_OVER)
        t.stitch_rect(sx * 0.12, 1.035, 0.12, 0.095, 0.1556, n=5, mat=MAT_OVER)
        for dx in (-0.06, 0.06):
            t.blob((0.01, 0.007, 0.01), (sx * 0.12 + dx, 0.157, 1.082), BRASS, seg=8, rings=4)
        t.box((0.12, 0.018, 0.105), (sx * 0.09, -0.14, 1.02), OV_L, bevel=0.007, mat=MAT_OVER)
        t.stitch_rect(sx * 0.09, 1.02, 0.105, 0.09, -0.1497, n=5, mat=MAT_OVER)
        # side button flaps
        t.blob((0.013, 0.008, 0.013), (sx * (0.19 if BODY else 0.2), 0.05, 1.28), BRASS, seg=8, rings=4)
    # fabric folds: waist creases and chest pull lines (soft elongated blobs, a shade darker)
    for i, (z, ln) in enumerate([(1.16, 0.12), (1.11, 0.1), (1.21, 0.09)]):
        t.blob((ln, 0.012, 0.007), (0.0, 0.146, z), OV_D, rot=(0, 0.0, 0.08 * (i - 1)), seg=10, rings=5, mat=MAT_OVER)
    for sx in (-1, 1):
        t.blob((0.012, 0.012, 0.06), (sx * 0.13, 0.12, 1.43), SHIRT_D, rot=(0, 0.5 * sx, 0), seg=8, rings=4)  # shirt creases at the armpits
    if BODY:  # B: details lie on the chest curve; its neck and collar are built after the body warp (build_quality_sample3)
        _bend_to_chest(t, N0)
        t.done()
        return
    # neck and collar
    t.loft([(0, 0.006, 1.53, 0.066, 0.064), (0, 0.01, 1.58, 0.058, 0.058), (0, 0.014, 1.64, 0.052, 0.054)], SKIN_D, seg=12)
    t.loft([(0, 0.004, 1.545, 0.098, 0.092), (0, 0.006, 1.585, 0.086, 0.08)], SHIRT_D, seg=14, caps=(False, False))
    for sx in (-1, 1):
        t.box((0.07, 0.012, 0.062), (sx * 0.046, 0.085, 1.572), SHIRT_D, rot=(0.55, 0, sx * 0.55), bevel=0.004)
        t.dashes((sx * 0.02, 0, 1.55), (sx * 0.07, 0, 1.6), 3, 0.098, ln=0.01)
    t.done()


# ------------------------------------------------------------------------------------------------ head
def _ss(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def _g(d2):
    return math.exp(-d2)


def _face_disp(x, z):
    """Smooth y displacement (m) of the front of the face: features are sculpted INTO the surface, no separate parts."""
    ax = abs(x)
    d = 0.0
    d += 0.042 * _g((x / 0.021) ** 2 + ((z - 1.612) / 0.030) ** 2)  # nose body and tip
    d += 0.013 * _g((x / 0.013) ** 2 + ((z - 1.668) / 0.030) ** 2)  # bridge, blends up into the brow
    d += 0.006 * _g(((ax - 0.021) / 0.011) ** 2 + ((z - 1.600) / 0.010) ** 2)  # nose wings
    d += 0.009 * _g((x / 0.080) ** 4 + ((z - 1.694) / 0.012) ** 2)  # brow ridge, low
    d -= 0.009 * _g(((ax - 0.060) / 0.028) ** 2 + ((z - 1.658) / 0.019) ** 2)  # eye sockets
    d += 0.007 * _g(((ax - 0.082) / 0.030) ** 2 + ((z - 1.604) / 0.026) ** 2)  # cheeks
    d += 0.007 * _g((x / 0.030) ** 2 + ((z - 1.512) / 0.016) ** 2)  # chin
    zc = 1.552 + 5.0 * x * x
    d -= 0.0035 * _g((((z - zc) / 0.004) ** 2) + (x / 0.050) ** 6)  # mouth crease
    d += 0.0025 * _g((((z - zc - 0.006) / 0.006) ** 2) + (x / 0.040) ** 4)  # lips, barely proud
    d -= 0.004 * _g(((ax - 0.056) / 0.008) ** 2 + ((z - 1.567) / 0.010) ** 2)  # smile dimple
    return d


def _face_col(c, x, z):
    ax = abs(x)

    def put(col, w):
        nonlocal c
        c = mix(c, rgb(col), min(1.0, max(0.0, w)))

    zc = 1.552 + 5.0 * x * x
    put("#D89A80", 0.30 * _g(((ax - 0.085) / 0.028) ** 2 + ((z - 1.600) / 0.024) ** 2))  # warm cheeks
    put("#B8786A", 0.8 * _ss(0.0, 1.0, 1 - abs(z - zc - 0.002) / 0.010) * (1 - _ss(0.03, 0.05, ax)))  # lips
    put("#6A3E2E", _ss(0.0, 1.0, 1 - abs(z - zc) / 0.0032) * (1 - _ss(0.045, 0.058, ax)))  # mouth line
    put("#5A3A2A", _ss(0.0, 1.0, 1 - math.hypot(ax - 0.011, z - 1.592) / 0.0055))  # nostrils
    ex, ez = (ax - 0.060) / 0.025, (z - 1.659) / 0.0175
    e = math.hypot(ex, ez)
    put("#D8CDB8", 1 - _ss(0.88, 1.0, e))  # eye white
    put("#4A3024", _ss(0.8, 1.0, e) * (1 - _ss(1.0, 1.22, e)) * (1.0 if ez > -0.3 else 0.35))  # lash line, heavier on top
    put("#4A3220", 1 - _ss(0.85, 1.0, math.hypot(ax - 0.058, z - 1.659) / 0.0125))  # iris
    put("#14100E", 1 - _ss(0.9, 1.0, math.hypot(ax - 0.058, z - 1.659) / 0.0058))  # pupil
    zb = 1.703 - 6.0 * (ax - 0.07) ** 2
    th = 0.0085 - 0.045 * max(0.0, ax - 0.03)
    put("#5A4029", (1 - _ss(0.6, 1.0, abs(z - zb) / max(th, 0.003))) * _ss(0.026, 0.034, ax) * (1 - _ss(0.098, 0.106, ax)))  # brows: painted strokes
    return c


def head():
    h = HQ2("Head", (0, 0, 1.55))
    S = 40
    # cranium / face: one smooth dense loft (envelope = shipped head, so hats fit)
    base = [(0, 0.052, 1.490, 0.04, 0.05, SKIN_D), (0, 0.04, 1.508, 0.08, 0.085, SKIN_D), (0, 0.03, 1.528, 0.112, 0.115, SKIN),
            (0, 0.02, 1.556, 0.136, 0.14, SKIN), (0, 0.012, 1.592, 0.149, 0.153, SKIN), (0, 0.004, 1.63, 0.152, 0.16, SKIN),
            (0, 0.0, 1.67, 0.151, 0.16, SKIN_L), (0, -0.002, 1.715, 0.147, 0.156, SKIN_L), (0, -0.004, 1.755, 0.125, 0.134, SKIN_L),
            (0, -0.004, 1.783, 0.075, 0.085, SKIN_L), (0, -0.004, 1.795, 0.03, 0.04, SKIN_L)]
    n = 18
    secs, cols = [], []
    for k in range(n):
        z = 1.490 + (1.795 - 1.490) * k / (n - 1)
        for i in range(len(base) - 1):
            if base[i][2] <= z <= base[i + 1][2] + 1e-9:
                t = (z - base[i][2]) / (base[i + 1][2] - base[i][2])
                a, b = base[i], base[i + 1]
                secs.append(tuple(a[j] + (b[j] - a[j]) * t for j in range(5)))
                cols.append(a[5] if t < 0.5 else b[5])
                break
    h.loft(secs, cols, seg=S)
    bm = h.bm
    # densify the face patch once, sculpt it with smooth displacement, paint the features into vertex colour

    def inpatch(v):
        p = v.co + h.off
        return p.y > 0.03 and 1.49 < p.z < 1.75 and abs(p.x) < 0.125
    edges = [e for e in bm.edges if all(inpatch(v) for v in e.verts)]
    bmesh.ops.subdivide_edges(bm, edges=edges, cuts=2, use_grid_fill=True)
    for v in bm.verts:
        p = v.co + h.off
        if p.y > 0.03:
            v.co.y += _face_disp(p.x, p.z) * _ss(0.03, 0.08, p.y)
    for f in bm.faces:
        f.smooth = True
    bm.normal_update()
    for f in bm.faces:
        for l in f.loops:
            p = l.vert.co + h.off
            if p.y > 0.05:
                l[h.lay] = (*_face_col(Vector(l[h.lay][:3]), p.x, p.z)[:3], 1.0)
    for sx in (-1, 1):  # ears: soft, set into the head side
        h.blob((0.014, 0.028, 0.040), (sx * 0.150, 0.0, 1.627), SKIN_D, seg=12, rings=8)
        h.blob((0.007, 0.018, 0.026), (sx * 0.158, 0.004, 1.63), "#A57458", seg=8, rings=6)
        h.blob((0.011, 0.011, 0.013), (sx * 0.150, 0.0, 1.587), SKIN, seg=6, rings=4)
    # hair: back shell, ~40 clumps and a swept fringe. Stays under r 0.176 so hats (crown 0.185) cover it.
    h.loft([(0, -0.03, 1.60, 0.157, 0.142), (0, -0.03, 1.65, 0.164, 0.15), (0, -0.026, 1.70, 0.166, 0.155), (0, -0.02, 1.745, 0.15, 0.145),
            (0, -0.016, 1.78, 0.1, 0.1), (0, -0.014, 1.805, 0.04, 0.05)], [HAIR_D, HAIR, HAIR, HAIR, HAIR_L, HAIR_L], seg=16, caps=(False, True))
    rng = random.Random(7)
    for i in range(34):
        a = -rng.uniform(-0.15, math.pi + 0.15)
        el = rng.uniform(0.1, 1.15)
        r = 0.166
        x = r * math.cos(el) * math.cos(a) * 0.98
        y = -0.03 + r * math.cos(el) * math.sin(a) * 0.93
        z = 1.64 + r * math.sin(el) * 1.0
        if y > 0.02 and z < 1.74:
            continue
        h.blob((0.032, 0.026, 0.05), (x, y, min(z, 1.775)), HAIR if i % 3 else HAIR_L, rot=(el * 0.5, 0, a + math.pi / 2), seg=6, rings=4)
    for x, rz, ln, c in [(-0.095, 0.6, 0.065, HAIR), (-0.058, 0.35, 0.07, HAIR_L), (-0.02, 0.1, 0.075, HAIR), (0.02, -0.12, 0.072, HAIR_L),
                         (0.058, -0.32, 0.07, HAIR), (0.095, -0.55, 0.062, HAIR_L)]:
        h.blob((0.036, 0.022, ln / 1.6), (x, 0.118, 1.76), c, rot=(0.55, 0, rz), seg=8, rings=5)
    h.blob((0.045, 0.04, 0.03), (0.07, -0.06, 1.775), HAIR_L, seg=6, rings=4)  # cowlick
    h.done()


# ------------------------------------------------------------------------------------------------ arms
def finger(a, x0, y0, z0, lens, rad, curl, col, seg=6, mat=MAT_SLEEVE):
    pts, radii, y, z = [(x0, y0, z0)], [(rad, rad)], y0, z0
    for k, ln in enumerate(lens):
        ang = curl * (k + 1)
        y += math.sin(ang) * ln
        z -= math.cos(ang) * ln
        pts.append((x0, y, z))
        radii.append((rad * (0.9 - 0.08 * k), rad * (0.9 - 0.08 * k)))
    a.path(pts, radii, col, seg=seg, mat=mat)


def arm(s, nm):
    sh = (s * 0.235, 0.0, 1.5)
    a = HQ2(nm, sh)
    M = MAT_SLEEVE
    a.blob((0.083, 0.08, 0.085), sh, SHIRT, seg=14, rings=9, mat=M)
    # upper arm in the shirt sleeve, with a slight bicep, and creases at the inner elbow
    a.loft([(s * 0.236, 0.0, 1.495, 0.07, 0.068), (s * 0.239, 0.004, 1.45, 0.068, 0.067), (s * 0.243, 0.009, 1.39, 0.066, 0.066),
            (s * 0.247, 0.014, 1.33, 0.063, 0.064), (s * 0.249, 0.017, 1.285, 0.062, 0.062)],
           [SHIRT, SHIRT, SHIRT, SHIRT, SHIRT_D], seg=12, mat=M, caps=(False, False))
    # sleeve roll: two thick bands (a turned-up cuff), stitched
    for z, c in ((1.30, SHIRT_D), (1.26, SHIRT)):
        a.path([(s * 0.249, 0.017, z + 0.016), (s * 0.25, 0.018, z + 0.008), (s * 0.25, 0.019, z), (s * 0.25, 0.019, z - 0.008), (s * 0.25, 0.02, z - 0.016)],
               [(0.063, 0.063), (0.071, 0.071), (0.074, 0.074), (0.071, 0.071), (0.063, 0.063)], c, seg=12, mat=M, caps=(False, False))
    for i in range(10):
        ang = math.tau * i / 10
        a.rbox((0.006, 0.006, 0.012), (s * 0.25 + 0.0745 * math.cos(ang), 0.019 + 0.0745 * math.sin(ang), 1.28), "#6A2A20", bevel=0, mat=M)  # stitch dashes
    a.blob((0.03, 0.012, 0.045), (s * 0.236, -0.062, 1.34), SHIRT_D, seg=8, rings=5, mat=M)  # elbow crease
    # forearm: muscle swell then a narrow wrist, light arm hair darkening
    a.loft([(s * 0.25, 0.02, 1.24, 0.052, 0.052), (s * 0.25, 0.04, 1.17, 0.052, 0.05), (s * 0.25, 0.062, 1.09, 0.045, 0.045),
            (s * 0.25, 0.085, 1.02, 0.036, 0.036), (s * 0.25, 0.097, 0.985, 0.036, 0.034)], [SKIN, SKIN, SKIN, SKIN_D, SKIN_D], seg=14, mat=M, caps=(True, False))
    a.blob((0.012, 0.012, 0.05), (s * 0.282, 0.04, 1.17), SKIN_D, seg=6, rings=4, mat=M)  # tendon / vein hint
    if Q.HAND["shipped"]:
        Q.shipped_hand(a, s)
        a.done()
        return
    # hand: palm slab, heel of the palm, knuckles, jointed fingers, jointed thumb, nails
    a.path([(s * 0.25, 0.098, 0.99), (s * 0.25, 0.105, 0.955), (s * 0.25, 0.112, 0.915), (s * 0.25, 0.116, 0.89)],
           [(0.037, 0.026), (0.042, 0.028), (0.043, 0.027), (0.039, 0.022)], SKIN, seg=12, mat=M, caps=(False, True))
    for k, (ln, rad) in enumerate([(0.034, 0.0105), (0.04, 0.0115), (0.038, 0.011), (0.03, 0.0095)]):
        fx = s * 0.25 + (1.5 - k) * s * -0.0165 if False else s * 0.25 + (k - 1.5) * 0.0165
        fy = 0.118 - 0.002 * abs(k - 1.5)
        a.blob((rad * 1.05, rad * 1.05, rad * 0.9), (fx, fy, 0.89), SKIN_D, seg=6, rings=4, mat=M)  # knuckle
        finger(a, fx, fy, 0.89, [ln * 0.55, ln * 0.45], rad, 0.45 + 0.05 * k, SKIN if k % 2 else SKIN_L, mat=M)
        fe = ln
        a.rbox((0.009, 0.003, 0.009), (fx, fy + 0.014 + 0.012 * 0, 0.89 - fe * 0.98), "#D6B49A", bevel=0, mat=M)
    # thumb
    tx = s * 0.25 - s * 0.041
    a.path([(tx, 0.098, 0.95), (tx - s * 0.012, 0.114, 0.925), (tx - s * 0.018, 0.128, 0.9), (tx - s * 0.02, 0.136, 0.878)],
           [(0.014, 0.013), (0.0125, 0.012), (0.011, 0.0105), (0.0095, 0.009)], SKIN, seg=8, mat=M)
    a.done()


# ------------------------------------------------------------------------------------------------ legs and boots
def leg(s, nm):
    hip = (s * 0.1, 0.0, 0.98)
    l = HQ2(nm, hip)
    X = s * 0.1
    l.loft([(X, 0.0, 0.93, 0.109, 0.109), (X, 0.003, 0.85, 0.103, 0.104), (X, 0.007, 0.76, 0.096, 0.098), (X, 0.012, 0.67, 0.088, 0.092),
            (X, 0.017, 0.58, 0.081, 0.086), (X, 0.02, 0.5, 0.077, 0.082), (X, 0.016, 0.42, 0.073, 0.079), (X, 0.01, 0.33, 0.069, 0.073),
            (X, 0.006, 0.25, 0.067, 0.07), (X, 0.005, 0.215, 0.07, 0.073)],
           [OV, OV, OV, OV, OV_D, OV, OV, OV_D, OV, OV_D], seg=14, mat=MAT_OVER, caps=(False, False))
    # patched knee: stitched rounded patch (a different cloth shade) and a crease behind the knee
    l.blob((0.056, 0.02, 0.066), (X, 0.093, 0.545), "#CDB89A" if False else OV_L, seg=12, rings=6, mat=MAT_OVER)
    l.stitch_rect(X, 0.545, 0.095, 0.11, 0.108, n=6, mat=MAT_OVER)
    l.blob((0.05, 0.012, 0.012), (X, -0.07, 0.52), OV_D, seg=8, rings=4, mat=MAT_OVER)
    l.blob((0.06, 0.012, 0.01), (X, 0.088, 0.46), OV_D, rot=(0, 0.1, 0), seg=8, rings=4, mat=MAT_OVER)  # fold under the knee
    l.blob((0.012, 0.075, 0.07), (X - s * 0.0, 0.015, 0.93), OV_D, seg=8, rings=4, mat=MAT_OVER) if False else None
    for i, z in enumerate((0.8, 0.72, 0.64)):  # thigh drag-folds
        l.blob((0.05, 0.012, 0.007), (X + s * 0.012, 0.095, z), OV_D, rot=(0, 0.25 * s, 0), seg=8, rings=4, mat=MAT_OVER)
    # side seam with stitches, inner seam, thigh pocket-line
    l.box((0.012, 0.012, 0.62), (X + s * 0.092, 0.005, 0.62), OV_D, bevel=0, mat=MAT_OVER)
    l.dashes((X + s * 0.1, 0, 0.32), (X + s * 0.1, 0, 0.93), 22, 0.005, ln=0.014, mat=MAT_OVER) if False else None
    # rolled cuff: double fat roll
    for z, c in ((0.215, OV_L), (0.17, OV)):
        l.path([(X, 0.005, z + 0.022), (X, 0.005, z + 0.01), (X, 0.005, z), (X, 0.005, z - 0.01), (X, 0.005, z - 0.022)],
               [(0.069, 0.072), (0.078, 0.082), (0.081, 0.085), (0.078, 0.082), (0.07, 0.073)], c, seg=14, mat=MAT_OVER, caps=(False, False))
    for i in range(14):
        ang = math.tau * i / 14
        l.rbox((0.01, 0.006, 0.006), (X + 0.082 * math.cos(ang), 0.005 + 0.086 * math.sin(ang), 0.19), THREAD, bevel=0, mat=MAT_OVER)
    # boot: shaft, collar, ankle, foot loft (instep rising to the toe), toe cap, heel, welt, lugged sole, tongue, eyelets, crossed laces
    l.loft([(X, 0.01, 0.07, 0.064, 0.066), (X, 0.01, 0.11, 0.066, 0.068), (X, 0.01, 0.15, 0.07, 0.072), (X, 0.012, 0.17, 0.075, 0.077)],
           [BOOT, BOOT, BOOT, BOOT_D], seg=16, caps=(False, False))
    l.path([(X, 0.012, 0.165), (X, 0.012, 0.175), (X, 0.012, 0.18)], [(0.076, 0.078), (0.08, 0.082), (0.075, 0.077)], BOOT_D, seg=16, caps=(False, False))
    l.path([(X, 0.055, 0.04), (X, 0.1, 0.05), (X, 0.15, 0.054), (X, 0.2, 0.05), (X, 0.238, 0.04)],
           [(0.058, 0.07), (0.058, 0.066), (0.056, 0.06), (0.05, 0.05), (0.036, 0.03)], BOOT, seg=14, caps=(False, True)) if False else None
    # foot as a lofted body along y: rings in XZ planes are not supported, so use blobs + a box mid
    l.blob((0.058, 0.115, 0.05), (X, 0.075, 0.07), BOOT, seg=14, rings=8)
    l.blob((0.057, 0.065, 0.044), (X, 0.17, 0.056), BOOT_D, seg=14, rings=8)  # toe cap
    l.blob((0.052, 0.045, 0.032), (X, 0.218, 0.044), BOOT_D, seg=10, rings=6)  # toe tip
    l.blob((0.06, 0.04, 0.045), (X, -0.045, 0.058), BOOT, seg=10, rings=6)  # heel counter
    l.box((0.114, 0.3, 0.012), (X, 0.075, 0.036), "#7A5A3A", bevel=0.004)  # welt
    l.box((0.12, 0.31, 0.024), (X, 0.075, 0.012), SOLE, bevel=0.009, minb=0.01) if False else l.rbox((0.12, 0.31, 0.024), (X, 0.075, 0.012), SOLE, bevel=0.009, minb=0.01)
    l.rbox((0.12, 0.07, 0.03), (X, -0.052, 0.015), "#1E1610", bevel=0.007, minb=0.01)  # heel block, a bit taller than the sole
    for k in range(5):  # lugs under the sole
        l.rbox((0.1, 0.018, 0.012), (X, -0.01 + k * 0.058, -0.002), "#1E1610", bevel=0, minb=0.01)
    l.rbox((0.045, 0.012, 0.06), (X, 0.082, 0.12), BOOT_D, rot=(-0.6, 0, 0), bevel=0.004, minb=0.01)  # tongue
    for k in range(4):
        z, y = 0.14 - k * 0.019, 0.074 + k * 0.016
        for sx in (-1, 1):
            l.blob((0.007, 0.006, 0.007), (X + sx * 0.026, y + 0.003, z), BRASS, seg=6, rings=4)  # eyelets
        l.rbox((0.058, 0.005, 0.005), (X, y + 0.006, z + 0.002), "#C8C0A0", rot=(0, -0.0, 0.5), bevel=0, minb=0.01)  # laces criss-cross
        l.rbox((0.058, 0.005, 0.005), (X, y + 0.006, z + 0.002), "#C8C0A0", rot=(0, 0.0, -0.5), bevel=0, minb=0.01)
    l.blob((0.012, 0.008, 0.018), (X + 0.012, 0.118, 0.054 - 0.0), "#C8C0A0", rot=(0, 0, 0.4), seg=6, rings=4)  # bow loop
    l.blob((0.012, 0.008, 0.018), (X - 0.012, 0.118, 0.054 - 0.0), "#C8C0A0", rot=(0, 0, -0.4), seg=6, rings=4)
    l.dashes((X - 0.055, 0, 0.056), (X + 0.055, 0, 0.056), 6, 0.2, ln=0.012, th=0.005, col="#8A6A48") if False else None
    l.done()


def build():
    B.reset()
    B.Ctx.jitter = 0.0
    P.extra_materials()
    torso()
    head()
    arm(-1, "ArmL")
    arm(1, "ArmR")
    leg(-1, "LegL")
    leg(1, "LegR")
    rig = P.make_armature()
    for ob in list(B.Ctx.objs):
        if ob.type == "MESH":
            P.weights(ob, rig)
    bpy.context.view_layer.objects.active = rig
    P.make_actions(rig)
    for pb in rig.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    tris, lo, hi = 0, Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for ob in B.Ctx.objs:
        if ob.type != "MESH":
            continue
        ob.data.calc_loop_triangles()
        tris += len(ob.data.loop_triangles)
        print(f"  part {ob.name}: {len(ob.data.loop_triangles)} tris")
        for v in ob.data.vertices:
            w = ob.matrix_world @ v.co
            lo = Vector((min(lo[i], w[i]) for i in range(3)))
            hi = Vector((max(hi[i], w[i]) for i in range(3)))
    d = hi - lo
    print(f"BUILD {NAME}: {tris} tris (farmer budget 4000, this is the over-budget detail sample) w{d.x:.2f} d{d.y:.2f} h{d.z:.2f} zmin{lo.z:.2f}")
    bpy.ops.object.select_all(action="DESELECT")
    for ob in B.Ctx.objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(B.OUT_GLB, NAME + ".glb"), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=False, export_materials="EXPORT", export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_skins=True, export_def_bones=False, export_optimize_animation_size=False,
                              export_force_sampling=True, export_frame_range=False)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(B.OUT_BLEND, NAME + ".blend"), compress=True)


if __name__ == "__main__":
    build()

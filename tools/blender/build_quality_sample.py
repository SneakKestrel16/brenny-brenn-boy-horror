"""QUALITY SAMPLE: a higher-quality char_farmer, written to a NEW file (does not touch the shipped farmer).

  sh tools/blender/run.sh tools/blender/build_quality_sample.py

Writes assets/models/farmer_hq_sample.glb and assets/blender/farmer_hq_sample.blend.

Same contract as char_farmer (build_p5_12.py): 1.8 m, front +Y (Godot -Z), origin at the feet, the same 12 bones, the
same 9 animations, materials mat_flat_lit / mat_farmer_overalls (tint slot) / mat_farmer_sleeves (Taint slot), part
names Torso Head ArmL ArmR LegL LegR, hat bone at z 1.74, hair envelope unchanged so every hat still fits.

What is new, all inside doc 07 s1 "low-poly, hand-painted feel":
  - lofted organic forms (torso, limbs, head, boots) instead of boxes and spheres: real silhouette and proportion.
  - bevelled boxes on every hard edge (pockets, buckle, bib, soles) so edges catch a highlight.
  - smoothing groups: organic parts smooth-shaded, hard-edged parts flat. (Doc 07 s1 says "flat-shaded": see handoff.)
  - painted vertex colour: top light / underside dark, per-face hand-painted noise, dirt on boots, knees and cuffs,
    faded overalls seams. No pure white anywhere (channels clamped at 0.90).
  - detail: eye whites, irises, lids, nose bridge, lips, brow ridge, jaw, ears with inner, hair tufts with a parting,
    collar flaps, rolled sleeves, fingers, knee patches, belt loops, rivets, laces, boot heel and sole.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_phase4 as B  # noqa: E402
import build_p5_12 as P  # noqa: E402
from build_phase4 import BRASS, MAT_FLAT, srgb  # noqa: E402

MAT_OVER, MAT_SLEEVE = 3, 4
NAME = "farmer_hq_sample"
CAP = 0.90  # doc 07 s2: no object is pure white. Every channel is clamped here.

SKIN, SKIN_D, SKIN_L = "#C9A07A", "#B88A66", "#D9B28F"
HAIR, HAIR_D = "#5A4029", "#42301E"
SHIRT, SHIRT_D = "#9A3B2B", "#7A2E22"
OV, OV_D, OV_L = "#E4E4E4", "#BDBDBD", "#D2D2D2"  # light grey: the game multiplies the player tint in
BOOT, BOOT_D, SOLE = "#5A3F2A", "#3A281A", "#2A1E14"
DIRT = "#6B5035"


def rgb(h):
    return srgb(h)[:3]


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


class HQ(B.Part):
    """Part with lofts, bevelled boxes, per-primitive smoothing and a painted-colour finishing pass."""

    def _new(self, before, col, mat, smooth):
        c = srgb(col) if isinstance(col, str) else (*col, 1.0)
        for f in set(self.bm.faces) - before:
            f.material_index = mat
            f.smooth = smooth
            for l in f.loops:
                l[self.lay] = c

    def rbox(self, size, centre, col, rot=(0, 0, 0), bevel=0.008, mat=MAT_FLAT, minb=0.03):
        before = set(self.bm.faces)
        r = bmesh.ops.create_cube(self.bm, size=1.0)
        edges = list({e for v in r["verts"] for e in v.link_edges})
        self._xf(r["verts"], centre, rot, size)
        if bevel > 0 and min(size) >= minb:  # thin slabs stay sharp: a bevel there only adds tris
            bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, segments=1, affect="EDGES")
        self._new(before, col, mat, False)
        return self

    def blob(self, radii, centre, col, rot=(0, 0, 0), seg=8, rings=5, mat=MAT_FLAT, smooth=True):
        before = set(self.bm.faces)
        v = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=1.0)["verts"]
        self._xf(v, centre, rot, radii)
        self._new(before, col, mat, smooth)
        return self

    def loft(self, secs, col, seg=10, smooth=True, mat=MAT_FLAT, caps=(True, True), phase=0.0):
        """secs: (cx, cy, z, rx, ry) rings bottom to top, ring point 0 at +X, front is +Y. col is a hex or a list of hex per ring."""
        before = set(self.bm.faces)
        rings = []
        for (cx, cy, z, rx, ry) in secs:
            rings.append([self.bm.verts.new((cx + self.off.x + rx * math.cos(phase + math.tau * i / seg),
                                             cy + self.off.y + ry * math.sin(phase + math.tau * i / seg), z + self.off.z))
                          for i in range(seg)])
        for a, b in zip(rings, rings[1:]):
            for i in range(seg):
                j = (i + 1) % seg
                self.bm.faces.new((a[i], a[j], b[j], b[i]))
        if caps[0]:
            self.bm.faces.new(rings[0][::-1])
        if caps[1]:
            self.bm.faces.new(rings[-1])
        new = set(self.bm.faces) - before
        bmesh.ops.recalc_face_normals(self.bm, faces=list(new))
        cols = col if isinstance(col, list) else [col] * len(secs)
        zs = [s[2] for s in secs]
        for f in new:
            fz = f.calc_center_median().z
            k = max(range(len(zs) - 1), key=lambda i: -abs(fz - (zs[i] + zs[i + 1]) / 2)) if len(zs) > 1 else 0
            c = srgb(cols[min(k, len(cols) - 1)])
            f.material_index = mat
            f.smooth = smooth
            for l in f.loops:
                l[self.lay] = c
        return self


    def paint(self):
        """Hand-painted finish: top-lit / underside-dark gradient, per-face noise, dirt low on the model. Clamp to CAP."""
        rng = random.Random(self.name)
        dirt = rgb(DIRT)
        for f in self.bm.faces:
            n = f.normal
            cen = f.calc_center_median()
            light = 1.0 + 0.07 * n.z - 0.05 * max(0.0, -n.y) + rng.uniform(-0.035, 0.035)
            zworld = cen.z + self.off.z
            for l in f.loops:
                c = Vector(l[self.lay][:3]) * light
                t = max(0.0, (0.34 - zworld) / 0.34) * 0.35 if f.material_index != MAT_SLEEVE else 0.0
                c = mix(tuple(c), dirt, t) if t > 0 and zworld < 0.34 else tuple(c)
                l[self.lay] = (*[min(CAP, max(0.0, x)) for x in c], 1.0)

    def done(self):
        self.paint()
        return super().done()


# ------------------------------------------------------------------------------------------------ the farmer
def torso():
    t = HQ("Torso", (0, 0, 1.0))
    # shirt body: pelvis -> waist -> chest -> shoulders, slightly rounded belly
    t.loft([(0, 0, 0.90, 0.205, 0.125), (0, 0.004, 1.02, 0.215, 0.132), (0, 0.01, 1.16, 0.195, 0.128), (0, 0.006, 1.30, 0.205, 0.125),
            (0, 0, 1.42, 0.222, 0.122), (0, -0.004, 1.50, 0.225, 0.112), (0, -0.01, 1.55, 0.14, 0.09)],
           [SHIRT_D, SHIRT_D, SHIRT, SHIRT, SHIRT, SHIRT, SHIRT], seg=12)
    # overalls shell: hips to chest, wrapped a hair outside the shirt
    t.loft([(0, 0, 0.91, 0.212, 0.132), (0, 0.004, 1.02, 0.224, 0.14), (0, 0.01, 1.16, 0.203, 0.135), (0, 0.008, 1.30, 0.211, 0.132),
            (0, 0.004, 1.355, 0.205, 0.128)],
           [OV_D, OV, OV, OV_L, OV_D], seg=12, mat=MAT_OVER, caps=(False, False))
    t.rbox((0.27, 0.03, 0.24), (0, 0.128, 1.35), OV_L, bevel=0.012, mat=MAT_OVER)  # bib
    t.rbox((0.30, 0.034, 0.018), (0, 0.13, 1.475), OV_D, bevel=0.006, mat=MAT_OVER)  # bib top hem
    t.rbox((0.11, 0.02, 0.085), (0, 0.15, 1.31), OV, bevel=0.007, mat=MAT_OVER)  # bib pocket
    t.rbox((0.115, 0.012, 0.014), (0, 0.158, 1.343), OV_D, bevel=0.004, mat=MAT_OVER)  # pocket flap
    for sx in (-1, 1):
        t.rbox((0.045, 0.02, 0.15), (sx * 0.095, 0.13, 1.455), OV, bevel=0.006, mat=MAT_OVER)  # strap, front
        t.rbox((0.045, 0.17, 0.026), (sx * 0.095, -0.01, 1.548), OV, bevel=0.006, mat=MAT_OVER)  # strap over the shoulder
        t.rbox((0.045, 0.02, 0.15), (sx * 0.095, -0.118, 1.46), OV, bevel=0.006, mat=MAT_OVER)  # strap, back
        t.blob((0.021, 0.011, 0.021), (sx * 0.095, 0.145, 1.43), BRASS, seg=6, rings=3)  # strap buttons
        t.rbox((0.034, 0.012, 0.03), (sx * 0.095, 0.145, 1.39), BRASS, bevel=0.004)  # adjuster buckle
        t.rbox((0.14, 0.022, 0.11), (sx * 0.125, 0.14, 1.03), OV_L, rot=(0, 0, sx * 0.04), bevel=0.007, mat=MAT_OVER)  # hip pockets
        t.blob((0.01, 0.007, 0.01), (sx * 0.075, 0.153, 1.075), BRASS, seg=5, rings=3)  # pocket rivets
        t.blob((0.01, 0.007, 0.01), (sx * 0.175, 0.153, 1.075), BRASS, seg=5, rings=3)
        t.rbox((0.12, 0.02, 0.1), (sx * 0.09, -0.136, 1.02), OV_L, bevel=0.007, mat=MAT_OVER)  # back pockets
    t.loft([(0, 0.004, 1.005, 0.226, 0.141), (0, 0.004, 1.045, 0.228, 0.143)], "#3A3029", seg=12, caps=(False, False))  # belt
    t.rbox((0.045, 0.014, 0.04), (0, 0.147, 1.025), BRASS, bevel=0.005)  # buckle
    t.rbox((0.026, 0.016, 0.026), (0, 0.15, 1.025), "#6B5A22", bevel=0.004)  # buckle tongue
    for sx in (-1, 1):  # belt loops
        t.rbox((0.018, 0.012, 0.05), (sx * 0.12, 0.145, 1.025), "#3A3029", bevel=0.003)
    # neck and collar flaps
    t.loft([(0, 0.006, 1.54, 0.062, 0.062), (0, 0.012, 1.63, 0.052, 0.054)], SKIN_D, seg=9)
    t.loft([(0, 0.004, 1.545, 0.092, 0.088), (0, 0.006, 1.585, 0.082, 0.078)], SHIRT_D, seg=10, caps=(False, False))
    for sx in (-1, 1):
        t.rbox((0.072, 0.012, 0.062), (sx * 0.044, 0.085, 1.572), SHIRT_D, rot=(0.55, 0, sx * 0.55), bevel=0.004)
    t.done()


def head():
    h = HQ("Head", (0, 0, 1.55))
    ez, ey = 1.65, 0.145
    # cranium and face: lofted so the brow, cheek and jaw read; envelope matches the shipped head (hats fit)
    h.loft([(0, 0.03, 1.50, 0.075, 0.08), (0, 0.025, 1.535, 0.115, 0.125), (0, 0.012, 1.585, 0.142, 0.15),
            (0, 0, 1.64, 0.15, 0.16), (0, -0.002, 1.70, 0.148, 0.158), (0, -0.004, 1.755, 0.12, 0.13), (0, -0.004, 1.79, 0.05, 0.06)],
           [SKIN_D, SKIN, SKIN, SKIN, SKIN_L, SKIN_L, SKIN_L], seg=12)
    h.blob((0.03, 0.036, 0.034), (0, 0.158, 1.607), SKIN_D, seg=8, rings=5)  # nose ball
    h.rbox((0.026, 0.05, 0.065), (0, 0.145, 1.64), SKIN, rot=(-0.25, 0, 0), bevel=0.006)  # nose bridge
    h.blob((0.056, 0.03, 0.032), (0, 0.075, 1.52), SKIN, seg=8, rings=4)  # chin
    h.rbox((0.17, 0.035, 0.022), (0, 0.141, 1.693), SKIN_D, bevel=0.007)  # brow ridge
    h.rbox((0.05, 0.014, 0.014), (0, 0.15, 1.553), "#B0705A", bevel=0.005)  # lips
    h.rbox((0.07, 0.012, 0.008), (0, 0.153, 1.5605), "#8A5A3A", bevel=0.003)  # mouth line
    for sx in (-1, 1):
        h.blob((0.028, 0.02, 0.022), (sx * 0.06, 0.142, 1.658), "#DCD2BC", seg=8, rings=5)  # eye white (not pure white)
        h.blob((0.015, 0.012, 0.015), (sx * 0.06, 0.156, 1.657), "#3A2A1C", seg=8, rings=4)  # iris
        h.blob((0.007, 0.006, 0.007), (sx * 0.06, 0.163, 1.657), "#14100E", seg=5, rings=3)  # pupil
        h.rbox((0.058, 0.016, 0.012), (sx * 0.06, 0.15, 1.678), SKIN_D, rot=(0, 0, sx * -0.08), bevel=0.004)  # upper lid
        h.rbox((0.056, 0.014, 0.012), (sx * 0.06, 0.15, 1.724 - 0.0), HAIR, rot=(0.1, 0, sx * 0.14), bevel=0.004)  # brow
        h.blob((0.032, 0.016, 0.02), (sx * 0.082, 0.135, 1.59), "#D89A80", seg=6, rings=3)  # cheek blush
        h.blob((0.018, 0.03, 0.04), (sx * 0.153, 0.0, 1.625), SKIN_D, seg=7, rings=4)  # ear
        h.blob((0.008, 0.016, 0.024), (sx * 0.16, 0.004, 1.625), "#A57458", seg=5, rings=3)  # ear inner
        h.rbox((0.012, 0.02, 0.07), (sx * 0.14, 0.06, 1.625), HAIR_D, rot=(0, 0, 0), bevel=0.004)  # sideburn
    # hair: back/side shell, fringe tufts, a parting. Stays inside the shipped envelope (r 0.176, back y -0.156).
    h.loft([(0, -0.03, 1.60, 0.155, 0.14), (0, -0.03, 1.665, 0.162, 0.152), (0, -0.026, 1.72, 0.158, 0.152), (0, -0.022, 1.77, 0.13, 0.13),
            (0, -0.018, 1.805, 0.06, 0.07)], [HAIR_D, HAIR, HAIR, HAIR, HAIR], seg=12, caps=(False, True))
    for i, (x, rz, ln) in enumerate([(-0.085, 0.42, 0.06), (-0.04, 0.2, 0.065), (0.0, 0.0, 0.07), (0.045, -0.2, 0.062), (0.09, -0.42, 0.058)]):
        h.rbox((0.056, 0.026, ln), (x, 0.128, 1.762 - ln / 2 + 0.02), HAIR if i % 2 else "#684D31", rot=(0.38, 0, rz), bevel=0.006)  # fringe tufts
    h.rbox((0.014, 0.03, 0.025), (-0.01, 0.1, 1.797), HAIR_D, rot=(0.2, 0, 0.2), bevel=0.004)  # parting
    h.blob((0.045, 0.04, 0.032), (0.07, -0.06, 1.775), HAIR, seg=6, rings=4)  # cowlick tuft
    h.done()


HAND = {"shipped": False}  # build_quality_sample3 sets this: swap in the shipped char_farmer hand


def shipped_hand(a, s):
    """The shipped hand (build_p5_12.farmer_parts), at the shipped wrist, so a shipped-style hand sits on a new sleeve."""
    wr = (s * 0.25, 0.1, 0.96)
    a.ball((0.045, 0.05, 0.058), (wr[0], wr[1] + 0.015, wr[2] - 0.05), P.SKIN, seg=8, rings=5, mat=MAT_SLEEVE)
    a.ball((0.018, 0.03, 0.022), (wr[0] - s * 0.04, wr[1] + 0.04, wr[2] - 0.03), P.SKIN, rot=(0, 0, s * 0.5), seg=5, rings=3, mat=MAT_SLEEVE)
    a.box((0.07, 0.03, 0.04), (wr[0], wr[1] + 0.03, wr[2] - 0.095), P.SKIN, mat=MAT_SLEEVE)


def arm(s, nm):
    sh, el, wr = (s * 0.235, 0.0, 1.5), (s * 0.25, 0.02, 1.22), (s * 0.25, 0.1, 0.96)
    a = HQ(nm, sh)
    M = MAT_SLEEVE
    a.blob((0.082, 0.078, 0.082), sh, SHIRT, seg=10, rings=6, mat=M)  # shoulder cap
    # upper sleeve: shirt, slightly puffed, rolled to the elbow
    a.loft([(s * 0.236, 0.0, 1.495, 0.066, 0.064), (s * 0.243, 0.008, 1.40, 0.064, 0.062), (s * 0.249, 0.016, 1.30, 0.058, 0.058)],
           [SHIRT, SHIRT, SHIRT_D], seg=10, mat=M, caps=(False, False))
    a.loft([(s * 0.249, 0.016, 1.315, 0.064, 0.064), (s * 0.25, 0.02, 1.27, 0.062, 0.062)], SHIRT_D, seg=10, mat=M, caps=(False, False))  # rolled cuff band
    # forearm: bare skin below the rolled sleeve, strong wrist
    a.loft([(s * 0.25, 0.02, 1.275, 0.05, 0.05), (s * 0.25, 0.05, 1.14, 0.046, 0.045), (s * 0.25, 0.09, 1.01, 0.037, 0.037)],
           [SKIN, SKIN, SKIN_D], seg=8, mat=M, caps=(True, False))
    a.loft([(s * 0.25, 0.092, 1.0, 0.04, 0.036), (s * 0.25, 0.1, 0.985, 0.046, 0.03)], SKIN_D, seg=8, mat=M, caps=(False, False))  # wrist
    if HAND["shipped"]:
        shipped_hand(a, s)
        a.done()
        return
    # hand: palm, four fingers in two chunks, thumb
    a.rbox((0.078, 0.036, 0.08), (s * 0.25, 0.108, 0.94), SKIN, bevel=0.01, mat=M)
    a.rbox((0.074, 0.032, 0.05), (s * 0.25, 0.114, 0.88), SKIN, rot=(0.15, 0, 0), bevel=0.008, mat=M)
    for k in range(4):
        a.rbox((0.016, 0.022, 0.032), (s * 0.25 + (k - 1.5) * 0.019, 0.12, 0.845), SKIN_D if k % 2 else SKIN, rot=(0.25, 0, 0), bevel=0.004, mat=M)
    a.rbox((0.022, 0.026, 0.06), (s * 0.25 - s * 0.05, 0.098, 0.925), SKIN, rot=(0, 0, s * 0.45), bevel=0.006, mat=M)  # thumb
    a.done()


def leg(s, nm):
    hip, kn, an = (s * 0.1, 0.0, 0.98), (s * 0.1, 0.02, 0.5), (s * 0.1, 0.0, 0.09)
    l = HQ(nm, hip)
    # trouser leg: thigh -> knee -> calf -> rolled cuff, subtle taper
    l.loft([(s * 0.1, 0.0, 0.93, 0.108, 0.108), (s * 0.1, 0.005, 0.78, 0.098, 0.098), (s * 0.1, 0.015, 0.58, 0.083, 0.086),
            (s * 0.1, 0.02, 0.5, 0.078, 0.082), (s * 0.1, 0.012, 0.36, 0.07, 0.072), (s * 0.1, 0.005, 0.22, 0.067, 0.07)],
           [OV, OV, OV, OV_D, OV, OV_D], seg=10, mat=MAT_OVER, caps=(False, False))
    l.loft([(s * 0.1, 0.005, 0.215, 0.077, 0.08), (s * 0.1, 0.005, 0.165, 0.077, 0.08)], OV_L, seg=10, mat=MAT_OVER, caps=(False, False))  # rolled cuff
    l.rbox((0.105, 0.022, 0.1), (s * 0.1, 0.095, 0.56), OV_L, bevel=0.008, mat=MAT_OVER)  # knee patch
    l.rbox((0.012, 0.012, 0.3), (s * 0.1 + s * 0.077, 0.01, 0.78), OV_D, bevel=0.003, mat=MAT_OVER)  # outer seam strip
    # boot: lofted upper, heel, sole, toe cap, collar, laces
    l.loft([(s * 0.1, 0.01, 0.075, 0.062, 0.062), (s * 0.1, 0.01, 0.14, 0.068, 0.068)], BOOT, seg=9, caps=(False, False))  # shaft
    l.loft([(s * 0.1, 0.012, 0.145, 0.074, 0.072), (s * 0.1, 0.012, 0.165, 0.074, 0.072)], BOOT_D, seg=9, caps=(False, False))  # boot top band
    l.rbox((0.108, 0.17, 0.07), (s * 0.1, 0.085, 0.07), BOOT, bevel=0.016)  # foot
    l.blob((0.056, 0.07, 0.04), (s * 0.1, 0.17, 0.052), BOOT_D, seg=8, rings=4)  # toe cap
    l.rbox((0.112, 0.082, 0.04), (s * 0.1, -0.052, 0.022), BOOT_D, bevel=0.008)  # heel block
    l.rbox((0.12, 0.3, 0.022), (s * 0.1, 0.075, 0.011), SOLE, bevel=0.007)  # sole
    for k in range(3):  # laces
        l.rbox((0.066, 0.012, 0.01), (s * 0.1, 0.082 + 0.0, 0.125 - k * 0.018 + 0.0), "#C8C0A0", rot=(-0.55, 0, 0), bevel=0.002)
    l.rbox((0.04, 0.01, 0.05), (s * 0.1, 0.078, 0.115), BOOT_D, rot=(-0.5, 0, 0), bevel=0.004)  # tongue
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
    print(f"BUILD {NAME}: {tris} tris (farmer 4000 {'ok' if tris <= 4000 else 'OVER BUDGET'}) w{d.x:.2f} d{d.y:.2f} h{d.z:.2f} zmin{lo.z:.2f}")
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

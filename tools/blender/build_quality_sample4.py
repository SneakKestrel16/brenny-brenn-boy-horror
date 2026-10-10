"""QUALITY SAMPLE 4: the variant B farmer rebuilt with far fewer tris (target <= 4000, doc 07 s2) and the same look.

  sh tools/blender/run.sh tools/blender/build_quality_sample4.py

Same rig, animations, outfit, neck, shipped face and the approved 548-tri hair as build_quality_sample3 (variant B). What changed:
  - Round parts use 12-16 segments and 3-6 rings (torso, sleeves, legs, cuffs, boot, neck, collar).
  - Details are single curved slabs laid on the chest/leg curve (no boxes then subdivide-and-bend), with walls but no back or bottom face.
  - Stitching dashes, laces' criss-cross boxes, lugs, welt, creases and thread are dropped or reduced to flat strips and 4-tri pyramids
    (rivets, buttons, eyelets); buckles are one brass box with a dark quad.
  - post(): ray-cast hidden-face removal inside each limb object (faces whose centre and corners all sit inside the solid), plus a
    same-colour limited dissolve. The Head is left alone (shipped face verbatim, hair as approved).
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_phase4 as B  # noqa: E402
import build_quality_sample as Q  # noqa: E402
import build_quality_sample2 as Q2  # noqa: E402
from build_phase4 import BRASS, MAT_FLAT, srgb  # noqa: E402
from build_quality_sample import BOOT, BOOT_D, OV, OV_D, OV_L, SHIRT, SHIRT_D, SKIN_D, SOLE  # noqa: E402
from build_quality_sample2 import MAT_OVER, MAT_SLEEVE, _chest_drop  # noqa: E402

HAIR_DETAIL = True  # build_quality_sample3.make: use the approved 548-tri hair
BIB_DROP = 0.122
LACE = "#C8C0A0"
DARK = "#1E1610"


class HQ4(Q2.HQ2):
    def slab(self, cx, cz, w, h, nx, nz, top, base, col, wcol=None, mat=MAT_OVER, sign=1, walls=True):
        """A curved plate: a front grid whose y follows top(x, z) (a magnitude, sign gives front/back), walls down to base(x, z),
        no back face. One mesh island."""
        bm = self.bm
        wcol = wcol or col

        def xz(i, j):
            return cx - w / 2 + w * i / nx, cz - h / 2 + h * j / nz
        T = [[bm.verts.new((xz(i, j)[0], sign * top(*xz(i, j)), xz(i, j)[1])) for j in range(nz + 1)] for i in range(nx + 1)]
        newf = []
        for i in range(nx):
            for j in range(nz):
                f = bm.faces.new((T[i][j], T[i][j + 1], T[i + 1][j + 1], T[i + 1][j]))
                f.normal_update()
                if f.normal.y * sign < 0:
                    f.normal_flip()
                newf.append((f, col))
        if walls:
            Bv = {}

            def bv(i, j):
                if (i, j) not in Bv:
                    Bv[(i, j)] = bm.verts.new((xz(i, j)[0], sign * base(*xz(i, j)), xz(i, j)[1]))
                return Bv[(i, j)]
            edges = [((i, 0), (i + 1, 0)) for i in range(nx)] + [((i, nz), (i + 1, nz)) for i in range(nx)]
            edges += [((0, j), (0, j + 1)) for j in range(nz)] + [((nx, j), (nx, j + 1)) for j in range(nz)]
            for a, b in edges:
                f = bm.faces.new((T[a[0]][a[1]], T[b[0]][b[1]], bv(*b), bv(*a)))
                f.normal_update()
                mid = (Vector(xz(*a)) + Vector(xz(*b))) / 2 - Vector((cx, cz))
                t = Vector(xz(*b)) - Vector(xz(*a))
                mid -= t * (mid.dot(t) / t.length_squared)
                if f.normal.x * mid.x + f.normal.z * mid.y < 0:
                    f.normal_flip()
                newf.append((f, wcol))
        for f, c in newf:
            f.material_index, f.smooth = mat, False
            for l in f.loops:
                l[self.lay] = srgb(c)

    def stud(self, x, y, z, r, d, col=BRASS, mat=MAT_FLAT):
        """A 4-tri pyramid (rivet, button, eyelet) pointing along the axis vector d."""
        bm = self.bm
        d = Vector(d)
        u = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        a = d.cross(u).normalized() * r
        b = d.cross(a).normalized() * r
        c = Vector((x, y, z))
        ring = [bm.verts.new(c + a), bm.verts.new(c + b), bm.verts.new(c - a), bm.verts.new(c - b)]
        apex = bm.verts.new(c + d * (r * 0.7))
        for k in range(4):
            f = bm.faces.new((ring[k], ring[(k + 1) % 4], apex))
            f.normal_update()
            if f.normal.dot(d) < 0:
                f.normal_flip()
            f.material_index, f.smooth = mat, False
            for l in f.loops:
                l[self.lay] = srgb(col)

    def quad(self, pts, col, hint, mat=MAT_FLAT):
        f = self.bm.faces.new([self.bm.verts.new(p) for p in pts])
        f.normal_update()
        if f.normal.dot(Vector(hint)) < 0:
            f.normal_flip()
        f.material_index, f.smooth = mat, False
        for l in f.loops:
            l[self.lay] = srgb(col)


# ------------------------------------------------------------------------------------------------ torso
def torso():
    t = HQ4("Torso", (0, 0, 1.0))
    S = 16
    # shirt rings sit on the _CHEST table rows, so the slabs below follow the same curve
    SH = [(0, 0, 0.90, 0.195, 0.118), (0, 0.006, 1.04, 0.208, 0.128), (0, 0.009, 1.12, 0.186, 0.12), (0, 0.01, 1.20, 0.172, 0.113),
          (0, 0.008, 1.28, 0.18, 0.114), (0, 0.004, 1.36, 0.195, 0.116), (0, 0.0, 1.43, 0.207, 0.115), (0, -0.004, 1.49, 0.2, 0.108),
          (0, -0.007, 1.53, 0.15, 0.095), (0, -0.008, 1.58, 0.06, 0.065)]
    t.loft(SH, [SHIRT_D, SHIRT_D] + [SHIRT] * 7, seg=S, caps=(False, False))
    SHELL = [(0, 0, 0.91, 0.207, 0.126), (0, 0.007, 1.04, 0.22, 0.137), (0, 0.01, 1.12, 0.198, 0.13), (0, 0.011, 1.20, 0.184, 0.123),
             (0, 0.009, 1.28, 0.192, 0.124), (0, 0.005, 1.35, 0.205, 0.125)]
    t.loft(SHELL, [OV_D, OV, OV, OV, OV_L], seg=S, mat=MAT_OVER, caps=(False, False))
    D = BIB_DROP

    def top(yc, th):
        return lambda x, z: yc + th / 2 - _chest_drop(x, z)

    def base(yc, th):
        return lambda x, z: yc - th / 2 - _chest_drop(x, z)
    # bib, hem, chest pocket and flap: one curved slab each
    t.slab(0, 1.352 - D, 0.275, 0.235, 4, 2, top(0.134, 0.026), base(0.134, 0.026), OV_L, OV_D)
    t.slab(0, 1.472 - D, 0.285, 0.02, 4, 1, top(0.136, 0.03), base(0.136, 0.03), OV_D)
    sf = lambda x, z: 0.1485 - _chest_drop(x, z)  # noqa: E731  stitching: solid thread lines (not dashes) round the bib edge
    for dz in (-0.1075, 0.1075):
        t.slab(0, 1.352 - D + dz, 0.255, 0.004, 4, 1, sf, sf, "#8A8F8C", walls=False)
    for dx in (-0.1275, 0.1275):
        t.slab(dx, 1.352 - D, 0.004, 0.215, 1, 2, sf, sf, "#8A8F8C", walls=False)
    t.slab(0, 1.325 - D, 0.105, 0.08, 2, 1, top(0.152, 0.016), base(0.152, 0.016), OV, OV_D)
    t.slab(0, 1.362 - D, 0.11, 0.016, 2, 1, top(0.158, 0.016), base(0.158, 0.016), OV_D)
    t.stud(0, 0.168 - _chest_drop(0, 1.358 - D), 1.358 - D, 0.007, (0, 1, 0))
    for sx in (-1, 1):
        x = sx * 0.095
        t.slab(x, 1.435, 0.046, 0.19, 1, 2, top(0.131, 0.016), base(0.131, 0.016), OV, OV_D)  # strap, front
        t.box((0.046, 0.15, 0.022), (x, -0.005, 1.545), OV, bevel=0, mat=MAT_OVER)  # over the shoulder
        t.slab(x, 1.465, 0.046, 0.12, 1, 1, top(0.115, 0.016), base(0.115, 0.016), OV, OV_D, sign=-1)  # back
        by, bz = 0.148 - _chest_drop(x, 1.43), 1.43  # buckle: brass box and a dark centre quad
        t.box((0.042, 0.01, 0.038), (x, by, bz), BRASS, bevel=0)
        t.quad([(x - 0.012, by + 0.0055, bz - 0.01), (x + 0.012, by + 0.0055, bz - 0.01), (x + 0.012, by + 0.0055, bz + 0.01),
                (x - 0.012, by + 0.0055, bz + 0.01)], "#8A7228", (0, 1, 0))
        t.stud(x, 0.153 - _chest_drop(x, 1.37), 1.37, 0.011, (0, 1, 0))  # bib corner rivets
        t.stud(sx * 0.105, 0.148 - _chest_drop(sx * 0.105, 1.485), 1.485, 0.011, (0, 1, 0))
        # hip and back pockets
        t.slab(sx * 0.12, 1.035, 0.135, 0.11, 2, 1, top(0.145, 0.018), base(0.145, 0.018), OV_L, OV_D)
        t.slab(sx * 0.09, 1.02, 0.12, 0.105, 2, 1, top(0.14, 0.018), base(0.14, 0.018), OV_L, OV_D, sign=-1)
        for dx in (-0.06, 0.06):
            t.stud(sx * 0.12 + dx, 0.157 - _chest_drop(sx * 0.12 + dx, 1.082), 1.082, 0.01, (0, 1, 0))
        t.stud(sx * 0.19, 0.05, 1.28, 0.013, (sx, 0, 0))  # side button
    # waist creases: flat dark strips on the bib
    for i, z in enumerate((1.16, 1.11, 1.21)):
        ln = (0.12, 0.1, 0.09)[i]
        t.slab(0, z, ln * 2, 0.012, 2, 1, lambda x, zz: 0.149 - _chest_drop(x, zz), lambda x, zz: 0.14 - _chest_drop(x, zz), OV_D, walls=False)
    t.done()


# ------------------------------------------------------------------------------------------------ neck
def neck_part():
    n = HQ4("Neck", (0, 0, 1.4))
    n.loft([(0, 0, 1.38, 0.066, 0.07), (0, 0, 1.46, 0.061, 0.065), (0, 0.004, 1.54, 0.058, 0.06)], [Q2.SKIN_D, Q.SKIN], seg=10, caps=(False, False))
    n.loft([(0, 0, 1.405, 0.098, 0.092), (0, 0, 1.425, 0.09, 0.084), (0, 0, 1.444, 0.083, 0.077)], [SHIRT, SHIRT_D], seg=12, caps=(False, False))
    n.done()


# ------------------------------------------------------------------------------------------------ arms
def arm(s, nm):
    sh = (s * 0.235, 0.0, 1.5)
    a = HQ4(nm, sh)
    M = MAT_SLEEVE
    Q.HQ.blob(a, (0.083, 0.08, 0.085), sh, SHIRT, seg=10, rings=5, mat=M)  # shoulder cap
    a.loft([(s * 0.236, 0.0, 1.495, 0.07, 0.068), (s * 0.243, 0.009, 1.39, 0.066, 0.066), (s * 0.249, 0.017, 1.285, 0.062, 0.062)],
           [SHIRT, SHIRT_D], seg=10, mat=M, caps=(False, False))
    a.path([(s * 0.249, 0.017, 1.316), (s * 0.25, 0.019, 1.30), (s * 0.25, 0.019, 1.26), (s * 0.25, 0.02, 1.244)],
           [(0.063, 0.063), (0.074, 0.074), (0.074, 0.074), (0.063, 0.063)], [SHIRT_D, SHIRT, SHIRT_D], seg=10, mat=M, caps=(False, False))
    a.loft([(s * 0.25, 0.02, 1.24, 0.052, 0.052), (s * 0.25, 0.055, 1.12, 0.048, 0.047), (s * 0.25, 0.085, 1.02, 0.036, 0.036),
            (s * 0.25, 0.097, 0.985, 0.036, 0.034)], [Q.SKIN, Q.SKIN, SKIN_D], seg=10, mat=M, caps=(False, False))
    Q.shipped_hand(a, s)
    a.done()


# ------------------------------------------------------------------------------------------------ legs
_LEG = [(0.93, 0.0, 0.109, 0.109), (0.76, 0.007, 0.096, 0.098), (0.58, 0.017, 0.081, 0.086), (0.5, 0.02, 0.077, 0.082),
        (0.33, 0.01, 0.069, 0.073), (0.215, 0.005, 0.07, 0.073)]


def _leg_surf(X):
    def f(x, z):
        z = min(max(z, _LEG[-1][0]), _LEG[0][0])
        for a, b in zip(_LEG[::-1], _LEG[::-1][1:]):
            if a[0] <= z <= b[0]:
                k = (z - a[0]) / (b[0] - a[0])
                cy, rx, ry = (a[j] + (b[j] - a[j]) * k for j in (1, 2, 3))
                u = min(0.97, abs(x - X) / rx)
                return cy + ry * math.sqrt(1 - u * u)
    return f


def leg(s, nm):
    hip = (s * 0.1, 0.0, 0.98)
    l = HQ4(nm, hip)
    X = s * 0.1
    l.loft([(X, cy, z, rx, ry) for z, cy, rx, ry in _LEG], [OV, OV, OV_D, OV, OV_D], seg=12, mat=MAT_OVER, caps=(False, False))
    sf = _leg_surf(X)
    l.slab(X, 0.545, 0.095, 0.11, 2, 1, lambda x, z: sf(x, z) + 0.014, lambda x, z: sf(x, z) - 0.003, OV_L, OV_D)  # knee patch
    l.path([(X, 0.005, 0.237), (X, 0.005, 0.215), (X, 0.005, 0.17), (X, 0.005, 0.148)],
           [(0.069, 0.072), (0.081, 0.085), (0.081, 0.085), (0.07, 0.073)], [OV_L, OV_D, OV], seg=12, mat=MAT_OVER, caps=(False, False))
    # boot
    l.loft([(X, 0.011, 0.07, 0.064, 0.066), (X, 0.011, 0.15, 0.07, 0.072), (X, 0.012, 0.18, 0.075, 0.077)], [BOOT, BOOT_D], seg=12, caps=(False, False))
    Q.HQ.blob(l, (0.058, 0.115, 0.05), (X, 0.075, 0.07), BOOT, seg=12, rings=7)
    Q.HQ.blob(l, (0.06, 0.04, 0.045), (X, -0.045, 0.058), BOOT, seg=8, rings=4)  # heel counter
    Q.HQ.blob(l, (0.052, 0.045, 0.032), (X, 0.218, 0.044), BOOT_D, seg=8, rings=4)  # toe tip
    Q.HQ.blob(l, (0.057, 0.065, 0.044), (X, 0.17, 0.056), BOOT_D, seg=8, rings=4)  # toe cap
    l.box((0.12, 0.31, 0.024), (X, 0.075, 0.012), SOLE, bevel=0)
    l.box((0.12, 0.07, 0.03), (X, -0.052, 0.015), DARK, bevel=0)  # heel block
    l.quad([(X - 0.0225, 0.065, 0.095), (X + 0.0225, 0.065, 0.095), (X + 0.0225, 0.099, 0.145), (X - 0.0225, 0.099, 0.145)], BOOT_D, (0, 1, 1))  # tongue
    for k in range(3):
        z, y = 0.14 - k * 0.019, 0.074 + k * 0.016
        for sg in (-1, 1):  # crossed laces and eyelets
            ex, ez = math.cos(0.5 * sg) * 0.029, math.sin(0.5 * sg) * 0.029
            l.quad([(X - ex, y + 0.006, z - ez - 0.0025), (X + ex, y + 0.006, z + ez - 0.0025), (X + ex, y + 0.006, z + ez + 0.0025),
                    (X - ex, y + 0.006, z - ez + 0.0025)], LACE, (0, 1, 0))
            l.stud(X + sg * 0.026, y + 0.003, z, 0.007, (0, 1, 0))
    for sg in (-1, 1):  # bow loops
        l.stud(X + sg * 0.012, 0.118, 0.054, 0.012, (0, 1, 0), col=LACE)
    l.done()


# ------------------------------------------------------------------------------------------------ post pass
def cull_hidden(ob):
    """Delete faces whose centre and (pulled-in) corners all lie inside a solid of the same object, then dissolve flat same-colour edges."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()
    bvh = BVHTree.FromBMesh(bm)
    kill = []
    for f in bm.faces:
        n = f.normal
        c = f.calc_center_median()
        hid = True
        for p in [c] + [c.lerp(v.co, 0.8) for v in f.verts]:
            hit, nrm, _i, _d = bvh.ray_cast(p + n * 0.0015, n)
            if hit is None or nrm.dot(n) <= 0:
                hid = False
                break
        if hid:
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    lay = bm.loops.layers.color.get("Col")
    flat = []
    for e in bm.edges:
        if len(e.link_faces) == 2:
            a, b = e.link_faces
            if a.material_index == b.material_index and not a.smooth and not b.smooth and a.normal.dot(b.normal) > 0.9998 and \
                    all(max(abs(la[lay][i] - lb[lay][i]) for i in range(3)) < 0.02 for la in a.loops[:1] for lb in b.loops[:1]):
                flat.append(e)
    if flat:
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.5), use_dissolve_boundaries=False, verts=[], edges=flat)
    bm.to_mesh(ob.data)
    bm.free()
    return len(kill), len(flat)


def post():
    for ob in B.Ctx.objs:
        if ob.type == "MESH" and ob.name != "Head":
            k, d = cull_hidden(ob)
            print(f"  cull {ob.name}: {k} hidden faces deleted, {d} flat edges dissolved")


if __name__ == "__main__":
    import build_quality_sample3 as Q3
    Q.HAND["shipped"] = True
    Q2.BIB_DROP = BIB_DROP
    Q3.make("farmer_B_opt_sample", sys.modules[__name__], body=True)
    Q3.make("farmer_orig_hqclothes_opt_sample", Q, post=post)

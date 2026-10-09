"""Phase 4 gray-box models (P4-16, doc 07 s11). Headless:

  "/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/blender/build_phase4.py [-- name ...]

Writes assets/models/<name>.glb and assets/blender/<name>.blend, one fresh scene per model.
Blender coords: Z up, the model FRONT is +Y (glTF/Godot -Z, CONTRACTS s4). 1 unit = 1 m.
Origin is at the base (feet). Flat colour lives in the vertex colour layer "Col"; three
materials only (doc 07 s7): mat_flat_lit, mat_emissive_warm, mat_emissive_ember.
Each body part is its own object (own pivot) so a glimpse can show one part (doc 07 s2).
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_GLB = os.path.join(ROOT, "assets", "models")
OUT_BLEND = os.path.join(ROOT, "assets", "blender")
MAT_FLAT, MAT_WARM, MAT_EMBER = 0, 1, 2
BUDGET = {"small": 300, "mid": 800, "large": 2000, "creature": 5000, "bldg": 12000}


def lin(h):
    def f(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (f(int(h[1:3], 16)), f(int(h[3:5], 16)), f(int(h[5:7], 16)), 1.0)


def srgb(h):
    """Hex as raw sRGB floats, for the vertex colour layer. The bmesh layer is byte colour
    (sRGB-encoded storage) and the glTF exporter linearises it into COLOR_0, so lin() here
    would linearise twice (QA P4-16: #C8761F arrived as (0.29, 0.02, 0.0), dark red)."""
    return (int(h[1:3], 16) / 255.0, int(h[3:5], 16) / 255.0, int(h[5:7], 16) / 255.0, 1.0)


class Ctx:
    objs: list = []


def make_materials():
    out = []
    for name, emit in (("mat_flat_lit", None), ("mat_emissive_warm", "#FFB45A"), ("mat_emissive_ember", "#FF5A1F")):
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
        if emit:
            bsdf.inputs["Emission Color"].default_value = lin(emit)
            bsdf.inputs["Emission Strength"].default_value = 1.0
        nt.links.new(bsdf.outputs["BSDF"], out_n.inputs["Surface"])
        out.append(m)
    return out


class Part:
    """Accumulates primitives (centre-positioned, model space) into one object with its own pivot."""

    def __init__(self, name, pivot=(0, 0, 0), off=(0, 0, 0)):
        self.name, self.pivot, self.off = name, Vector(pivot), Vector(off)
        self.bm = bmesh.new()
        self.lay = self.bm.loops.layers.color.new("Col")

    def _fin(self, verts, col, mat):
        c = srgb(col)
        for f in {f for v in verts for f in v.link_faces}:
            f.material_index = mat
            f.smooth = False
            for l in f.loops:
                l[self.lay] = c

    def _xf(self, verts, centre, rot, scale):
        M = Matrix.Translation(Vector(centre) + self.off) @ Euler(rot, "XYZ").to_matrix().to_4x4() @ Matrix.Diagonal((*scale, 1))
        bmesh.ops.transform(self.bm, matrix=M, verts=verts)

    def box(self, size, centre, col, rot=(0, 0, 0), mat=MAT_FLAT):
        v = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        self._xf(v, centre, rot, size)
        self._fin(v, col, mat)
        return self

    def ball(self, radii, centre, col, rot=(0, 0, 0), mat=MAT_FLAT, seg=8, rings=6):
        v = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=1.0)["verts"]
        self._xf(v, centre, rot, radii)
        self._fin(v, col, mat)
        return self

    def cyl(self, r1, r2, depth, centre, col, rot=(0, 0, 0), seg=8, mat=MAT_FLAT):
        """Cone/cylinder on local Z; r1 at the -Z end."""
        v = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=depth)["verts"]
        self._xf(v, centre, rot, (1, 1, 1))
        self._fin(v, col, mat)
        return self

    def between(self, a, b, r1, r2, col, seg=6, mat=MAT_FLAT):
        a, b = Vector(a), Vector(b)
        d = b - a
        rot = Vector((0, 0, 1)).rotation_difference(d).to_euler()
        return self.cyl(r1, r2, d.length, (a + b) / 2, col, rot=rot, seg=seg, mat=mat)

    def done(self):
        bm = self.bm
        bmesh.ops.translate(bm, vec=-self.pivot, verts=bm.verts)
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        for m in Ctx.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        ob.location = self.pivot
        bpy.context.scene.collection.objects.link(ob)
        Ctx.objs.append(ob)
        return ob


def empty(name, loc):
    ob = bpy.data.objects.new(name, None)
    ob.location = loc
    bpy.context.scene.collection.objects.link(ob)
    Ctx.objs.append(ob)


def reset():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    for coll in (bpy.data.meshes, bpy.data.materials):
        for x in list(coll):
            coll.remove(x)
    Ctx.objs = []
    Ctx.mats = make_materials()


def ring_pts(n, r, z=0.0, phase=0.0):
    return [(r * math.cos(phase + i * math.tau / n), r * math.sin(phase + i * math.tau / n), z) for i in range(n)]


# ---------------------------------------------------------------- creatures
HIDE, HIDE2, BONE, EMBER = "#1E1B1A", "#2C2624", "#B8AE98", "#FF5A1F"


def gaunt():
    p = Part("Torso", (0, -0.1, 1.0))
    p.between((0, -0.1, 1.0), (0, 0.1, 1.95), 0.2, 0.24, HIDE, seg=7)
    p.ball((0.24, 0.2, 0.2), (0, 0.05, 1.9), HIDE2, seg=7, rings=5)  # hump
    for i in range(4):  # ribs
        z = 1.15 + i * 0.2
        p.box((0.44, 0.05, 0.03), (0, 0.06 + i * 0.03 - 0.1, z), BONE)
    p.done()
    q = Part("Head", (0, 0.35, 1.6))
    q.ball((0.12, 0.2, 0.13), (0, 0.5, 1.55), "#8E8777", seg=7, rings=5)
    q.box((0.1, 0.16, 0.04), (0, 0.58, 1.44), BONE)  # jaw
    for sx in (-1, 1):
        q.ball((0.025, 0.02, 0.025), (sx * 0.06, 0.66, 1.6), EMBER, mat=MAT_EMBER, seg=5, rings=4)
    q.done()
    for s, nm in ((-1, "ArmL"), (1, "ArmR")):
        sh, el, ha = (s * 0.3, 0.1, 1.85), (s * 0.4, 0.3, 1.2), (s * 0.36, 0.36, 0.4)
        a = Part(nm, sh)
        a.between(sh, el, 0.07, 0.05, HIDE2, seg=5).between(el, ha, 0.05, 0.035, HIDE2, seg=5)
        for k in (-1, 0, 1):  # claw fingers
            a.between(ha, (ha[0] + k * 0.04, ha[1] + 0.08, 0.2), 0.025, 0.01, BONE, seg=4)
        a.done()
    for s, nm in ((-1, "LegL"), (1, "LegR")):
        hip, kn, ft = (s * 0.17, -0.15, 1.0), (s * 0.2, 0.1, 0.5), (s * 0.2, -0.05, 0.0)
        l = Part(nm, hip)
        l.between(hip, kn, 0.1, 0.06, HIDE, seg=5).between(kn, ft, 0.06, 0.035, HIDE, seg=5)
        l.box((0.1, 0.2, 0.04), (s * 0.2, 0.05, 0.02), HIDE2)
        l.done()


def scarecrow_head(p):
    p.ball((0.19, 0.19, 0.22), (0, 0, 1.86), "#A58C5A", seg=8, rings=6)
    p.cyl(0.07, 0.08, 0.1, (0, 0, 1.68), "#A58C5A", seg=6)  # neck
    p.box((0.015, 0.02, 0.34), (0, 0.19, 1.86), "#2A2018")  # stitch seam
    for z in (1.76, 1.86, 1.96):
        p.box((0.1, 0.02, 0.015), (0, 0.19, z), "#2A2018")
    for sx in (-1, 1):
        p.ball((0.03, 0.02, 0.035), (sx * 0.08, 0.18, 1.9), EMBER, mat=MAT_EMBER, seg=5, rings=4)
    p.cyl(0.32, 0.31, 0.025, (0, 0, 2.02), "#4A3C28", seg=10)  # hat brim
    p.cyl(0.19, 0.12, 0.2, (0, 0, 2.12), "#4A3C28", seg=8)  # crown
    for i in range(5):  # straw
        p.between((0, 0.12, 1.7 + 0.0), ((i - 2) * 0.07, 0.3, 1.62), 0.012, 0.004, "#C9B26A", seg=3)


def scarecrow():
    t = Part("Torso", (0, 0, 0.7))
    t.cyl(0.4, 0.2, 0.9, (0, 0, 1.15), "#3B3226", seg=8)  # coat
    t.cyl(0.4, 0.4, 0.04, (0, 0, 0.72), "#2A2218", seg=8)
    for i in range(10):  # ragged hem tatters
        a = i * math.tau / 10
        h = 0.18 + 0.12 * ((i * 7) % 3)
        t.box((0.1, 0.02, h), (0.4 * math.cos(a), 0.4 * math.sin(a), 0.7 - h / 2 + 0.03), "#2F281D", rot=(0, 0, a + math.pi / 2))
    t.box((0.18, 0.02, 0.18), (0.1, 0.2, 1.3), "#5A4A2E")  # patch
    t.done()
    for s, nm in ((-1, "ArmL"), (1, "ArmR")):
        sh, ha = (s * 0.2, 0.0, 1.5), (s * 0.5, 0.3, 0.95)
        a = Part(nm, sh)
        a.between(sh, ha, 0.09, 0.06, "#3B3226", seg=6)
        for k in (-1, 0, 1):
            a.between(ha, (ha[0] + s * 0.04 * (k + 2) * 0.5, ha[1] + 0.12, ha[2] - 0.2), 0.012, 0.004, "#C9B26A", seg=3)
        a.done()
    for s, nm in ((-1, "LegL"), (1, "LegR")):
        l = Part(nm, (s * 0.1, 0, 0.75))
        l.between((s * 0.1, 0, 0.75), (s * 0.12, 0.03, 0.0), 0.05, 0.035, "#4A3C28", seg=5)
        l.done()


def _head_part(builder, name, pivot, standalone):
    p = Part(name, (0, 0, 0) if standalone else pivot, off=(-pivot[0], -pivot[1], -pivot[2]) if standalone else (0, 0, 0))
    builder(p)
    return p.done()


def husk_heart(p):
    p.ball((0.17, 0.17, 0.2), (0, 0, 1.2), EMBER, mat=MAT_EMBER, seg=7, rings=5)


def husk():
    p = Part("Stalks", (0, 0, 0))
    n = 16
    for i in range(n):
        a = i * math.tau / n
        r0, r1 = 0.42, 0.24 + 0.05 * math.sin(i * 2.3)
        h = 1.9 + 0.5 * ((i * 5) % 4) / 3
        p.between((r0 * math.cos(a), r0 * math.sin(a), 0), (r1 * math.cos(a), r1 * math.sin(a), h), 0.045, 0.012, "#7E7432" if i % 2 else "#5E5A2A", seg=5)
    for i in range(10):  # peeled leaves hanging off the torso
        a = i * math.tau / 10 + 0.3
        r = 0.3
        p.box((0.17, 0.012, 0.7), (r * math.cos(a), r * math.sin(a), 1.25 + 0.15 * (i % 3)), "#A89A52" if i % 2 else "#8C8442",
              rot=(0.0, 0.0, a + math.pi / 2))
    p.done()
    _head_part(lambda q: (q.ball((0.14, 0.14, 0.24), (0, 0.04, 2.05), "#9A8F48", seg=7, rings=5),
                          [q.between((0, 0.1, 2.25), ((k - 2) * 0.05, 0.2, 2.4), 0.012, 0.004, "#C9B26A", seg=3) for k in range(5)]),
               "Head", (0, 0, 1.85), False)
    for s, nm in ((-1, "ArmL"), (1, "ArmR")):
        sh, ha = (s * 0.3, 0, 1.6), (s * 0.46, 0.45, 0.9)
        a = Part(nm, sh)
        for k in range(3):
            a.between((sh[0] + k * 0.02 * s, sh[1], sh[2] - k * 0.04), (ha[0] + (k - 1) * 0.04, ha[1] + k * 0.03, ha[2] - k * 0.05), 0.04, 0.01, "#7E7432", seg=4)
        a.done()
    _head_part(husk_heart, "Heart", (0, 0, 1.2), False)


def boar():
    b = Part("Body", (0, 0, 0.8))
    b.ball((0.55, 0.75, 0.58), (0, -0.1, 0.85), "#3A2E27", seg=9, rings=6)
    b.ball((0.45, 0.4, 0.38), (0, 0.2, 1.1), "#2E241F", seg=8, rings=5)  # shoulder hump
    for i in range(5):  # bristle ridge
        b.box((0.05, 0.12, 0.12), (0, 0.5 - i * 0.28, 1.45 - 0.05 * abs(i - 1)), HIDE)
    b.between((0, -0.8, 1.0), (0.1, -0.95, 0.7), 0.04, 0.015, "#3A2E27", seg=4)  # tail
    for sx in (-1, 1):
        for y in (-0.4, 0.4):
            b.between((sx * 0.32, y, 0.55), (sx * 0.32, y, 0.0), 0.13, 0.09, "#2E241F", seg=6)
            b.box((0.16, 0.2, 0.06), (sx * 0.32, y + 0.03, 0.03), HIDE)
    b.done()
    h = Part("Head", (0, 0.6, 0.8))
    h.ball((0.36, 0.38, 0.34), (0, 0.85, 0.8), "#3A2E27", seg=8, rings=6)
    h.between((0, 1.1, 0.72), (0, 1.4, 0.66), 0.19, 0.15, "#4A3A33", seg=7)
    for sx in (-1, 1):
        h.between((sx * 0.14, 1.3, 0.6), (sx * 0.2, 1.48, 0.98), 0.045, 0.01, BONE, seg=5)  # tusk
        h.ball((0.03, 0.02, 0.03), (sx * 0.2, 1.12, 0.92), EMBER, mat=MAT_EMBER, seg=5, rings=4)
        h.box((0.1, 0.03, 0.16), (sx * 0.28, 0.75, 1.12), "#2E241F", rot=(0.4, 0, sx * 0.3))  # ear
    h.done()
    collar(Part("Collar", (0, 0.6, 0.85)))
    chain(Part("Chain", (0, 0.6, 0.85)))


def collar(p):
    p.cyl(0.45, 0.45, 0.12, (0, 0.6, 0.85), "#55595C", rot=(math.pi / 2 - 0.2, 0, 0), seg=10)
    p.box((0.08, 0.08, 0.08), (0, 0.65, 0.42), "#6A6F72")  # ring at the chin
    p.done()


def chain(p):
    pts = [(0, 0.65, 0.4), (0, 0.65, 0.25), (0, 0.6, 0.1), (0, 0.35, 0.02), (0, 0.05, 0.02), (0, -0.25, 0.02), (0, -0.55, 0.02)]
    for i in range(len(pts) - 1):
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        p.between(a, b, 0.025, 0.025, "#4C5154", seg=4)
        p.box((0.07, 0.07, 0.04), (a + b) / 2, "#6A6F72", rot=(0, 0, 0.5))
    p.done()


def hull_of(name, col="#6C7A99"):
    """Convex hull of everything built so far (the ghost-view smear, doc 07 s8)."""
    bpy.context.view_layer.update()
    verts = []
    for ob in Ctx.objs:
        verts += [ob.matrix_world @ v.co for v in ob.data.vertices]
    for ob in list(Ctx.objs):
        bpy.data.objects.remove(ob)
    Ctx.objs = []
    p = Part(name)
    bm = p.bm
    vs = [bm.verts.new(v) for v in verts]
    bmesh.ops.convex_hull(bm, input=vs, use_existing_faces=False)
    # drop interior points the hull left behind, then flat-colour it
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    p._fin(list(bm.verts), col, MAT_FLAT)
    p.done()


# ---------------------------------------------------------------- pumpkins
def pumpkin(d, h, bites=0, sad=False):
    p = Part("Pumpkin")
    bm = p.bm
    v = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1.0)["verts"]
    base = "#C8761F" if not sad else "#A8794A"
    for vt in v:
        th = math.atan2(vt.co.y, vt.co.x)
        k = (1 + 0.07 * math.cos(8 * th) * (1 - abs(vt.co.z))) / 1.07
        vt.co.x *= k * d / 2
        vt.co.y *= k * d / 2
        vt.co.z = (vt.co.z * 0.5 + 0.5) * h * 0.88
    cream = srgb("#E8D3A0")
    centres = [Vector((0.5 * d * 0.78, 0.2 * d, 0.55 * h)), Vector((-0.4 * d * 0.78, -0.35 * d, 0.7 * h)),
               Vector((0.1 * d, -0.45 * d, 0.4 * h)), Vector((-0.45 * d, 0.2 * d, 0.45 * h))][:bites]
    for c in centres:
        R = 0.28 * d
        for vt in v:
            dist = (vt.co - c).length
            if dist < R:
                vt.co += (Vector((0, 0, h * 0.44)) - vt.co).normalized() * 0.28 * R * (1 - dist / R)
    p._fin(v, base, MAT_FLAT)
    lay = p.lay
    for f in bm.faces:
        for l in f.loops:
            if any((l.vert.co - c).length < 0.28 * d for c in centres):
                l[lay] = cream
    p.box((d * 0.07, d * 0.07, h * 0.16), (0, 0, h * 0.94), "#4F5A2B", rot=(0.15 if sad else 0, 0, 0))
    p.done()


def patch():
    p = Part("Patch")
    p.cyl(2.0, 2.0, 0.08, (0, 0, 0.04), "#4A3322", seg=16)
    p.cyl(1.7, 1.1, 0.12, (0, 0, 0.14), "#5A4029", seg=12)
    for i in range(10):
        a = i * math.tau / 10
        p.ball((0.18, 0.15, 0.1), (1.9 * math.cos(a), 1.9 * math.sin(a), 0.1), "#7A756C", seg=5, rings=4)
    for i in range(6):  # vines out from the middle, wavy
        a = i * math.tau / 6 + 0.2
        prev = Vector((0.6 * math.cos(a), 0.6 * math.sin(a), 0.12))
        for k in range(1, 5):
            r = 0.6 + k * 0.28
            aa = a + 0.18 * math.sin(k * 1.4 + i)
            nxt = Vector((r * math.cos(aa), r * math.sin(aa), 0.12))
            p.between(prev, nxt, 0.03, 0.025, "#3F5A2A", seg=4)
            if k % 2 == 0:
                p.box((0.34, 0.3, 0.015), nxt + Vector((0, 0, 0.1)), "#4F7A32", rot=(0.25, 0, aa))
            prev = nxt
    p.done()


# ---------------------------------------------------------------- cart
WOOD, WOOD2, IRON = "#7A5638", "#5C402A", "#3E4244"


def cart():
    p = Part("Cart")
    p.box((1.3, 2.4, 0.08), (0, 0.0, 0.6), WOOD)  # deck
    for sx in (-1, 1):
        p.box((0.06, 2.4, 0.3), (sx * 0.62, 0.0, 0.8), WOOD2)  # side rails
        p.cyl(0.55, 0.55, 0.1, (sx * 0.7, -0.2, 0.55), WOOD2, rot=(0, math.pi / 2, 0), seg=10)  # wheel
        p.cyl(0.1, 0.1, 0.14, (sx * 0.7, -0.2, 0.55), IRON, rot=(0, math.pi / 2, 0), seg=6)
        for k in range(4):  # spokes
            p.box((0.06, 0.05, 1.05), (sx * 0.7, -0.2, 0.55), WOOD, rot=(k * math.pi / 4, 0, 0))
    p.cyl(0.04, 0.04, 1.5, (0, -0.2, 0.55), IRON, rot=(0, math.pi / 2, 0), seg=5)  # axle
    p.box((1.24, 0.06, 0.3), (0, -1.17, 0.8), WOOD2)  # tail board
    p.box((1.24, 0.06, 0.3), (0, 1.17, 0.8), WOOD2)
    p.between((0, 1.2, 0.6), (0, 1.5, 0.45), 0.05, 0.04, WOOD2, seg=5)  # tongue
    for sx in (-1, 1):  # push handle at the back
        p.between((sx * 0.55, -1.2, 0.7), (sx * 0.55, -1.45, 1.05), 0.035, 0.03, WOOD2, seg=5)
    p.between((-0.55, -1.45, 1.05), (0.55, -1.45, 1.05), 0.035, 0.035, WOOD2, seg=5)
    p.between((0.58, 1.1, 0.64), (0.58, 1.1, 1.65), 0.04, 0.035, WOOD2, seg=5)  # lantern post
    p.between((0.58, 1.1, 1.65), (0.3, 1.1, 1.72), 0.03, 0.03, WOOD2, seg=5)
    p.done()
    empty("LanternSocket", (0.3, 1.1, 1.72))
    empty("PumpkinSlot", (0, 0, 0.64))


def lantern(w=0.2, h=0.3, hook=False):
    """Origin at the base. Cart lantern: same model, hung from LanternSocket (top ring)."""
    p = Part("Lantern")
    p.cyl(w * 0.55, w * 0.5, 0.03, (0, 0, 0.015), IRON, seg=8)
    gh = h * 0.62
    p.box((w * 0.8, w * 0.8, gh), (0, 0, 0.03 + gh / 2), "#FFB45A", mat=MAT_WARM)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((0.012, 0.012, gh + 0.01), (sx * w * 0.4, sy * w * 0.4, 0.03 + gh / 2), IRON)
    p.cyl(w * 0.55, w * 0.1, h * 0.2, (0, 0, 0.03 + gh + h * 0.1), IRON, seg=8)
    p.box((w * 0.7, 0.012, 0.03), (0, 0, h - 0.05), IRON)
    p.done()


def slot(bitten):
    p = Part("Slot")
    p.cyl(0.75, 0.75, 0.04, (0, 0, 0.02), WOOD2, seg=12)
    n = 10
    for i in range(n):
        a = i * math.tau / n
        h = 0.28
        broken = bitten and i in (2, 3)
        hh = 0.14 if broken else h
        p.box((0.2, 0.04, hh), (0.7 * math.cos(a), 0.7 * math.sin(a), 0.04 + hh / 2), WOOD,
              rot=((0.5 if broken else 0.0), 0, a + math.pi / 2))
    p.ball((0.45, 0.45, 0.04), (0, 0, 0.06), "#C9B26A", seg=8, rings=3)  # straw
    p.done()


# ---------------------------------------------------------------- town + props
def town_stand():
    p = Part("Stand")
    # front (customer side, +Y) at y=0; threshold origin at front centre
    p.box((2.8, 0.7, 0.95), (0, -0.55, 0.475), WOOD)
    p.box((3.0, 0.9, 0.05), (0, -0.55, 0.97), WOOD2)
    p.box((3.0, 0.06, 2.2), (0, -1.95, 1.1), WOOD2)  # back wall
    for sx in (-1, 1):
        p.box((0.1, 0.1, 2.5), (sx * 1.45, -0.1, 1.25), WOOD2)
        p.box((0.1, 0.1, 2.3), (sx * 1.45, -1.9, 1.15), WOOD2)
    for i in range(6):  # striped awning, front edge lower
        p.box((0.5, 2.3, 0.04), (-1.25 + i * 0.5, -1.0, 2.58), "#9A3B2B" if i % 2 == 0 else "#E8DCC0", rot=(0.1, 0, 0))
        p.box((0.5, 0.04, 0.2), (-1.25 + i * 0.5, 0.13, 2.45), "#9A3B2B" if i % 2 == 0 else "#E8DCC0")
    p.box((1.6, 0.05, 0.35), (0, -0.05, 2.1), "#E8DCC0")  # sign board
    p.box((1.3, 0.06, 0.1), (0, -0.04, 2.1), "#6B4A2F")
    p.box((0.7, 0.45, 0.3), (-0.8, -0.6, 1.15), "#9A8350")  # crate on the counter
    for k in range(3):
        p.ball((0.11, 0.11, 0.11), (-0.95 + k * 0.17, -0.6, 1.36), "#CFC3D8", seg=6, rings=4)
    p.cyl(0.25, 0.22, 0.22, (0.8, -0.6, 1.08), "#8A8277", seg=8)  # coin bowl
    p.between((1.45, -0.1, 2.3), (1.45, 0.2, 2.3), 0.02, 0.02, IRON, seg=4)  # lamp bracket
    p.ball((0.07, 0.07, 0.09), (1.45, 0.2, 2.2), "#FFB45A", mat=MAT_WARM, seg=6, rings=4)
    p.done()


def crate():
    p = Part("Crate")
    p.box((2, 1, 0.9), (0, 0, 0.45), "#8A7448")
    for sx in (-1, 1):
        p.box((0.1, 1.04, 0.95), (sx * 0.95, 0, 0.475), WOOD2)
    p.box((2.04, 0.1, 0.1), (0, 0.5, 0.9), WOOD2)
    p.box((2.04, 0.1, 0.1), (0, -0.5, 0.9), WOOD2)
    p.box((1.6, 0.05, 0.6), (0, 0.52, 1.0), "#E8DCC0", rot=(-0.5, 0, 0))  # open flap with a price card
    p.done()


def scarecrow_player():
    p = Part("Scarecrow")
    p.between((0, 0, 0), (0, 0, 1.9), 0.05, 0.04, WOOD2, seg=5)
    p.between((-0.4, 0, 1.45), (0.4, 0, 1.45), 0.035, 0.035, WOOD2, seg=5)
    p.cyl(0.26, 0.15, 0.7, (0, 0, 1.15), "#3C5A7A", seg=8)  # friendly blue shirt
    p.ball((0.17, 0.17, 0.19), (0, 0, 1.72), "#C9A86A", seg=8, rings=6)
    for sx in (-1, 1):
        p.ball((0.025, 0.02, 0.025), (sx * 0.07, 0.15, 1.76), "#222222", seg=4, rings=3)
    p.box((0.1, 0.02, 0.02), (0, 0.16, 1.66), "#222222")
    p.box((0.2, 0.2, 0.04), (0, 0.05, 1.5), "#9A3B2B", rot=(0, 0.5, 0))  # neckerchief
    p.cyl(0.4, 0.3, 0.03, (0, 0, 1.88), "#D2B15A", seg=10)
    p.cyl(0.17, 0.12, 0.14, (0, 0, 1.96), "#D2B15A", seg=8)
    for s in (-1, 1):
        for k in range(3):
            p.between((s * 0.4, 0, 1.45), (s * 0.5, 0.04 * (k - 1), 1.35 - 0.02 * k), 0.012, 0.004, "#C9B26A", seg=3)
    p.done()


def plot():
    p = Part("Plot")
    p.box((3, 3, 0.1), (0, 0, 0.05), "#6B4A2F")
    for sy in (-1, 1):
        p.box((3.0, 0.1, 0.15), (0, sy * 1.45, 0.075), WOOD)
        p.box((0.1, 3.0, 0.15), (sy * 1.45, 0, 0.075), WOOD)
    for i in range(5):
        p.box((2.6, 0.22, 0.06), (0, -1.1 + i * 0.55, 0.13), "#5A3E27")
    p.done()


# ---------------------------------------------------------------- tools
def watering_can(quiet=False):
    p = Part("Can")
    p.cyl(0.1, 0.095, 0.2, (0, 0, 0.1), "#4F7A9A" if not quiet else "#6B7C8A", seg=8)
    p.between((0, 0.08, 0.08), (0, 0.2, 0.26), 0.025, 0.02, "#4F7A9A", seg=5)
    p.cyl(0.04, 0.04, 0.02, (0, 0.2, 0.27), IRON, rot=(0.7, 0, 0), seg=6)
    p.box((0.015, 0.2, 0.025), (0, -0.04, 0.28), IRON, rot=(0.0, 0, 0))
    p.box((0.015, 0.14, 0.02), (0, -0.09, 0.2), IRON)
    p.between((0, -0.1, 0.12), (0, -0.04, 0.28), 0.012, 0.012, IRON, seg=4)
    if quiet:
        p.cyl(0.108, 0.108, 0.07, (0, 0, 0.1), "#B8AE98", seg=8)  # cloth wrap
    p.done()


def lantern_tool(bright=False):
    lantern(0.24 if bright else 0.2, 0.34 if bright else 0.3)


def walkie():
    p = Part("Walkie")
    p.box((0.08, 0.04, 0.14), (0, 0, 0.07), "#3C4A3A")
    p.cyl(0.008, 0.005, 0.06, (0.025, 0, 0.17), IRON, seg=4)
    p.box((0.05, 0.005, 0.04), (0, 0.022, 0.1), IRON)
    p.cyl(0.012, 0.012, 0.02, (-0.02, 0, 0.15), "#9A3B2B", seg=5)
    p.done()


def walkie_battery():
    Part("Battery").box((0.04, 0.02, 0.07), (0, 0, 0.035), "#C9A02A").box((0.02, 0.01, 0.01), (0, 0, 0.075), IRON).done()


def flare_gun():
    p = Part("FlareGun")
    p.cyl(0.022, 0.022, 0.2, (0, 0.08, 0.15), "#B8451F", rot=(math.pi / 2, 0, 0), seg=8)
    p.box((0.035, 0.07, 0.1), (0, -0.04, 0.09), "#4A3322", rot=(0.3, 0, 0))
    p.box((0.03, 0.06, 0.05), (0, -0.01, 0.15), IRON)
    p.box((0.01, 0.04, 0.03), (0, 0.01, 0.1), IRON)
    p.done()


def shed_lock():
    p = Part("Lock")
    p.box((0.1, 0.05, 0.08), (0, 0, 0.04), "#B89A3A")
    p.box((0.02, 0.02, 0.07), (-0.035, 0, 0.115), IRON)
    p.box((0.02, 0.02, 0.07), (0.035, 0, 0.115), IRON)
    p.box((0.09, 0.02, 0.02), (0, 0, 0.15), IRON)
    p.done()


def scrap():
    p = Part("Scrap")
    p.box((0.12, 0.08, 0.015), (0, 0, 0.008), "#6B6F72", rot=(0, 0, 0.3))
    p.box((0.08, 0.05, 0.02), (0.02, 0.01, 0.025), "#8A5A3A", rot=(0, 0.2, -0.4))
    p.cyl(0.02, 0.02, 0.05, (-0.04, 0.02, 0.03), "#55595C", rot=(0, 1.2, 0), seg=6)
    p.done()


def seed_packet(col):
    p = Part("Packet")
    p.box((0.1, 0.008, 0.15), (0, 0, 0.075), "#E8DCC0")
    p.box((0.1, 0.01, 0.05), (0, 0, 0.11), col)
    p.ball((0.02, 0.006, 0.02), (0, 0.006, 0.05), col, seg=5, rings=4)
    p.done()


# ---------------------------------------------------------------- animals
def chicken():
    p = Part("Chicken")
    p.ball((0.12, 0.15, 0.12), (0, 0, 0.22), "#E8E0D0", seg=8, rings=5)
    p.ball((0.06, 0.06, 0.07), (0, 0.13, 0.35), "#E8E0D0", seg=6, rings=4)
    p.cyl(0.02, 0.0, 0.05, (0, 0.2, 0.34), "#E8A030", rot=(math.pi / 2, 0, 0), seg=4)
    p.box((0.015, 0.05, 0.04), (0, 0.13, 0.42), "#C03030")
    p.ball((0.04, 0.12, 0.1), (0, -0.17, 0.3), "#CDBFA5", rot=(0.5, 0, 0), seg=6, rings=4)
    for sx in (-1, 1):
        p.between((sx * 0.04, 0, 0.12), (sx * 0.04, 0.0, 0.0), 0.012, 0.01, "#E8A030", seg=4)
    p.done()


def pig():
    p = Part("Pig")
    p.ball((0.28, 0.45, 0.3), (0, -0.05, 0.45), "#E8A8A0", seg=8, rings=6)
    p.ball((0.2, 0.2, 0.2), (0, 0.43, 0.5), "#E8A8A0", seg=7, rings=5)
    p.cyl(0.09, 0.09, 0.1, (0, 0.6, 0.46), "#D88880", rot=(math.pi / 2, 0, 0), seg=7)
    for sx in (-1, 1):
        p.box((0.1, 0.03, 0.12), (sx * 0.14, 0.45, 0.68), "#D88880", rot=(0.4, 0, sx * 0.4))
        for y in (-0.3, 0.25):
            p.between((sx * 0.17, y, 0.3), (sx * 0.17, y, 0.0), 0.07, 0.055, "#E8A8A0", seg=5)
    p.between((0, -0.55, 0.55), (0.05, -0.65, 0.62), 0.02, 0.01, "#D88880", seg=4)
    p.done()


def cow():
    p = Part("Cow")
    p.ball((0.38, 0.85, 0.42), (0, -0.05, 0.95), "#E8E4DA", seg=9, rings=6)
    for pos in ((0.2, 0.0, 1.15), (-0.2, -0.4, 1.0), (0.15, -0.5, 0.85)):  # spots
        p.ball((0.2, 0.28, 0.2), pos, "#2C2624", seg=5, rings=4)
    p.ball((0.18, 0.28, 0.2), (0, 0.85, 1.2), "#E8E4DA", rot=(-0.4, 0, 0), seg=7, rings=5)
    p.box((0.2, 0.1, 0.12), (0, 1.05, 1.05), "#D8A0A0")
    for sx in (-1, 1):
        p.between((sx * 0.14, 0.8, 1.38), (sx * 0.3, 0.8, 1.5), 0.03, 0.01, BONE, seg=4)
        p.box((0.12, 0.05, 0.05), (sx * 0.26, 0.78, 1.28), "#2C2624")
        for y in (-0.55, 0.5):
            p.between((sx * 0.22, y, 0.65), (sx * 0.22, y, 0.0), 0.09, 0.07, "#E8E4DA", seg=5)
            p.box((0.13, 0.15, 0.06), (sx * 0.22, y, 0.03), "#2C2624")
    p.ball((0.1, 0.12, 0.08), (0, -0.5, 0.6), "#D8A0A0", seg=5, rings=4)  # udder
    p.between((0, -0.9, 1.1), (0, -1.0, 0.5), 0.025, 0.015, "#2C2624", seg=4)
    p.done()


# ---------------------------------------------------------------- registry
# (file name, builder, budget class). Smear files wrap the body builder in hull_of.
def _smear(fn):
    return lambda: (fn(), hull_of("Smear"))


def _scarecrow_body():
    scarecrow()
    _head_part(scarecrow_head, "Head", (0, 0, 1.68), False)


MODELS = [
    ("creature_gaunt", gaunt, "creature"),
    ("creature_scarecrow", _scarecrow_body, "creature"),
    ("creature_scarecrow_head", lambda: _head_part(scarecrow_head, "Head", (0, 0, 1.68), True), "creature"),
    ("creature_boar", boar, "creature"),
    ("creature_boar_chain", lambda: chain(Part("Chain", (0, 0, 0), off=(0, -0.6, -0.85))), "creature"),
    ("creature_corn_husk", husk, "creature"),
    ("creature_corn_husk_heart", lambda: _head_part(husk_heart, "Heart", (0, 0, 1.2), True), "creature"),
    ("creature_smear_gaunt", _smear(gaunt), "creature"),
    ("creature_smear_scarecrow", _smear(_scarecrow_body), "creature"),
    ("creature_smear_boar", _smear(boar), "creature"),
    ("creature_smear_corn_husk", _smear(husk), "creature"),
    ("pumpkin_prize_giant", lambda: pumpkin(3.0, 2.4), "mid"),
    ("pumpkin_prize_large", lambda: pumpkin(2.0, 1.6), "mid"),
    ("pumpkin_prize_medium", lambda: pumpkin(1.2, 1.0), "mid"),
    ("pumpkin_prize_sad", lambda: pumpkin(0.7, 0.5, sad=True), "mid"),
    ("pumpkin_prize_giant_gnawed", lambda: pumpkin(3.0, 2.4, 3), "mid"),
    ("pumpkin_prize_large_gnawed", lambda: pumpkin(2.0, 1.6, 3), "mid"),
    ("pumpkin_prize_medium_gnawed", lambda: pumpkin(1.2, 1.0, 2), "mid"),
    ("pumpkin_prize_sad_gnawed", lambda: pumpkin(0.7, 0.5, 2, sad=True), "mid"),
    ("pumpkin_patch", patch, "large"),
    ("prop_cart", cart, "large"),
    ("prop_cart_lantern", lambda: lantern(), "small"),
    ("prop_cart_pumpkin_slot", lambda: slot(False), "mid"),
    ("prop_cart_pumpkin_slot_bitten", lambda: slot(True), "mid"),
    ("bldg_town_stand", town_stand, "large"),
    ("animal_chicken", chicken, "mid"),
    ("animal_pig", pig, "mid"),
    ("animal_cow", cow, "mid"),
    ("prop_shipping_crate", crate, "large"),
    ("prop_scarecrow_player", scarecrow_player, "large"),
    ("crop_plot", plot, "mid"),
    ("tool_watering_can", watering_can, "small"),
    ("tool_watering_can_quiet", lambda: watering_can(True), "small"),
    ("tool_lantern", lantern_tool, "small"),
    ("tool_lantern_bright", lambda: lantern_tool(True), "small"),
    ("tool_walkie_talkie", walkie, "small"),
    ("tool_walkie_battery", walkie_battery, "small"),
    ("tool_flare_gun", flare_gun, "small"),
    ("tool_shed_lock", shed_lock, "small"),
    ("tool_scrap", scrap, "small"),
    ("tool_seed_packet_turnip", lambda: seed_packet("#CFC3D8"), "small"),
    ("tool_seed_packet_pumpkin", lambda: seed_packet("#C8761F"), "small"),
    ("tool_seed_packet_moonflower", lambda: seed_packet("#7FE6D8"), "small"),
]


def build(name, fn, cls):
    reset()
    fn()
    bpy.context.view_layer.update()
    tris, lo, hi = 0, Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for ob in Ctx.objs:
        if ob.type != "MESH":
            continue
        ob.data.calc_loop_triangles()
        tris += len(ob.data.loop_triangles)
        for v in ob.data.vertices:
            w = ob.matrix_world @ v.co
            lo = Vector((min(lo[i], w[i]) for i in range(3)))
            hi = Vector((max(hi[i], w[i]) for i in range(3)))
    d = hi - lo
    ok = "ok" if tris <= BUDGET[cls] else "OVER BUDGET"
    print(f"BUILD {name}: {tris} tris ({cls} {BUDGET[cls]} {ok}) w{d.x:.2f} d{d.y:.2f} h{d.z:.2f} zmin{lo.z:.2f}")
    bpy.ops.object.select_all(action="DESELECT")
    for ob in Ctx.objs:
        ob.select_set(True)
    os.makedirs(OUT_GLB, exist_ok=True)
    os.makedirs(OUT_BLEND, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_GLB, name + ".glb"), export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True, export_materials="EXPORT")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_BLEND, name + ".blend"), compress=True)
    return tris


if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for nm, fn, cls in MODELS:
        if not only or nm in only:
            build(nm, fn, cls)

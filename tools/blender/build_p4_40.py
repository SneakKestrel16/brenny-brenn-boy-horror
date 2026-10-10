"""P4-40 model upgrades (D-151): Blender-built detail plus CC0 library models edited to fit doc 07.

  sh tools/blender/run.sh tools/blender/build_p4_40.py [-- name ...]

Reuses the build_phase4.py helpers (Part, materials, export) so conventions are the same: 1 unit = 1 m, model FRONT is
+Y in Blender (glTF/Godot -Z, CONTRACTS s4), origin at the base, flat colour in vertex colour layer "Col", three
materials only (doc 07 s7). File names and part/node names are the P4-16 ones, so scenes need no rewiring.
build_phase4.py skips the names in SUPERSEDED; they are built only here.

Library inputs (untrusted downloads, CC0, see doc 07 "Model sources") sit in DL_DIR, outside the repo, and are read
only through Blender's own glTF importer. Nothing inside a download is ever run.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_phase4 as B  # noqa: E402
from build_phase4 import BRASS, IRON, MAT_EMBER, MAT_FLAT, MAT_WARM, WOOD, WOOD2, Part, empty  # noqa: E402

DL_DIR = os.environ.get("FC_DL_MODELS", "C:/Users/Ockey/fc_dl/models")
SUPERSEDED = {"animal_chicken", "animal_pig", "animal_cow", "char_farmer", "prop_cart", "prop_cart_lantern",
              "tool_lantern", "tool_lantern_bright", "bldg_town_stand", "crop_plot", "pumpkin_patch",
              "pumpkin_prize_giant", "pumpkin_prize_large", "pumpkin_prize_medium", "pumpkin_prize_sad",
              "pumpkin_prize_giant_gnawed", "pumpkin_prize_large_gnawed", "pumpkin_prize_medium_gnawed",
              "pumpkin_prize_sad_gnawed"}


def lin2srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


# ---------------------------------------------------------------- CC0 library animals (edited)
def fit(bm, size):
    """Scale a bmesh per axis to size (w, l, h) metres (doc 07 s11.7), feet on z 0, centred on x/y."""
    lo = Vector((min(v.co[i] for v in bm.verts) for i in range(3)))
    hi = Vector((max(v.co[i] for v in bm.verts) for i in range(3)))
    s = [size[i] / (hi[i] - lo[i]) for i in range(3)]
    bmesh.ops.transform(bm, matrix=Matrix.Diagonal((s[0], s[1], s[2], 1)) @ Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))), verts=bm.verts)


def lib_part(name, glb, palette, size):
    """Import a library glb with Blender's importer, bake it into one flat-coloured part: armature and helper objects
    dropped, rest pose applied, turned to face +Y, scaled per axis to `size` (w, l, h), feet on z 0, centred on x/y.
    `palette` maps the library material name to our hex colour (doc 07 s2 palette)."""
    bpy.ops.import_scene.gltf(filepath=os.path.join(DL_DIR, glb))
    dg = bpy.context.evaluated_depsgraph_get()
    src = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.data.polygons and not o.name.startswith("Icosphere")]
    assert len(src) == 1, [o.name for o in src]
    ob = src[0]
    me = ob.evaluated_get(dg).to_mesh()
    mats = [s.material for s in ob.material_slots]
    cols = []
    for poly in me.polygons:
        m = mats[poly.material_index]
        if m.name in palette:
            cols.append(B.srgb(palette[m.name]))
        else:
            bc = m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value
            cols.append(tuple(lin2srgb(bc[i]) for i in range(3)) + (1.0,))
            print("  library material", m.name, "not in palette, using", cols[-1])
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.transform(ob.matrix_world)
    bmesh.ops.transform(bm, matrix=Euler((0, 0, math.pi)).to_matrix().to_4x4(), verts=bm.verts)  # library front is -Y
    fit(bm, size)
    for coll in (bm.loops.layers.color, bm.loops.layers.float_color):  # library colour layers: exporter would take them first
        for old in list(coll.values()):
            coll.remove(old)
    for dl in list(bm.verts.layers.deform.values()):  # skin weights point at bones we dropped: 7429 "invalid deform group" log lines (P5-12)
        bm.verts.layers.deform.remove(dl)
    lay = bm.loops.layers.color.new("Col")
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        f.smooth = False
        f.material_index = MAT_FLAT
        for l in f.loops:
            l[lay] = cols[f.index]
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    for coll in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials):
        for x in list(coll):
            if x.name not in ("mat_flat_lit", "mat_emissive_warm", "mat_emissive_ember"):
                coll.remove(x)
    p = Part(name)
    p.bm.free()
    p.bm, p.lay = bm, lay
    ob = p.done()
    print("  validate", name, "fixed" if ob.data.validate(verbose=True) else "clean")
    return ob


def cow():  # CC0 low-poly Holstein, edited: our palette, 0.8 x 2 x 1.5 m (doc 07 s11.7), facing -Z in Godot
    lib_part("Cow", "cow_a.glb", {"White": "#E8E4DA", "Black": "#2C2624", "Pink": "#D8A0A0"}, (0.8, 2.0, 1.5))


def pig():  # CC0 low-poly farm pig, edited: our palette, 0.6 x 1.2 x 0.8 m (doc 07 s11.7)
    lib_part("Pig", "pig_a.glb", {"Material.003": "#D9A3A0", "Material": "#C48A8A"}, (0.6, 1.2, 0.8))


# ---------------------------------------------------------------- chicken (built, real hen proportions)
def chicken():
    # a hen standing on two toed legs: tail up behind, deep breast, small head with comb and wattle
    F, F2, F3 = "#E8E0D0", "#CDBFA5", "#B8A888"
    p = Part("Chicken")
    p.ball((0.105, 0.17, 0.115), (0, -0.02, 0.23), F, rot=(-0.3, 0, 0), seg=10, rings=6)  # body, tail end raised
    p.ball((0.09, 0.1, 0.1), (0, 0.1, 0.25), F, seg=8, rings=5)  # breast
    p.between((0, 0.12, 0.28), (0, 0.17, 0.4), 0.05, 0.032, F, seg=6)  # neck
    p.ball((0.04, 0.05, 0.045), (0, 0.185, 0.43), F, seg=7, rings=5)  # head
    p.between((0, 0.215, 0.43), (0, 0.265, 0.42), 0.016, 0.003, "#E8A030", seg=4)  # beak
    for i, (z, r) in enumerate(((0.47, 0.016), (0.49, 0.02), (0.47, 0.016))):  # comb
        p.ball((0.008, 0.016, r), (0, 0.165 + 0.025 * i, z), "#C03030", seg=5, rings=4)
    p.ball((0.009, 0.01, 0.022), (0, 0.222, 0.395), "#C03030", seg=5, rings=4)  # wattle
    for sx in (-1, 1):
        p.ball((0.009, 0.008, 0.009), (sx * 0.036, 0.2, 0.44), "#1E1B1A", seg=4, rings=3)  # eye
        p.ball((0.02, 0.115, 0.075), (sx * 0.105, -0.01, 0.245), F2, rot=(-0.25, 0, sx * 0.12), seg=7, rings=4)  # wing
        p.ball((0.012, 0.05, 0.03), (sx * 0.112, -0.1, 0.22), F3, rot=(-0.25, 0, sx * 0.12), seg=5, rings=3)  # wing tip
        hip, ft = (sx * 0.04, 0.0, 0.14), (sx * 0.04, 0.02, 0.0)
        p.between(hip, ft, 0.014, 0.01, "#E8A030", seg=4)  # shank
        for k in (-1, 0, 1):  # three toes forward, one back
            p.between((ft[0], ft[1], 0.008), (ft[0] + k * 0.025, ft[1] + 0.06, 0.003), 0.007, 0.004, "#E8A030", seg=3)
        p.between((ft[0], ft[1], 0.008), (ft[0], ft[1] - 0.035, 0.004), 0.007, 0.004, "#E8A030", seg=3)
    for i in range(5):  # tail feathers in a fan
        a = (i - 2) * 0.28
        p.ball((0.012, 0.07, 0.06), (math.sin(a) * 0.05, -0.2 - 0.01 * abs(i - 2), 0.36 + 0.02 * (2 - abs(i - 2))), F2 if i % 2 else F3,
               rot=(0.2, 0, -a), seg=5, rings=3)
    fit(p.bm, (0.3, 0.4, 0.4))  # doc 07 s11.7
    p.done()


# ---------------------------------------------------------------- farmer body (char_farmer, doc 07 s11.7)
SKIN, HAIR, SHIRT, OVER, BOOT = "#C9A07A", "#5A4029", "#9A3B2B", "#3C5A7A", "#4A3322"


def farmer():
    # 1.8 m, eye 1.65, head sphere r 0.16 centred 1.62 (the hats sit at 1.74). Parts are separate objects with their
    # own pivots (Torso, Head, ArmL/R at the shoulder, LegL/R at the hip) so a rig or a glimpse can use them.
    t = Part("Torso", (0, 0, 1.0))
    t.ball((0.21, 0.12, 0.12), (0, 0, 1.02), OVER, seg=8, rings=5)  # hips
    t.box((0.4, 0.22, 0.3), (0, 0, 1.2), OVER)  # overall bib and waist
    t.box((0.42, 0.24, 0.26), (0, 0, 1.42), SHIRT)  # chest in the shirt
    t.box((0.26, 0.02, 0.26), (0, 0.115, 1.2), OVER)  # bib front
    t.box((0.1, 0.02, 0.08), (0, 0.13, 1.17), "#2F4A66")  # bib pocket
    for sx in (-1, 1):
        t.box((0.05, 0.25, 0.04), (sx * 0.11, 0.0, 1.5), OVER, rot=(0, 0, 0))  # straps over the shoulder
        t.ball((0.018, 0.012, 0.018), (sx * 0.11, 0.125, 1.36), BRASS, seg=5, rings=3)  # buttons
        t.box((0.14, 0.02, 0.1), (sx * 0.16, 0.115, 1.0), "#2F4A66")  # hip pocket
    t.box((0.4, 0.23, 0.04), (0, 0, 1.31), "#2F4A66")  # seam band
    t.cyl(0.055, 0.06, 0.09, (0, 0, 1.6), SKIN, seg=8)  # neck
    t.ball((0.2, 0.1, 0.05), (0, 0, 1.56), SHIRT, seg=7, rings=3)  # collar
    t.done()
    h = Part("Head", (0, 0, 1.55))
    h.ball((0.15, 0.16, 0.17), (0, 0, 1.62), SKIN, seg=12, rings=8)
    h.ball((0.03, 0.04, 0.035), (0, 0.155, 1.6), "#B88A66", seg=6, rings=4)  # nose
    h.ball((0.155, 0.15, 0.12), (0, -0.03, 1.67), HAIR, seg=10, rings=6)  # hair at the back and sides
    for sx in (-1, 1):
        h.ball((0.018, 0.012, 0.022), (sx * 0.06, 0.145, 1.65), "#1E1B1A", seg=5, rings=4)  # eyes
        h.box((0.05, 0.01, 0.012), (sx * 0.06, 0.15, 1.69), HAIR)  # brows
        h.ball((0.02, 0.03, 0.04), (sx * 0.15, 0.0, 1.62), "#B88A66", seg=5, rings=4)  # ears
    h.box((0.07, 0.01, 0.01), (0, 0.15, 1.54), "#8A5A3A")  # mouth
    h.done()
    for s, nm in ((-1, "ArmL"), (1, "ArmR")):
        sh, el, wr = (s * 0.23, 0.0, 1.5), (s * 0.25, 0.02, 1.22), (s * 0.25, 0.1, 0.96)
        a = Part(nm, sh)
        a.ball((0.07, 0.07, 0.07), sh, SHIRT, seg=6, rings=4)
        a.between(sh, el, 0.06, 0.052, SHIRT, seg=6).between(el, wr, 0.052, 0.045, SHIRT, seg=6)
        a.cyl(0.05, 0.05, 0.03, (wr[0], wr[1] - 0.005, wr[2] + 0.04), "#7A2E22", seg=6)  # cuff
        a.ball((0.045, 0.05, 0.055), (wr[0], wr[1] + 0.015, wr[2] - 0.05), SKIN, seg=6, rings=4)  # hand
        a.done()
    for s, nm in ((-1, "LegL"), (1, "LegR")):
        hip, kn, an = (s * 0.1, 0.0, 0.98), (s * 0.1, 0.02, 0.5), (s * 0.1, 0.0, 0.09)
        l = Part(nm, hip)
        l.between(hip, kn, 0.093, 0.075, OVER, seg=6).between(kn, an, 0.075, 0.062, OVER, seg=6)
        l.box((0.12, 0.28, 0.1), (s * 0.1, 0.06, 0.05), BOOT)  # boot
        l.box((0.13, 0.1, 0.06), (s * 0.1, 0.13, 0.03), "#2E2218")  # toe cap
        l.cyl(0.075, 0.075, 0.04, (s * 0.1, 0.0, 0.14), "#2E2218", seg=6)  # boot top
        l.done()


# ---------------------------------------------------------------- pumpkins: ribbed, dented top, curled stem
def pumpkin(d, h, bites=0, sad=False):
    p = Part("Pumpkin")
    bm = p.bm
    v = bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=1.0)["verts"]
    base = "#C8761F" if not sad else "#A8794A"
    deep = "#8E4F14" if not sad else "#7A5A38"
    for vt in v:
        th = math.atan2(vt.co.y, vt.co.x)
        k = (1 + 0.1 * math.cos(12 * th) * (1 - abs(vt.co.z) ** 2)) / 1.1  # twelve ribs, fading to the poles
        pole = abs(vt.co.z) > 0.999
        vt.co.x *= k * d / 2
        vt.co.y *= k * d / 2
        vt.co.z = (vt.co.z * 0.5 + 0.5) * h * 0.88
        if pole and vt.co.z > h * 0.5:
            vt.co.z -= h * 0.07  # the stem dimple
    cream = srgb_("#E8D3A0")
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
    deepc, basec = srgb_(deep), srgb_(base)
    for f in bm.faces:
        cen = f.calc_center_median()
        g = 0.5 + 0.5 * math.cos(12 * math.atan2(cen.y, cen.x))  # 1 on a rib crest, 0 in a groove
        col = tuple(deepc[i] + (basec[i] - deepc[i]) * (0.35 + 0.65 * g) for i in range(3)) + (1.0,)
        for l in f.loops:
            l[lay] = cream if any((l.vert.co - c).length < 0.28 * d for c in centres) else col
    # stem: a curved, ridged stalk with a curl (sad one leans)
    lean = 0.15 if sad else 0.0
    pts = [(0, 0, h * 0.84), (d * 0.01, 0, h * 0.92), (d * 0.03 + lean * d * 0.1, 0, h * 0.99), (d * 0.07 + lean * d * 0.2, 0, h * 1.0)]
    for a, b, r1, r2 in zip(pts, pts[1:], (d * 0.045, d * 0.04, d * 0.032), (d * 0.04, d * 0.032, d * 0.022)):
        p.between(a, b, r1, r2, "#4F5A2B", seg=6)
    p.done()


def srgb_(h):
    return B.srgb(h)


# ---------------------------------------------------------------- pumpkin patch
def patch():
    p = Part("Patch")
    p.cyl(2.0, 2.0, 0.08, (0, 0, 0.04), "#4A3322", seg=20)
    p.cyl(1.7, 1.1, 0.12, (0, 0, 0.14), "#5A4029", seg=16)  # raised mound
    p.cyl(1.15, 1.05, 0.03, (0, 0, 0.215), "#6B4A2F", seg=12)  # trodden top
    for i in range(14):  # edge stones, varied
        a = i * math.tau / 14 + 0.1 * (i % 3)
        s = 0.13 + 0.05 * (i % 3)
        p.ball((s, s * 0.8, 0.09), (1.92 * math.cos(a), 1.92 * math.sin(a), 0.09), "#7A756C" if i % 2 else "#8A8277", rot=(0, 0, a), seg=6, rings=4)
    for i in range(8):  # clods
        a = i * 0.9 + 0.3
        r = 0.4 + 0.1 * (i % 4)
        p.ball((0.12, 0.1, 0.06), (r * math.cos(a), r * math.sin(a), 0.22), "#4A3322", seg=5, rings=3)
    for i in range(6):  # vines, wavy, out from the middle, with leaves and a few flowers
        a = i * math.tau / 6 + 0.2
        prev = Vector((0.6 * math.cos(a), 0.6 * math.sin(a), 0.2))
        for k in range(1, 6):
            r = 0.6 + k * 0.24
            aa = a + 0.2 * math.sin(k * 1.3 + i)
            nxt = Vector((r * math.cos(aa), r * math.sin(aa), 0.16 - 0.01 * k))
            p.between(prev, nxt, 0.032, 0.026, "#3F5A2A", seg=4)
            if k % 2 == 0:
                for sgn in (-1, 1):
                    off = Vector((-math.sin(aa), math.cos(aa), 0)) * sgn * 0.22
                    p.ball((0.2, 0.17, 0.012), nxt + off + Vector((0, 0, 0.1)), "#4F7A32" if sgn > 0 else "#3F6A2A",
                           rot=(0.3 * sgn, 0, aa + 0.4 * sgn), seg=6, rings=3)
            if k == 3 and i % 2 == 0:  # yellow flower
                p.cyl(0.08, 0.02, 0.08, nxt + Vector((0, 0, 0.1)), "#E8B83A", seg=6)
            prev = nxt
    p.done()


# ---------------------------------------------------------------- crop plot
def plot():
    p = Part("Plot")
    p.box((2.94, 2.94, 0.1), (0, 0, 0.05), "#6B4A2F")
    for i in range(6):  # six tilled ridges with a groove between each
        y = -1.15 + i * 0.46
        p.between((-1.28, y, 0.1), (1.28, y, 0.1), 0.1, 0.1, "#5A3E27" if i % 2 else "#64442C", seg=6)
    for i in range(10):  # clods and pebbles
        p.ball((0.07 + 0.02 * (i % 3), 0.06, 0.04), (-1.1 + 0.25 * i, -1.2 + 0.52 * (i % 5), 0.14), "#7A756C" if i % 3 == 0 else "#4A3322", seg=5, rings=3)
    for sy in (-1, 1):  # border boards, ends overlap like a real raised bed
        p.box((3.0, 0.1, 0.15), (0, sy * 1.45, 0.075), WOOD if sy > 0 else "#6E4D33")
        p.box((0.1, 2.8, 0.15), (sy * 1.45, 0, 0.075), "#6E4D33" if sy > 0 else WOOD)
        p.box((0.12, 0.12, 0.2), (sy * 1.47, sy * 1.47, 0.1), WOOD2)  # corner posts
        p.box((0.12, 0.12, 0.2), (sy * 1.47, -sy * 1.47, 0.1), WOOD2)
    p.done()


# ---------------------------------------------------------------- cart (same layout, anchors and Empties as P4-16)
def wheel(p, cx):
    cy, cz = -0.2, 0.55
    for i in range(12):  # felloe segments with an iron tyre
        a = i * math.tau / 12
        p.box((0.1, 0.27, 0.09), (cx, cy + 0.49 * math.cos(a), cz + 0.49 * math.sin(a)), WOOD2 if i % 2 else "#6A4A32", rot=(a + math.pi / 2, 0, 0))
        p.box((0.11, 0.295, 0.02), (cx, cy + 0.535 * math.cos(a), cz + 0.535 * math.sin(a)), IRON, rot=(a + math.pi / 2, 0, 0))
    for i in range(8):  # spokes
        a = i * math.tau / 8 + 0.2
        p.between((cx, cy, cz), (cx, cy + 0.46 * math.cos(a), cz + 0.46 * math.sin(a)), 0.03, 0.022, WOOD, seg=4)
    p.cyl(0.1, 0.1, 0.18, (cx, cy, cz), IRON, rot=(0, math.pi / 2, 0), seg=8)  # hub
    p.cyl(0.05, 0.05, 0.22, (cx, cy, cz), "#2A2D2F", rot=(0, math.pi / 2, 0), seg=6)  # axle cap


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
        wheel(p, sx * 0.7)
    p.cyl(0.04, 0.04, 1.5, (0, -0.2, 0.55), IRON, rot=(0, math.pi / 2, 0), seg=5)  # axle
    for y in (-1.17, 1.17):  # end boards
        for k, z in enumerate((0.7, 0.8, 0.9)):
            p.box((1.24, 0.05, 0.095), (0, y, z), WOOD2 if k % 2 == 0 else "#6A4A32")
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
    empty("LanternSocket", (0.3, 1.1, 1.72))
    empty("PumpkinSlot", (0, 0, 0.64))


# ---------------------------------------------------------------- lanterns
def lantern(w=0.2, h=0.3):
    """Origin at the base; the cart lantern is the same model, hung from LanternSocket."""
    p = Part("Lantern")
    p.cyl(w * 0.58, w * 0.5, 0.03, (0, 0, 0.015), IRON, seg=8)
    gh = h * 0.6
    p.box((w * 0.8, w * 0.8, gh), (0, 0, 0.03 + gh / 2), "#FFB45A", mat=MAT_WARM)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((0.014, 0.014, gh + 0.012), (sx * w * 0.41, sy * w * 0.41, 0.03 + gh / 2), IRON)
    p.cyl(w * 0.62, w * 0.2, h * 0.14, (0, 0, 0.03 + gh + h * 0.07), IRON, seg=8)  # cap
    p.cyl(w * 0.2, w * 0.14, h * 0.07, (0, 0, 0.03 + gh + h * 0.17), IRON, seg=6)  # vent chimney
    arc = [(w * 0.42 * math.cos(a), 0, 0.03 + gh + h * 0.2 + w * 0.3 * math.sin(a)) for a in (math.pi, 2.4, 1.57, 0.74, 0)]
    for a, b in zip(arc, arc[1:]):
        p.between(a, b, 0.008, 0.008, IRON, seg=4)  # bail handle
    p.done()


def lantern_tool(bright=False):
    lantern(0.24 if bright else 0.2, 0.34 if bright else 0.3)


# ---------------------------------------------------------------- town stand
def town_stand():
    p = Part("Stand")
    # customer side +Y at y=0; threshold origin at front centre; body behind (Godot -Z)
    for i in range(6):  # counter front, vertical boards
        p.box((0.46, 0.05, 0.92), (-1.15 + i * 0.46, -0.22, 0.47), WOOD if i % 2 else "#6E4D33")
    p.box((2.9, 0.65, 0.05), (0, -0.55, 0.05), WOOD2)  # counter base
    p.box((0.08, 0.65, 0.9), (-1.42, -0.55, 0.47), WOOD2)  # counter ends
    p.box((0.08, 0.65, 0.9), (1.42, -0.55, 0.47), WOOD2)
    for i in range(4):  # counter top planks
        p.box((3.0, 0.22, 0.04), (0, -0.14 - i * 0.23, 0.97), "#6B4A2F" if i % 2 else "#7A5638")
    p.box((3.0, 0.05, 0.06), (0, 0.0, 0.93), WOOD2)  # nosing
    for i in range(8):  # back wall, horizontal boards
        p.box((3.0, 0.06, 0.26), (0, -1.95, 0.13 + i * 0.275), "#8A8277" if i % 2 else "#7A756C")
    for sx in (-1, 1):  # posts, front taller
        p.box((0.1, 0.1, 2.5), (sx * 1.45, -0.1, 1.25), WOOD2)
        p.box((0.1, 0.1, 2.3), (sx * 1.45, -1.9, 1.15), WOOD2)
        p.between((sx * 1.45, -0.1, 2.0), (sx * 1.45, -0.7, 2.4), 0.03, 0.03, WOOD2, seg=4)  # roof brace
    p.box((2.8, 0.06, 0.06), (0, -1.9, 1.5), WOOD2)  # shelf rail
    p.box((2.7, 0.3, 0.04), (0, -1.78, 1.5), WOOD)  # back shelf
    for i in range(5):  # jars and tins on the shelf
        p.cyl(0.07, 0.065, 0.16, (-1.0 + i * 0.5, -1.78, 1.6), ["#CFC3D8", "#7FB0A0", "#E8D3A0", "#B88A66", "#9AA7B8"][i], seg=8)
    for i in range(7):  # striped awning, front edge lower
        c = "#9A3B2B" if i % 2 == 0 else "#E8DCC0"
        x = -1.5 + 0.25 + i * (3.0 / 7) + 0.0
        p.box((3.0 / 7, 2.4, 0.04), (x, -1.0, 2.58), c, rot=(0.1, 0, 0))
        p.box((3.0 / 7, 0.04, 0.14), (x, 0.17, 2.49), c)  # valance
        p.box((0.26, 0.035, 0.26), (x, 0.17, 2.34), c, rot=(0, 0.785, 0))  # scallop
    p.box((1.6, 0.05, 0.35), (0, -0.05, 2.0), "#E8DCC0")  # hanging sign
    p.box((1.7, 0.06, 0.05), (0, -0.04, 2.2), "#6B4A2F")
    p.box((1.7, 0.06, 0.05), (0, -0.04, 1.81), "#6B4A2F")
    for sx in (-0.7, 0.7):
        p.between((sx, -0.04, 2.2), (sx, -0.04, 2.5), 0.01, 0.01, IRON, seg=4)  # chains
    p.ball((0.14, 0.03, 0.12), (-0.35, -0.01, 2.0), "#CFC3D8", seg=7, rings=4)  # turnip painted on the sign
    p.between((-0.35, -0.01, 2.08), (-0.35, -0.01, 2.17), 0.03, 0.01, "#4F7A32", seg=4)
    p.box((0.55, 0.02, 0.06), (0.35, -0.01, 2.04), "#2A2018")  # sign scrawl
    p.box((0.4, 0.02, 0.05), (0.35, -0.01, 1.94), "#2A2018")
    p.box((0.7, 0.45, 0.3), (-0.8, -0.6, 1.14), "#9A8350")  # crate on the counter
    p.box((0.74, 0.04, 0.05), (-0.8, -0.38, 1.3), WOOD2)
    for k in range(3):
        for j in range(2):
            p.ball((0.1, 0.1, 0.1), (-0.98 + k * 0.18, -0.52 - j * 0.16, 1.37), "#CFC3D8", seg=6, rings=4)  # turnips
            p.cyl(0.03, 0.01, 0.07, (-0.98 + k * 0.18, -0.52 - j * 0.16, 1.5), "#4F7A32", seg=4)  # tops
    p.ball((0.14, 0.14, 0.12), (0.0, -0.55, 1.05), "#C8761F", seg=8, rings=5)  # a pumpkin on the counter
    p.box((0.03, 0.03, 0.04), (0.0, -0.55, 1.17), "#4F5A2B")
    p.cyl(0.25, 0.22, 0.22, (0.8, -0.6, 1.08), "#8A8277", seg=10)  # coin bowl
    for k in range(4):
        p.cyl(0.03, 0.03, 0.008, (0.74 + 0.04 * k, -0.6, 1.2 + 0.006 * k), BRASS, seg=6)
    p.between((1.45, -0.1, 2.3), (1.45, 0.2, 2.3), 0.02, 0.02, IRON, seg=4)  # lamp bracket
    p.between((1.45, 0.2, 2.3), (1.45, 0.2, 2.26), 0.01, 0.01, IRON, seg=4)
    p.ball((0.07, 0.07, 0.09), (1.45, 0.2, 2.2), "#FFB45A", mat=MAT_WARM, seg=6, rings=4)
    p.done()


# ---------------------------------------------------------------- registry
MODELS = [
    ("animal_chicken", chicken, "mid"),
    ("animal_pig", pig, "mid"),
    ("animal_cow", cow, "mid"),
    ("char_farmer", farmer, "creature"),  # doc 07 s2: farmer up to 4,000 tris
    ("pumpkin_patch", patch, "large"),
    ("prop_cart", cart, "large"),
    ("prop_cart_lantern", lambda: lantern(), "small"),
    ("tool_lantern", lantern_tool, "small"),
    ("tool_lantern_bright", lambda: lantern_tool(True), "small"),
    ("bldg_town_stand", town_stand, "bldg"),
    ("crop_plot", plot, "mid"),
    ("pumpkin_prize_giant", lambda: pumpkin(3.0, 2.4), "mid"),
    ("pumpkin_prize_large", lambda: pumpkin(2.0, 1.6), "mid"),
    ("pumpkin_prize_medium", lambda: pumpkin(1.2, 1.0), "mid"),
    ("pumpkin_prize_sad", lambda: pumpkin(0.7, 0.5, sad=True), "mid"),
    ("pumpkin_prize_giant_gnawed", lambda: pumpkin(3.0, 2.4, 3), "mid"),
    ("pumpkin_prize_large_gnawed", lambda: pumpkin(2.0, 1.6, 3), "mid"),
    ("pumpkin_prize_medium_gnawed", lambda: pumpkin(1.2, 1.0, 2), "mid"),
    ("pumpkin_prize_sad_gnawed", lambda: pumpkin(0.7, 0.5, 2, sad=True), "mid"),
]

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    from build_p5_12 import SUPERSEDED_P5  # P5-12 rebuilds these in build_p5_12.py
    for nm, fn, cls in MODELS:
        if (not only and nm not in SUPERSEDED_P5) or nm in only:
            B.build(nm, fn, cls)

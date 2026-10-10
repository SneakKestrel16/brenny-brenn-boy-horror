"""P5-16 crop growth stages and corn (D-151, D-154): Blender-built, no outside source.

  sh tools/blender/run.sh tools/blender/build_p5_16.py [-- name ...]

Same conventions as build_p5_12.py (1 unit = 1 m, model front +Y in Blender = -Z in Godot, origin at the base on the plot
soil, flat colour in vertex colour layer "Col", reuses the build_phase4.py Part helper and exporter).

Crops (doc 07 s11.5): one mesh node "Crop" per file. Budget class "mid" (800), in practice 40-330 tris.
Corn (doc 07 s11.6, s10.1): one mesh node, one surface, one material (mat_corn_stalk), so each file is MultiMesh friendly.
Materials added to the three base ones: mat_moonflower (emissive #7FE6D8, doc 07 s2, s7), mat_taint_surface (oil black
#0A0710, doc 07 s7), mat_corn_stalk (vertex colour; the game swaps in the sway shader, doc 07 s10.1).
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_phase4 as B  # noqa: E402
from build_phase4 import Part  # noqa: E402

MAT_MOON, MAT_TAINT, MAT_CORN = 3, 4, 5

# ---- palette (doc 07 s2; the crop greens and bulb colours are placeholder like the rest of the palette)
LEAF, LEAF2, STEM = "#5F8A3A", "#4F7A32", "#3F5A2A"
BULB, BULB_TOP = "#D8CFE0", "#8E5FA0"
DEAD, DEAD2, ROT, ROT2 = "#A89A5A", "#8A7C46", "#4A3A2A", "#2E241A"
PUMP, PUMP_G = "#C8761F", "#8E9A3A"
MOON, MOON_BUD = "#7FE6D8", "#6FA89E"
TAINT, TAINT2 = "#0A0710", "#3A1F4A"
CORN_LO, CORN_HI, CORN_LEAF, CORN_COB, CORN_SILK = "#8E8236", "#B9A545", "#A39A3E", "#D8B84A", "#8A6A3A"


def extra_materials():
    for name, emit in (("mat_moonflower", "#7FE6D8"), ("mat_taint_surface", None), ("mat_corn_stalk", None)):
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
            bsdf.inputs["Emission Color"].default_value = B.lin(emit)
            bsdf.inputs["Emission Strength"].default_value = 1.0
        nt.links.new(bsdf.outputs["BSDF"], out_n.inputs["Surface"])
        B.Ctx.mats.append(m)


def poly(p, pts, cols, mat=0):
    """One n-gon from world-ish points; cols is one hex or a list per vertex (gradient)."""
    vs = [p.bm.verts.new(Vector(q)) for q in pts]
    f = p.bm.faces.new(vs)
    f.material_index, f.smooth = mat, False
    cols = [cols] * len(vs) if isinstance(cols, str) else cols
    for l, c in zip(f.loops, cols):
        l[p.lay] = B.srgb(c)
    return f


def leaf(p, base, yaw, L, W, pitch, col, droop=0.0, mat=0):
    """Flat diamond leaf (2 tris) from base, pointing yaw (0 = +Y), rising at pitch, tip sagging by droop."""
    d = Vector((-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
    side = Vector((math.cos(yaw), math.sin(yaw), 0)) * (W / 2)
    b = Vector(base)
    mid = b + d * (L * 0.45) + Vector((0, 0, droop * 0.25))
    tip = b + d * L + Vector((0, 0, -droop))
    poly(p, [b, mid + side, tip, mid - side], col, mat)


def leaves(p, base, n, L, W, pitch, col, droop=0.0, phase=0.0, mat=0):
    for i in range(n):
        leaf(p, (base[0], base[1], base[2]), phase + i * math.tau / n, L, W, pitch, col if isinstance(col, str) else col[i % len(col)],
             droop, mat)


def bulb(p, r, top=BULB_TOP, low=BULB, cz=None):
    cz = r * 0.6 if cz is None else cz
    p.ball((r, r, r * 0.95), (0, 0, cz), low, seg=8, rings=6)
    p.dome((r * 1.03, r * 1.03, r * 0.98), (0, 0, cz), top, seg=8, rings=6)


# ---------------------------------------------------------------- turnip (up to 0.4 high, doc 07 s11.5)
def turnip(stage):
    p = Part("Crop")
    if stage == 0:  # seedling: two cotyledons
        leaves(p, (0, 0, 0.0), 2, 0.07, 0.04, 1.0, LEAF)
        p.between((0, 0, 0), (0, 0, 0.05), 0.006, 0.004, LEAF, seg=3)
    elif stage == 1:  # four small leaves
        leaves(p, (0, 0, 0.02), 4, 0.15, 0.07, 0.9, LEAF, droop=0.02)
        p.between((0, 0, 0), (0, 0, 0.06), 0.01, 0.006, STEM, seg=4)
    elif stage == 2:  # bulb top breaking the soil
        bulb(p, 0.05)
        leaves(p, (0, 0, 0.05), 6, 0.24, 0.08, 0.95, [LEAF, LEAF2], droop=0.03)
    elif stage == 3:  # harvest: fat bulb, full rosette
        bulb(p, 0.095)
        leaves(p, (0, 0, 0.1), 7, 0.3, 0.1, 1.05, [LEAF, LEAF2], droop=0.04)
        p.between((0, 0, 0.1), (0, 0, 0.14), 0.014, 0.01, STEM, seg=4)
    elif stage == "wilted":  # bulb pale, leaves yellow and flopped
        bulb(p, 0.085, top="#9A8AA0", low="#BDB4BA")
        leaves(p, (0, 0, 0.1), 6, 0.3, 0.09, 0.2, [DEAD, DEAD2], droop=0.1)
    else:  # rotten: dark slumped bulb, brown limp leaves
        p.ball((0.1, 0.1, 0.065), (0, 0, 0.04), ROT, seg=8, rings=6)
        p.ball((0.05, 0.05, 0.03), (0.04, 0.03, 0.09), ROT2, seg=6, rings=4)
        leaves(p, (0, 0, 0.08), 5, 0.26, 0.08, 0.1, [ROT2, ROT], droop=0.1)
    p.done()


# ---------------------------------------------------------------- pumpkin (up to 0.8 high)
def pumpkin_fruit(p, r, h, col, cz=None, seg=10):
    cz = h if cz is None else cz
    p.ball((r, r, h), (0, 0, cz), col, seg=seg, rings=6)
    p.box((r * 0.18, r * 0.18, h * 0.35), (0, 0, cz + h * 0.95), STEM)


def vine(p, a, n, step, col=STEM, leafcol=LEAF2, L=0.3, drop=0.0):
    prev = Vector((0.04 * math.cos(a), 0.04 * math.sin(a), 0.05))
    for k in range(1, n + 1):
        aa = a + 0.25 * math.sin(k * 1.3 + a)
        nxt = prev + Vector((math.cos(aa), math.sin(aa), 0)) * step
        p.between(prev, nxt, 0.014, 0.012, col, seg=4)
        if k % 2 == 1:
            leaf(p, nxt + Vector((0, 0, 0.18)), aa - math.pi / 2 + 0.3, L, L * 0.9, 0.5, leafcol, droop=drop)
            p.between(nxt, nxt + Vector((0, 0, 0.18)), 0.008, 0.006, col, seg=3)
        prev = nxt


def pumpkin_crop(stage):
    p = Part("Crop")
    if stage == 0:
        leaves(p, (0, 0, 0.0), 2, 0.11, 0.07, 1.0, LEAF)
        p.between((0, 0, 0), (0, 0, 0.06), 0.008, 0.005, LEAF, seg=3)
    elif stage == 1:  # short vines, big leaves
        p.between((0, 0, 0), (0, 0, 0.1), 0.014, 0.01, STEM, seg=4)
        for a in (0.4, 2.2, 4.2):
            vine(p, a, 2, 0.14, L=0.22)
    elif stage == 2:  # green fruit, 0.35 high
        pumpkin_fruit(p, 0.14, 0.11, PUMP_G)
        for a in (0.4, 2.3, 4.2):
            vine(p, a, 2, 0.2, L=0.3)
    elif stage == 3:  # ripe orange fruit under big leaves, 0.8 high
        pumpkin_fruit(p, 0.24, 0.19, PUMP)
        for a in (0.3, 2.0, 3.6, 5.0):
            vine(p, a, 2, 0.26, L=0.38)
        p.between((0.22, 0.2, 0.0), (0.26, 0.24, 0.62), 0.016, 0.012, STEM, seg=4)  # tall petioles reach the 0.8 ceiling
        leaf(p, (0.26, 0.24, 0.62), 0.7, 0.34, 0.3, 0.45, LEAF)
        p.between((-0.2, 0.22, 0.0), (-0.25, 0.26, 0.55), 0.016, 0.012, STEM, seg=4)
        leaf(p, (-0.25, 0.26, 0.55), -0.6, 0.34, 0.3, 0.45, LEAF2)
    elif stage == "wilted":
        pumpkin_fruit(p, 0.2, 0.15, "#B88A4A")
        for a in (0.3, 2.0, 3.6, 5.0):
            vine(p, a, 2, 0.24, col="#6A5C34", leafcol=DEAD, L=0.34, drop=0.12)
    else:  # rotten: collapsed, dark
        p.ball((0.26, 0.26, 0.09), (0, 0, 0.07), ROT, seg=10, rings=4)
        p.ball((0.12, 0.1, 0.05), (0.14, 0.08, 0.16), ROT2, seg=6, rings=4)
        p.box((0.04, 0.04, 0.09), (-0.06, 0, 0.17), ROT2, rot=(0, 0.5, 0))
        for a in (0.5, 3.0, 4.6):
            vine(p, a, 2, 0.22, col=ROT2, leafcol=ROT, L=0.28, drop=0.12)
    p.done()


# ---------------------------------------------------------------- moonflower (up to 0.6 high; the only crop that glows)
def stem_curve(p, h, col=STEM, lean=0.0, n=3):
    pts = [(lean * (i / n) ** 2, 0, h * i / n) for i in range(n + 1)]
    for a, b in zip(pts, pts[1:]):
        p.between(a, b, 0.014, 0.011, col, seg=4)
    return Vector(pts[-1])


def moonflower(stage):
    p = Part("Crop")
    if stage == 0:
        leaves(p, (0, 0, 0.0), 2, 0.09, 0.05, 1.0, LEAF)
        p.between((0, 0, 0), (0, 0, 0.08), 0.007, 0.005, LEAF, seg=3)
    elif stage == 1:  # tall stem, closed bud (does not glow yet)
        top = stem_curve(p, 0.32)
        leaves(p, (0, 0, 0.08), 4, 0.16, 0.06, 0.6, LEAF)
        p.ball((0.04, 0.04, 0.07), top + Vector((0, 0, 0.05)), MOON_BUD, seg=6, rings=4)
    elif stage == 2:  # open bloom, steady glow (doc 07 s2, s7)
        top = stem_curve(p, 0.4)
        leaves(p, (0, 0, 0.08), 4, 0.2, 0.07, 0.6, LEAF)
        for i in range(6):
            leaf(p, top + Vector((0, 0, 0.01)), i * math.tau / 6, 0.16, 0.1, 0.55, MOON, mat=MAT_MOON)
        p.ball((0.035, 0.035, 0.035), top + Vector((0, 0, 0.06)), MOON, seg=6, rings=4, mat=MAT_MOON)
    elif stage == "wilted":  # grey, bowed, dark
        top = stem_curve(p, 0.36, col="#5A5A4A", lean=0.2)
        leaves(p, (0, 0, 0.08), 4, 0.18, 0.06, 0.15, "#6A6A58", droop=0.08)
        for i in range(5):
            leaf(p, top, i * math.tau / 5, 0.13, 0.08, -0.5, "#7A7A6A")
    else:  # taint: oil-black bloom with purple sheen and tendrils, nothing glows
        top = stem_curve(p, 0.42, col=TAINT, lean=0.06)
        for i in range(7):
            leaf(p, top, i * math.tau / 7, 0.2, 0.09, 0.4 + 0.25 * (i % 2), TAINT if i % 2 else TAINT2, mat=MAT_TAINT)
        p.ball((0.05, 0.05, 0.05), top + Vector((0, 0, 0.05)), TAINT2, seg=6, rings=4, mat=MAT_TAINT)
        for i in range(4):  # tendrils creeping on the soil
            a = i * math.tau / 4 + 0.4
            p.between((0, 0, 0.01), (0.22 * math.cos(a), 0.22 * math.sin(a), 0.01), 0.012, 0.004, TAINT, seg=3, mat=MAT_TAINT)
        p.between((0, 0, 0), top, 0.02, 0.012, TAINT, seg=4, mat=MAT_TAINT)
    p.done()


# ---------------------------------------------------------------- corn (doc 07 s11.6): one mesh, one surface, tiny
def tube4(p, z0, z1, r0, r1, col0, col1, mat=MAT_CORN, lean=(0, 0)):
    """4-sided open tapered tube, 8 tris, gradient colour. Returns the top ring centre."""
    def ring(z, r, dx):
        return [(dx[0] + r * math.cos(a), dx[1] + r * math.sin(a), z) for a in (math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4)]
    lo, hi = ring(z0, r0, (0, 0)), ring(z1, r1, lean)
    for i in range(4):
        j = (i + 1) % 4
        poly(p, [lo[i], lo[j], hi[j], hi[i]], [col0, col0, col1, col1], mat)
    return Vector((lean[0], lean[1], z1))


def corn_leaf(p, z, yaw, L, W, pitch, droop):
    d = Vector((-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
    side = Vector((math.cos(yaw), math.sin(yaw), 0)) * (W / 2)
    b = Vector((0, 0, z)) + d * 0.01
    tip = b + d * L + Vector((0, 0, -droop))
    poly(p, [b + side, tip, b - side], [CORN_LEAF, CORN_HI, CORN_LEAF], MAT_CORN)  # a triangle blade, 1 tri


def stalk_lod0():  # 40 tris: 3 stem segments (24), 4 leaf blades (4), cob (6), husk leaf (2), 2 tassel quads... counted in build
    p = Part("Stalk")
    tube4(p, 0.0, 0.8, 0.026, 0.02, CORN_LO, CORN_LO)
    tube4(p, 0.8, 1.6, 0.02, 0.015, CORN_LO, CORN_HI)
    top = tube4(p, 1.6, 2.2, 0.015, 0.008, CORN_HI, CORN_HI)
    for z, yaw, droop in ((0.9, 0.0, 0.18), (1.2, math.pi, 0.2), (1.55, math.pi / 2, 0.15), (1.85, -math.pi / 2, 0.12)):
        corn_leaf(p, z, yaw, 0.07, 0.035, 0.7, droop)
    # cob: 4-sided cone on the stem at 1.35 m, tilted out (tip 4 tris + 1 base quad = 6 tris), pale husk colour
    cb = Vector((0.02, 0.0, 1.3))
    tip = cb + Vector((0.05, 0.0, 0.18))
    ring = [cb + Vector((0.02 * math.cos(a), 0.02 * math.sin(a), 0)) for a in (0, math.pi / 2, math.pi, 3 * math.pi / 2)]
    for i in range(4):
        poly(p, [ring[i], ring[(i + 1) % 4], tip], [CORN_COB, CORN_COB, CORN_HI], MAT_CORN)
    poly(p, ring, CORN_LEAF, MAT_CORN)
    # tassel: one thin crossed pair of quads at the top (4 tris)
    for yaw in (0.0, math.pi / 2):
        s = Vector((math.cos(yaw), math.sin(yaw), 0)) * 0.025
        poly(p, [top - s, top + s, top + s * 0.2 + Vector((0, 0, 0.2)), top - s * 0.2 + Vector((0, 0, 0.2))], [CORN_HI, CORN_HI, CORN_COB, CORN_COB], MAT_CORN)
    # lift tassel top to the 2.4 m ceiling is the stem 2.2 + 0.2
    p.done()


def stalk_lod1():  # 12 tris: one 8-tri tube + two 2-tri leaf quads
    p = Part("Stalk")
    tube4(p, 0.0, 2.4, 0.03, 0.012, CORN_LO, CORN_HI)
    for z, yaw in ((1.2, 0.0), (1.7, math.pi)):
        d = Vector((-math.sin(yaw), math.cos(yaw), 0))
        side = Vector((math.cos(yaw), math.sin(yaw), 0)) * 0.012
        b = Vector((0, 0, z))
        poly(p, [b - side, b + side, b + d * 0.07 + Vector((0, 0, 0.5)) + side * 0.5, b + d * 0.07 + Vector((0, 0, 0.5)) - side * 0.5], [CORN_LEAF, CORN_LEAF, CORN_HI, CORN_HI], MAT_CORN)
    p.done()


def corn_card():  # 4 tris: two parallel quads 0.2 m apart, 1 m wide, 2.4 high; the far impostor of one cluster
    p = Part("Card")
    for y in (-0.1, 0.1):
        poly(p, [(-0.5, y, 0), (0.5, y, 0), (0.5, y, 2.4), (-0.5, y, 2.4)], [CORN_LO, CORN_LO, CORN_HI, CORN_HI], MAT_CORN)
    p.done()


def corn_band():  # tiles along edges: two jagged-top faces 0.5 apart, 4 m wide, 2.4 high, ends equal for seamless tiling
    p = Part("Band")
    hts = [2.3, 2.4, 2.2, 2.4, 2.3, 2.4, 2.2, 2.4, 2.3]
    for y, flip in ((-0.25, False), (0.25, True)):
        for i in range(8):
            x0, x1 = -2 + i * 0.5, -1.5 + i * 0.5
            q = [(x0, y, 0), (x1, y, 0), (x1, y, hts[i + 1]), (x0, y, hts[i])]
            poly(p, q[::-1] if flip else q, [CORN_LO, CORN_LO, CORN_HI, CORN_HI], MAT_CORN)
    p.done()


def corn_cut():  # flat trampled stalks, 1 x 1 x 0.05, doc 07 s11.6
    p = Part("Cut")
    for i, (yaw, x, y) in enumerate(((0.3, -0.1, 0.0), (1.2, 0.1, 0.1), (2.6, 0.0, -0.1), (-0.8, 0.1, 0.05), (1.9, -0.15, 0.2))):
        d = Vector((math.cos(yaw), math.sin(yaw), 0))
        side = Vector((-d.y, d.x, 0)) * 0.025
        a, b = Vector((x, y, 0.0)) - d * 0.42, Vector((x, y, 0.0)) + d * 0.42
        z = 0.012 + 0.008 * i
        poly(p, [a - side + Vector((0, 0, z)), a + side + Vector((0, 0, z)), b + side + Vector((0, 0, z + 0.02)), b - side + Vector((0, 0, z + 0.02))],
             [CORN_LO, CORN_LO, CORN_HI, CORN_HI], MAT_CORN)
    p.done()


def _wrap(fn, *a):
    def go():
        extra_materials()
        fn(*a)
    return go


MODELS = (
    [(f"crop_turnip_stage{i}", _wrap(turnip, i), "mid") for i in range(4)]
    + [("crop_turnip_wilted", _wrap(turnip, "wilted"), "mid"), ("crop_turnip_rotten", _wrap(turnip, "rotten"), "mid")]
    + [(f"crop_pumpkin_stage{i}", _wrap(pumpkin_crop, i), "mid") for i in range(4)]
    + [("crop_pumpkin_wilted", _wrap(pumpkin_crop, "wilted"), "mid"), ("crop_pumpkin_rotten", _wrap(pumpkin_crop, "rotten"), "mid")]
    + [(f"crop_moonflower_stage{i}", _wrap(moonflower, i), "mid") for i in range(3)]
    + [("crop_moonflower_wilted", _wrap(moonflower, "wilted"), "mid"), ("crop_moonflower_taint", _wrap(moonflower, "taint"), "mid")]
    + [("corn_stalk_lod0", _wrap(stalk_lod0), "mid"), ("corn_stalk_lod1", _wrap(stalk_lod1), "mid"),
       ("corn_card_lod2", _wrap(corn_card), "mid"), ("corn_wall_band", _wrap(corn_band), "mid"),
       ("corn_stalk_cut", _wrap(corn_cut), "mid")]
)

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for nm, fn, cls in MODELS:
        if not only or nm in only:
            B.build(nm, fn, cls)

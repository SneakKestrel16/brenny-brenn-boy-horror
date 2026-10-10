"""P5-06 cosmetic models (D-151): Blender-built, no outside source.

  sh tools/blender/run.sh tools/blender/build_p5_06.py [-- name ...]

One model per record in data/cosmetics.json (ids = the record ids):
  char_hat_<id>.glb       flat_cap bucket_hat tin_pot party_cone turnip_crown top_hat. One "Hat" object, origin at the
                          centre of the band's bottom edge (same rule as hat_<role_id>.glb, doc 07 s11.7), so it goes on the
                          farmer's `hat` bone (bone head z 1.74) exactly like a role hat. Crown base radius 0.14 to cover the
                          farmer hair (radii 0.158 x 0.15 at z 1.67, shifted back 0.03). Vertex colour, nothing emissive.
  char_overalls_<id>.glb  overalls_<id> for denim patched striped plaid gold. Overalls are the player tint slot (doc 07 s8,
                          data/cosmetics.json overalls_use_tint_slot), so the cosmetic is (a) a tint colour and (b) a thin
                          decoration shell (stripes, patches, plaid bands, trim) skinned to the SAME 12 bones as char_farmer.
                          The Armature root carries glTF extras `tint`: a hex colour to set on mat_farmer_overalls, or
                          "player" to keep the player colour. Decoration uses mat_flat_lit with fixed colours.
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
import build_p5_12 as P  # noqa: E402
import build_quality_sample as Q  # noqa: E402
import build_quality_sample2 as Q2  # noqa: E402
import build_quality_sample3 as Q3  # noqa: E402
import build_quality_sample4 as Q4  # noqa: E402
from build_phase4 import BRASS, Part  # noqa: E402

R = 0.185  # crown base radius: covers the farmer hair fringe corners (radius 0.176 at z 1.75 to 1.8) and the back of the hair (y -.156)
OY = 0.0


# ---------------------------------------------------------------- hats
def flat_cap():
    p = Part("Hat")
    p.dome((0.19, 0.2, 0.11), (0, OY, 0.0), "#6F6A5E", seg=10, rings=6)  # soft round crown
    p.ball((0.19, 0.19, 0.02), (0, OY, 0.0), "#5A564C", seg=10, rings=2)  # band
    p.ball((0.095, 0.075, 0.009), (0, 0.21, 0.0), "#4F4B42", rot=(-0.25, 0, 0), seg=8, rings=4)  # short peak
    p.ball((0.016, 0.016, 0.012), (0, OY + 0.01, 0.099), "#4F4B42", seg=5, rings=3)  # button
    p.done()


def bucket_hat():
    p = Part("Hat")
    p.cyl(R + 0.01, R - 0.01, 0.1, (0, OY, 0.05), "#B8A878", seg=10)  # crown
    p.cyl(R - 0.01, R - 0.02, 0.012, (0, OY, 0.105), "#C6B88A", seg=10)  # top
    p.cyl(0.29, R, 0.05, (0, OY, -0.005), "#B8A878", seg=10)  # drooping brim
    p.cyl(R + 0.012, R + 0.012, 0.03, (0, OY, 0.035), "#7A6A48", seg=10)  # band
    p.cyl(0.29, 0.285, 0.012, (0, OY, -0.03), "#9A8A5E", seg=10)  # stitched brim edge
    p.done()


def tin_pot():
    p = Part("Hat")
    p.cyl(R + 0.01, R, 0.17, (0, OY, 0.085), "#9AA0A4", seg=10)  # pot worn mouth-down
    p.cyl(R + 0.02, R + 0.02, 0.02, (0, OY, 0.01), "#7C8286", seg=10)  # rolled rim
    p.cyl(R - 0.01, R - 0.01, 0.012, (0, OY, 0.176), "#B4BABD", seg=10)  # base of the pot, now the top
    p.ball((0.02, 0.02, 0.014), (0, OY, 0.19), "#6E7478", seg=6, rings=3)  # knob
    for s in (-1, 1):  # ear handles
        p.box((0.035, 0.03, 0.07), (s * (R + 0.03), OY, 0.12), "#6E7478")
        p.box((0.03, 0.03, 0.02), (s * (R + 0.012), OY, 0.16), "#6E7478")
    p.box((0.06, 0.012, 0.05), (0.06, OY + R + 0.005, 0.1), "#7C8286", rot=(0, 0, 0.5))  # dent
    for i in range(6):  # rivets round the rim
        a = i * math.tau / 6 + 0.3
        p.ball((0.01, 0.01, 0.01), ((R + 0.014) * math.cos(a), OY + (R + 0.014) * math.sin(a), 0.01), "#B4BABD", seg=4, rings=3)
    p.done()


def party_cone():
    p = Part("Hat")
    cols = ("#C0408A", "#E8C83A", "#40B0C8", "#C0408A")
    p.cyl(R, R, 0.11, (0, OY, 0.055), cols[0], seg=10)  # straight band: radius R up to 0.11 m keeps the hair fringe covered
    h, radii = 0.07, (0.15, 0.105, 0.072, 0.04, 0.008)
    for i, c in enumerate(cols):
        p.cyl(radii[i], radii[i + 1], h, (0, OY, 0.11 + h * (i + 0.5)), c, seg=8)
    p.ball((0.04, 0.04, 0.04), (0, OY, 0.40), "#F2E8D0", seg=6, rings=4)  # pompom
    for i, c in enumerate(("#40B0C8", "#E8C83A", "#C0408A")):  # streamers
        a = i * math.tau / 3 + 0.5
        p.between((0, OY, 0.38), (0.06 * math.cos(a), OY + 0.06 * math.sin(a), 0.33), 0.008, 0.004, c, seg=3)
    p.done()


def turnip_crown():
    p = Part("Hat")
    p.cyl(R, R, 0.04, (0, OY, 0.02), "#CFC3D8", seg=10)  # band
    p.cyl(R + 0.005, R + 0.005, 0.012, (0, OY, 0.044), "#8A5AA0", seg=10)  # purple turnip-shoulder trim
    for i in range(7):  # leaf spikes
        a = i * math.tau / 7 + 0.2
        top = 0.2 if i % 2 == 0 else 0.15
        p.between(((R - 0.01) * math.cos(a), OY + (R - 0.01) * math.sin(a), 0.03), ((R + 0.035) * math.cos(a), OY + (R + 0.035) * math.sin(a), top),
                  0.03, 0.004, "#4F7A32" if i % 2 == 0 else "#6A9A3F", seg=4)
    p.ball((0.045, 0.045, 0.05), (0, OY + R + 0.02, 0.035), "#E3D5E8", seg=8, rings=5)  # turnip on the front
    p.ball((0.046, 0.046, 0.022), (0, OY + R + 0.02, 0.058), "#8A5AA0", seg=8, rings=3)  # purple top
    p.between((0, OY + R + 0.02, 0.07), (0, OY + R + 0.02, 0.12), 0.012, 0.004, "#4F7A32", seg=4)  # stalk
    p.done()


def top_hat():
    p = Part("Hat")
    p.cyl(R - 0.005, R - 0.02, 0.27, (0, OY, 0.145), "#26211F", seg=10)  # tall crown
    p.cyl(R - 0.02, R - 0.02, 0.012, (0, OY, 0.282), "#322C2A", seg=10)  # top disc
    p.cyl(0.26, 0.26, 0.014, (0, OY, 0.005), "#26211F", seg=10)  # brim
    for s in (-1, 1):  # brim sides curl up
        p.box((0.06, 0.28, 0.014), (s * 0.26, OY, 0.02), "#1E1A18", rot=(0, -s * 0.4, 0))
    p.cyl(R, R, 0.05, (0, OY, 0.045), "#7A2E3A", seg=10)  # ribbon
    p.box((0.045, 0.012, 0.04), (0, OY + R, 0.045), BRASS)  # buckle
    p.box((0.024, 0.014, 0.02), (0, OY + R + 0.002, 0.045), "#26211F")
    p.done()


HATS = {"flat_cap": flat_cap, "bucket_hat": bucket_hat, "tin_pot": tin_pot, "party_cone": party_cone,
        "turnip_crown": turnip_crown, "top_hat": top_hat}


# ---------------------------------------------------------------- overalls decoration (skinned shells)
# Geometry of the farmer parts in build_p5_12.farmer_parts: legs are 8-sided tapers hip (z .98, y 0, r .095) to knee
# (z .5, y .02, r .078) to ankle (z .09, y 0, r .064); bib front face y .125 (z 1.08 to 1.36, x +-.13); straps x +-.11.
CREAM, INK, THREAD = "#E8DCC0", "#2A2D2F", "#D9A35A"
GOLD, GOLD2 = "#E8C040", "#B8902A"
BIB_Y = 0.129  # decoration sits 4 mm proud of the bib


def leg_axis(z):
    """(y of the axis, radius) of the leg at height z."""
    if z >= 0.5:
        t = (0.98 - z) / 0.48
        return 0.02 * t, 0.095 - 0.017 * t
    t = (0.5 - z) / 0.41
    return 0.02 * (1 - t), 0.078 - 0.014 * t


def leg_pt(s, z, deg, lift=0.004):
    """Point on the leg surface at height z, angle deg round the axis (0 front, +90 outward), `lift` metres off it."""
    y, r = leg_axis(z)
    a = math.radians(deg)
    return (s * 0.1 + s * (r + lift) * math.sin(a), y + (r + lift) * math.cos(a), z)


def leg_line(p, s, deg, z0, z1, col, rad=0.007):
    zs = (z0, (z0 + z1) / 2 if abs(z0 - z1) > 0.5 else None, z1)
    zs = [z for z in zs if z is not None]
    for a, b in zip(zs, zs[1:]):
        p.between(leg_pt(s, a, deg), leg_pt(s, b, deg), rad, rad, col, seg=4)


def leg_ring(p, s, z, col, depth=0.02):
    y, r = leg_axis(z)
    p.cyl(r + 0.006, r + 0.006, depth, (s * 0.1, y, z), col, seg=8)


def patch(p, centre, size, col, rot=(0, 0, 0), thread="#2A2018"):
    p.box((size[0] + 0.014, size[1] - 0.002, size[2] + 0.014), centre, thread, rot=rot)  # stitched border
    p.box(size, (centre[0], centre[1] + 0.003 * (1 if centre[1] > 0 else -1), centre[2]), col, rot=rot)


def deco_denim(torso, legs):
    t = torso
    for x in (-1, 1):  # bib edge stitching
        t.box((0.005, 0.006, 0.27), (x * 0.126, BIB_Y, 1.22), THREAD)
    t.box((0.25, 0.006, 0.005), (0, BIB_Y, 1.355), THREAD)
    t.box((0.1, 0.006, 0.005), (0, BIB_Y + 0.008, 1.157), THREAD)  # pocket stitch (pocket sits proud 0.008)
    for x in (-1, 1):
        t.ball((0.011, 0.007, 0.011), (x * 0.05, BIB_Y + 0.008, 1.19), "#B8683A", seg=5, rings=3)  # pocket rivets
        t.ball((0.012, 0.008, 0.012), (x * 0.11, BIB_Y + 0.0, 1.34), "#B8683A", seg=5, rings=3)  # strap rivets
        t.ball((0.01, 0.007, 0.01), (x * 0.205, 0.108, 1.0), "#B8683A", seg=5, rings=3)
    for s, l in zip((-1, 1), legs):
        leg_line(l, s, 90, 0.95, 0.2, THREAD, 0.005)  # outer seam
        leg_line(l, s, -90, 0.95, 0.2, THREAD, 0.005)  # inner seam
        for z in (0.185, 0.135):  # turn-up stitching
            leg_ring(l, s, z, THREAD, 0.006)


def deco_patched(torso, legs):
    t = torso
    patch(t, (0.05, BIB_Y, 1.22), (0.09, 0.008, 0.09), "#7A5A3A", rot=(0, 0.1, 0.15))
    patch(t, (0.1, -0.133, 1.0), (0.1, 0.008, 0.09), "#C9B890", rot=(0, 0.05, -0.1))  # seat
    patch(t, (-0.12, -0.133, 1.04), (0.07, 0.008, 0.06), "#5B7A8A", rot=(0, 0, 0.2))
    t.box((0.2, 0.006, 0.016), (-0.095, BIB_Y + 0.012, 1.31), "#2A2018", rot=(0, 0, -0.2))  # darned tear
    for s, l in zip((-1, 1), legs):
        for z, col, w in ((0.55, "#C9B890" if s < 0 else "#7A5A3A", 0.085), (0.32, "#5B7A8A" if s < 0 else "#C9B890", 0.07)):
            y, r = leg_axis(z)
            patch(l, (s * 0.1, y + r + 0.005, z), (w, 0.008, w - 0.01), col, rot=(0, 0, 0.12 * s))


def deco_striped(torso, legs):
    t = torso
    for i in range(6):  # bib pinstripes
        t.box((0.012, 0.006, 0.27), (-0.1 + i * 0.04, BIB_Y, 1.22), INK)
    for x in (-1, 1):  # strap stripes
        t.box((0.012, 0.006, 0.2), (x * 0.11, BIB_Y, 1.43), INK)
        t.box((0.012, 0.25, 0.006), (x * 0.11, 0.0, 1.523), INK)
    for x in (-0.19, -0.16, 0.16, 0.19):  # waist stripes beside the bib
        t.box((0.012, 0.006, 0.28), (x, 0.114, 1.2), INK)
    for s, l in zip((-1, 1), legs):
        for deg in (-60, -30, 0, 30, 60):
            leg_line(l, s, deg, 0.96, 0.2, INK, 0.0065)


def deco_plaid(torso, legs):
    t = torso
    for x in (-0.09, -0.03, 0.03, 0.09):  # bib: dark verticals, pale horizontals
        t.box((0.016, 0.006, 0.27), (x, BIB_Y, 1.22), INK)
    for z in (1.12, 1.2, 1.28):
        t.box((0.25, 0.007, 0.014), (0, BIB_Y + 0.001, z), INK)
    for x in (-0.06, 0.0, 0.06):
        t.box((0.005, 0.008, 0.27), (x, BIB_Y + 0.001, 1.22), CREAM)
    for z in (1.16, 1.24, 1.32):
        t.box((0.25, 0.008, 0.005), (0, BIB_Y + 0.002, z), CREAM)
    for x in (-1, 1):
        t.box((0.016, 0.006, 0.2), (x * 0.11, BIB_Y, 1.43), INK)
    for s, l in zip((-1, 1), legs):
        for deg in (-45, 0, 45):
            leg_line(l, s, deg, 0.96, 0.2, INK, 0.0085)
        for z in (0.85, 0.7, 0.4, 0.28):
            leg_ring(l, s, z, INK, 0.022)
        for z in (0.775, 0.34):
            leg_ring(l, s, z, CREAM, 0.007)


def deco_gold(torso, legs):
    t = torso
    t.box((0.27, 0.008, 0.014), (0, BIB_Y, 1.358), GOLD)  # bib frame
    for x in (-1, 1):
        t.box((0.014, 0.008, 0.29), (x * 0.133, BIB_Y, 1.22), GOLD)
        t.ball((0.027, 0.012, 0.027), (x * 0.11, BIB_Y + 0.004, 1.335), GOLD, seg=6, rings=4)  # big buttons
        t.box((0.058, 0.01, 0.05), (x * 0.11, BIB_Y + 0.002, 1.47), GOLD)  # strap buckles
        t.box((0.034, 0.012, 0.028), (x * 0.11, BIB_Y + 0.003, 1.47), "#6A5420")
        t.box((0.01, 0.014, 0.05), (x * 0.11, BIB_Y + 0.003, 1.47), GOLD2)
    t.box((0.1, 0.01, 0.09), (0, BIB_Y + 0.004, 1.19), GOLD2)  # pocket plate
    t.box((0.09, 0.012, 0.012), (0, BIB_Y + 0.008, 1.225), GOLD)
    t.box((0.06, 0.012, 0.045), (0, 0.128, 1.12), GOLD)  # belt plate
    for s, l in zip((-1, 1), legs):
        leg_line(l, s, 90, 0.95, 0.2, GOLD, 0.008)  # side stripe
        for z, w in ((0.19, 0.03), (0.12, 0.02)):
            leg_ring(l, s, z, GOLD, w)
        y, r = leg_axis(0.55)
        l.ball((0.026, 0.012, 0.026), (s * 0.1, y + r + 0.006, 0.55), GOLD, seg=6, rings=4)  # knee stud


OVERALLS = {  # id: (tint, builder). tint = hex for mat_farmer_overalls.albedo_color, or "player" to keep the player colour
    "overalls_denim": ("#3F5F8F", deco_denim),
    "overalls_patched": ("player", deco_patched),
    "overalls_striped": ("player", deco_striped),
    "overalls_plaid": ("player", deco_plaid),
    "overalls_gold": ("#D9AE2C", deco_gold),
}


# ---------------------------------------------------------------- refit to the B body (CEO 2026-10-10, P5-40)
# The decoration above is authored on the OLD P5-12 body. build_overalls builds that body for reference, then the new body
# (via build_quality_sample3.make), subdivides each decoration and moves every vertex from the old surface to the same offset above
# the new one: a ray from an axis point through the vertex hits the old and the new mesh; new = new hit + (vertex distance - old hit).
SUB = 0.14# edges longer than this are halved until none is, so a flat stripe can follow the curved chest
SHOULDER_Z = 1.47  # above this the decoration lies on the shoulder, so its ray goes up


def _tree(ob):
    me = ob.data
    me.calc_loop_triangles()
    vs = [ob.location + v.co for v in me.vertices]  # no rotation or parent on the body parts
    return BVHTree.FromPolygons(vs, [tuple(t.vertices) for t in me.loop_triangles])


def _far(tree, o, d, reach=0.6):
    """Distance along d from o (inside the body) to the farthest surface crossing, or None."""
    best, p = None, o.copy()
    for _ in range(8):
        h = tree.ray_cast(p, d, reach)
        if h[0] is None:
            break
        best = (h[0] - o).dot(d)
        p = h[0] + d * 1e-4
    return best


def _squeeze(z):  # build_quality_sample3.reshape_body leg narrowing
    return 1 - 0.09 * min(1.0, max(0.0, (0.72 - z) / 0.2)) * min(1.0, max(0.0, (z - 0.24) / 0.08))


def refit(part, old, new, torso):
    """Move the Part's vertices (world coords) from the old body mesh (BVH `old`) onto the new one (`new`). Returns the miss count."""
    bm = part.bm
    for _ in range(4):
        long = [e for e in bm.edges if e.calc_length() > (SUB if torso else 3 * SUB)]  # legs are near-straight, the squeeze is gentle
        if not long:
            break
        bmesh.ops.subdivide_edges(bm, edges=long, cuts=1, use_grid_fill=True)
    miss = 0
    for v in bm.verts:
        p = v.co.copy()
        if torso:
            # try a ray out from the torso axis first; where either body has no surface there (the shoulder top), a ray up
            for c_old, d in ((Vector((p.x * 0.5, 0.0, p.z)), None), (Vector((p.x, max(-0.09, min(0.09, p.y)), p.z - 0.12)), Vector((0, 0, 1)))):
                if d is None:
                    d = (p - c_old).normalized()
                c_new = Vector((c_old.x, c_old.y, Q3.fz(c_old.z)))
                dist = (p - c_old).dot(d)
                d_old, d_new = _far(old, c_old, d), _far(new, c_new, d)
                if d_old is not None and d_new is not None:
                    break
            if d_old is None or d_new is None:
                miss += 1
                v.co = c_new + d * dist
            else:
                v.co = c_new + d * (d_new + (dist - d_old))
            continue
        else:
            X = -0.1 if p.x < 0 else 0.1
            y_ax = leg_axis(p.z)[0]
            c_old = Vector((X, y_ax, p.z))
            d = Vector((p.x - X, p.y - y_ax, 0))
            d = d.normalized() if d.length > 1e-6 else Vector((0, 1, 0))
            c_new = Vector((X, 0.01 + (y_ax - 0.01) * _squeeze(p.z), p.z))
        dist = (p - c_old).dot(d)
        d_old, d_new = _far(old, c_old, d), _far(new, c_new, d)
        for k in range(1, 6):  # a leg now starts lower than before: probe the surface a little lower, keep the height
            if d_new is not None or torso:
                break
            d_new = _far(new, c_new - Vector((0, 0, 0.02 * k)), d)
        if d_old is None or d_new is None:
            miss += 1
            v.co = c_new + d * dist
            continue
        v.co = c_new + d * (d_new + (dist - d_old))
    return miss


def build_overalls(oid, tint, fn):
    name = "char_overalls_" + oid.removeprefix("overalls_")
    B.reset()
    B.Ctx.jitter = 0.0
    P.extra_materials()
    P.farmer_parts()  # the old body, only as the reference surface
    olds = {ob.name: _tree(ob) for ob in B.Ctx.objs if ob.type == "MESH"}

    def post():
        news = {ob.name: _tree(ob) for ob in B.Ctx.objs if ob.type == "MESH"}
        for ob in list(B.Ctx.objs):
            bpy.data.objects.remove(ob)
        B.Ctx.objs = []
        torso = Part("Torso", (0, 0, 1.0))
        legs = [Part("LegL", (-0.1, 0, 0.98)), Part("LegR", (0.1, 0, 0.98))]
        fn(torso, legs)
        miss = refit(torso, olds["Torso"], news["Torso"], True)
        for part, nm in zip(legs, ("LegL", "LegR")):
            miss += refit(part, olds[nm], news[nm], False)
        print(f"  refit {name}: {miss} vertices without a ray hit")
        for part in (torso, *legs):
            part.done()

    Q.HAND["shipped"] = True
    Q2.BIB_DROP = 0.122
    Q3.make(name, Q4, body=True, post=post, anims={}, rig_props={"tint": tint, "cosmetic_id": oid})


if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for hid, fn in HATS.items():
        if not only or "char_hat_" + hid in only:
            B.build("char_hat_" + hid, fn, "small")
    for oid, (tint, fn) in OVERALLS.items():
        if not only or "char_overalls_" + oid.removeprefix("overalls_") in only:
            build_overalls(oid, tint, fn)

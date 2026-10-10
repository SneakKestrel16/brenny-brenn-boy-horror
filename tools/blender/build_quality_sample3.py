"""QUALITY SAMPLE 3: the SHIPPED farmer head, face, hair and hands wearing the new clothes.

  sh tools/blender/run.sh tools/blender/build_quality_sample3.py

Writes assets/models/farmer_orig_hqclothes_sample.glb   (A: shipped head/hands + farmer_hq_sample clothes)
       assets/models/farmer_orig_hq2clothes_sample.glb  (B: shipped head/hands + farmer_hq2_sample clothes)
and the matching .blend files. Same rig, weights, animations and material slots as char_farmer.
The head is the shipped build_p5_12.farmer_parts head verbatim (plain Part, no painted finish).
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
import build_quality_sample2 as Q2  # noqa: E402
from build_phase4 import Part  # noqa: E402


def detailed_hair(h, HAIR, lite=True):  # lite=False is the first (972 tri) version, kept for the before/after render
    """hq2-style hair refitted to the shipped head (ball r .15/.16/.17 at z 1.62): shell, tufts, side part, layered fringe, sideburns.
    Same Part as the head, so it moves rigidly with the Head bone (no clipping in idle or walk). Shipped colour, small shade steps."""
    def shade(k):
        c = HAIR.lstrip("#")
        v = [int(c[i:i + 2], 16) for i in (0, 2, 4)]
        return "#%02X%02X%02X" % tuple(max(0, min(230, int(x * k))) for x in v)
    D, M, L = shade(0.85), HAIR, shade(1.12)
    h.ball((0.158, 0.15, 0.14), (0, -0.015, 1.665), M, seg=12 if lite else 14, rings=6 if lite else 7)  # shell: back and sides
    rng = random.Random(11)
    placed = 0
    for i in range(80):  # 14 tufts: 4-sided pointed strands lying on the shell
        if placed >= (14 if lite else 30):
            break
        a = -rng.uniform(-0.2, math.pi + 0.2)
        el = rng.uniform(0.0, 0.7)
        x = 0.158 * math.cos(el) * math.cos(a)
        y = -0.015 + 0.15 * math.cos(el) * math.sin(a)
        z = 1.665 + 0.14 * math.sin(el)
        if y > 0.005 and z < 1.77:
            continue
        if abs(x) > 0.1 and 1.57 < z < 1.69:
            continue  # keep clear of the ears
        k = 1.0 if (abs(x) > 0.1 and z < 1.735) else 1.04  # QA 6: side tufts above the ears sink into the shell instead of jutting out
        h.ball((0.026, 0.02, 0.04), (x * k, y * k - 0.002, z), (D, M, L)[i % 3], rot=(el * 0.6, 0, a + math.pi / 2), seg=4 if lite else 5, rings=3)
        placed += 1
    # side part at x +0.05, layered fringe swept away from it
    h.box((0.01, 0.12, 0.012), (0.05, 0.075, 1.775), D, rot=(0.2, 0, 0))
    for layer, (z, y, ln, n, tilt) in enumerate([(1.768, 0.095, 0.05, 4 if lite else 5, 0.5), (1.752, 0.122, 0.045, 4 if lite else 5, 0.5),
                                                 (1.734, 0.135, 0.04, 3 if lite else 4, 0.3)]):  # QA 2: lowest layer lies on the forehead
        for k in range(n):
            x = -0.09 + k * 0.17 / (n - 1)
            if lite and layer == 0 and k == 2:
                continue  # QA 5: leave a gap in the top layer so the side part shows
            sweep = 0.5 if x < 0.05 else -0.45
            h.box((0.05, 0.026, ln), (x, y, z), (L, M, D)[layer], rot=(tilt, 0, sweep))  # QA 7: one shade per layer
    for sx in (-1, 1):  # sideburns, in front of the ear; QA 3: taller, tucked under the shell and fringe, same shade as the hair
        h.box((0.022, 0.035, 0.115), (sx * 0.131, 0.065, 1.67), M, rot=(0, 0, sx * -0.12))
    if not lite:
        h.box((0.018, 0.03, 0.03), (-0.128, 0.075, 1.6), M)
        h.box((0.018, 0.03, 0.03), (0.128, 0.075, 1.6), M)
        h.ball((0.045, 0.04, 0.03), (0.06, -0.07, 1.762), L, seg=6, rings=4)
    for k in range(3 if lite else 5):  # nape fringe; QA 4: wider so neighbours overlap, hugging the skull, tops under the shell rim
        h.box((0.065, 0.03, 0.04), (-0.06 + k * 0.06, -0.158, 1.615), (D, M, L)[k % 3], rot=(-0.3, 0, 0.1 * (k - 1)))


def shipped_head(detail=False, lite=True):
    SKIN, HAIR = P.SKIN, P.HAIR
    h = Part("Head", (0, 0, 1.55))
    h.ball((0.15, 0.16, 0.17), (0, 0, 1.62), SKIN, seg=12, rings=8)
    h.ball((0.1, 0.1, 0.07), (0, 0.045, 1.55), SKIN, seg=8, rings=4)  # jaw and chin
    h.ball((0.03, 0.04, 0.035), (0, 0.155, 1.6), "#B88A66", seg=6, rings=4)  # nose
    if detail:
        n0 = sum(len(f.verts) - 2 for f in h.bm.faces)
        detailed_hair(h, HAIR, lite)
        print("HAIR tris:", sum(len(f.verts) - 2 for f in h.bm.faces) - n0)
    else:
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


ZMAP = [(0.0, 0.0), (1.0, 1.0), (1.28, 1.235), (1.58, 1.425), (3.0, 2.845)]  # body warp: pre z -> post z (the head stays put, the torso is shorter)


def fz(z):
    for (a, b), (c, d) in zip(ZMAP, ZMAP[1:]):
        if a <= z <= c:
            return b + (d - b) * (z - a) / (c - a)
    return z


def az(z):
    """Arm warp: hands stay put, the shoulder follows the lowered torso, the span between compresses."""
    return z - (1.5 - fz(1.5)) * P.sstep((z - 0.9) / 0.5)


def reshape_body():
    """Variant B: shorten the torso so a neck shows under the shipped head (head and height unchanged), slope the shoulder caps
    into the arms, and narrow the legs a little at knee and shin."""
    for ob in B.Ctx.objs:
        if ob.type != "MESH" or ob.name not in ("Torso", "ArmL", "ArmR", "LegL", "LegR"):
            continue
        loc = ob.location.copy()
        for v in ob.data.vertices:
            w = v.co + loc
            if ob.name == "Torso":
                w.z = fz(w.z)
            elif ob.name.startswith("Arm"):
                w.z = az(w.z - 0.4 * max(0.0, w.z - 1.45))
            else:
                X = 0.1 if ob.name == "LegR" else -0.1
                s = 1 - 0.09 * min(1.0, max(0.0, (0.72 - w.z) / 0.2)) * min(1.0, max(0.0, (w.z - 0.24) / 0.08))
                w.x = X + (w.x - X) * s
                w.y = 0.01 + (w.y - 0.01) * s
            v.co = w - loc


def neck_part():
    """Skin neck (shipped skin colour) and a shirt collar ring around its base, built after the warp."""
    n = Q2.HQ2("Neck", (0, 0, 1.4))
    n.loft([(0, 0, 1.38, 0.066, 0.07), (0, 0, 1.44, 0.062, 0.066), (0, 0, 1.50, 0.06, 0.064), (0, 0.004, 1.54, 0.058, 0.06)],
           [Q2.SKIN_D, P.SKIN, P.SKIN, P.SKIN], seg=14)
    n.loft([(0, 0, 1.405, 0.098, 0.092), (0, 0, 1.425, 0.09, 0.084), (0, 0, 1.444, 0.083, 0.077)], [Q2.SHIRT, Q2.SHIRT, Q2.SHIRT_D],
           seg=18, caps=(False, False))
    n.done()


def body_bones(rig):
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig.data.edit_bones
    for s, sfx in ((-1, "l"), (1, "r")):
        eb["arm_" + sfx].head = (s * 0.23, 0, az(1.5))
        eb["arm_" + sfx].tail = (s * 0.25, 0.02, az(1.22))
        eb["forearm_" + sfx].head = (s * 0.25, 0.02, az(1.22))
    eb["head"].head = (0, 0, 1.44)
    bpy.ops.object.mode_set(mode="OBJECT")


def body_weights(ob):
    """Neck blends spine to head; arms keep the elbow blend centred on the lowered elbow."""
    ob.vertex_groups.clear()
    elbow = az(1.22)
    for v in ob.data.vertices:
        z = v.co.z + ob.location.z
        if ob.name == "Neck":
            t = P.sstep((z - 1.46) / 0.05)
            w = {"head": t, "spine": 1 - t}
        else:
            side = "l" if ob.name.endswith("L") else "r"
            t = P.sstep((elbow + 0.06 - z) / 0.12)
            w = {"arm_" + side: 1 - t, "forearm_" + side: t}
        for bone, wt in w.items():
            if wt > 1e-4:
                g = ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
                g.add([v.index], wt, "REPLACE")


def tri_report(name):
    """Tris per object and per category. Inference (nothing in the files tags them): details = small separate pieces (mesh island extent
    < 0.06 m: brass, rivets, buckles, stitch dashes, eyelets, laces); Head = hair (dark brown, above the brow or at the nape) or face;
    skin-coloured faces on arms and neck = body; everything else = clothes."""
    cats = {"body": 0, "face": 0, "clothes": 0, "hair": 0, "details": 0}
    per = {}
    for ob in B.Ctx.objs:
        if ob.type != "MESH":
            continue
        me = ob.data
        me.calc_loop_triangles()
        per[ob.name] = len(me.loop_triangles)
        bm = bmesh.new()
        bm.from_mesh(me)
        lay = bm.loops.layers.color.get("Col")
        seen = set()
        for f in bm.faces:
            if f.index in seen:
                continue
            isl, stack = [], [f]
            seen.add(f.index)
            while stack:
                g = stack.pop()
                isl.append(g)
                for e in g.edges:
                    for h in e.link_faces:
                        if h.index not in seen:
                            seen.add(h.index)
                            stack.append(h)
            vs = [v.co for g in isl for v in g.verts]
            ext = max(max(c[i] for c in vs) - min(c[i] for c in vs) for i in range(3))
            for g in isl:
                n = len(g.verts) - 2
                c = Vector(g.loops[0][lay][:3])
                cen = g.calc_center_median() + ob.location
                if ob.name == "Head":
                    cats["hair" if (c.x < 0.5 and (cen.z > 1.70 or cen.y < -0.05)) else "face"] += n
                elif ext < 0.06:
                    cats["details"] += n
                elif ob.name in ("Neck", "ArmL", "ArmR") and c.x > 0.5 and c.y / max(c.x, 1e-6) > 0.65:
                    cats["body"] += n
                else:
                    cats["clothes"] += n
        bm.free()
    print("TRIS", name, per, cats)


def make(name, mod, body=False, lite=True, post=None, anims=None, rig_props=None):
    B.reset()
    B.Ctx.jitter = 0.0
    P.extra_materials()
    Q2.BODY = body
    mod.torso()
    shipped_head(detail=getattr(mod, "HAIR_DETAIL", mod is Q2), lite=lite)
    mod.arm(-1, "ArmL")
    mod.arm(1, "ArmR")
    mod.leg(-1, "LegL")
    mod.leg(1, "LegR")
    if body:
        reshape_body()
        getattr(mod, "neck_part", neck_part)()
    post = post or getattr(mod, "post", None)
    if post:
        post()
    rig = P.make_armature()
    for k, v in (rig_props or {}).items():
        rig[k] = v
    if body:
        body_bones(rig)
    for ob in list(B.Ctx.objs):
        if ob.type == "MESH":
            P.weights(ob, rig)
            if body and (ob.name == "Neck" or ob.name.startswith("Arm")):
                body_weights(ob)
    Q2.BODY = False
    bpy.context.view_layer.objects.active = rig
    old_anims = P.ANIMS
    P.ANIMS = anims if anims is not None else old_anims
    P.make_actions(rig)
    P.ANIMS = old_anims
    for pb in rig.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    tris, hi_z = 0, -1e9
    for ob in B.Ctx.objs:
        if ob.type != "MESH":
            continue
        ob.data.calc_loop_triangles()
        tris += len(ob.data.loop_triangles)
        hi_z = max(hi_z, max((ob.matrix_world @ v.co).z for v in ob.data.vertices))
    print(f"BUILD {name}: {tris} tris, height {hi_z:.2f}")
    tri_report(name)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in B.Ctx.objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(B.OUT_GLB, name + ".glb"), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=False, export_materials="EXPORT", export_animations=bool(P.ANIMS if anims is None else anims), export_animation_mode="NLA_TRACKS",
                              export_skins=True, export_def_bones=False, export_optimize_animation_size=False, export_extras=bool(rig_props),
                              export_force_sampling=True, export_frame_range=False)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(B.OUT_BLEND, name + ".blend"), compress=True)


if __name__ == "__main__":
    Q.HAND["shipped"] = True
    make("farmer_orig_hqclothes_sample", Q)
    Q2.BIB_DROP = 0.122  # B only: bib top at the shipped farmer height (z 1.36)
    make("farmer_orig_hq2clothes_sample", Q2, body=True)
    make("farmer_B_hair_v1_sample", Q2, body=True, lite=False)  # heavier first hair, only for the before/after render

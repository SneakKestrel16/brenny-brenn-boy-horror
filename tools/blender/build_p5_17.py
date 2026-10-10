"""P5-17 missing models (D-151, D-159): crow, dead crow, first-person hands, road sign and lamp, farmer ragdoll, ghost shell.

  sh tools/blender/run.sh tools/blender/build_p5_17.py [-- name ...]

Same conventions as build_p5_12.py (1 unit = 1 m, model FRONT is +Y in Blender = glTF/Godot -Z, origin at the base, flat colour in
vertex colour layer "Col", Part helpers and the farmer rig reused). Rigs: bone axes follow the farmer's (bones are vertical, so
Euler X pitches about world X, Y twists about the vertical, Z rolls about the forward axis, inverted).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_p5_12 as F  # noqa: E402
import build_phase4 as B  # noqa: E402
from build_phase4 import IRON, MAT_FLAT, MAT_WARM, WOOD, WOOD2, Part, empty  # noqa: E402

MAT_SLEEVE = F.MAT_SLEEVE  # 4: mat_farmer_sleeves (hands and sleeves; the Taint slot)
MAT_GHOST = 3  # mat_ghost_shell, only in char_ghost
D = math.radians
BUDGET = {"small": 300, "mid": 800, "farmer": 4000}
FEATHER, FEATHER2, BEAK, LEG = "#1E1B24", "#2C2A36", "#3A3630", "#4A4440"


# ---------------------------------------------------------------- rigged-model helper
def build_rigged(name, parts_fn, bones, weight_fn, anims, budget, materials_fn=None):
    B.reset()
    B.Ctx.jitter = 0.0
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    for a in list(bpy.data.armatures):
        bpy.data.armatures.remove(a)
    if materials_fn:
        materials_fn()
    parts_fn()
    old_bones, old_anims = F.BONES, F.ANIMS
    F.BONES, F.ANIMS = bones, anims
    try:
        arm = F.make_armature()
        for ob in list(B.Ctx.objs):
            if ob.type == "MESH":
                weight_fn(ob, arm)
        bpy.context.view_layer.objects.active = arm
        F.make_actions(arm)
    finally:
        F.BONES, F.ANIMS = old_bones, old_anims
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    tris, lo, hi = 0, Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for ob in B.Ctx.objs:
        if ob.type != "MESH":
            continue
        ob.data.calc_loop_triangles()
        tris += len(ob.data.loop_triangles)
        for v in ob.data.vertices:
            w = ob.matrix_world @ v.co
            lo = Vector((min(lo[i], w[i]) for i in range(3)))
            hi = Vector((max(hi[i], w[i]) for i in range(3)))
    d = hi - lo
    print(f"BUILD {name}: {tris} tris (budget {budget} {'ok' if tris <= budget else 'OVER BUDGET'}) w{d.x:.2f} d{d.y:.2f} h{d.z:.2f} zmin{lo.z:.2f}")
    bpy.ops.object.select_all(action="DESELECT")
    for ob in B.Ctx.objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(B.OUT_GLB, name + ".glb"), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=False, export_materials="EXPORT", export_animations=bool(anims), export_animation_mode="NLA_TRACKS",
                              export_skins=True, export_def_bones=False, export_optimize_animation_size=False,
                              export_force_sampling=True, export_frame_range=False)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(B.OUT_BLEND, name + ".blend"), compress=True)


def rigid_weights(table):
    """table: part name -> bone. Every vertex of the part is bound to that one bone."""
    def fn(ob, arm):
        g = ob.vertex_groups.new(name=table[ob.name])
        g.add([v.index for v in ob.data.vertices], 1.0, "REPLACE")
        ob.parent = arm
        ob.modifiers.new("Armature", "ARMATURE").object = arm
    return fn


# ---------------------------------------------------------------- crow (animal_crow, rig: body head tail wing_l wing_r)
def crow_parts():
    # perched, wings folded; body 0.3 long. Wings are long along -Y so a 90 degree yaw spreads them for the flight.
    b = Part("Body")
    b.ball((0.055, 0.1, 0.055), (0, -0.01, 0.115), FEATHER, rot=(0.5, 0, 0), seg=8, rings=5)
    b.ball((0.04, 0.05, 0.04), (0, 0.06, 0.14), FEATHER2, rot=(0.5, 0, 0), seg=6, rings=4)  # chest
    for s in (-1, 1):
        b.between((s * 0.025, 0.0, 0.105), (s * 0.025, 0.012, 0.012), 0.008, 0.006, LEG, seg=4)
        for k in (-1, 0, 1):  # three toes forward
            b.box((0.008, 0.035, 0.007), (s * 0.025 + k * 0.012, 0.03, 0.004), LEG, rot=(0, 0, k * 0.3))
        b.box((0.008, 0.02, 0.007), (s * 0.025, -0.01, 0.004), LEG)  # back toe
    b.done()
    h = Part("Head", (0, 0.07, 0.17))
    h.ball((0.04, 0.045, 0.04), (0, 0.075, 0.175), FEATHER, seg=7, rings=5)
    h.cyl(0.02, 0.004, 0.075, (0, 0.14, 0.168), BEAK, rot=(-math.pi / 2, 0, 0), seg=5)
    h.box((0.014, 0.05, 0.008), (0, 0.125, 0.152), BEAK)  # lower beak
    for s in (-1, 1):
        h.ball((0.008, 0.008, 0.008), (s * 0.034, 0.09, 0.185), "#8A8A92", seg=4, rings=3)  # pale eye, never ember (doc 07 s2)
    h.done()
    t = Part("Tail", (0, -0.08, 0.12))
    t.box((0.07, 0.11, 0.012), (0, -0.145, 0.1), FEATHER2, rot=(0.3, 0, 0))
    t.box((0.05, 0.05, 0.012), (0, -0.075, 0.115), FEATHER, rot=(0.3, 0, 0))
    t.done()
    for s, nm in ((-1, "WingL"), (1, "WingR")):
        w = Part(nm, (s * 0.05, 0.02, 0.13))
        w.ball((0.016, 0.1, 0.045), (s * 0.058, -0.075, 0.125), FEATHER, rot=(0.15, 0, 0), seg=6, rings=4)
        for k in range(4):  # primaries fan out behind
            w.box((0.014, 0.1, 0.008), (s * (0.06 + 0.004 * k), -0.185 - 0.01 * k, 0.108 - 0.006 * k), FEATHER2, rot=(0.15, 0, s * 0.06 * k))
        w.done()


CROW_BONES = {  # vertical stubs: Euler X pitch, Y twist, Z roll (see module doc)
    "body": ((0, 0, 0.1), (0, 0, 0.14), None),
    "head": ((0, 0.07, 0.15), (0, 0.07, 0.2), "body"),
    "tail": ((0, -0.08, 0.12), (0, -0.08, 0.16), "body"),
    "wing_l": ((-0.05, 0.02, 0.13), (-0.05, 0.02, 0.18), "body"),
    "wing_r": ((0.05, 0.02, 0.13), (0.05, 0.02, 0.18), "body"),
}


def crow_idle():  # perched: breathes, looks about, flicks the tail; 2 s loop
    t, n = {}, 48
    for f in (0, 12, 24, 36, 48):
        ph = f / n * math.tau
        t.setdefault("body", {})[f] = (1.0 * math.sin(ph), 0, 0)
        t.setdefault("head", {})[f] = (-4 * math.sin(2 * ph), (0, 28, -25, 0, 0)[f // 12], 0)
        t.setdefault("tail", {})[f] = (3 * max(0.0, math.sin(2 * ph - 0.5)), 0, 0)
        for s in ("l", "r"):
            t.setdefault("wing_" + s, {})[f] = (0, 0, 0)
    return n, t


def crow_caw():  # beak up, body tips back, tail drops; one-shot
    F5 = (0, 4, 8, 12, 16, 20, 24)
    return 24, {
        "head": F.hold(F5, [(0, 0, 0), (30, 0, 0), (36, 0, 0), (30, 0, 0), (36, 0, 0), (20, 0, 0), (0, 0, 0)]),
        "body": F.hold(F5, [(0, 0, 0), (10, 0, 0), (14, 0, 0), (10, 0, 0), (14, 0, 0), (6, 0, 0), (0, 0, 0)]),
        "tail": F.hold(F5, [(0, 0, 0), (-8, 0, 0), (-12, 0, 0), (-8, 0, 0), (-12, 0, 0), (-4, 0, 0), (0, 0, 0)]),
    }


def crow_fly():  # 12 frames at 24 fps = 0.5 s, 2 flaps a second (under D-046's 3 per second); wings spread and beat
    t, n = {}, 12
    for f in range(0, n + 1, 2):
        ph = f / n * math.tau
        c = math.cos(ph)
        # wing_l: Z+ is down; wing_r: Z+ is up. Spread by yaw (l -88, r +88). Mean 8 deg up, +-38 swing.
        t.setdefault("wing_l", {})[f] = (-6 * c, -88, 38 * c - 8)
        t.setdefault("wing_r", {})[f] = (-6 * c, 88, -(38 * c - 8))
        t.setdefault("body", {})[f] = (-12, 0, 0, (0, 0.018 * -c, 0))
        t.setdefault("head", {})[f] = (12, 0, 0)
        t.setdefault("tail", {})[f] = (-6 + 4 * c, 0, 0)
    return n, t


def build_crow():
    build_rigged("animal_crow", crow_parts, CROW_BONES,
                 rigid_weights({"Body": "body", "Head": "head", "Tail": "tail", "WingL": "wing_l", "WingR": "wing_r"}),
                 {"idle": crow_idle, "caw": crow_caw, "fly": crow_fly}, BUDGET["mid"])


def dead_crow():
    # 0.3 x 0.15 x 0.1: on its back, head lolling, one wing flung out, legs stiff in the air, a few loose feathers
    p = Part("DeadCrow")
    p.ball((0.05, 0.09, 0.04), (0, 0, 0.04), FEATHER, rot=(0, 0, 0.2), seg=8, rings=4)
    p.ball((0.035, 0.05, 0.02), (0.01, 0.01, 0.075), "#3A3844", seg=6, rings=3)  # pale-grey belly facing up
    p.ball((0.035, 0.04, 0.032), (-0.03, 0.115, 0.035), FEATHER2, seg=6, rings=3)  # head
    p.cyl(0.017, 0.004, 0.06, (-0.045, 0.165, 0.03), BEAK, rot=(-math.pi / 2, 0, 0.5), seg=5)  # beak open
    p.cyl(0.017, 0.004, 0.05, (-0.005, 0.16, 0.03), BEAK, rot=(-math.pi / 2, 0, -0.1), seg=5)
    p.box((0.012, 0.012, 0.004), (-0.055, 0.125, 0.052), "#101014", rot=(0, 0, 0.8))  # X eye
    p.box((0.012, 0.012, 0.004), (-0.055, 0.125, 0.052), "#101014", rot=(0, 0, -0.8))
    p.ball((0.06, 0.03, 0.01), (0.095, 0.0, 0.012), FEATHER, rot=(0, 0, 0.15), seg=6, rings=3)  # wing flung out
    for k in range(2):
        p.box((0.045, 0.012, 0.005), (0.15 + 0.008 * k, -0.01 + 0.025 * k, 0.01), FEATHER2, rot=(0, 0, 0.3 * (k - 0.5)))
    p.ball((0.03, 0.06, 0.012), (-0.06, -0.03, 0.02), FEATHER, rot=(0, 0, -0.2), seg=5, rings=3)  # folded wing under
    for s in (-1, 1):  # stiff legs up
        p.between((s * 0.02, -0.07, 0.06), (s * 0.03, -0.1, 0.1), 0.007, 0.005, LEG, seg=4)
        p.box((0.02, 0.012, 0.006), (s * 0.03, -0.105, 0.1), LEG)
    p.box((0.05, 0.1, 0.01), (0.01, -0.13, 0.025), FEATHER2, rot=(0, 0, 0.1))  # tail
    for x, y, r in ((-0.08, 0.0, 0.7),):  # loose feathers
        p.box((0.05, 0.012, 0.003), (x, y, 0.002), FEATHER2, rot=(0, 0, r))
    p.done()


# ---------------------------------------------------------------- hands (tool_hands)
def hands():
    # First person, origin between the elbows, arms reach toward +Y (Godot -Z) and tilt up. Each arm pivots at its elbow
    # so the Taint shader can climb from the fingers (far in local +Y) back to the elbow (local origin).
    F.extra_materials()  # mat_farmer_overalls (3, unused here) and mat_farmer_sleeves (4)
    SHIRT, CUFF, SKIN = F.SHIRT, "#7A2E22", F.SKIN
    for s, nm in ((-1, "HandL"), (1, "HandR")):
        el = (s * 0.19, 0.0, 0.0)
        wr = (s * 0.125, 0.3, 0.07)
        p = Part(nm, el)
        p.ball((0.062, 0.062, 0.062), el, SHIRT, seg=8, rings=5, mat=MAT_SLEEVE)  # elbow
        p.between(el, wr, 0.062, 0.05, SHIRT, seg=8, mat=MAT_SLEEVE)  # sleeve
        p.between((el[0] + (wr[0] - el[0]) * 0.86, 0.26, 0.06), (wr[0], wr[1] + 0.012, wr[2] + 0.002), 0.055, 0.055, CUFF, seg=8, mat=MAT_SLEEVE)  # rolled cuff
        hx, hy, hz = s * 0.115, 0.3, 0.075
        p.box((0.085, 0.085, 0.032), (hx, hy + 0.055, hz), SKIN, rot=(0.23, 0, 0), mat=MAT_SLEEVE)  # palm
        for k in range(4):  # four relaxed fingers, middle ones longest, a gentle curl
            fl = (0.062, 0.072, 0.07, 0.056)[k]
            fx = hx + (k - 1.5) * 0.021
            p.box((0.0185, fl, 0.017), (fx, hy + 0.1 + fl / 2 - 0.004, hz + 0.022 - 0.0), SKIN, rot=(-0.12, 0, 0), mat=MAT_SLEEVE)
        p.ball((0.02, 0.04, 0.02), (hx - s * 0.05, hy + 0.04, hz + 0.01), SKIN, rot=(0, 0, s * 0.5), seg=5, rings=3, mat=MAT_SLEEVE)  # thumb
        p.done()


# ---------------------------------------------------------------- road items
def road_sign():
    # 0.4 x 0.1 x 2: weathered post, one big arrow board toward town (+X), one small board the other way, nails, stone footing
    GREY, GREY2, PAINT, RED = "#8A8277", "#6F6A60", "#D2C9AE", "#9A3B2B"
    p = Part("Sign")
    p.ball((0.14, 0.075, 0.07), (0, 0, 0.02), "#5C5A55", seg=7, rings=3)  # stone footing
    p.box((0.08, 0.08, 1.95), (0, 0, 0.99), WOOD2)  # post
    p.box((0.095, 0.095, 0.03), (0, 0, 1.975), WOOD)  # cap
    p.box((0.26, 0.03, 0.17), (0.0, 0.055, 1.78), GREY)  # arrow board
    p.box((0.12, 0.03, 0.12), (0.13, 0.055, 1.78), GREY, rot=(0, math.pi / 4, 0))  # arrow tip, x to 0.2
    p.box((0.2, 0.034, 0.014), (-0.02, 0.056, 1.8), PAINT)  # painted lettering stand-in: two bars
    p.box((0.14, 0.034, 0.014), (-0.05, 0.056, 1.75), PAINT)
    p.box((0.2, 0.03, 0.12), (-0.05, 0.05, 1.5), RED)  # small board the other way
    p.box((0.085, 0.03, 0.085), (-0.15, 0.05, 1.5), RED, rot=(0, math.pi / 4, 0))
    p.box((0.12, 0.034, 0.012), (-0.06, 0.052, 1.5), PAINT)
    for x, z in ((-0.1, 1.78), (0.1, 1.78), (0.0, 1.5)):  # nails
        p.ball((0.008, 0.006, 0.008), (x, 0.072, z), IRON, seg=4, rings=3)
    p.box((0.3, 0.014, 0.03), (0, -0.05, 1.6), WOOD2, rot=(0, 0, 0))  # brace plank behind
    p.done()


def road_lamp():
    # 0.3 x 0.3 x 3.5: iron post on a flared foot, caged glass lantern on top. The glass is its own surface in
    # mat_emissive_warm (same as tool_lantern). LightRig is an empty at the glass for the game's light rig (doc 07 s4).
    GLASS_FRAME = "#2A2D2F"
    p = Part("Lamp")
    p.cyl(0.14, 0.07, 0.3, (0, 0, 0.15), IRON, seg=8)  # flared foot
    p.cyl(0.075, 0.075, 0.04, (0, 0, 0.32), "#55595C", seg=8)  # collar
    p.cyl(0.045, 0.04, 2.8, (0, 0, 1.7), IRON, seg=6)  # post
    p.cyl(0.07, 0.07, 0.04, (0, 0, 2.5), "#55595C", seg=8)  # mid band
    p.cyl(0.07, 0.07, 0.04, (0, 0, 3.08), "#55595C", seg=8)
    p.box((0.26, 0.26, 0.03), (0, 0, 3.12), GLASS_FRAME)  # lantern floor
    p.box((0.2, 0.2, 0.26), (0, 0, 3.26), "#FFB45A", mat=MAT_WARM)  # glass
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((0.025, 0.025, 0.28), (sx * 0.115, sy * 0.115, 3.26), GLASS_FRAME)  # corner posts
    p.box((0.27, 0.27, 0.025), (0, 0, 3.4), GLASS_FRAME)  # top plate
    p.cyl(0.19, 0.03, 0.1, (0, 0, 3.45), GLASS_FRAME, rot=(0, 0, math.pi / 4), seg=4)  # cap
    p.ball((0.03, 0.03, 0.03), (0, 0, 3.49), IRON, seg=5, rings=3)  # finial
    p.done()
    empty("LightRig", (0, 0, 3.26))


# ---------------------------------------------------------------- ghost shell (char_ghost)
GHOST, GHOST2, GHOST_EYE = "#BFD8FF", "#9DBDEB", "#5E7FB0"


def ghost_material():
    """mat_ghost_shell: alpha-blended cold white-blue (doc 07 s2 palette), vertex colour for the two tones. Static: no emission, no
    animation of alpha, so nothing flashes (doc 01 'Photosensitivity safety', D-046). Fading in light and the rim are game shaders."""
    m = bpy.data.materials.new("mat_ghost_shell")
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
    bsdf.inputs["Alpha"].default_value = 0.42
    nt.links.new(bsdf.outputs["BSDF"], out_n.inputs["Surface"])
    if hasattr(m, "surface_render_method"):
        m.surface_render_method = "BLENDED"
    if hasattr(m, "blend_method"):
        try:
            m.blend_method = "BLEND"
        except (TypeError, AttributeError):
            pass
    B.Ctx.mats.append(m)  # index 3
    return m


def ghost_materials():
    # indexes 0..2 are the base three; 3 is the ghost shell. Part._fin sets material_index, so only MAT_GHOST is used here.
    ghost_material()


def ghost_parts():
    G = dict(mat=MAT_GHOST)
    t = Part("Torso", (0, 0, 1.0))
    t.ball((0.2, 0.125, 0.14), (0, 0, 1.04), GHOST2, seg=10, rings=6, **G)  # hips
    t.ball((0.205, 0.13, 0.3), (0, 0, 1.28), GHOST, seg=10, rings=6, **G)  # body
    t.ball((0.22, 0.13, 0.09), (0, 0, 1.52), GHOST, seg=10, rings=4, **G)  # shoulders
    t.cyl(0.06, 0.06, 0.1, (0, 0, 1.6), GHOST, seg=8, **G)  # neck
    t.done()
    h = Part("Head", (0, 0, 1.55))
    h.ball((0.15, 0.16, 0.18), (0, 0, 1.65), GHOST, seg=12, rings=8, **G)
    for s in (-1, 1):  # hollow eyes and mouth, a darker blue so the face reads through the translucency
        h.ball((0.026, 0.012, 0.04), (s * 0.06, 0.145, 1.67), GHOST_EYE, seg=5, rings=4, **G)
    h.ball((0.03, 0.012, 0.04), (0, 0.15, 1.58), GHOST_EYE, seg=5, rings=4, **G)
    h.done()
    for s, nm in ((-1, "ArmL"), (1, "ArmR")):
        sh, el, wr = (s * 0.23, 0.0, 1.5), (s * 0.25, 0.02, 1.22), (s * 0.25, 0.1, 0.96)
        a = Part(nm, sh)
        a.ball((0.075, 0.075, 0.075), sh, GHOST, seg=8, rings=5, **G)
        a.between(sh, el, 0.062, 0.054, GHOST, seg=8, **G).between(el, wr, 0.054, 0.04, GHOST2, seg=8, **G)
        a.ball((0.05, 0.055, 0.06), (wr[0], wr[1] + 0.015, wr[2] - 0.05), GHOST2, seg=8, rings=5, **G)  # hand blob
        a.done()
    for s, nm in ((-1, "LegL"), (1, "LegR")):  # legs taper into a wisp that touches the ground
        hip, kn, an = (s * 0.1, 0.0, 0.98), (s * 0.1, 0.02, 0.5), (s * 0.1, 0.0, 0.0)
        l = Part(nm, hip)
        l.between(hip, kn, 0.095, 0.078, GHOST2, seg=8, **G).between(kn, an, 0.078, 0.012, GHOST2, seg=8, **G)
        l.done()


# ---------------------------------------------------------------- ragdoll (char_farmer_ragdoll)
def ragdoll_lie():
    """One static pose, 'lie': the dead body on its back, for a prop without a physics simulator. The physical bones ignore it."""
    pose = {"hips": (90, 0, 0, (0, -0.85, 0)), "spine": (-6, 0, 0), "head": (-12, 0, 6), "arm_l": (0, 0, 28), "arm_r": (14, 0, -34),
            "forearm_l": (14, 0, 0), "forearm_r": (30, 0, 0), "thigh_l": (-6, 0, 10), "thigh_r": (-10, 0, -14), "shin_l": (4, 0, 0), "shin_r": (8, 0, 0)}
    return 2, {b: {0: v, 2: v} for b, v in pose.items()}


def build_ragdoll():
    build_rigged("char_farmer_ragdoll", F.farmer_parts, F.BONES, F.weights, {"lie": ragdoll_lie}, BUDGET["farmer"], F.extra_materials)


def ghost_float():  # slow drift: whole body sways, arms hang loose; 3 s loop, nothing quick
    t, n = {}, 72
    for f in range(0, n + 1, 12):
        ph = f / n * math.tau
        b = math.sin(ph)
        t.setdefault("hips", {})[f] = (3 * b, 0, 2 * math.sin(ph + 1), (0, 0.02 * math.sin(ph * 2), 0))
        t.setdefault("spine", {})[f] = (-2 * b, 0, 0)
        t.setdefault("head", {})[f] = (2 * b, 3 * math.sin(ph + 0.5), 0)
        t.setdefault("arm_l", {})[f] = (6 * b, 0, 12 + 4 * b)
        t.setdefault("arm_r", {})[f] = (6 * b, 0, -12 - 4 * b)
        t.setdefault("forearm_l", {})[f] = (14 + 4 * b, 0, 0)
        t.setdefault("forearm_r", {})[f] = (14 + 4 * b, 0, 0)
        for s in "lr":
            t.setdefault("thigh_" + s, {})[f] = (4 + 3 * b, 0, 0)
            t.setdefault("shin_" + s, {})[f] = (-10 - 4 * b, 0, 0)
    return n, t


def build_ghost():
    build_rigged("char_ghost", ghost_parts, F.BONES, F.weights, {"idle": F.tracks_idle, "float": ghost_float}, BUDGET["farmer"], ghost_materials)


# ---------------------------------------------------------------- registry
MODELS = [
    ("prop_dead_crow", dead_crow, "small"),
    ("tool_hands", hands, "mid"),
    ("prop_road_sign", road_sign, "small"),
    ("prop_road_lamp", road_lamp, "mid"),
]
RIGGED = {"animal_crow": build_crow, "char_farmer_ragdoll": build_ragdoll, "char_ghost": build_ghost}

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for nm, fn, cls in MODELS:
        if not only or nm in only:
            B.build(nm, fn, cls)
    for nm, fn in RIGGED.items():
        if not only or nm in only:
            fn()

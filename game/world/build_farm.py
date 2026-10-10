"""Generates game/world/farm_phase1.tscn (DD Phase 1 gray box, x -32..46) and farm.tscn (DD Phase 2 full
farm) from doc 04 coordinates.

    cd tools && uv run python ../game/world/build_farm.py

Edit coordinates here, regenerate, commit all three files. Both scenes use the same coordinates (doc 04 s9).
"""
import json
import math
import re
from pathlib import Path

H_CORN = 2.4  # CONTRACTS section 4
L_WORLD, L_CORN = 1, 16  # layer 1 world, layer 5 corn (bit value 16)

subs: dict[str, str] = {}  # id -> resource text
nodes: list[str] = []
MATS: dict[str, str] = {}


def sub(kind: str, body: str) -> str:
    text = f'[sub_resource type="{kind}" id="@"]\n{body}'
    for k, v in subs.items():
        if v == text:
            return k
    key = f"{kind}_{len(subs)}"
    subs[key] = text
    return key


def mat(color: str) -> str:
    return sub("StandardMaterial3D", f"albedo_color = Color({color})\n")


def tf(x, y, z) -> str:
    return f"Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})"


def node(name, typ, parent, extra="", groups=(), meta=None):
    path = name if parent in (None, ".") else f"{parent}/{name}"
    p = "" if parent is None else f' parent="{parent}"'
    g = (" groups=[" + ", ".join('"' + x + '"' for x in groups) + "]") if groups else ""
    lines = [f'[node name="{name}" type="{typ}"{p}{g}]']
    if extra:
        lines.append(extra.rstrip("\n"))
    for k, v in (meta or {}).items():
        if isinstance(v, bool):
            s = "true" if v else "false"
        elif isinstance(v, str):
            s = '"' + v + '"'
        else:
            s = str(v)
        lines.append(f"metadata/{k} = {s}")
    nodes.append("\n".join(lines) + "\n")
    return path


def marker(parent, name, x, z, group, **meta):
    node(name, "Marker3D", parent, f"transform = {tf(x, 0, z)}\n", [group], meta)


FULL = False
EXT: dict[str, str] = {}  # P5-22: model name -> ext_resource id


def art(parent, name, model, x=0.0, y=0.0, z=0.0, yaw=0.0, sx=1.0, extra=""):
    """P5-22: a P5-14..17 model instanced under `parent` (full scene only); yaw in degrees about Y, sx scales along X."""
    eid = EXT.setdefault(model, f"m{len(EXT)}")
    a = math.radians(yaw)
    c, sn = round(math.cos(a), 5), round(math.sin(a), 5)
    nodes.append(f'[node name="{name}" parent="{parent}" instance=ExtResource("{eid}")]\n'
                 f"transform = Transform3D({round(c * sx, 5)}, 0, {sn}, 0, 1, 0, {round(-sn * sx, 5)}, 0, {c}, {x}, {y}, {z})\n{extra}")
    return f"{parent}/{name}"


def hide_meshes(prefix: str) -> None:
    """Hide every gray-box MeshInstance3D at or under `prefix` (collision bodies stay)."""
    for i, n in enumerate(nodes):
        m = re.match(r'\[node name="[^"]+" type="MeshInstance3D" parent="([^"]+)"', n)
        if m and (m.group(1) == prefix or m.group(1).startswith(prefix + "/")):
            nodes[i] = n.rstrip("\n") + "\nvisible = false\n"


def box(parent, name, cx, cz, sx, sz, h, m, layer=L_WORLD, y0=0.0, groups=()):
    """Static box centred at x/z in parent space, footprint sx*sz, height h, base at y0."""
    body = node(name, "StaticBody3D", parent,
                f"transform = {tf(cx, y0 + h / 2, cz)}\ncollision_layer = {layer}\ncollision_mask = 0\n", groups)
    bm = sub("BoxMesh", f"size = Vector3({sx}, {h}, {sz})\n")
    bs = sub("BoxShape3D", f"size = Vector3({sx}, {h}, {sz})\n")
    node("Mesh", "MeshInstance3D", body, f'mesh = SubResource("{bm}")\nmaterial_override = SubResource("{MATS[m]}")\n')
    node("Shape", "CollisionShape3D", body, f'shape = SubResource("{bs}")\n')


def vis(parent, name, mesh, m, x, y, z, s=0.0, c=1.0):
    """Visual-only mesh (no collision) at x/y/z, yawed so local +z points along (s, c) = (sin, cos)."""
    node(name, "MeshInstance3D", parent, f"transform = Transform3D({c}, 0, {s}, 0, 1, 0, {-s}, 0, {c}, {x}, {y}, {z})\n"
         f'mesh = SubResource("{mesh}")\nmaterial_override = SubResource("{MATS[m]}")\n')


def vbox(parent, name, cx, cz, sx, sz, h, m, y0=0.0, s=0.0, c=1.0):
    vis(parent, name, sub("BoxMesh", f"size = Vector3({sx}, {h}, {sz})\n"), m, cx, y0 + h / 2, cz, s, c)


def cyl(parent, name, x, z, r, h, m, y0=0.0, top=None):
    mesh = sub("CylinderMesh", f"top_radius = {r if top is None else top}\nbottom_radius = {r}\nheight = {h}\nradial_segments = 12\n")
    vis(parent, name, mesh, m, x, y0 + h / 2, z)


def path(name, pts, w):
    """Dirt path: one flat visual strip per leg, joints overlap by half a width so corners close."""
    for i in range(1, len(pts)):
        (x0, z0), (x1, z1) = pts[i - 1], pts[i]
        dx, dz = x1 - x0, z1 - z0
        n = (dx * dx + dz * dz) ** 0.5
        s, c = round(dx / n, 5), round(dz / n, 5)
        vbox("Paths", f"{name}{i}", (x0 + x1) / 2, (z0 + z1) / 2, w, n + w, 0.02, "path", 0.0, s, c)


def tree(name, x, z, kind):
    """Gray-box tree. Trunk is visual only; the canopy from 1.2 m up is a layer-5 sight blocker like corn
    (D-100): the creature and players pass through, nothing at the 1 m corn point queries hits it."""
    t = node(name, "StaticBody3D", "Trees", f"transform = {tf(x, 0, z)}\ncollision_layer = {L_CORN}\ncollision_mask = 0\n")
    cyl(t, "Trunk", 0, 0, 0.25, 2.0, "trunk")
    if kind == "pine":
        cyl(t, "Canopy", 0, 0, 1.8, 5.5, "pine", y0=1.2, top=0.0)
        shape = sub("CylinderShape3D", "height = 3.0\nradius = 1.3\n")
        node("Shape", "CollisionShape3D", t, f'transform = {tf(0, 2.7, 0)}\nshape = SubResource("{shape}")\n')
    else:
        vis(t, "Canopy", sub("SphereMesh", "radius = 2.0\nheight = 3.4\nradial_segments = 12\nrings = 6\n"), "leaf", 0, 3.0, 0)
        shape = sub("CylinderShape3D", "height = 3.0\nradius = 1.8\n")
        node("Shape", "CollisionShape3D", t, f'transform = {tf(0, 2.8, 0)}\nshape = SubResource("{shape}")\n')


def fence(name, x0, z0, x1, z1):
    """Visual-only split-rail fence on an axis-aligned line: posts about every 3 m and two rails, 1 m tall."""
    length = max(abs(x1 - x0), abs(z1 - z0))
    n = max(1, round(length / 3))
    f = node(name, "Node3D", "Fences")
    for i in range(n):  # P5-22: n prop_fence_segment models, X scaled L / (3 n) (handoff P5-14)
        t = (i + 0.5) / n
        art(f, f"Seg{i}", "prop_fence_segment", x0 + (x1 - x0) * t, 0, z0 + (z1 - z0) * t,
            90.0 if abs(z1 - z0) > abs(x1 - x0) else 0.0, length / n / 3)


def board_labels(parent, text, w, y, zf, px=0.004):
    """P5-61: painted text flat on both faces of a board (front +z, back -z), `zf` m off the face. Not billboard."""
    for nm, yaw in (("Front", 0.0), ("Back", 180.0)):
        a = math.radians(yaw)
        c, sn = round(math.cos(a), 5), round(math.sin(a), 5)
        node(nm, "Label3D", parent, f"transform = Transform3D({c}, 0, {sn}, 0, 1, 0, {-sn}, 0, {c}, 0, {y}, {zf if yaw == 0 else -zf})\n"
             f'shaded = true\npixel_size = {px}\nmodulate = Color(0.93, 0.88, 0.70, 1)\n'
             f'outline_modulate = Color(0.16, 0.10, 0.05, 1)\ntext = "{text}"\nfont_size = 96\noutline_size = 12\n'
             f'width = {int(w / px)}\n')


def sign(name, x, z, text, yaw=0.0):
    """P5-61: a plank board on two posts, visual only (no collision), text painted on both faces. `yaw` turns the
    faces: 0 faces +-z, 90 faces +-x (toward walkers on a path running along x)."""
    a = math.radians(yaw)
    c, sn = round(math.cos(a), 5), round(math.sin(a), 5)
    s = node(name, "Node3D", "Signs", f"transform = Transform3D({c}, 0, {sn}, 0, 1, 0, {-sn}, 0, {c}, {x}, 0, {z})\n")
    w = round(0.3 * len(text) + 0.5, 2)
    for i, px in enumerate((-w / 2 + 0.12, w / 2 - 0.12), 1):
        vbox(s, f"Post{i}", px, 0, 0.12, 0.12, 2.3, "trunk")
    vbox(s, "Board", 0, 0, w, 0.08, 0.7, "board", y0=1.45)
    board_labels(s, text, w, 1.8, 0.05)


# P4-27 (doc 04 s13): cover, tree lines and landmarks. Tree canopies keep every work spot's open ground at least
# as wide as its corn distance (doc 04 s8.4), stay out of the audio band and off the cart route and walk lines.
TREES = ([(f"Orchard{i + 1}", x, z, "round") for i, (x, z) in enumerate(
             (x, z) for z in (30, 36, 42) for x in (24, 30, 36))]
         + [(f"WindbreakA{i + 1}", x, -32, "pine") for i, x in enumerate(range(22, 39, 4))]
         + [(f"WindbreakB{i + 1}", x, -36, "pine") for i, x in enumerate(range(24, 37, 4))]
         + [(f"NorthEast{i + 1}", x, z, "pine") for i, (x, z) in enumerate(((80, -30), (84, -35), (88, -29), (91, -36), (85, -40)))]
         + [(f"EastLine{i + 1}", 97, z, "pine") for i, z in enumerate(range(22, 48, 5))]
         + [(f"EastLineB{i + 1}", 93, z, "pine") for i, z in enumerate((30, 40))]
         + [(f"West{i + 1}", x, z, "pine") for i, (x, z) in enumerate(((-56, -34), (-51, -29), (-47, -37), (-59, -25), (-53, -41)))]
         + [(f"SouthGrove{i + 1}", x, z, "round") for i, (x, z) in enumerate(((-27, 47), (-22, 51), (-19, 44)))])
PATHS = [  # side paths, 1.6 m; the 3 m cart route path is drawn from ROUTE in generate()
         # P5-21: every structure joins the network; each strip reaches w/2 = 0.8 m past its end points, so the barn-door paths start at x +-2.5, z 1.3 to stay out of the 1.2 m door lane
         ("ToYard", [(-2.5, 1.3), (-25, 9)], 1.6), ("ToHouse", [(-25, 9), (-45, 1)], 1.6),
         ("ToShed", [(-25, 11), (-15, 25)], 1.6), ("ToDrum", [(-15, 25), (-10, 25), (-10, 26)], 1.6),
         ("ToPumpkin", [(-45, 1), (-44, 20), (-46, 31)], 1.6),
         ("ToGen", [(-11, -5.5), (-11, 4.5)], 1.6), ("ToPen", [(-25, 9), (-24, -27)], 1.6),
         ("ToRoute", [(2.5, 1.3), (10, 1.5), (10, 8.5)], 1.6),
         ("ToCrate", [(73.5, 5), (90, 5), (90, -10.8)], 1.6), ("ToMoon", [(72.5, 5.2), (61, 17.8)], 1.6),
         ("ToWell", [(49, -23), (49, -20)], 1.6)]  # P5-47: the well stands between the fields, a stub off the cart route
FENCES = [("FieldA_N", 23, -14, 28, -14), ("FieldA_N2", 32, -14, 37, -14), ("FieldA_S", 23, 0, 28, 0),
          ("FieldA_S2", 32, 0, 37, 0), ("FieldB_N", 65, -11, 70, -11), ("FieldB_N2", 74, -11, 79, -11),
          ("Moon_W", 56, 18, 56, 26), ("Moon_S", 56, 26, 64, 26), ("Moon_E", 64, 18, 64, 26),
          ("Gate_N", 104.5, -20, 104.5, -8.5), ("Gate_S", 104.5, -1.5, 104.5, 10)]
SIGNS = [("FieldA", 21.5, 0.5, "FIELD A", 90), ("FieldB", 63.5, -8, "FIELD B", 90), ("Moonflowers", 55, 17, "MOONFLOWERS", 90),
         ("Store", 75, 6.5, "STORE", 90), ("Town", 102, -10, "TOWN", 90), ("Pumpkin", -42, 28, "PRIZE PUMPKIN", 0),
         ("Shed", -11, 23.5, "TOOL SHED", 0), ("Pen", -20.5, -25.5, "PEN", 0), ("Farmhouse", -39, 3, "FARMHOUSE", 90),
         ("Well", 52.5, -18, "WELL", 0)]  # x, z, text, yaw (P5-61)


def landmarks() -> None:
    """Visual-only landmarks tall enough to read over the corn: silo north (behind the barn), water tower south,
    windpump beside the well (P5-47: between the fields), an arch over the farm gate. No collision: the silo and tower stand in the ring corn."""
    node("Silo", "Node3D", "Landmarks", f"transform = {tf(6, 0, -53)}\n")
    cyl("Landmarks/Silo", "Body", 0, 0, 3.5, 14, "metal")
    vis("Landmarks/Silo", "Dome", sub("SphereMesh", "radius = 3.5\nheight = 3.5\nis_hemisphere = true\nradial_segments = 12\nrings = 4\n"), "metal", 0, 14, 0)
    node("WaterTower", "Node3D", "Landmarks", f"transform = {tf(40, 0, 64)}\n")
    for i, (lx, lz) in enumerate(((-2, -2), (2, -2), (-2, 2), (2, 2)), 1):
        vbox("Landmarks/WaterTower", f"Leg{i}", lx, lz, 0.3, 0.3, 10, "trunk")
    cyl("Landmarks/WaterTower", "Tank", 0, 0, 3, 5, "rust", y0=10)
    cyl("Landmarks/WaterTower", "Roof", 0, 0, 3.3, 2, "rust", y0=15, top=0.0)
    node("Windpump", "Node3D", "Landmarks", f"transform = {tf(45.5, 0, -20)}\n")
    cyl("Landmarks/Windpump", "Mast", 0, 0, 0.15, 9, "metal")
    cyl("Landmarks/Windpump", "Tail", 0, -1, 0.05, 0.1, "metal", y0=9)
    vbox("Landmarks/Windpump", "Rotor", 0, 0.3, 3.2, 0.1, 3.2, "metal", y0=7.4)
    node("GateArch", "Node3D", "Landmarks", f"transform = {tf(105, 0, -5)}\n")
    for nm, z in (("PoleN", -3.2), ("PoleS", 3.2)):
        vbox("Landmarks/GateArch", nm, 0, z, 0.3, 0.3, 4.6, "fence")
    vbox("Landmarks/GateArch", "Beam", 0, 0, 0.4, 7.0, 0.5, "fence", y0=4.4)
    # P5-61: the TOWN board is nailed across the beam face, text on both faces. Not hung below it: from the farm side a
    # board under the beam covered P5-48's BRENN FARM road sign 5 m beyond the gate (QA); the beam hides nothing behind.
    vbox("Landmarks/GateArch", "Board", 0, 0, 0.48, 2.0, 0.42, "board", y0=4.44)
    node("Text", "Node3D", "Landmarks/GateArch", "transform = Transform3D(0, 0, -1, 0, 1, 0, 1, 0, 0, 0, 4.65, 0)\n")
    board_labels("Landmarks/GateArch/Text", "TOWN", 1.9, 0, 0.25, 0.004)
    node("HayStack", "Node3D", "Landmarks", f"transform = {tf(38, 0, 12)}\n")
    for i, (hx, hz, hy) in enumerate(((0, 0, 0), (1.3, 0, 0), (0.65, 0, 0.8), (0, 1.1, 0)), 1):
        vbox("Landmarks/HayStack", f"Bale{i}", hx, hz, 1.2, 1.0, 0.8, "hay", y0=hy)
    node("WoodPile", "Node3D", "Landmarks", f"transform = {tf(-20, 0, 29)}\n")
    for i, y in enumerate((0, 0.3, 0.6), 1):
        vbox("Landmarks/WoodPile", f"Logs{i}", 0, 0, 0.9, 2.6, 0.3, "trunk", y0=y)


def building(name, door_x, door_z, x0, x1, z0, z1, door_side, h, parent="Buildings", m="bldg"):
    """Walls as local boxes; node origin = door threshold (CONTRACTS section 4). 3 m door gap."""
    b = node(name, "Node3D", parent, f"transform = {tf(door_x, 0, door_z)}\n")
    t = 0.3
    lx0, lx1, lz0, lz1 = x0 - door_x, x1 - door_x, z0 - door_z, z1 - door_z
    # P5-63: N/S walls run the full outer width, W/E walls fill between their inner faces, so corners do not overlap
    ox0, ox1 = lx0 - t / 2, lx1 + t / 2
    for side, z in (("N", lz0), ("S", lz1)):
        if side == door_side:
            for nm, a, c in (("WallL", ox0, -1.5), ("WallR", 1.5, ox1)):
                box(b, f"{side}{nm}", (a + c) / 2, z, c - a, t, h, m)
        else:
            box(b, f"Wall{side}", (ox0 + ox1) / 2, z, ox1 - ox0, t, h, m)
    iz0, iz1 = lz0 + t / 2, lz1 - t / 2
    box(b, "WallW", lx0, (iz0 + iz1) / 2, t, iz1 - iz0, h, m)
    box(b, "WallE", lx1, (iz0 + iz1) / 2, t, iz1 - iz0, h, m)
    node("Door", "Marker3D", b, "", ["doors"], {"building": name.lower()})
    if FULL:  # P5-22: model and door replace the gray-box meshes, collision stays. Door leaves start open; game/interaction/doors.gd swings them and adds the blockers
        hide_meshes(b)
        model = {"Barn": "barn", "Farmhouse": "farmhouse", "ToolShed": "shed"}[name]
        art(b, "Art", f"bldg_{model}")
        art(b, "DoorArt", f"prop_door_{model}")
        nodes.append(f'[node name="LeafL" parent="{b}/DoorArt"]\nrotation = Vector3(0, {-math.pi / 2}, 0)\n')
        nodes.append(f'[node name="LeafR" parent="{b}/DoorArt"]\nrotation = Vector3(0, {math.pi / 2}, 0)\n')
    # LightRig scene is the Technical Artist's (game/render); spot only, Q-026. 6 m = lit doorway radius.
    inward = -0.5 if door_side == "S" else 0.5
    node("LightRigDoor", "Marker3D", b, f"transform = {tf(0, 3, inward)}\n", ["lightrig_spots"], {"radius_m": 6.0})
    return b


# Full marker lists, doc 04 s7. Phase 1 keeps the subsets named in doc 04 s9 (and P1-03).
TRAPS = [  # id, x, z, kind
    (1, 15, 6, "edge"), (2, 21, -4, "edge"), (3, 16, -14, "row"), (4, 14, -24, "row"), (5, 15, -57, "deep"),
    (6, 40, -6, "edge"), (7, 48, -10, "row"), (8, 49, -26, "edge"), (9, 50, 0, "row"), (10, 60, 66, "deep"),
    (11, 64, 15, "edge"), (12, 60, -20, "edge"), (13, 80, -48, "row"), (14, 90, 58, "row"), (15, -6, 41, "row"),
    (16, -14, 36, "edge"), (17, -47, 44, "row"), (18, -58, 30, "edge"), (19, -24, -47, "row"), (20, -35, 68, "deep"),
    (21, 100, 10, "edge"), (22, 30, -55, "deep")]
COVER = [(1, 13, -6), (2, 17, -8), (3, 47, -4), (4, 51, -6), (5, 49, -13), (6, 51, 18), (7, 72, -47), (8, 80, 57),
         (9, -6, 40), (10, -47, 42), (11, -67, 30), (12, -24, -47), (13, 107, 8), (14, -9, -47), (15, 30, 57),
         (16, -42, 57), (17, 73, -21.5), (18, 95.5, -17.5), (19, 81, 15.5), (20, 58.5, -4), (21, 100.5, 23), (22, 69, 39.5),
         (23, 45, -36), (24, 28, -23), (25, -1, -37), (26, 11, 34), (27, 28, 26), (28, 59, 46), (29, 78, 36), (30, 89, 25.5),
         (31, -35, 44)]
CROWS = [(1, 30, 1), (2, 72, -12), (3, 13, 2), (4, -47, 38), (5, 60, 17), (6, -24, -27), (7, 46, 30), (8, -62, 0),
         (9, -23, 11)]
SCARECROWS = [(1, 30, -5.5), (2, 72, -5.5), (3, 20, 20), (4, -40, 20), (5, 60, -30), (6, 90, 20), (7, -8, -32)]
ESCAPES = [(1, 35, -40), (2, 95, -40), (3, 35, 50), (4, -60, 50)]
AUDIO = [("audio_listener", -26, 16), ("audio_10m", -16, 16), ("audio_30m", 4, 16), ("audio_60m", 34, 16)]
P1_IDS = {"trap": {1, 2, 3, 4, 5, 6, 15, 16, 19, 22}, "cover": {1, 2, 3, 9, 12, 14, 15}, "crow": {1, 3, 6, 7, 9},
          "scarecrow": {1, 3, 7}, "escape": {1, 3}}
# P5-31 (doc 04 s3): extra corn for the creature, most of it round field B. Islands keep 5+ m from plots, 3.7+ m from the cart
# route, off the walks of doc 04 s8.7 and clear of tree canopies; the last is a strip off the ring. Cover points 17..22 sit inside.
PATCHES = [(68, 78, -40, -20), (94, 100, -30, -16), (78, 84, 14, 30), (57, 60, -8, 0), (99, 102, 16, 30),
           (66, 72, 38, 55)]
# P5-51 (doc 04 s16, CEO: the creature "only really around the edges"): corn woven through the middle. Hedges and strips join
# the ring to the farm's centre; each keeps the doc 04 s8.4 corn distances, 6 m from plots, 3.7 m from the cart route and
# 1 m from every s8.7 walk (check_farm.gd). Cover points 23..31 sit inside, in this order.
WEAVE = [(42, 48, -45, -31), (22, 36, -26, -20), (-6, 4, -45, -30), (8, 14, 30, 55), (20, 36, 24, 28), (52, 66, 43, 49),
         (72, 84, 33, 40), (84, 94, 23, 28), (-38, -32, 40, 55)]
# P5-47 (CEO STOP 6, doc 04 s4): the well stands between field A and field B, at the north tip of strip 3 (open ground
# midway between the fields, 1.5 m off the cart route edge, 5 m from corn, 4 m off the A to B walk). Phase 1 keeps the yard well.
WELL, WELL_P1, CROW_WELL = (49, -20), (-25, 10), (51, -19)
ROUTE = [(5, 6), (5, 8), (15, 9), (40, 5), (41, -24), (58, -24), (66, -14), (82, -14), (105, -5)]  # doc 04 s6.1 R0..R8; R0 parked east of the barn door, P5-18


def bear_slots() -> int:
    """pegboard_bear_slots from data/season.json (Game Designer's table), so the pegboard follows the data."""
    recs = json.loads((Path(__file__).parents[2] / "data" / "season.json").read_text(encoding="utf-8"))["records"]
    return int(next(r["value"] for r in recs if r["id"] == "pegboard_bear_slots"))


def pen_fence(nm: str, sx: float, sz: float) -> None:
    """P5-22: n = round(L / 3) prop_fence_segment per pen section, as children so a broken section hides them with the box."""
    if not FULL:
        return
    hide_meshes(f"Pen/{nm}")
    length = max(sx, sz)
    n = round(length / 3)
    along_z = sz > sx
    for k in range(n):
        off = -length / 2 + length / n * (k + 0.5)
        art(f"Pen/{nm}", f"Seg{k}", "prop_fence_segment", 0 if along_z else off, -0.6, off if along_z else 0,
            90.0 if along_z else 0.0, length / n / 3)


def plots(first: int, field: str, x0: float, z0: float, cols: int, rows: int, upgrade_from: int) -> None:
    """3 m plots, rows from z0 north to south; rows >= upgrade_from are the upgrade row (doc 04 s5.1)."""
    for r in range(rows):
        for c in range(cols):
            n = first + r * cols + c
            body = node(f"Plot{n:02d}", "Marker3D", "Fields",
                        f"transform = {tf(x0 + 1.5 + 3 * c, 0, z0 + 1.5 + 3 * r)}\n", ["plot_spots"],
                        {"field": field, "upgrade": r >= upgrade_from})
            pm = sub("BoxMesh", "size = Vector3(2.8, 0.05, 2.8)\n")
            node("Mesh", "MeshInstance3D", body, f'mesh = SubResource("{pm}")\nmaterial_override = SubResource("{MATS["plot"]}")\n')


def extra_plots(first: int, field: str, x0: float, zc: float) -> None:
    """D-039 headcount plots: a row of 4 outside the field (z centre zc), same 3 m grid. Inner two open at 5+
    players, outer two at 6 (start and ceiling both grow by 4 per player above 4). Not upgrade plots."""
    for c, opens in enumerate((6, 5, 5, 6)):
        node(f"Plot{first + c:02d}", "Marker3D", "Fields", f"transform = {tf(x0 + 1.5 + 3 * c, 0, zc)}\n", ["plot_spots"],
             {"field": field, "upgrade": False, "extra": True, "min_players": opens, "extra_order": c + 1})
        pm = sub("BoxMesh", "size = Vector3(2.8, 0.05, 2.8)\n")
        node("Mesh", "MeshInstance3D", f"Fields/Plot{first + c:02d}",
             f'mesh = SubResource("{pm}")\nmaterial_override = SubResource("{MATS["plot"]}")\n')


# Doc 03 s11.6 regions: name, x0, x1, z0, z1. Placeholder cuts that tile the clearing (x -65..105, z -45..55) so
# neighbours touch, plus the ring sides and the road lane; the director picks the smallest box holding a point.
REGIONS = [("yard", -65, 15, -25, 32), ("pen", -65, 15, -45, -25), ("pumpkin", -65, 15, 32, 55),
           ("field_a", 15, 50, -45, 5), ("field_b", 50, 105, -45, 5), ("moonflower", 15, 105, 5, 55),
           ("town_road", 105, 130, -12, 2), ("corn_ring_north", -90, 130, -70, -45),
           ("corn_ring_south", -90, 130, 55, 80), ("corn_ring_west", -90, -65, -45, 55), ("corn_ring_east", 105, 130, -45, 55)]


def generate(full: bool) -> str:
    global MATS, FULL
    FULL = full
    subs.clear()
    nodes.clear()
    EXT.clear()
    MATS = {
        "ground": mat("0.30, 0.34, 0.22, 1"), "corn": mat("0.35, 0.55, 0.15, 1"),
        "bldg": mat("0.45, 0.30, 0.22, 1"), "prop": mat("0.55, 0.55, 0.58, 1"),
        "house": mat("0.82, 0.78, 0.66, 1"), "plot": mat("0.35, 0.24, 0.14, 1"), "fence": mat("0.55, 0.45, 0.30, 1"),
    }
    if full:  # P4-27 cover and landmarks; the Phase 1 scene stays byte-identical
        MATS |= {"path": mat("0.52, 0.43, 0.30, 1"), "trunk": mat("0.33, 0.24, 0.16, 1"),
                 "pine": mat("0.12, 0.26, 0.16, 1"), "leaf": mat("0.22, 0.36, 0.14, 1"),
                 "metal": mat("0.62, 0.66, 0.70, 1"), "rust": mat("0.55, 0.22, 0.16, 1"), "hay": mat("0.80, 0.68, 0.36, 1"),
                 "board": mat("0.36, 0.25, 0.15, 1")}  # P5-61 weathered planks
    node("Farm", "Node3D", None)
    for c in ("Ground", "CornBlockers", "Buildings", "Props", "Fields", "Pen", "Markers", "Regions", "Bounds"):
        node(c, "Node3D", ".")

    # Ground and map boundary (doc 04 s3: invisible wall at the ring's outer edge; Phase 1 temp walls end at x -57 / 71)
    if full:
        box("Ground", "Floor", 30, 5, 240, 150, 0.2, "ground", y0=-0.2)
        walls = (("North", 30, -70, 242, 1), ("South", 30, 80, 242, 1), ("West", -90, 5, 1, 150), ("East", 150, 5, 1, 150))
    else:
        box("Ground", "Floor", 7, 5, 128, 150, 0.2, "ground", y0=-0.2)
        walls = (("North", 7, -70, 130, 1), ("South", 7, 80, 130, 1), ("West", -57, 5, 1, 150), ("East", 71, 5, 1, 150))
    for nm, cx, cz, sx, sz in walls:
        body = node(nm, "StaticBody3D", "Bounds", f"transform = {tf(cx, 5, cz)}\ncollision_layer = {L_WORLD}\ncollision_mask = 0\n")
        bs = sub("BoxShape3D", f"size = Vector3({sx}, 10, {sz})\n")
        node("Shape", "CollisionShape3D", body, f'shape = SubResource("{bs}")\n')

    # Corn (doc 04 s3 + s9): coarse layer-5 blockers with a plain green visual (MultiMesh corn is the Technical Artist's)
    if full:  # ring x -90..130, z -70..80 minus the clearing x -65..105, z -45..55 and the road lane z -9..-1; strips 1 to 4
        corn = [("RingNorth", -90, 130, -70, -45), ("RingSouth", -90, 130, 55, 80), ("RingWest", -90, -65, -45, 55),
                ("RingEastN", 105, 130, -45, -9), ("RingEastS", 105, 130, -1, 55),
                ("Strip1", -50, -44, 40, 55), ("Strip2", 12, 18, -45, 2), ("Strip3", 46, 52, -15, 55),
                ("Strip4", -9, -3, 38, 55)] + [(f"Patch{i + 1}", *r) for i, r in enumerate(PATCHES)] \
                + [(f"Weave{i + 1}", *r) for i, r in enumerate(WEAVE)]
    else:
        corn = [("RingNorth", -32, 46, -70, -45), ("RingSouth", -32, 46, 55, 80),
                ("TempWallWest", -57, -32, -45, 55), ("TempWallEast", 46, 71, -45, 55),
                ("Strip2", 12, 18, -45, 2), ("Strip4", -9, -3, 38, 55)]
    for nm, x0, x1, z0, z1 in corn:
        box("CornBlockers", nm, (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0, H_CORN, "corn", L_CORN)

    # Buildings (doc 04 s4); origin = door threshold
    building("Barn", 0, 0, -8, 8, -20, 0, "S", 5)
    if full:
        building("Farmhouse", -45, 0, -51, -39, -10, 0, "S", 4, m="house")  # P2-25: cream, not barn brown
    building("ToolShed", -15, 26, -18, -12, 26, 31, "N", 3)
    node("Pegboard", "Marker3D", "Buildings/ToolShed", f"transform = {tf(0, 1.5, 4.5)}\n", ["pegboard_spots"])
    if full:  # one slot marker per bear the board holds (season.json pegboard_bear_slots), 0.8 m apart on the back wall
        n = bear_slots()
        for i in range(n):  # P5-22: slot = prop_pegboard Hook, 0.32 m apart; board back plane on the shed's inner wall (z 4.85)
            node(f"Slot{i + 1}", "Marker3D", "Buildings/ToolShed/Pegboard",
                 f"transform = {tf((i - (n - 1) / 2) * 0.32, 0, 0.3)}\n", ["pegboard_slots"])
        art("Buildings/ToolShed", "PegboardArt", "prop_pegboard", 0, 1.2, 4.85)
        # Barn staging (doc 01 "Recording lines", doc 04 s4): where a player records, and the lantern that blows out.
        node("RecordingSpot", "Marker3D", "Buildings/Barn", f"transform = {tf(0, 0, -15)}\n", ["recording_spots"])
        node("BarnLantern", "Marker3D", "Buildings/Barn", f"transform = {tf(-5, 1.6, -17)}\n", ["barn_lantern", "lightrig_spots"], {"radius_m": 6.0})  # world_look puts the real LightRig here (Q-054 item 4)

    # Props
    props = [("Generator", -11, -6, 2, 1, 1.2, "generator"), ("FuelDrum", -10, 27, 1, 1, 1.0, "fuel_drum"),
             ("Well", *(WELL if full else WELL_P1), 2, 2, 1.0, "well")]
    if full:
        props += [("ShippingCrate", 72, 5, 2, 1, 1.0, "store_crate"), ("TownStand", 120, -5, 3, 2, 1.0, "sell_box")]
    else:
        props.append(("SellBox", 40, 20, 1.5, 1.5, 1.0, "sell_box"))
    for nm, x, z, sx, sz, h, grp in props:
        box("Props", nm, x, z, sx, sz, h, "prop", groups=[grp])
        if full and nm == "Well":  # P5-22: prop_well replaces the box mesh, collision stays
            hide_meshes("Props/Well")
            art("Props/Well", "Art", "prop_well", 0, -h / 2, 0)
    if full:
        marker("Props", "FarmGate", 105, -5, "farm_gate")
        for nm, z in (("PostN", -8), ("PostS", -2)):  # 6 m gate, doc 04 s4
            box("Props", f"Gate{nm}", 105, z, 0.3, 0.3, 2.0, "fence")
        hide_meshes("Props/GatePostN")
        hide_meshes("Props/GatePostS")
        art("Props/FarmGate", "Art", "prop_farm_gate", 0, 0, 0, 90.0)  # P5-22: the model spans X, the gate span is Z
        node("Sanctuary", "Marker3D", "Props", f"transform = {tf(120, 0, -5)}\n", ["sanctuary"], {"radius_m": 10.0})
        node("PrizePumpkin", "Marker3D", "Props", f"transform = {tf(-47, 0, 33)}\n", ["pumpkin_patch"], {"width_m": 4.0})
        node("MoonflowerBed", "Marker3D", "Props", f"transform = {tf(60, 0, 22)}\n", ["moonflower_bed"])

    # Fields: 4 x 3 plots of 3 m; the south row (z -4..-1) is the upgrade row (doc 04 s5.1)
    plots(1, "a", 24, -10, 4, 3, 2)
    if full:
        plots(13, "b", 66, -10, 4, 3, 2)
        plots(25, "moonflower", 57, 19, 2, 2, 9)  # 1 plot per player (doc 04 s5.2), none an upgrade
        extra_plots(29, "a", 24, -11.5)  # north of field A (barn side), doc 04 s5.1
        extra_plots(33, "b", 66, 0.5)  # south of field B (the cart route runs north of it)

    # Animal pen x -30..-18, z -38..-28, gate (-24,-28), 2 m gap in the south side
    # P4-08: the north, west and east walls are six breakable sections (group fence_sections; broken_fence, doc 03 s10.1)
    for nm, cx, cz, sx, sz in (("NorthW", -27, -38, 6, .2), ("NorthE", -21, -38, 6, .2),
                               ("WestN", -30, -35.45, .2, 4.9), ("WestS", -30, -30.55, .2, 4.9),
                               ("EastN", -18, -35.45, .2, 4.9), ("EastS", -18, -30.55, .2, 4.9)):  # P5-63: west/east fill between the north and south faces, so corners butt, not overlap
        box("Pen", nm, cx, cz, sx, sz, 1.2, "fence", groups=["fence_sections"])
        pen_fence(nm, sx, sz)
    for nm, cx, cz, sx, sz in (("SouthL", -27.5, -28, 5, .2), ("SouthR", -20.5, -28, 5, .2)):
        box("Pen", nm, cx, cz, sx, sz, 1.2, "fence")
        pen_fence(nm, sx, sz)
    marker("Pen", "PenGate", -24, -28, "pen_gates")
    if full:
        art("Pen/PenGate", "Art", "prop_fence_gate")

    # AI Director regions (doc 03 s11.6): flat Area3D boxes, no collision; the director reads the shapes and links
    # regions within ai_director.json nudge.link_m. Bounds are placeholder cuts of the clearing and ring (P3-04);
    # the same boxes go in both scenes, the Phase 1 farm just has no players in the outer ones.
    for nm, x0, x1, z0, z1 in REGIONS:
        area = node(nm, "Area3D", "Regions", f"transform = {tf((x0 + x1) / 2, 1, (z0 + z1) / 2)}\n"
                    "collision_layer = 0\ncollision_mask = 0\nmonitoring = false\nmonitorable = false\n", ["regions"])
        rs = sub("BoxShape3D", f"size = Vector3({x1 - x0}, 2, {z1 - z0})\n")
        node("Shape", "CollisionShape3D", area, f'shape = SubResource("{rs}")\n')

    # Markers (doc 04 s7). Group names: D-016.
    M = "Markers"

    def keep(kind: str, i: int) -> bool:
        return full or i in P1_IDS[kind]

    for i, x, z, kind in TRAPS:
        if keep("trap", i):
            marker(M, f"trap_{i:02d}", x, z, "trap_spots", kind=kind)
    for i, x, z in COVER:
        if keep("cover", i):
            marker(M, f"cover_{i:02d}", x, z, "creature_cover")
    for i, x, z in CROWS:
        if keep("crow", i):
            marker(M, f"crow_{i:02d}", *(CROW_WELL if full and i == 9 else (x, z)), "crow_perches")  # crow_09 perches on the well
    for i, x, z in SCARECROWS:
        if keep("scarecrow", i):
            marker(M, f"scarecrow_{i:02d}", x, z, "scarecrow_spots")
    for i, x, z in ESCAPES:
        if keep("escape", i):
            marker(M, f"escape_{i:02d}", x, z, "animal_escape_spots")
    for nm, x, z in AUDIO:
        marker(M, nm, x, z, "spatial_audio_markers")
    for i, (x, z) in enumerate(((-3, -8), (-1, -8), (1, -8), (3, -8), (-2, -11), (2, -11)), 1):  # 6 players (D-038), in the barn: lobby / dawn respawn (doc 04 s4)
        marker(M, f"spawn_{i}", x, z, "player_spawns")

    if full:  # cart route R0..R8 (doc 04 s6.1); Curve3D _data is (in, out, position) per point
        pts = ", ".join(f"0, 0, 0, 0, 0, 0, {x}, 0, {z}" for x, z in ROUTE)
        tilts = ", ".join("0" for _ in ROUTE)
        curve = sub("Curve3D", f'_data = {{\n"points": PackedVector3Array({pts}),\n"tilts": PackedFloat32Array({tilts})\n}}\n')
        node("CartRoute", "Path3D", ".", f'curve = SubResource("{curve}")\n')
        for c in ("Paths", "Fences", "Trees", "Signs", "Landmarks"):  # P4-27, doc 04 s13
            node(c, "Node3D", ".")
        path("Route", ROUTE + [(120, -5)], 3.0)  # doc 04 s6.1 R0..R8, then the lane to the town stand
        for nm, pts, w in PATHS:
            path(nm, pts, w)
        for f in FENCES:
            fence(*f)
        for t in TREES:
            tree(*t)
        for s in SIGNS:
            sign(*s)
        for i, z in enumerate((-10.5, 0.5)):  # P5-22: prop_road_lamp either side of the road lane; the glass stays unlit (no light node)
            art("Signs", f"RoadLamp{i}", "prop_road_lamp", 112, 0, z)
        landmarks()

    out = ["[gd_scene format=3]\n"]
    for model, eid in EXT.items():
        out.append(f'[ext_resource type="PackedScene" path="res://assets/models/{model}.glb" id="{eid}"]\n')
    for k, v in subs.items():
        out.append(v.replace('id="@"', f'id="{k}"'))
    out += nodes
    return "\n".join(out)


if __name__ == "__main__":
    here = Path(__file__).parent
    for name, full in (("farm_phase1.tscn", False), ("farm.tscn", True)):
        (here / name).write_text(generate(full), encoding="utf-8", newline="\n")
        print(name, len(nodes), "nodes,", len(subs), "resources")

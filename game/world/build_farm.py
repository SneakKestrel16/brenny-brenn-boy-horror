"""Generates game/world/farm_phase1.tscn (DD Phase 1 gray box, x -32..46) from doc 04 coordinates.

    python game/world/build_farm.py

Edit coordinates here, regenerate, commit both. Phase 2 widens the window (doc 04 section 9).
"""
from pathlib import Path

H_CORN = 2.4  # CONTRACTS section 4
L_WORLD, L_CORN = 1, 16  # layer 1 world, layer 5 corn (bit value 16)

subs: dict[str, str] = {}  # id -> resource text
nodes: list[str] = []


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


MATS = {
    "ground": mat("0.30, 0.34, 0.22, 1"), "corn": mat("0.35, 0.55, 0.15, 1"),
    "bldg": mat("0.45, 0.30, 0.22, 1"), "prop": mat("0.55, 0.55, 0.58, 1"),
    "plot": mat("0.35, 0.24, 0.14, 1"), "fence": mat("0.55, 0.45, 0.30, 1"),
}


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


def box(parent, name, cx, cz, sx, sz, h, m, layer=L_WORLD, y0=0.0, groups=()):
    """Static box centred at x/z in parent space, footprint sx*sz, height h, base at y0."""
    body = node(name, "StaticBody3D", parent,
                f"transform = {tf(cx, y0 + h / 2, cz)}\ncollision_layer = {layer}\ncollision_mask = 0\n", groups)
    bm = sub("BoxMesh", f"size = Vector3({sx}, {h}, {sz})\n")
    bs = sub("BoxShape3D", f"size = Vector3({sx}, {h}, {sz})\n")
    node("Mesh", "MeshInstance3D", body, f'mesh = SubResource("{bm}")\nmaterial_override = SubResource("{MATS[m]}")\n')
    node("Shape", "CollisionShape3D", body, f'shape = SubResource("{bs}")\n')


def building(name, door_x, door_z, x0, x1, z0, z1, door_side, h, parent="Buildings"):
    """Walls as local boxes; node origin = door threshold (CONTRACTS section 4). 3 m door gap."""
    b = node(name, "Node3D", parent, f"transform = {tf(door_x, 0, door_z)}\n")
    t = 0.3
    lx0, lx1, lz0, lz1 = x0 - door_x, x1 - door_x, z0 - door_z, z1 - door_z
    for side, z in (("N", lz0), ("S", lz1)):
        if side == door_side:
            for nm, a, c in (("WallL", lx0, -1.5), ("WallR", 1.5, lx1)):
                box(b, f"{side}{nm}", (a + c) / 2, z, c - a, t, h, "bldg")
        else:
            box(b, f"Wall{side}", (lx0 + lx1) / 2, z, lx1 - lx0, t, h, "bldg")
    box(b, "WallW", lx0, (lz0 + lz1) / 2, t, lz1 - lz0, h, "bldg")
    box(b, "WallE", lx1, (lz0 + lz1) / 2, t, lz1 - lz0, h, "bldg")
    node("Door", "Marker3D", b, "", ["doors"], {"building": name.lower()})
    # LightRig scene is the Technical Artist's (game/render); spot only, Q-026. 6 m = lit doorway radius.
    inward = -0.5 if door_side == "S" else 0.5
    node("LightRigDoor", "Marker3D", b, f"transform = {tf(0, 3, inward)}\n", ["lightrig_spots"], {"radius_m": 6.0})
    return b


# ---- tree ----
node("Farm", "Node3D", None)
for c in ("Ground", "CornBlockers", "Buildings", "Props", "Fields", "Pen", "Markers", "Bounds"):
    node(c, "Node3D", ".")

# Ground and map boundary (doc 04 s3: invisible wall at the ring's outer edge; temp walls end at x -57 / 71)
box("Ground", "Floor", 7, 5, 128, 150, 0.2, "ground", y0=-0.2)
for nm, cx, cz, sx, sz in (("North", 7, -70, 130, 1), ("South", 7, 80, 130, 1), ("West", -57, 5, 1, 150), ("East", 71, 5, 1, 150)):
    body = node(nm, "StaticBody3D", "Bounds", f"transform = {tf(cx, 5, cz)}\ncollision_layer = {L_WORLD}\ncollision_mask = 0\n")
    bs = sub("BoxShape3D", f"size = Vector3({sx}, 10, {sz})\n")
    node("Shape", "CollisionShape3D", body, f'shape = SubResource("{bs}")\n')

# Corn (doc 04 s3 + s9): coarse layer-5 blockers with a plain green visual (MultiMesh corn is the Technical Artist's)
corn = [
    ("RingNorth", -32, 46, -70, -45), ("RingSouth", -32, 46, 55, 80),
    ("TempWallWest", -57, -32, -45, 55), ("TempWallEast", 46, 71, -45, 55),
    ("Strip2", 12, 18, -45, 2), ("Strip4", -9, -3, 38, 55),
]
for nm, x0, x1, z0, z1 in corn:
    box("CornBlockers", nm, (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0, H_CORN, "corn", L_CORN)

# Buildings (doc 04 s4); origin = door threshold
building("Barn", 0, 0, -8, 8, -20, 0, "S", 5)
building("ToolShed", -15, 26, -18, -12, 26, 31, "N", 3)
node("Pegboard", "Marker3D", "Buildings/ToolShed", f"transform = {tf(0, 1.5, 4.5)}\n", ["pegboard_spots"])

# Props
PROPS = (("Generator", -11, -6, 2, 1, 1.2, "generator"), ("FuelDrum", -10, 27, 1, 1, 1.0, "fuel_drum"),
         ("Well", -25, 10, 2, 2, 1.0, "well"), ("SellBox", 40, 20, 1.5, 1.5, 1.0, "sell_box"))
for nm, x, z, sx, sz, h, grp in PROPS:
    box("Props", nm, x, z, sx, sz, h, "prop", groups=[grp])

# Field A, 4 x 3 plots of 3 m; south row (z -4..-1) is the upgrade row (doc 04 s5.1, s9)
for r, zc in enumerate((-8.5, -5.5, -2.5)):
    for c, xc in enumerate((25.5, 28.5, 31.5, 34.5)):
        n = r * 4 + c + 1
        body = node(f"Plot{n:02d}", "Marker3D", "Fields", f"transform = {tf(xc, 0, zc)}\n", ["plot_spots"], {"field": "a", "upgrade": r == 2})
        pm = sub("BoxMesh", "size = Vector3(2.8, 0.05, 2.8)\n")
        node("Mesh", "MeshInstance3D", body, f'mesh = SubResource("{pm}")\nmaterial_override = SubResource("{MATS["plot"]}")\n')

# Animal pen x -30..-18, z -38..-28, gate (-24,-28), 2 m gap in the south side
for nm, cx, cz, sx, sz in (("North", -24, -38, 12, .2), ("West", -30, -33, .2, 10), ("East", -18, -33, .2, 10),
                           ("SouthL", -27.5, -28, 5, .2), ("SouthR", -20.5, -28, 5, .2)):
    box("Pen", nm, cx, cz, sx, sz, 1.2, "fence")
marker("Pen", "PenGate", -24, -28, "pen_gates")

# Markers (doc 04 s7, Phase 1 subset of s9). Group names: D-016.
M = "Markers"
for nm, x, z, kind in (("01", 15, 6, "edge"), ("02", 21, -4, "edge"), ("03", 16, -14, "row"), ("04", 14, -24, "row"),
                       ("05", 15, -57, "deep"), ("06", 40, -6, "edge"), ("15", -6, 41, "row"), ("16", -14, 36, "edge"),
                       ("19", -24, -47, "row"), ("22", 30, -55, "deep")):
    marker(M, f"trap_{nm}", x, z, "trap_spots", kind=kind)
# cover_03 sits 1 m inside the temp east wall (doc 04 s9)
for nm, x, z in (("01", 13, -6), ("02", 17, -8), ("03", 47, -4), ("09", -6, 40), ("12", -24, -47), ("14", -9, -47), ("15", 30, 57)):
    marker(M, f"cover_{nm}", x, z, "creature_cover")
for nm, x, z in (("01", 30, 1), ("03", 13, 2), ("06", -24, -27), ("07", 46, 30), ("09", -23, 11)):
    marker(M, f"crow_{nm}", x, z, "crow_perches")
for nm, x, z in (("01", 30, -5.5), ("03", 20, 20), ("07", -8, -32)):
    marker(M, f"scarecrow_{nm}", x, z, "scarecrow_spots")
for nm, x, z in (("01", 35, -40), ("03", 35, 50)):
    marker(M, f"escape_{nm}", x, z, "animal_escape_spots")
for nm, x, z in (("audio_listener", -26, 16), ("audio_10m", -16, 16), ("audio_30m", 4, 16), ("audio_60m", 34, 16)):
    marker(M, nm, x, z, "spatial_audio_markers")
for i, (x, z) in enumerate(((-3, -8), (-1, -8), (1, -8), (3, -8)), 1):  # in the barn: lobby / dawn respawn (doc 04 s4)
    marker(M, f"spawn_{i}", x, z, "player_spawns")

# ---- write ----
out = ["[gd_scene format=3]\n"]
for k, v in subs.items():
    out.append(v.replace('id="@"', f'id="{k}"'))
out += nodes
Path(__file__).with_name("farm_phase1.tscn").write_text("\n".join(out), encoding="utf-8", newline="\n")
print(len(nodes), "nodes,", len(subs), "resources")

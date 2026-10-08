"""Generates game/world/farm_phase1.tscn (DD Phase 1 gray box, x -32..46) and farm.tscn (DD Phase 2 full
farm) from doc 04 coordinates.

    cd tools && uv run python ../game/world/build_farm.py

Edit coordinates here, regenerate, commit all three files. Both scenes use the same coordinates (doc 04 s9).
"""
import json
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


def box(parent, name, cx, cz, sx, sz, h, m, layer=L_WORLD, y0=0.0, groups=()):
    """Static box centred at x/z in parent space, footprint sx*sz, height h, base at y0."""
    body = node(name, "StaticBody3D", parent,
                f"transform = {tf(cx, y0 + h / 2, cz)}\ncollision_layer = {layer}\ncollision_mask = 0\n", groups)
    bm = sub("BoxMesh", f"size = Vector3({sx}, {h}, {sz})\n")
    bs = sub("BoxShape3D", f"size = Vector3({sx}, {h}, {sz})\n")
    node("Mesh", "MeshInstance3D", body, f'mesh = SubResource("{bm}")\nmaterial_override = SubResource("{MATS[m]}")\n')
    node("Shape", "CollisionShape3D", body, f'shape = SubResource("{bs}")\n')


def building(name, door_x, door_z, x0, x1, z0, z1, door_side, h, parent="Buildings", m="bldg"):
    """Walls as local boxes; node origin = door threshold (CONTRACTS section 4). 3 m door gap."""
    b = node(name, "Node3D", parent, f"transform = {tf(door_x, 0, door_z)}\n")
    t = 0.3
    lx0, lx1, lz0, lz1 = x0 - door_x, x1 - door_x, z0 - door_z, z1 - door_z
    for side, z in (("N", lz0), ("S", lz1)):
        if side == door_side:
            for nm, a, c in (("WallL", lx0, -1.5), ("WallR", 1.5, lx1)):
                box(b, f"{side}{nm}", (a + c) / 2, z, c - a, t, h, m)
        else:
            box(b, f"Wall{side}", (lx0 + lx1) / 2, z, lx1 - lx0, t, h, m)
    box(b, "WallW", lx0, (lz0 + lz1) / 2, t, lz1 - lz0, h, m)
    box(b, "WallE", lx1, (lz0 + lz1) / 2, t, lz1 - lz0, h, m)
    node("Door", "Marker3D", b, "", ["doors"], {"building": name.lower()})
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
         (16, -42, 57)]
CROWS = [(1, 30, 1), (2, 72, -12), (3, 13, 2), (4, -47, 38), (5, 60, 17), (6, -24, -27), (7, 46, 30), (8, -62, 0),
         (9, -23, 11)]
SCARECROWS = [(1, 30, -5.5), (2, 72, -5.5), (3, 20, 20), (4, -40, 20), (5, 60, -30), (6, 90, 20), (7, -8, -32)]
ESCAPES = [(1, 35, -40), (2, 95, -40), (3, 35, 50), (4, -60, 50)]
AUDIO = [("audio_listener", -26, 16), ("audio_10m", -16, 16), ("audio_30m", 4, 16), ("audio_60m", 34, 16)]
P1_IDS = {"trap": {1, 2, 3, 4, 5, 6, 15, 16, 19, 22}, "cover": {1, 2, 3, 9, 12, 14, 15}, "crow": {1, 3, 6, 7, 9},
          "scarecrow": {1, 3, 7}, "escape": {1, 3}}
ROUTE = [(0, 0), (0, 8), (15, 9), (40, 5), (41, -24), (58, -24), (66, -14), (82, -14), (105, -5)]  # doc 04 s6.1 R0..R8


def bear_slots() -> int:
    """pegboard_bear_slots from data/season.json (Game Designer's table), so the pegboard follows the data."""
    recs = json.loads((Path(__file__).parents[2] / "data" / "season.json").read_text(encoding="utf-8"))["records"]
    return int(next(r["value"] for r in recs if r["id"] == "pegboard_bear_slots"))


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


def generate(full: bool) -> str:
    global MATS
    subs.clear()
    nodes.clear()
    MATS = {
        "ground": mat("0.30, 0.34, 0.22, 1"), "corn": mat("0.35, 0.55, 0.15, 1"),
        "bldg": mat("0.45, 0.30, 0.22, 1"), "prop": mat("0.55, 0.55, 0.58, 1"),
        "house": mat("0.82, 0.78, 0.66, 1"), "plot": mat("0.35, 0.24, 0.14, 1"), "fence": mat("0.55, 0.45, 0.30, 1"),
    }
    node("Farm", "Node3D", None)
    for c in ("Ground", "CornBlockers", "Buildings", "Props", "Fields", "Pen", "Markers", "Bounds"):
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
                ("Strip4", -9, -3, 38, 55)]
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
        for i in range(n):
            node(f"Slot{i + 1}", "Marker3D", "Buildings/ToolShed/Pegboard",
                 f"transform = {tf((i - (n - 1) / 2) * 0.8, 0, 0)}\n", ["pegboard_slots"])
        # Barn staging (doc 01 "Recording lines", doc 04 s4): where a player records, and the lantern that blows out.
        node("RecordingSpot", "Marker3D", "Buildings/Barn", f"transform = {tf(0, 0, -15)}\n", ["recording_spots"])
        node("BarnLantern", "Marker3D", "Buildings/Barn", f"transform = {tf(-5, 1.6, -17)}\n", ["barn_lantern", "lightrig_spots"], {"radius_m": 6.0})  # world_look puts the real LightRig here (Q-054 item 4)

    # Props
    props = [("Generator", -11, -6, 2, 1, 1.2, "generator"), ("FuelDrum", -10, 27, 1, 1, 1.0, "fuel_drum"),
             ("Well", -25, 10, 2, 2, 1.0, "well")]
    if full:
        props += [("ShippingCrate", 72, 5, 2, 1, 1.0, "store_crate"), ("TownStand", 120, -5, 3, 2, 1.0, "sell_box")]
    else:
        props.append(("SellBox", 40, 20, 1.5, 1.5, 1.0, "sell_box"))
    for nm, x, z, sx, sz, h, grp in props:
        box("Props", nm, x, z, sx, sz, h, "prop", groups=[grp])
    if full:
        marker("Props", "FarmGate", 105, -5, "farm_gate")
        for nm, z in (("PostN", -8), ("PostS", -2)):  # 6 m gate, doc 04 s4
            box("Props", f"Gate{nm}", 105, z, 0.3, 0.3, 2.0, "fence")
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
    for nm, cx, cz, sx, sz in (("North", -24, -38, 12, .2), ("West", -30, -33, .2, 10), ("East", -18, -33, .2, 10),
                               ("SouthL", -27.5, -28, 5, .2), ("SouthR", -20.5, -28, 5, .2)):
        box("Pen", nm, cx, cz, sx, sz, 1.2, "fence")
    marker("Pen", "PenGate", -24, -28, "pen_gates")

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
            marker(M, f"crow_{i:02d}", x, z, "crow_perches")
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

    out = ["[gd_scene format=3]\n"]
    for k, v in subs.items():
        out.append(v.replace('id="@"', f'id="{k}"'))
    out += nodes
    return "\n".join(out)


if __name__ == "__main__":
    here = Path(__file__).parent
    for name, full in (("farm_phase1.tscn", False), ("farm.tscn", True)):
        (here / name).write_text(generate(full), encoding="utf-8", newline="\n")
        print(name, len(nodes), "nodes,", len(subs), "resources")

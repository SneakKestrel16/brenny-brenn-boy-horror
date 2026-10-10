"""Inspect downloaded models with Blender's own glTF importer (P4-40, D-151). Never executes anything inside a download.

  blender -b --factory-startup -P tools/blender/inspect_dl.py -- <out_dir> <file.glb> [...]

Prints object names, triangles, bounds, materials; renders <out_dir>/<name>.png (EEVEE, 3/4 view from the model front).
"""
import os
import sys

import bpy
from mathutils import Vector

out = sys.argv[sys.argv.index("--") + 1]
for path in sys.argv[sys.argv.index("--") + 2:]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    lo, hi, tris = Vector((1e9,) * 3), Vector((-1e9,) * 3), 0
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH":
            me = ob.data
            me.calc_loop_triangles()
            tris += len(me.loop_triangles)
            for v in me.vertices:
                w = ob.matrix_world @ v.co
                lo = Vector(min(lo[i], w[i]) for i in range(3))
                hi = Vector(max(hi[i], w[i]) for i in range(3))
    name = os.path.splitext(os.path.basename(path))[0]
    print(f"INSPECT {name}: {tris} tris size {tuple(round(x, 3) for x in hi - lo)} min {tuple(round(x, 3) for x in lo)}")
    for ob in bpy.context.scene.objects:
        print("  ", ob.type, ob.name, [m.name for m in getattr(ob.data, "materials", [])] if ob.type == "MESH" else "")
    sc = bpy.context.scene
    c = (lo + hi) / 2
    r = max((hi - lo).length, 0.1)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.location = c + Vector((0.9, 1.1, 0.5)) * r  # front is +Y in Blender
    d = c - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.rotation_euler = (0.9, 0.2, 2.5)
    sun.data.energy = 3
    sc.collection.objects.link(sun)
    sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.5, 0.55, 0.6)
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 480, 360
    sc.render.filepath = os.path.join(out, name + ".png")
    bpy.ops.render.render(write_still=True)

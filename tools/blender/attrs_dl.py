"""Print mesh attributes and first colour values of a glb (P4-40 debug). sh tools/blender/run.sh tools/blender/attrs_dl.py -- <file.glb>"""
import sys

import bpy

bpy.ops.import_scene.gltf(filepath=sys.argv[sys.argv.index("--") + 1])
for ob in bpy.context.scene.objects:
    if ob.type == "MESH":
        print("OBJ", ob.name, [(a.name, a.domain, a.data_type) for a in ob.data.attributes])
        for a in ob.data.color_attributes:
            print("  col", a.name, [tuple(round(x, 2) for x in d.color) for d in list(a.data)[:3]])

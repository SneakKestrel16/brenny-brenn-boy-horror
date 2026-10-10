"""Print loose-part islands of a downloaded glb (P4-40): bbox, tris, material names. Blender importer only.

  sh tools/blender/run.sh tools/blender/islands_dl.py -- <file.glb>
"""
import sys

import bmesh
import bpy

path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.import_scene.gltf(filepath=path)
for ob in bpy.context.scene.objects:
    if ob.type != "MESH" or not ob.data.polygons:
        continue
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.transform(ob.matrix_world)
    seen = set()
    isl = []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, grp = [f], []
        seen.add(f.index)
        while stack:
            c = stack.pop()
            grp.append(c)
            for e in c.edges:
                for n in e.link_faces:
                    if n.index not in seen:
                        seen.add(n.index)
                        stack.append(n)
        isl.append(grp)
    print(ob.name, len(isl), "islands")
    for i, g in enumerate(isl):
        vs = [v.co for f in g for v in f.verts]
        lo = [round(min(v[k] for v in vs), 2) for k in range(3)]
        hi = [round(max(v[k] for v in vs), 2) for k in range(3)]
        mats = sorted({ob.data.materials[f.material_index].name for f in g})
        print(f"  #{i} tris {sum(len(f.verts) - 2 for f in g)} lo {lo} hi {hi} {mats}")

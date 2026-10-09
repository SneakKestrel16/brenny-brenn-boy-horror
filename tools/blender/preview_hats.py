"""Line-up preview of the ten role hats (P4-36) on the lobby's placeholder farmer. Headless:

  "/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/blender/preview_hats.py

Imports assets/models/hat_<role>.glb, sets each at 1.74 m on a head sphere (r 0.16, centre 1.62) over a
capsule body, as LineUp._hat does, and renders front and 3/4 views to logs/qa/p4_36/ (gitignored).
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(__file__))
from build_phase4 import ROLE_IDS  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "logs", "qa", "p4_36")
SPACING = 0.9

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
hats = []
for i, role in enumerate(ROLE_IDS):
    x = (i - 4.5) * SPACING
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "models", "hat_%s.glb" % role))
    for ob in bpy.context.selected_objects:
        if ob.parent is None:
            ob.location = (x, 0, 1.74)
            hats.append(ob)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.16, location=(x, 0, 1.62))
    bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=1.2, location=(x, 0, 0.75))
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "VERTEX"
sc.render.resolution_x, sc.render.resolution_y = 2400, 640
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"
cam.rotation_euler = (math.radians(90), 0, math.pi)  # looks along -Y at the model fronts (+Y in Blender)
os.makedirs(OUT, exist_ok=True)
# the whole row, then the hats close up in two halves (the camera faces -Y, so +x is screen left)
for shot, x, z, scale in (("row", 0.0, 1.75, 9.2), ("close_a", 2.25, 1.85, 4.6), ("close_b", -2.25, 1.85, 4.6)):
    cam.location = (x, 12, z)
    cam.data.ortho_scale = scale
    sc.render.resolution_y = 640 if shot == "row" else 520
    for name, yaw in (("front", 0.0), ("three_quarter", math.radians(-40))):
        for h in hats:  # each farmer turns in place, so the row does not overlap
            h.rotation_mode = "XYZ"
            h.rotation_euler = (h.rotation_euler.x, 0, yaw)
        sc.render.filepath = os.path.join(OUT, "hats_%s_%s.png" % (shot, name))
        bpy.ops.render.render(write_still=True)
        print("WROTE", sc.render.filepath)

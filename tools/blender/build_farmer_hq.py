"""FARMER-HQ (CEO 2026-10-10): the shipped farmer and its ragdoll, B body. Supersedes `build_p5_12.build_farmer` and the
ragdoll in `build_p5_17` (both now delegate here).

  sh tools/blender/run.sh tools/blender/build_farmer_hq.py [-- char_farmer | char_farmer_ragdoll]

Geometry: `build_quality_sample4.py` (clothes, 3,600 tris), `build_quality_sample3.py` (pipeline, neck, body reshape, hair),
`build_quality_sample.py`/`build_quality_sample2.py` (loft helpers). Same 12 bones, 9 animations, material slots
(mat_flat_lit, mat_farmer_overalls, mat_farmer_sleeves) and names as the P5-12 farmer; front -Z, origin at the feet, 1.80 m.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_quality_sample as Q  # noqa: E402
import build_quality_sample2 as Q2  # noqa: E402
import build_quality_sample3 as Q3  # noqa: E402
import build_quality_sample4 as Q4  # noqa: E402


def _lie():
    """The ragdoll's one static pose (same as build_p5_17.ragdoll_lie): the dead body on its back."""
    pose = {"hips": (90, 0, 0, (0, -0.85, 0)), "spine": (-6, 0, 0), "head": (-12, 0, 6), "arm_l": (0, 0, 28), "arm_r": (14, 0, -34),
            "forearm_l": (14, 0, 0), "forearm_r": (30, 0, 0), "thigh_l": (-6, 0, 10), "thigh_r": (-10, 0, -14), "shin_l": (4, 0, 0), "shin_r": (8, 0, 0)}
    return 2, {b: {0: v, 2: v} for b, v in pose.items()}


def setup():
    Q.HAND["shipped"] = True
    Q2.BIB_DROP = 0.122  # bib top at the shipped farmer height


def build_farmer(name="char_farmer"):
    setup()
    Q3.make(name, Q4, body=True)


def build_ragdoll(name="char_farmer_ragdoll"):
    setup()
    Q3.make(name, Q4, body=True, anims={"lie": _lie})


if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not only or "char_farmer" in only:
        build_farmer()
    if not only or "char_farmer_ragdoll" in only:
        build_ragdoll()

"""P5-40: the ten role hats refitted to the B farmer's hair (QA fail 1).

  sh tools/blender/run.sh tools/blender/build_p5_40_hats.py [-- hat_<role> ...]

The P4-36 hats (build_phase4.py) were authored for a head of radius 0.106; the shipped hair is a shell of radii 0.158 x 0.15 centred
1.67 and 0.03 behind the head, with a fringe to radius 0.176 (the same numbers build_p5_06.R = 0.185 covers for the cosmetic hats).
Each hat is built as before, then warped around the band centre: inside radius WARP_IN every vertex moves out by SCALE and back by
SHIFT_Y; the effect fades to nothing at WARP_OUT, so brims, peaks and frills keep their outer size. Origin, bone and 1.74 m unchanged.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_phase4 as B  # noqa: E402

SCALE, SHIFT_Y, WARP_IN, WARP_OUT = 1.6, -0.01, 0.12, 0.27


def warp(ob):
    me = ob.data
    for v in me.vertices:
        r = math.hypot(v.co.x, v.co.y)
        w = 1.0 if r <= WARP_IN else max(0.0, (WARP_OUT - r) / (WARP_OUT - WARP_IN))
        v.co.x *= 1 + (SCALE - 1) * w
        v.co.y = v.co.y * (1 + (SCALE - 1) * w) + SHIFT_Y * w
    me.update()


def fitted(fn):
    def run():
        fn()
        for ob in B.Ctx.objs:
            if ob.type == "MESH":
                warp(ob)
    return run


if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for nm, fn, cls in B.MODELS:
        if nm.startswith("hat_") and (not only or nm in only):
            B.build(nm, fitted(fn), cls)

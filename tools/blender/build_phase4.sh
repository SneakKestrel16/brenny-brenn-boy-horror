#!/bin/sh
# Rebuild the Phase 4 models headless. Optional args: model names (see MODELS in build_phase4.py).
# Run from the repo root.
BLENDER="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
"$BLENDER" -b -P tools/blender/build_phase4.py -- "$@"

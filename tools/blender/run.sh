#!/bin/sh
# Run one Blender script headless: sh tools/blender/run.sh tools/blender/<script>.py [-- args...]
# One Blender process at a time (CEO resource cap).
BLENDER="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
script="$1"
shift
exec "$BLENDER" -b --factory-startup -P "$script" "$@"

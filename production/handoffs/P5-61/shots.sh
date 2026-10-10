#!/bin/bash
# usage: shots.sh prefix   -> production/handoffs/P5-61/<prefix>_<view>_<day|night>.png (run from repo root)
G=/c/Users/Ockey/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe
export APPDATA=$(cygpath -w /tmp/ap61)
mkdir -p /tmp/ap61
shot(){ timeout 120 "$G" --path . --audio-driver Dummy --resolution 1280x720 res://game/world/farm_view.tscn -- --free-mouse --view-cam=$3 --look-phase=$4 --view-frames=60 --view-shot=$(cygpath -w "$PWD/production/handoffs/P5-61/$1_$2_$4.png") >/dev/null 2>&1; }
for ph in ${PHASES:-day}; do
shot $1 fieldA 15,1.65,9,-37,0 $ph
shot $1 shed -11,1.65,33,0,0 $ph
shot $1 town 92,1.65,-10,-90,0 $ph
shot $1 pumpkin -42,1.65,38,0,0 $ph
shot $1 gate 96,1.65,-5,-90,0 $ph
done

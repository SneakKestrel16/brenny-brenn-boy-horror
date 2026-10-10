#!/bin/bash
# usage (from repo root): production/handoffs/P5-59/shots.sh before|after
export APPDATA=/tmp/p559/appdata
mkdir -p $APPDATA
O=production/handoffs/P5-59
for ph in "day:0.4" "dusk:0.6" "night:0.5"; do
 for cam in "yard:0,1.65,14,0,-5" "inbarn:0,1.65,-2,0,-5" "house:-45,1.65,14,0,-5" "corn:30,1.65,42,180,-5"; do
  n=${cam%%:*}; c=${cam#*:}
  bash production/handoffs/P5-59/g.sh --path . res://game/world/farm_view.tscn -- --free-mouse --look-phase=$ph --view-cam=$c --view-shot=$O/$1_${n}_${ph%%:*}.png --view-frames=40 > /tmp/p559/log_$1_${n}_${ph%%:*}.txt 2>&1
 done
done

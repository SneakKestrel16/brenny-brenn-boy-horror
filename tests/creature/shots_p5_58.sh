#!/bin/bash
# P5-58: windowed night shot of each creature body (shot_p5_58.gd) into production/handoffs/P5-58/. GODOT=<console exe>. Ports 56670-56673.
W="$(pwd -W)"; p=56670
mkdir -p production/handoffs/P5-58
for b in gaunt scarecrow boar husk; do
  APPDATA=/tmp/p558_s_$b timeout 120 "$GODOT" --audio-driver Dummy --path . --resolution 960x540 -s res://tests/creature/shot_p5_58.gd -- --host --lobby-start=1 --no-intro --port=$p --free-mouse --creature-body=$b "--out=$W/production/handoffs/P5-58/$b.png" 2>&1 | grep -E "shot:|ERROR"
  p=$((p+1)); rm -rf /tmp/p558_s_$b
done

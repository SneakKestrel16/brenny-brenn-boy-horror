#!/bin/bash
# P5-68: the jumpscare check (shot_p5_68.gd) for every creature body, day and night. GODOT=<console exe>.
# `--headless` runs the checks only; windowed runs also save production/handoffs/P5-68/<body>_<phase>.png. Ports $PORT (default 34680) to +7.
W="$(pwd -W)"; p=${PORT:-34680}; rc=0
mkdir -p production/handoffs/P5-68
for b in gaunt scarecrow boar husk; do
  for ph in day night; do
    APPDATA=/tmp/p568_$b$ph timeout 120 "$GODOT" $1 --audio-driver Dummy --path . --resolution 960x540 -s res://tests/creature/shot_p5_68.gd -- --host --lobby-start=1 --no-intro --port=$p --free-mouse --creature-body=$b --phase=$ph "--out=$W/production/handoffs/P5-68/${b}_$ph.png" > /tmp/p568_$b$ph.log 2>&1 || rc=1
    echo "== $b $ph"; grep -E "FAIL|PASS|shot:|SCRIPT ERROR|^ERROR" /tmp/p568_$b$ph.log
    p=$((p+1)); rm -rf /tmp/p568_$b$ph
  done
done
exit $rc

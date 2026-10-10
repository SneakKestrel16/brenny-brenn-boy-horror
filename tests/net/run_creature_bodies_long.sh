#!/bin/bash
# P5-58: soak, all four bodies in parallel (host + client each, own APPDATA), 240 s of --creature-test nights.
# Read logs/qa/p5_58_long_<body>/user_logs/*/peer_1.jsonl for hunt, trap, scare and dawn events. Ports 56660-56663.
p=56660
for b in gaunt scarecrow boar husk; do
  APPDATA=/tmp/p558_$b uv run tools/qa/multi.py -n 2 --headless --duration 240 --out logs/qa/p5_58_long_$b \
    --args "-- --host --port=$p --free-mouse --creature-test --log-creature --creature-body=$b" \
    --args "-- --join=127.0.0.1 --port=$p --free-mouse --log-creature" >/dev/null 2>&1 &
  p=$((p+1))
done
wait
rm -rf /tmp/p558_gaunt /tmp/p558_scarecrow /tmp/p558_boar /tmp/p558_husk

#!/bin/bash
# P5-58: loops the 4 creature bodies through host + client (see test_creature_bodies.gd). Usage: [STAGGER=s] tests/net/run_creature_bodies.sh [first_port]
# Isolated APPDATA so saves and logs stay out of the real profile. Exit 1 if any body fails.
# STAGGER (default 1 s) delays the client so a slow host is listening and in the session first (busy machine).
port=${1:-56650}; fail=0
export APPDATA="$(mktemp -d)"
for b in gaunt scarecrow boar husk; do
  out=$(uv run tools/qa/multi.py -n 2 --headless --duration $((75 + ${STAGGER:-1})) --stagger "${STAGGER:-1}" --out "logs/qa/p5_58_$b" \
    --args "-- --host --port=$port --free-mouse --creature-test --creature-body=$b" \
    --args "-s res://tests/net/test_creature_bodies.gd -- --join=127.0.0.1 --port=$port --free-mouse --expect-body=body_$b" 2>&1)
  # multi.py does not echo instance stdout: the verdict line is in the client's log
  echo "$out" | grep -E "ERROR"; grep -hE "test_creature_bodies:" "logs/qa/p5_58_$b/instance_2.log"
  grep -q "test_creature_bodies: PASS" "logs/qa/p5_58_$b/instance_2.log" || fail=1
  port=$((port+1))
done
rm -rf "$APPDATA"; exit $fail

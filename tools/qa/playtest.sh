#!/usr/bin/env bash
# One entry point for a doc 09 playtest. Run from the repo root in Git Bash.
#
#   tools/qa/playtest.sh check            pre-flight: clean smoke run, self-tests, review greps
#   tools/qa/playtest.sh local [2-4]      2 to 4 windows on this PC, first one hosts (default 2);
#                                         joiners speak a synthetic test voice, the host uses the mic
#   tools/qa/playtest.sh host             host a real session (shows the join code)
#   tools/qa/playtest.sh join <code|ip>   join a real session
#   tools/qa/playtest.sh logs [folder]    log measures: newest multi run, or this PC's user://logs
#
# Extra game flags go last, e.g. `local 2 --bots 1` or `host --net-sim-latency-ms 120`.
set -euo pipefail
cd "$(dirname "$0")/../.."

command -v uv >/dev/null || { echo "uv missing: winget install astral-sh.uv, then reopen Git Bash"; exit 1; }
godot() { uv run python -c "import sys; sys.path.insert(0, 'tools/qa'); import godot_qa; print(godot_qa.find_godot())"; }

cmd="${1:-}"; shift || true
case "$cmd" in
  check)
    uv run tools/qa/smoke.py --clean-import
    uv run tests/qa/test_harness.py
    uv run tests/qa/test_grep_rules.py
    uv run tools/qa/grep_rules.py
    echo "Pre-flight passed."
    ;;
  local)
    n=2
    if [[ "${1:-}" =~ ^[2-4]$ ]]; then n=$1; shift; fi
    # One PC has one mic: every window captures it, so your voice only comes back as a faint copy
    # under your own speech. Joiners talk with a synthetic test voice instead (doc 01 "Testing > Fake
    # input"), so the host window plays a voice you can hear. CONTRACTS section 11: kept outside the repo.
    wav="${TMPDIR:-/tmp}/bbb_test_voice.wav"
    [[ -f "$wav" ]] || uv run spikes/voice/make_test_wav.py "$wav" >/dev/null
    wav=$(cygpath -m "$wav")
    joins=()
    for ((i = 1; i < n; i++)); do joins+=(--args "-- --join=127.0.0.1 --voice-wav='$wav'"); done
    uv run tools/qa/multi.py -n "$n" --common "-- --phase1 $*" --args "-- --host" "${joins[@]}"
    ;;
  host)
    "$(godot)" --path . -- --phase1 --host "$@"
    ;;
  join)
    [[ -n "${1:-}" ]] || { echo "usage: $0 join <code|ip>"; exit 1; }
    code=$1; shift
    "$(godot)" --path . -- --phase1 --join="$code" "$@"
    ;;
  logs)
    if [[ -n "${1:-}" ]]; then
      uv run tools/qa/check_logs.py "$1"
    elif latest=$(ls -d logs/qa/multi_*/user_logs 2>/dev/null | sort | tail -1) && [[ -n "$latest" ]]; then
      uv run tools/qa/check_logs.py "$latest"
    else
      uv run tools/qa/check_logs.py --user-logs
    fi
    ;;
  *)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac

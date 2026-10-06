# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
"""Read CONTRACTS section 10 JSONL logs and report the doc 01 measures found in them.

    uv run tools/qa/check_logs.py logs/qa/multi_<timestamp>/user_logs
    uv run tools/qa/check_logs.py --user-logs            # the project's user://logs on this machine
    uv run tools/qa/check_logs.py <paths...> --json      # machine-readable report
    uv run tools/qa/check_logs.py <paths...> --strict    # exit 1 on any malformed record

Paths may be .jsonl files or folders (searched recursively). A session is the folder holding
peer_<id>.jsonl files. The host (peer 1) file is authoritative for gameplay events (CONTRACTS
section 10), so measures count host files only; a session without a peer_1 file falls back to all
its files, with a warning.

Measures (doc 01 "Testing" and "Build Plan"):
  - Lure success rate. "A lure worked: the target moved more than 10 m toward the source within
    8 seconds" (doc 01 Testing). Recomputed from moved_m and within_s, not trusted from `worked`;
    disagreements are listed. Phase 1 gate: at least 30% (doc 01 Build Plan, Phase 1 "Done when").
  - Trap race results. Doc 01 Testing: "log whether a solo, untainted player who pries at once
    survives". Reported overall and for that subset.
  - Spatial audio trials. Doc 01 Testing: place a voice and a whistle at 10, 30 and 60 m.
    Field names are provisional (sound, distance_m, correct) until doc 05 (PP-07) fixes them.
  - Also tallied: deaths, hold_completed by verb, inside_at_night seconds, money_changed count.
A report with no measures is still a pass: absent events are reported as "none logged".
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

PHASE_IDS = {"day", "dusk", "night", "dawn", "harvest_moon"}  # CONTRACTS section 8
HOST_PEER = 1  # CONTRACTS section 5
LURE_MIN_MOVE_M = 10.0  # doc 01 Testing: "more than 10 m toward the source"
LURE_MAX_SECONDS = 8.0  # doc 01 Testing: "within 8 seconds"
LURE_GATE = 0.30  # doc 01 Build Plan, Phase 1: "at least 30% of lures"
SPATIAL_DISTANCES_M = (10, 30, 60)  # doc 01 Testing: "at 10, 30 and 60 m"
SPATIAL_SOUNDS = ("voice", "whistle")  # doc 01 Testing
_PEER_FILE = re.compile(r"^peer_(\d+)\.jsonl$")


@dataclass
class Record:
    session: str
    file_peer: int | None
    t: float
    day: int
    phase: str
    peer: int
    event: str
    data: dict[str, Any]


@dataclass
class Loaded:
    records: list[Record] = field(default_factory=list)
    files: list[Path] = field(default_factory=list)
    problems: list[str] = field(default_factory=list)  # malformed records: fail under --strict
    warnings: list[str] = field(default_factory=list)


def _is_number(v: Any) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)


def find_files(paths: list[Path]) -> list[Path]:
    files: list[Path] = []
    for p in paths:
        if p.is_dir():
            files += sorted(p.rglob("*.jsonl"))
        elif p.is_file():
            files.append(p)
        else:
            raise SystemExit(f"No such file or folder: {p}")
    return files


def load(paths: list[Path]) -> Loaded:
    out = Loaded(files=find_files(paths))
    for f in out.files:
        m = _PEER_FILE.match(f.name)
        file_peer = int(m.group(1)) if m else None
        if file_peer is None:
            out.warnings.append(f"{f}: name is not peer_<id>.jsonl (CONTRACTS section 10)")
        session = f.parent.name
        for n, line in enumerate(f.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if not line.strip():
                continue
            where = f"{f}:{n}"
            try:
                obj = json.loads(line)
            except json.JSONDecodeError as e:
                out.problems.append(f"{where}: not JSON ({e.msg})")
                continue
            if not isinstance(obj, dict):
                out.problems.append(f"{where}: not a JSON object")
                continue
            bad = []
            if not _is_number(obj.get("t")):
                bad.append("t")
            if not isinstance(obj.get("day"), int) or isinstance(obj.get("day"), bool):
                bad.append("day")
            if not isinstance(obj.get("phase"), str):
                bad.append("phase")
            if not isinstance(obj.get("peer"), int) or isinstance(obj.get("peer"), bool):
                bad.append("peer")
            if not isinstance(obj.get("event"), str) or not obj.get("event"):
                bad.append("event")
            if not isinstance(obj.get("data", {}), dict):
                bad.append("data")
            if bad:
                out.problems.append(f"{where}: missing or wrong type: {', '.join(bad)}")
                continue
            if obj["phase"] not in PHASE_IDS:
                out.problems.append(f"{where}: phase {obj['phase']!r} is not a CONTRACTS section 8 phase ID")
            if file_peer is not None and obj["peer"] != file_peer:
                out.warnings.append(f"{where}: peer {obj['peer']} in file peer_{file_peer}.jsonl")
            out.records.append(Record(session, file_peer, float(obj["t"]), obj["day"], obj["phase"], obj["peer"], obj["event"], obj.get("data", {})))
    return out


def authoritative(loaded: Loaded) -> list[Record]:
    """Host-file records per session; all records for a session with no host file."""
    by_session: dict[str, list[Record]] = defaultdict(list)
    for r in loaded.records:
        by_session[r.session].append(r)
    chosen: list[Record] = []
    for session, recs in sorted(by_session.items()):
        host = [r for r in recs if r.file_peer == HOST_PEER]
        if host:
            chosen += host
        else:
            loaded.warnings.append(f"session {session}: no peer_{HOST_PEER}.jsonl (host file); measures use every peer's file and may double count")
            chosen += recs
    return chosen


def lure_measure(recs: list[Record], problems: list[str]) -> dict[str, Any]:
    results = [r for r in recs if r.event == "lure_result"]
    played = sum(1 for r in recs if r.event == "lure_played")
    worked = 0
    counted = 0
    mismatches: list[str] = []
    by_phase: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    for r in results:
        moved, within = r.data.get("moved_m"), r.data.get("within_s")
        if not (_is_number(moved) and _is_number(within)):
            problems.append(f"{r.session} t={r.t}: lure_result needs numeric moved_m and within_s")
            continue
        # Inference: within_s is the seconds the target took to cover moved_m. CONTRACTS section 10
        # shows within_s: 8 in its example; doc 05 (PP-07) settles whether it is the time or the window.
        ok = moved > LURE_MIN_MOVE_M and within <= LURE_MAX_SECONDS
        counted += 1
        worked += ok
        by_phase[r.phase][0] += ok
        by_phase[r.phase][1] += 1
        if "worked" in r.data and bool(r.data["worked"]) != ok:
            mismatches.append(f"{r.session} t={r.t}: logged worked={r.data['worked']}, doc 01 rule gives {ok} (moved_m={moved}, within_s={within})")
    rate = worked / counted if counted else None
    return {
        "lure_played": played,
        "lure_results": counted,
        "worked": worked,
        "rate": rate,
        "phase1_gate": None if rate is None else rate >= LURE_GATE,
        "by_phase": {k: {"worked": v[0], "total": v[1]} for k, v in sorted(by_phase.items())},
        "worked_mismatches": mismatches,
    }


def trap_race_measure(recs: list[Record], problems: list[str]) -> dict[str, Any]:
    keys = ("solo", "tainted", "pried_at_once", "survived")
    races = []
    for r in recs:
        if r.event != "trap_race_result":
            continue
        if not all(isinstance(r.data.get(k), bool) for k in keys):
            problems.append(f"{r.session} t={r.t}: trap_race_result needs booleans {', '.join(keys)}")
            continue
        races.append(r)
    key = [r for r in races if r.data["solo"] and not r.data["tainted"] and r.data["pried_at_once"]]
    spare = [r.data["seconds_spare"] for r in races if r.data["survived"] and _is_number(r.data.get("seconds_spare"))]
    return {
        "races": len(races),
        "survived": sum(r.data["survived"] for r in races),
        "solo_untainted_pried_at_once": {
            "races": len(key),
            "survived": sum(r.data["survived"] for r in key),
            "deaths": [f"{r.session} t={r.t} day {r.day} peer {r.data.get('player', r.peer)}" for r in key if not r.data["survived"]],
        },
        "seconds_spare_min": min(spare) if spare else None,
        "seconds_spare_mean": sum(spare) / len(spare) if spare else None,
    }


def spatial_measure(recs: list[Record], problems: list[str]) -> dict[str, Any]:
    cells: dict[tuple[str, float], list[int]] = defaultdict(lambda: [0, 0])
    trials = 0
    for r in recs:
        if r.event != "spatial_audio_trial":
            continue
        sound, dist, correct = r.data.get("sound"), r.data.get("distance_m"), r.data.get("correct")
        if not (isinstance(sound, str) and _is_number(dist) and isinstance(correct, bool)):
            problems.append(f"{r.session} t={r.t}: spatial_audio_trial needs sound (str), distance_m (number), correct (bool); has {sorted(r.data)}")
            continue
        trials += 1
        cells[(sound, dist)][0] += correct
        cells[(sound, dist)][1] += 1
    grid = {f"{s}@{d:g}m": {"correct": c, "trials": n} for (s, d), (c, n) in sorted(cells.items())}
    missing = [f"{s}@{d}m" for s in SPATIAL_SOUNDS for d in SPATIAL_DISTANCES_M if (s, float(d)) not in {(k[0], float(k[1])) for k in cells}]
    return {"trials": trials, "by_sound_distance": grid, "untested_doc01_cells": missing if trials else []}


def other_measures(recs: list[Record]) -> dict[str, Any]:
    holds: dict[str, list[float]] = defaultdict(list)
    inside: dict[int, float] = defaultdict(float)
    for r in recs:
        if r.event == "hold_completed" and isinstance(r.data.get("verb"), str) and _is_number(r.data.get("seconds")):
            holds[r.data["verb"]].append(float(r.data["seconds"]))
        if r.event == "inside_at_night" and _is_number(r.data.get("seconds")):
            inside[r.data.get("player", r.peer)] += float(r.data["seconds"])
    return {
        "deaths": sum(1 for r in recs if r.event == "death"),
        "traps_sprung": sum(1 for r in recs if r.event == "trap_sprung"),
        "money_changed_events": sum(1 for r in recs if r.event == "money_changed"),
        "hold_seconds_by_verb": {v: {"n": len(s), "mean": sum(s) / len(s)} for v, s in sorted(holds.items())},
        "inside_at_night_seconds_by_player": dict(sorted(inside.items())),
    }


def analyze(paths: list[Path]) -> dict[str, Any]:
    loaded = load(paths)
    recs = authoritative(loaded)
    problems = loaded.problems
    report = {
        "files": [str(f) for f in loaded.files],
        "sessions": sorted({r.session for r in loaded.records}),
        "records": len(loaded.records),
        "event_counts": dict(sorted(Counter(r.event for r in recs).items())),
        "lure": lure_measure(recs, problems),
        "trap_race": trap_race_measure(recs, problems),
        "spatial_audio": spatial_measure(recs, problems),
        "other": other_measures(recs),
        "problems": problems,
        "warnings": loaded.warnings,
    }
    return report


def _pct(x: float | None) -> str:
    return "n/a" if x is None else f"{x:.0%}"


def format_report(rep: dict[str, Any]) -> str:
    out: list[str] = []
    add = out.append
    add(f"Files: {len(rep['files'])}  sessions: {len(rep['sessions'])}  records: {rep['records']}")
    add("Events counted (host files): " + (", ".join(f"{k}={v}" for k, v in rep["event_counts"].items()) or "none"))
    lure = rep["lure"]
    add("")
    add("Lure success (doc 01 Testing: moved > 10 m toward the source within 8 s; Phase 1 gate >= 30%)")
    if lure["lure_results"]:
        gate = "PASS" if lure["phase1_gate"] else "BELOW GATE"
        add(f"  {lure['worked']}/{lure['lure_results']} worked = {_pct(lure['rate'])}  [{gate}]  (lure_played: {lure['lure_played']})")
        for phase, v in lure["by_phase"].items():
            add(f"  {phase}: {v['worked']}/{v['total']}")
        for m in lure["worked_mismatches"]:
            add(f"  MISMATCH {m}")
    else:
        add(f"  none logged (lure_played: {lure['lure_played']})")
    tr = rep["trap_race"]
    add("")
    add("Trap race (doc 01 Testing: does a solo, untainted player who pries at once survive?)")
    if tr["races"]:
        k = tr["solo_untainted_pried_at_once"]
        add(f"  all races: {tr['survived']}/{tr['races']} survived; seconds_spare min {tr['seconds_spare_min']}, mean {tr['seconds_spare_mean']}")
        add(f"  solo, untainted, pried at once: {k['survived']}/{k['races']} survived")
        for d in k["deaths"]:
            add(f"  DIED {d}")
    else:
        add("  none logged")
    sp = rep["spatial_audio"]
    add("")
    add("Spatial audio trials (doc 01 Testing: voice and whistle at 10, 30, 60 m)")
    if sp["trials"]:
        for cell, v in sp["by_sound_distance"].items():
            add(f"  {cell}: {v['correct']}/{v['trials']} placed correctly")
        if sp["untested_doc01_cells"]:
            add(f"  untested: {', '.join(sp['untested_doc01_cells'])}")
    else:
        add("  none logged")
    o = rep["other"]
    add("")
    add(f"Other: deaths {o['deaths']}, traps sprung {o['traps_sprung']}, money_changed {o['money_changed_events']}")
    for verb, v in o["hold_seconds_by_verb"].items():
        add(f"  hold {verb}: n={v['n']} mean {v['mean']:.2f} s")
    for player, s in o["inside_at_night_seconds_by_player"].items():
        add(f"  inside at night, player {player}: {s:.0f} s")
    if rep["problems"]:
        add("")
        add(f"Malformed records ({len(rep['problems'])}):")
        out += [f"  {p}" for p in rep["problems"]]
    if rep["warnings"]:
        add("")
        add(f"Warnings ({len(rep['warnings'])}):")
        out += [f"  {w}" for w in rep["warnings"]]
    return "\n".join(out)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paths", nargs="*", type=Path, help=".jsonl files or folders")
    parser.add_argument("--user-logs", action="store_true", help="also read the project's user://logs (asks Godot where it is)")
    parser.add_argument("--json", action="store_true", help="print the report as JSON")
    parser.add_argument("--strict", action="store_true", help="exit 1 if any record is malformed")
    args = parser.parse_args(argv)
    paths = list(args.paths)
    if args.user_logs:
        from godot_qa import find_godot, user_data_dir

        paths.append(user_data_dir(find_godot()) / "logs")
    if not paths:
        parser.error("give at least one path, or --user-logs")
    rep = analyze(paths)
    print(json.dumps(rep, indent=2) if args.json else format_report(rep))
    return 1 if args.strict and rep["problems"] else 0


if __name__ == "__main__":
    sys.exit(main())

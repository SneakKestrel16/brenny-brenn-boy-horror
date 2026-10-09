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
    Written by the tester's own client (doc 09 sections 5 and 7), so read from every peer's
    file, not the host's only. Also broken down by tester (file peer) for doc 09's 60% floor.
  - Also reported (P2-22): recorded vs generic lures played, trap sweeps, medical bills and
    dawn summaries, and `net_rtt` per peer pair.
  - Also tallied (Q-021): lure `window_s` values (a window other than 8 s is listed), spatial
    `angle_error_deg` per cell, and `close_call` results per victim with the worst `rtt_ms`.
  - Also tallied: deaths, hold_completed by verb, inside_at_night seconds, money_changed count,
    ghost_action by kind (P3-09), dawn_report_shown.
  - Phase 3 (P3-13): `tension` samples and gaps; scares per player against doc 01 "Rules" (one big
    a day, none within 2 minutes, none in the first third of the day; dev-forced ones left out);
    Taint causes and cures and "Shaken never Taints"; sabotage by day against data opens_day; lures
    in a dead player's voice (`owner_dead`) and as ghost static (`ghost`).
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
SPATIAL_DISTANCES_M = (10, 30, 60, 72)  # doc 01 Testing: "at 10, 30 and 60 m"; 72 m from doc 09 section 4
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
    windows: Counter = Counter()
    off_window: list[str] = []
    by_phase: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    # Doc 09 s3 "lure success by source" (P2-04): a recorded clip (kind "clip") against the generic
    # stranger and sound lures; read, not gated. Logs before P2-04 have no kind and count as generic.
    kind_of = {(r.session, r.data.get("lure_id")): r.data.get("kind") for r in recs if r.event == "lure_played"}
    by_source: dict[str, list[int]] = {"recorded": [0, 0], "generic": [0, 0]}
    played_by_source = Counter("recorded" if r.data.get("kind") == "clip" else "generic" for r in recs if r.event == "lure_played")
    for r in results:
        moved, within = r.data.get("moved_m"), r.data.get("within_s")
        if not (_is_number(moved) and _is_number(within)):
            problems.append(f"{r.session} t={r.t}: lure_result needs numeric moved_m and within_s")
            continue
        # within_s is the seconds the target took; window_s is the allowed window (D-018, CONTRACTS s10).
        ok = moved > LURE_MIN_MOVE_M and within <= LURE_MAX_SECONDS
        counted += 1
        # Q-021: tally window_s; a window other than doc 01's 8 s is listed (the rule above stays 8 s).
        window = r.data.get("window_s")
        windows[f"{window:g}" if _is_number(window) else "missing"] += 1
        if _is_number(window) and window != LURE_MAX_SECONDS:
            off_window.append(f"{r.session} t={r.t}: window_s={window:g}, doc 01 Testing gives {LURE_MAX_SECONDS:g}")
        worked += ok
        by_phase[r.phase][0] += ok
        by_phase[r.phase][1] += 1
        src = "recorded" if kind_of.get((r.session, r.data.get("lure_id"))) == "clip" else "generic"
        by_source[src][0] += ok
        by_source[src][1] += 1
        if "worked" in r.data and bool(r.data["worked"]) != ok:
            mismatches.append(f"{r.session} t={r.t}: logged worked={r.data['worked']}, doc 01 rule gives {ok} (moved_m={moved}, within_s={within})")
    rate = worked / counted if counted else None
    return {
        "lure_played": played,
        # P3-03 / P3-10: lures in a dead player's voice, and lures sent as ghost static (night only).
        "played_owner_dead": sum(1 for r in recs if r.event == "lure_played" and r.data.get("owner_dead")),
        "played_ghost": sum(1 for r in recs if r.event == "lure_played" and r.data.get("ghost")),
        "lure_results": counted,
        "worked": worked,
        "rate": rate,
        "phase1_gate": None if rate is None else rate >= LURE_GATE,
        "by_phase": {k: {"worked": v[0], "total": v[1]} for k, v in sorted(by_phase.items())},
        "by_source": {k: {"played": played_by_source[k], "worked": v[0], "total": v[1], "rate": v[0] / v[1] if v[1] else None} for k, v in sorted(by_source.items())},
        "worked_mismatches": mismatches,
        "window_s": dict(sorted(windows.items())),
        "window_not_doc01": off_window,
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
    per_tester: dict[tuple[str, int], dict[tuple[str, float], list[int]]] = defaultdict(lambda: defaultdict(lambda: [0, 0]))
    angles: dict[tuple[str, float], list[float]] = defaultdict(list)
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
        tester = per_tester[(r.session, r.file_peer if r.file_peer is not None else r.peer)][(sound, dist)]
        tester[0] += correct
        tester[1] += 1
        if _is_number(r.data.get("angle_error_deg")):  # doc 05 s18 extra field, Q-021
            angles[(sound, dist)].append(float(r.data["angle_error_deg"]))
    grid = {f"{s}@{d:g}m": {"correct": c, "trials": n} for (s, d), (c, n) in sorted(cells.items())}
    angle_error = {f"{s}@{d:g}m": {"n": len(a), "mean": sum(a) / len(a), "max": max(a)} for (s, d), a in sorted(angles.items())}
    by_tester = {
        f"{session}/peer_{peer}": {f"{s}@{d:g}m": {"correct": c, "trials": n} for (s, d), (c, n) in sorted(t.items())}
        for (session, peer), t in sorted(per_tester.items())
    }
    missing = [f"{s}@{d}m" for s in SPATIAL_SOUNDS for d in SPATIAL_DISTANCES_M if (s, float(d)) not in {(k[0], float(k[1])) for k in cells}]
    return {"trials": trials, "by_sound_distance": grid, "angle_error_deg": angle_error, "by_tester": by_tester, "untested_doc01_cells": missing if trials else []}


def close_call_measure(recs: list[Record]) -> dict[str, Any]:
    """Doc 05 s18 `close_call` (OPEN_ISSUES "Found by the studio" 1, a laggy player must be killable):
    results overall and per victim with the worst `rtt_ms`, since `miss_timeout` vs `miss_disagree` per
    player RTT settles it (Q-021)."""
    calls = [r for r in recs if r.event == "close_call"]
    victims: dict[str, dict[str, Any]] = {}
    for r in calls:
        v = victims.setdefault(f"{r.session}/{r.data.get('victim')}", {"results": Counter(), "rtt_ms_max": None})
        v["results"][str(r.data.get("result"))] += 1
        if _is_number(r.data.get("rtt_ms")):
            v["rtt_ms_max"] = r.data["rtt_ms"] if v["rtt_ms_max"] is None else max(v["rtt_ms_max"], r.data["rtt_ms"])
    for v in victims.values():
        v["results"] = dict(sorted(v["results"].items()))
    return {
        "calls": len(calls),
        "by_result": dict(sorted(Counter(str(r.data.get("result")) for r in calls).items())),
        "by_kind": dict(sorted(Counter(str(r.data.get("kind")) for r in calls).items())),
        "by_victim": dict(sorted(victims.items())),
    }


def trap_sweep_measure(recs: list[Record]) -> dict[str, Any]:
    """Doc 09 s3 trap sweeps: what the creature set and stole, what players did about it (P2-22)."""
    set_by_creature: Counter = Counter()
    by_player: Counter = Counter()
    for r in recs:
        if r.event == "trap_changed":
            if r.data.get("by") == "creature":
                set_by_creature[str(r.data.get("kind"))] += 1
            else:
                by_player[str(r.data.get("state"))] += 1
    verbs = Counter(r.data.get("verb") for r in recs if r.event == "hold_completed" and str(r.data.get("verb", "")).startswith(("disarm", "fill", "cut", "pick")))
    return {
        "set_by_creature": dict(sorted(set_by_creature.items())),
        "stolen": sum(1 for r in recs if r.event == "trap_stolen"),
        "sprung": sum(1 for r in recs if r.event == "trap_sprung"),
        "player_state_changes": dict(sorted(by_player.items())),
        "sweep_holds": dict(sorted(verbs.items())),
    }


def bill_measure(recs: list[Record]) -> dict[str, Any]:
    """Doc 09 s3 death, dawn, bills: the host's `medical_bill` and `dawn_summary` events (not `money_changed`)."""
    bills = [r for r in recs if r.event == "medical_bill"]
    return {
        "bills": [{"day": r.day, **{k: r.data.get(k) for k in ("players", "deaths", "bill", "paid", "to_final")}} for r in bills],
        "dawn_summaries": [{"day": r.day, **{k: r.data.get(k) for k in ("coins", "deaths", "medical_bill", "final_extra")}} for r in recs if r.event == "dawn_summary"],
        "respawns": sum(1 for r in recs if r.event == "respawn"),
    }


def tension_measure(recs: list[Record]) -> dict[str, Any]:
    """Doc 09 s3 "The AI Director": `tension` every 10 s (P3-04) with value, phase and profile."""
    ts = [r for r in recs if r.event == "tension" and _is_number(r.data.get("value"))]
    by_session: dict[str, list[float]] = defaultdict(list)
    for r in ts:
        by_session[r.session].append(r.t)
    gaps: list[float] = []
    for times in by_session.values():
        times.sort()
        gaps += [b - a for a, b in zip(times, times[1:])]
    vals = [float(r.data["value"]) for r in ts]
    return {
        "samples": len(ts),
        "value_min": min(vals) if vals else None,
        "value_max": max(vals) if vals else None,
        "gap_s_min": min(gaps) if gaps else None,
        "gap_s_max": max(gaps) if gaps else None,
        "phases": dict(sorted(Counter(str(r.data.get("phase")) for r in ts).items())),
        "profiles": dict(sorted(Counter(str(r.data.get("profile")) for r in ts).items())),
    }


SCARE_BIG_PER_DAY = 1  # doc 01 "Rules": at most one big scare per player per day (ai_director.json scare_rules)
SCARE_GAP_S = 120.0  # doc 01 "Rules": never two on the same player within 2 minutes
SCARE_FORCED_WINDOW_S = 5.0  # inference: a dev "scare" command then the 3 s build-up (doc 03 s13.1)


def scare_measure(recs: list[Record]) -> dict[str, Any]:
    """Doc 09 s3 "The AI Director, day arc, jumpscares": per player, at most one big scare a day, no two
    big or private scares within 120 s, none in the first third of the day. A scare that follows a dev
    console `scare` command within 5 s is counted as forced and left out of the rules."""
    devs = [(r.session, r.t) for r in recs if r.event == "dev_command" and str(r.data.get("line", "")).startswith("scare")]
    per_player: dict[str, dict[str, Any]] = {}
    violations: list[str] = []
    forced = 0
    last: dict[tuple[str, int], float] = {}
    big_day: Counter = Counter()
    scares = sorted((r for r in recs if r.event == "scare"), key=lambda r: (r.session, r.t))
    for r in scares:
        tgt = r.data.get("target")
        key = f"{r.session}/{tgt}" if isinstance(tgt, int) and tgt >= 0 else f"{r.session}/public"
        p = per_player.setdefault(key, {"scares": 0, "big": 0, "private": 0, "kinds": Counter(), "min_gap_s": None})
        p["scares"] += 1
        p["big"] += bool(r.data.get("big"))
        p["private"] += bool(r.data.get("private"))
        p["kinds"][str(r.data.get("kind"))] += 1
        if any(s == r.session and 0 <= r.t - t <= SCARE_FORCED_WINDOW_S for s, t in devs):
            forced += 1
            continue
        where = f"{r.session} t={r.t:.0f} day {r.day} target {tgt} {r.data.get('kind')}"
        if r.phase == "day" and r.data.get("third") == 1:
            violations.append(f"{where}: scare in the first third of the day")
        if not (isinstance(tgt, int) and tgt >= 0):
            continue  # the crow fake-out is public (target -1)
        if r.data.get("big") or r.data.get("private"):
            prev = last.get((r.session, tgt))
            if prev is not None:
                gap = r.t - prev
                p["min_gap_s"] = gap if p["min_gap_s"] is None else min(p["min_gap_s"], gap)
                if gap < SCARE_GAP_S:
                    violations.append(f"{where}: {gap:.0f} s after the last big or private scare (rule {SCARE_GAP_S:g} s)")
            last[(r.session, tgt)] = r.t
        if r.data.get("big"):
            big_day[(r.session, tgt, r.day)] += 1
            if big_day[(r.session, tgt, r.day)] > SCARE_BIG_PER_DAY:
                violations.append(f"{where}: big scare {big_day[(r.session, tgt, r.day)]} today (rule {SCARE_BIG_PER_DAY})")
    for p in per_player.values():
        p["kinds"] = dict(sorted(p["kinds"].items()))
    return {
        "scares": len(scares),
        "forced": forced,
        "dropped_by_why": dict(sorted(Counter(str(r.data.get("why")) for r in recs if r.event == "scare_dropped").items())),
        "per_player": dict(sorted(per_player.items())),
        "violations": violations,
    }


def taint_measure(recs: list[Record]) -> dict[str, Any]:
    """Doc 09 s3 "Taint and Shaken" (P3-07): causes and cures from `taint_changed`, `shaken` lengths, and
    doc 01's rule that Shaken never Taints: a Taint on the same player within 2 s after a `shaken` is
    listed (inference: the 2 s window is mine; a scare's Shaken and a Taint from it would share a frame)."""
    tc = [r for r in recs if r.event == "taint_changed"]
    sh = [r for r in recs if r.event == "shaken"]
    flagged = [
        f"{r.session} t={r.t:.0f} player {r.data.get('player')} tainted ({r.data.get('cause')}) {r.t - s.t:.1f} s after shaken"
        for r in tc if r.data.get("on")
        for s in sh if s.session == r.session and s.data.get("player") == r.data.get("player") and 0 <= r.t - s.t <= 2.0
    ]
    return {
        "tainted_by_cause": dict(sorted(Counter(str(r.data.get("cause")) for r in tc if r.data.get("on")).items())),
        "cured_by_cause": dict(sorted(Counter(str(r.data.get("cause")) for r in tc if not r.data.get("on")).items())),
        "shaken": len(sh),
        "shaken_seconds": sorted({r.data.get("seconds") for r in sh if _is_number(r.data.get("seconds"))}),
        "taint_after_shaken": flagged,
    }


SABOTAGE_JSON = Path(__file__).resolve().parents[2] / "data" / "sabotage.json"


def _sabotage_opens() -> dict[str, int]:
    """`opens_day` per sabotage kind from data/sabotage.json (P3-02); empty if the file is missing."""
    try:
        recs = json.loads(SABOTAGE_JSON.read_text(encoding="utf-8"))["records"]
    except (OSError, KeyError, json.JSONDecodeError):
        return {}
    return {r["id"]: r["opens_day"] for r in recs if isinstance(r.get("opens_day"), int)}


def sabotage_measure(recs: list[Record]) -> dict[str, Any]:
    """P3-06 sabotage: kinds placed by day, fixes by verb, the dawn trample, and any kind placed before its
    `opens_day` in data/sabotage.json."""
    opens = _sabotage_opens()
    placed = [r for r in recs if r.event == "disturbance_placed"]
    by_day: dict[int, Counter] = defaultdict(Counter)
    for r in placed:
        by_day[int(r.data.get("day", r.day))][str(r.data.get("kind"))] += 1
    return {
        "plans": sum(1 for r in recs if r.event == "sabotage_plan"),
        "placed_by_day": {d: dict(sorted(c.items())) for d, c in sorted(by_day.items())},
        "fixed_by_fix": dict(sorted(Counter(str(r.data.get("fix")) for r in recs if r.event == "disturbance_fixed").items())),
        "dawn_trample": [{"day": r.day, **{k: r.data.get(k) for k in ("want", "trampled", "farm_damage")}} for r in recs if r.event == "trample"],
        "before_opens_day": [
            f"{r.session} day {r.data.get('day', r.day)} {r.data.get('kind')} (opens day {opens[r.data.get('kind')]})" for r in placed
            if r.data.get("kind") in opens and int(r.data.get("day", r.day)) < opens[r.data.get("kind")]
        ],
    }


def rtt_measure(loaded_records: list[Record]) -> dict[str, Any]:
    """Doc 06 s13/s14 `net_rtt`: every peer writes its own, so read every file (P2-21)."""
    cells: dict[str, list[float]] = defaultdict(list)
    for r in loaded_records:
        if r.event == "net_rtt" and _is_number(r.data.get("rtt_ms")):
            cells[f"{r.session}/peer_{r.file_peer if r.file_peer is not None else r.peer}->{r.data.get('to')}"].append(float(r.data["rtt_ms"]))
    return {k: {"n": len(v), "min": min(v), "max": max(v), "mean": sum(v) / len(v)} for k, v in sorted(cells.items())}


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
        # Doc 09 s13 (P3-09, P3-10): ghost powers used, by kind (flicker, crow, rustle, caw, static_voice).
        "dawn_reports_shown": sum(1 for r in recs if r.event == "dawn_report_shown"),
        "ghost_actions_by_kind": dict(sorted(Counter(str(r.data.get("kind")) for r in recs if r.event == "ghost_action").items())),
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
        # Clients write their own trials (doc 09 section 7), so every file counts here.
        "spatial_audio": spatial_measure([r for r in loaded.records if r.event == "spatial_audio_trial"], problems),
        "close_calls": close_call_measure(recs),
        "trap_sweeps": trap_sweep_measure(recs),
        "bills": bill_measure(recs),
        "net_rtt": rtt_measure([r for r in loaded.records if r.event == "net_rtt"]),
        "other": other_measures(recs),
        "tension": tension_measure(recs),
        "scares": scare_measure(recs),
        "taint": taint_measure(recs),
        "sabotage": sabotage_measure(recs),
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
        for src, v in lure["by_source"].items():
            add(f"  {src} lures: played {v['played']}, results {v['worked']}/{v['total']} = {_pct(v['rate'])}  (doc 09 s3, read not gated)")
        for m in lure["worked_mismatches"]:
            add(f"  MISMATCH {m}")
        add("  window_s: " + ", ".join(f"{k}={v}" for k, v in lure["window_s"].items()))
        out += [f"  WINDOW {w}" for w in lure["window_not_doc01"]]
    else:
        add(f"  none logged (lure_played: {lure['lure_played']})")
    add(f"  in a dead player's voice: {lure['played_owner_dead']}; as ghost static: {lure['played_ghost']}")
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
    add("Spatial audio trials (doc 01 Testing: voice and whistle at 10, 30, 60, 72 m)")
    if sp["trials"]:
        for cell, v in sp["by_sound_distance"].items():
            a = sp["angle_error_deg"].get(cell)
            add(f"  {cell}: {v['correct']}/{v['trials']} placed correctly" + (f"; angle error mean {a['mean']:.1f}, max {a['max']:.1f} deg" if a else ""))
        if sp["untested_doc01_cells"]:
            add(f"  untested: {', '.join(sp['untested_doc01_cells'])}")
    else:
        add("  none logged")
    cc = rep["close_calls"]
    add("")
    add("Close calls (doc 05 s18 close_call; OPEN_ISSUES studio 1: a laggy player must be killable)")
    if cc["calls"]:
        add(f"  {cc['calls']} calls; results {cc['by_result']}; kinds {cc['by_kind']}")
        for who, v in cc["by_victim"].items():
            add(f"  {who}: {v['results']}, worst rtt {v['rtt_ms_max']} ms")
    else:
        add("  none logged")
    ts = rep["trap_sweeps"]
    add("")
    add("Trap sweeps (doc 09 s3)")
    add(f"  creature set {ts['set_by_creature'] or 'none'}, stolen {ts['stolen']}, sprung {ts['sprung']}")
    add(f"  player state changes {ts['player_state_changes'] or 'none'}, sweep holds {ts['sweep_holds'] or 'none'}")
    b = rep["bills"]
    add("")
    add("Death, dawn, bills (doc 09 s3: medical_bill, dawn_summary)")
    if b["bills"] or b["dawn_summaries"]:
        for x in b["bills"]:
            add(f"  day {x['day']}: {x['deaths']} death(s), {x['players']} players, bill {x['bill']}, paid {x['paid']}, to final {x['to_final']}")
        for x in b["dawn_summaries"]:
            add(f"  dawn day {x['day']}: coins {x['coins']}, bill {x['medical_bill']}, final_extra {x['final_extra']}")
        add(f"  respawns {b['respawns']}")
    else:
        add("  none logged")
    add("")
    add("Network round trip (doc 06 s13, net_rtt)")
    for k, v in rep["net_rtt"].items():
        add(f"  {k}: n={v['n']} min {v['min']:.0f} max {v['max']:.0f} mean {v['mean']:.1f} ms")
    if not rep["net_rtt"]:
        add("  none logged")
    o = rep["other"]
    add("")
    add(f"Other: deaths {o['deaths']}, traps sprung {o['traps_sprung']}, money_changed {o['money_changed_events']} (the game logs bills as medical_bill)")
    for verb, v in o["hold_seconds_by_verb"].items():
        add(f"  hold {verb}: n={v['n']} mean {v['mean']:.2f} s")
    for player, s in o["inside_at_night_seconds_by_player"].items():
        add(f"  inside at night, player {player}: {s:.0f} s")
    if o["ghost_actions_by_kind"]:
        add("  ghost actions: " + ", ".join(f"{k}={v}" for k, v in o["ghost_actions_by_kind"].items()))
    add(f"  dawn reports shown: {o['dawn_reports_shown']}")
    te = rep["tension"]
    add("")
    add("AI Director tension (doc 09 s3: a `tension` line every 10 s)")
    if te["samples"]:
        add(f"  {te['samples']} samples, value {te['value_min']}..{te['value_max']}, gap {te['gap_s_min']:.1f}..{te['gap_s_max']:.1f} s" if te["gap_s_min"] is not None else f"  {te['samples']} samples")
        add(f"  phases {te['phases']}; profiles {te['profiles']}")
    else:
        add("  none logged")
    sc = rep["scares"]
    add("")
    add(f"Scares (doc 01 Rules: <= {SCARE_BIG_PER_DAY} big per player per day, none within {SCARE_GAP_S:g} s, none in day third 1)")
    add(f"  {sc['scares']} scares ({sc['forced']} forced from the dev console); dropped {sc['dropped_by_why'] or 'none'}")
    for who, v in sc["per_player"].items():
        gap = "" if v["min_gap_s"] is None else f", closest {v['min_gap_s']:.0f} s"
        add(f"  {who}: {v['scares']} ({v['big']} big, {v['private']} private{gap}) {v['kinds']}")
    add("  rules: " + ("PASS" if not sc["violations"] else f"{len(sc['violations'])} VIOLATION(S)"))
    out += [f"  VIOLATION {v}" for v in sc["violations"]]
    tn = rep["taint"]
    add("")
    add("Taint and Shaken (doc 09 s3: cause and cure; Shaken never Taints)")
    add(f"  tainted by {tn['tainted_by_cause'] or 'none'}; cured by {tn['cured_by_cause'] or 'none'}")
    add(f"  shaken {tn['shaken']} (seconds {tn['shaken_seconds']}); Taint right after Shaken: " + ("none" if not tn["taint_after_shaken"] else str(len(tn["taint_after_shaken"]))))
    out += [f"  FLAG {f}" for f in tn["taint_after_shaken"]]
    sb = rep["sabotage"]
    add("")
    add("Sabotage (P3-06)")
    add(f"  plans {sb['plans']}; placed by day {sb['placed_by_day'] or 'none'}; fixed by {sb['fixed_by_fix'] or 'none'}")
    for x in sb["dawn_trample"]:
        add(f"  dawn trample day {x['day']}: want {x['want']}, trampled {x['trampled']}, farm damage {x['farm_damage']}")
    out += [f"  BEFORE OPENS_DAY {v}" for v in sb["before_opens_day"]]
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

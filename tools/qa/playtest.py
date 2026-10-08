# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
"""Run a DD phase playtest session the way doc 09 sections 2, 3 and 11 describe it.

    uv run tools/qa/playtest.py new --session 1 --networks different --fresh B
    uv run tools/qa/playtest.py tally <session folder>
    uv run tools/qa/playtest.py collect <session folder> [friend's logs zip or folder ...]
    uv run tools/qa/playtest.py report <session folder> [<session folder> ...]

`new` makes logs/qa/playtest_p<phase>_s<n>_<timestamp>/ with session.json (the facts the gate
needs) and notes.md (the observer's sheet, from tools/qa/playtest/session_notes.md). `tally` is
the silent observer's counter: one letter and Enter per scream, laugh or bored stretch, timed
against the game's `t`. `collect` copies this machine's section 10 logs written since `new`, plus
the other players' logs, into the session folder and runs check_logs.py on them. `report` reads
one or more session folders and prints the doc 09 section 3 pass/fail table for the phase.

Only DD Phase 1 has gates here; later phases print their measures with no gate (doc 09 section 3
still applies by hand). Standard library only.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
import zipfile
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_logs  # noqa: E402
from godot_qa import QA_OUT_ROOT, REPO_ROOT  # noqa: E402

TEMPLATES = Path(__file__).resolve().parent / "playtest"
NETWORKS = ("different", "same", "one_machine")  # doc 09 s2: only "different" closes the "First" item
TALLY_KINDS = {"s": "scream", "l": "laugh", "b": "bored", "n": "note"}  # doc 01 "Testing"
# Doc 09 s2 and s3. Numbers marked placeholder there are placeholders here too.
MIN_SESSIONS = 2
PHASE_PLAYERS = {1: 2}  # Phase 1: 2 players; later phases 2 to 4
LURE_MIN_RESULTS = 20  # placeholder (doc 09 s3)
TRAP_MIN_SPARE_S = 2.0  # doc 03 trap_race_min_spare_s, placeholder
SPATIAL_POOLED = 0.80  # inference (doc 09 s5)
SPATIAL_PER_TESTER = 0.60  # inference (doc 09 s5)
SPATIAL_MIN_TESTERS = 2  # doc 09 s5


def _now() -> datetime:
    return datetime.now(timezone.utc)


def build_id() -> str:
    """Git commit of this checkout, with -dirty when it has local edits (doc 09 s2 "Build")."""
    try:
        out = subprocess.run(["git", "-C", str(REPO_ROOT), "describe", "--always", "--dirty"], capture_output=True, text=True, check=True)
        return out.stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def load_session(folder: Path) -> dict[str, Any]:
    meta = folder / "session.json"
    if not meta.is_file():
        raise SystemExit(f"{folder} has no session.json; make it with `playtest.py new`.")
    return json.loads(meta.read_text(encoding="utf-8"))


# --- new -------------------------------------------------------------------------------------


def cmd_new(a: argparse.Namespace) -> int:
    if a.smoke:
        smoke = subprocess.run([sys.executable, str(Path(__file__).with_name("smoke.py"))], check=False)
        if smoke.returncode != 0 and not a.force:
            print("Smoke run failed: doc 09 s2 needs a build whose smoke run passed. --force to go on anyway.", file=sys.stderr)
            return 1
    started = _now()
    folder = (a.out_root or QA_OUT_ROOT) / f"playtest_p{a.phase}_s{a.session}_{started:%Y%m%d_%H%M%S}"
    folder.mkdir(parents=True)
    testers = [t.strip() for t in a.testers.split(",") if t.strip()]
    fresh = [t.strip() for t in a.fresh.split(",") if t.strip()] if a.fresh else []
    unknown = [t for t in fresh if t not in testers]
    if unknown:
        raise SystemExit(f"--fresh names {unknown}, not in --testers {testers}")
    meta = {
        "phase": a.phase,
        "session": a.session,
        "created_at": started.isoformat(timespec="seconds"),
        "created_epoch": started.timestamp(),
        "build_id": a.build_id or build_id(),
        "networks": a.networks,
        "testers": testers,
        "fresh_testers": fresh,
        "smoke": "passed" if a.smoke and smoke.returncode == 0 else ("failed" if a.smoke else "not run"),
        "valid": True,  # set false by hand for a session that does not count (doc 09 s2 stop rule)
    }
    (folder / "session.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    notes = (TEMPLATES / "session_notes.md").read_text(encoding="utf-8")
    for key, value in {
        "PHASE": str(a.phase),
        "SESSION": str(a.session),
        "DATE": f"{started:%Y-%m-%d %H:%M} UTC",
        "BUILD_ID": meta["build_id"],
        "NETWORKS": a.networks,
        "TESTERS": ", ".join(testers),
        "FRESH": ", ".join(fresh) or "none",
        "SMOKE": meta["smoke"],
    }.items():
        notes = notes.replace("{{" + key + "}}", value)
    (folder / "notes.md").write_text(notes, encoding="utf-8")
    print(f"Session folder: {folder}")
    print("Next (doc 09 s2):")
    print("  1. Read tools/qa/playtest/checklist.md and give each tester tools/qa/playtest/tester_brief.md.")
    print(f"  2. Observer: uv run tools/qa/playtest.py tally {folder.relative_to(REPO_ROOT) if folder.is_relative_to(REPO_ROOT) else folder}")
    print("  3. Play. Debrief. Fill notes.md.")
    print("  4. collect, then report.")
    if a.networks != "different":
        print("Note: only --networks different closes the DD Phase 1 'First' item (doc 09 s2).")
    return 0


# --- tally -----------------------------------------------------------------------------------

TALLY_HELP = """Observer tally (doc 09 s2: silent during play). One letter, then Enter:
  g        game t = 0 now (press when the host's session starts, so times line up with the logs)
  s        scream        l   laugh        b   bored silence
  n TEXT   free note     u   undo last    ?   counts so far      q   quit
Add a tester after the letter to say who: "s A", "l B". Lines append to observer.jsonl."""


def _tally_counts(path: Path) -> dict[str, int]:
    counts: dict[str, int] = defaultdict(int)
    if path.is_file():
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                counts[json.loads(line)["kind"]] += 1
    return dict(counts)


def cmd_tally(a: argparse.Namespace, stdin=sys.stdin, clock=time.time) -> int:
    folder = a.folder
    load_session(folder)
    path = folder / "observer.jsonl"
    go: float | None = None
    if path.is_file():  # resuming: keep the earlier zero point
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip() and json.loads(line)["kind"] == "go":
                go = json.loads(line)["epoch"]
    print(TALLY_HELP)
    if go is not None:
        print(f"Resuming; game t = 0 was at {datetime.fromtimestamp(go, timezone.utc):%H:%M:%S} UTC.")
    for raw in stdin:
        line = raw.strip()
        if not line:
            continue
        key, _, rest = line.partition(" ")
        key = key.lower()
        if key == "q":
            break
        if key == "?":
            print(_tally_counts(path))
            continue
        if key == "u":
            lines = path.read_text(encoding="utf-8").splitlines() if path.is_file() else []
            if lines:
                path.write_text("".join(x + "\n" for x in lines[:-1]), encoding="utf-8")
                print(f"undid: {lines[-1]}")
            continue
        if key != "g" and key not in TALLY_KINDS:
            print("? unknown; " + TALLY_HELP.splitlines()[0])
            continue
        now = clock()
        if key == "g":
            go = now
        rec: dict[str, Any] = {
            "kind": "go" if key == "g" else TALLY_KINDS[key],
            "epoch": round(now, 2),
            "t": None if go is None else round(now - go, 1),  # seconds, same clock as the logs' t
        }
        if key == "n":
            rec["text"] = rest
        elif rest:
            rec["who"] = rest
        with path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(rec) + "\n")
        print(f"  {rec['kind']} t={rec['t']}")
    print(f"Counts: {_tally_counts(path)}")
    return 0


# --- collect ---------------------------------------------------------------------------------


def _session_files_from_dir(root: Path, since: float | None) -> list[tuple[str, str, Path]]:
    """(session_id, file name, source) for each peer_<id>.jsonl under root."""
    found = []
    for f in sorted(root.rglob("peer_*.jsonl")):
        if check_logs._PEER_FILE.match(f.name) and (since is None or f.stat().st_mtime >= since):
            found.append((f.parent.name, f.name, f))
    return found


def _safe_member(name: str) -> tuple[str, str] | None:
    """A zip member's (session_id, peer file), or None if it isn't one or tries to escape."""
    parts = PurePosixPath(name.replace("\\", "/")).parts
    if len(parts) < 2 or any(p in ("..", "") for p in parts) or name.startswith("/"):
        return None
    session, fname = parts[-2], parts[-1]
    if not check_logs._PEER_FILE.match(fname) or session in (".", "logs"):
        return None
    return session, fname


def _place(dest_root: Path, session: str, fname: str, data: bytes, origin: str, log: list[str]) -> None:
    target = dest_root / session / fname
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        old = target.stat().st_size
        if len(data) <= old:
            log.append(f"kept {session}/{fname} ({old} B); skipped a copy from {origin} ({len(data)} B)")
            return
        log.append(f"replaced {session}/{fname} ({old} B) with the longer copy from {origin} ({len(data)} B)")
    else:
        log.append(f"{session}/{fname} <- {origin}")
    target.write_bytes(data)


def collect(folder: Path, sources: list[Path], user_logs: Path | None, keep_all: bool = False) -> list[str]:
    meta = load_session(folder)
    dest = folder / "user_logs"
    log: list[str] = []
    local: set[str] = set()
    if user_logs is not None:
        if user_logs.is_dir():
            # Only logs written since `new`: older sessions on this machine are not this playtest.
            for session, fname, src in _session_files_from_dir(user_logs, meta["created_epoch"] - 60):
                _place(dest, session, fname, src.read_bytes(), str(src), log)
                local.add(session)
        else:
            log.append(f"no user://logs folder at {user_logs}")

    def take(session: str, fname: str, read, origin: str) -> None:
        # The host collects: a friend's older sessions are not this playtest (doc 05 s18 session_id).
        if local and session not in local and not keep_all:
            log.append(f"skipped {session}/{fname} from {origin}: not a session on this machine since `new` (--keep-all keeps it)")
            return
        _place(dest, session, fname, read(), origin, log)

    for src in sources:
        if src.is_dir():
            for session, fname, f in _session_files_from_dir(src, None):
                take(session, fname, f.read_bytes, str(f))
        elif zipfile.is_zipfile(src):
            with zipfile.ZipFile(src) as z:
                for info in z.infolist():
                    picked = _safe_member(info.filename)
                    if picked and not info.is_dir():
                        take(*picked, lambda info=info: z.read(info), f"{src.name}:{info.filename}")
        else:
            raise SystemExit(f"Not a folder or zip: {src}")
    if not dest.is_dir():
        log.append("no peer_<id>.jsonl files found")
        return log
    rep = check_logs.analyze([dest])
    (folder / "measures.json").write_text(json.dumps(rep, indent=2) + "\n", encoding="utf-8")
    (folder / "measures.txt").write_text(check_logs.format_report(rep) + "\n", encoding="utf-8")
    return log


def cmd_collect(a: argparse.Namespace) -> int:
    user_logs: Path | None = None
    if a.user_logs_dir:
        user_logs = a.user_logs_dir
    elif not a.no_user_logs:
        from godot_qa import find_godot, user_data_dir

        user_logs = user_data_dir(find_godot(a.godot)) / "logs"
    for line in collect(a.folder, a.sources, user_logs, a.keep_all):
        print(line)
    txt = a.folder / "measures.txt"
    if txt.is_file():
        print()
        print(txt.read_text(encoding="utf-8"))
    return 0


# --- report ----------------------------------------------------------------------------------


def _session_facts(folder: Path) -> dict[str, Any]:
    meta = load_session(folder)
    logs = folder / "user_logs"
    loaded = check_logs.load([logs]) if logs.is_dir() else check_logs.Loaded()
    game_sessions: dict[str, set[int]] = defaultdict(set)
    players: dict[str, set[int]] = defaultdict(set)
    for r in loaded.records:
        if r.file_peer is not None:
            game_sessions[r.session].add(r.file_peer)
        if r.event == "session_start" and isinstance(r.data.get("players"), list):
            players[r.session].update(p for p in r.data["players"] if isinstance(p, int))
    for sid, peers in game_sessions.items():
        players[sid] |= peers
    tally = _tally_counts(folder / "observer.jsonl")
    return {
        "folder": folder,
        "meta": meta,
        "game_sessions": sorted(game_sessions),
        "has_host_file": bool(game_sessions) and all(check_logs.HOST_PEER in p for p in game_sessions.values()),
        "players": max((len(p) for p in players.values()), default=0),
        "tally": tally,
    }


def phase1_rows(facts: list[dict[str, Any]], rep: dict[str, Any]) -> list[tuple[str, str, str]]:
    """(item, PASS / FAIL / MANUAL / NO DATA, detail) per doc 09 s2 and s3 row."""
    rows: list[tuple[str, str, str]] = []
    need_players = PHASE_PLAYERS[1]
    valid = [f for f in facts if f["meta"].get("valid", True) and f["has_host_file"] and f["players"] >= need_players]
    for f in facts:
        why = []
        if not f["meta"].get("valid", True):
            why.append("marked invalid in session.json")
        if not f["has_host_file"]:
            why.append("no host file (peer_1.jsonl)")
        if f["players"] < need_players:
            why.append(f"{f['players']} players, needs {need_players}")
        rows.append((f"Session {f['meta']['session']} counts", "FAIL" if why else "PASS", "; ".join(why) or f"build {f['meta']['build_id']}, {f['players']} players"))
    rows.append(("At least 2 valid sessions", "PASS" if len(valid) >= MIN_SESSIONS else "FAIL", f"{len(valid)} valid"))
    fresh = sorted({t for f in valid for t in f["meta"].get("fresh_testers", [])})
    rows.append(("A fresh tester (has not read doc 01)", "PASS" if fresh else "FAIL", ", ".join(fresh) or "none recorded"))
    different = [f for f in valid if f["meta"].get("networks") == "different"]
    rows.append(("First: voice on different home networks", "MANUAL" if different else "FAIL",
                 f"{len(different)} session(s) on different networks; confirm in notes.md that both heard each other by join code" if different else "no valid session with --networks different"))
    for item in ("Day feels safe", "Night feels tense", "Stalk named by sound alone"):
        rows.append((item, "MANUAL", "debrief and observer notes (notes.md)"))

    lure = rep["lure"]
    if lure["lure_results"] == 0:
        rows.append(("Lures: at least 30% walk toward", "NO DATA", "no lure_result logged"))
    else:
        ok = lure["lure_results"] >= LURE_MIN_RESULTS and lure["rate"] >= check_logs.LURE_GATE
        rows.append(("Lures: at least 30% walk toward", "PASS" if ok else "FAIL",
                     f"{lure['worked']}/{lure['lure_results']} = {lure['rate']:.0%} (needs >= 30% over >= {LURE_MIN_RESULTS} results)"))

    key = rep["trap_race"]["solo_untainted_pried_at_once"]
    if key["races"] == 0:
        rows.append(("Trap race: solo, untainted, pried at once survives", "NO DATA", "no such trap_race_result"))
    else:
        spare = rep["trap_race"]["seconds_spare_min"]
        ok = key["survived"] == key["races"]
        rows.append(("Trap race: solo, untainted, pried at once survives", "PASS" if ok else "FAIL",
                     f"{key['survived']}/{key['races']} survived" + "".join(f"; died {d}" for d in key["deaths"])))
        rows.append(("Trap race: min seconds_spare >= 2.0 at a normal trap", "MANUAL",
                     f"min over all survivors {spare}; normal vs deep is not in the log, read trap_id (doc 03 s7.2)"))

    sp = rep["spatial_audio"]
    if sp["trials"] == 0:
        rows.append(("Spatial audio: 6 cells", "NO DATA", "no spatial_audio_trial logged"))
    else:
        cells = [f"{s}@{d}m" for s in check_logs.SPATIAL_SOUNDS for d in check_logs.SPATIAL_DISTANCES_M]
        fails = []
        for c in cells:
            v = sp["by_sound_distance"].get(c)
            if not v:
                fails.append(f"{c} untested")
            elif v["correct"] / v["trials"] < SPATIAL_POOLED:
                fails.append(f"{c} {v['correct']}/{v['trials']}")
        low = []
        for tester, grid in sp["by_tester"].items():
            for c, v in grid.items():
                if v["correct"] / v["trials"] < SPATIAL_PER_TESTER:
                    low.append(f"{tester} {c} {v['correct']}/{v['trials']}")
        testers = len(sp["by_tester"])
        if testers < SPATIAL_MIN_TESTERS:
            fails.append(f"{testers} tester(s), needs {SPATIAL_MIN_TESTERS}")
        rows.append(("Spatial audio: every cell >= 80% pooled", "FAIL" if fails else "PASS", "; ".join(fails) or f"{sp['trials']} trials, {testers} testers"))
        rows.append(("Spatial audio: no tester below 60% in a cell", "FAIL" if low else "PASS", "; ".join(low) or "all at or above 60%"))

    holds = rep["other"]["hold_seconds_by_verb"]
    missing = [v for v in ("plant", "water", "sell") if v not in holds]
    rows.append(("Turnips: plant, water, sell logged", "FAIL" if missing else "MANUAL",
                 f"missing {', '.join(missing)}" if missing else "compare means with data/labor.json (within 15%): " + ", ".join(f"{v} {holds[v]['mean']:.2f} s" for v in ("plant", "water", "sell"))))
    counts = rep["event_counts"]
    gen = counts.get("generator", 0)
    rows.append(("Generator run, no speed_violation", "FAIL" if counts.get("speed_violation") else ("PASS" if gen else "NO DATA"),
                 f"generator events {gen}, speed_violation {counts.get('speed_violation', 0)}"))
    rows.append(("2 instances, authority split", "MANUAL", "doc 09 s7 host-only grep on each session's client files"))
    return rows


def report(folders: list[Path]) -> str:
    facts = [_session_facts(f) for f in folders]
    phases = {f["meta"]["phase"] for f in facts}
    if len(phases) > 1:
        raise SystemExit(f"Sessions from different phases: {sorted(phases)}")
    phase = phases.pop()
    log_dirs = [f["folder"] / "user_logs" for f in facts if (f["folder"] / "user_logs").is_dir()]
    rep = check_logs.analyze(log_dirs) if log_dirs else check_logs.analyze([])
    out = [f"# DD Phase {phase} playtest report", "", f"Sessions: {', '.join(str(f['folder'].name) for f in facts)}", ""]
    out.append("| Session | Build | Networks | Testers (fresh) | Screams | Laughs | Bored |")
    out.append("|---|---|---|---|---|---|---|")
    for f in facts:
        m, t = f["meta"], f["tally"]
        out.append(f"| {m['session']} | {m['build_id']} | {m['networks']} | {', '.join(m['testers'])} ({', '.join(m.get('fresh_testers', [])) or 'none'}) "
                   f"| {t.get('scream', 0)} | {t.get('laugh', 0)} | {t.get('bored', 0)} |")
    out.append("")
    if phase == 1:
        rows = phase1_rows(facts, rep)
        out += ["| Item (doc 09 s3) | Result | Detail |", "|---|---|---|"]
        out += [f"| {i} | {r} | {d} |" for i, r, d in rows]
        fails = [i for i, r, _ in rows if r in ("FAIL", "NO DATA")]
        manual = [i for i, r, _ in rows if r == "MANUAL"]
        out += ["", f"Automatic: {'FAIL' if fails else 'PASS'} ({len(fails)} failing or without data). "
                f"{len(manual)} rows need the notes; the phase passes only when every row holds (doc 09 s3)."]
    else:
        out.append(f"No automatic gate for DD Phase {phase}; apply doc 09 section 3 by hand.")
    out += ["", "## Measures (check_logs.py, all sessions pooled)", "", "```", check_logs.format_report(rep), "```", ""]
    return "\n".join(out)


def cmd_report(a: argparse.Namespace) -> int:
    text = report(a.folders)
    out = a.out or a.folders[-1] / "report.md"
    out.write_text(text, encoding="utf-8")
    print(text)
    print(f"Written to {out}")
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    n = sub.add_parser("new", help="start a session folder with session.json and notes.md")
    n.add_argument("--phase", type=int, default=1, choices=(1, 2, 3, 4))
    n.add_argument("--session", type=int, required=True, help="session number within the phase (1, 2, ...)")
    n.add_argument("--networks", choices=NETWORKS, required=True, help="different = two home networks over UPnP and a join code")
    n.add_argument("--testers", default="A,B", help="tester labels, never real names (doc 09 s2); default A,B")
    n.add_argument("--fresh", default="", help="labels of testers who have not read doc 01, e.g. B")
    n.add_argument("--build-id", help="override the git build id, e.g. for an exported zip")
    n.add_argument("--smoke", action="store_true", help="run smoke.py first and refuse on a fail")
    n.add_argument("--force", action="store_true", help="go on after a failed smoke run (recorded in session.json)")
    n.add_argument("--out-root", type=Path, help=argparse.SUPPRESS)
    n.set_defaults(func=cmd_new)

    t = sub.add_parser("tally", help="observer's scream / laugh / bored counter")
    t.add_argument("folder", type=Path)
    t.set_defaults(func=cmd_tally)

    c = sub.add_parser("collect", help="gather every peer's logs into the session folder and check them")
    c.add_argument("folder", type=Path)
    c.add_argument("sources", nargs="*", type=Path, help="other players' logs: a zip from send_logs.bat or a folder")
    c.add_argument("--no-user-logs", action="store_true", help="skip this machine's user://logs")
    c.add_argument("--user-logs-dir", type=Path, help="read this folder instead of asking Godot for user://logs")
    c.add_argument("--keep-all", action="store_true", help="keep other players' sessions this machine has no log of")
    c.add_argument("--godot", help="Godot executable (else $GODOT, else CONTRACTS s1)")
    c.set_defaults(func=cmd_collect)

    r = sub.add_parser("report", help="doc 09 s3 pass/fail table over one or more sessions")
    r.add_argument("folders", nargs="+", type=Path)
    r.add_argument("--out", type=Path, help="default: report.md in the last session folder")
    r.set_defaults(func=cmd_report)

    a = ap.parse_args(argv)
    return a.func(a)


if __name__ == "__main__":
    sys.exit(main())

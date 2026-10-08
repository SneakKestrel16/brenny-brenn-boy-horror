# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
"""Start N (2 to 6) local Godot instances with per-instance arguments and collect their logs.

    uv run tools/qa/multi.py -n 2 --args "-- --host" --args "-- --join=127.0.0.1"
    uv run tools/qa/multi.py -n 4 --headless --frames 3600 --common "-- --bot"

Arguments are Godot command lines, split like a shell would. Engine flags go first; anything after
`--` reaches the game through OS.get_cmdline_user_args(). --common is given to every instance,
then the instance's own --args (the first --args is instance 1, which should be the host, peer 1).
Engine parts and game parts are merged, so --common "-- --x" plus --args "--headless -- --y" works.

Instances start in order, --stagger seconds apart (host first). The script waits until all exit,
or kills them after --duration seconds. Killing can lose unflushed log lines: prefer --frames or a
game-side quit.

Collected into logs/qa/multi_<timestamp>/ (or --out):
  instance_<i>.log          each instance's console output
  user_logs/<session_id>/peer_<id>.jsonl   CONTRACTS section 10 logs written during the run,
                            copied from the project's real user:// folder (asked from Godot)
  manifest.json             commands, exit codes, error lines, copied files
Exit code 1 if any instance printed an ERROR / SCRIPT ERROR line, crashed or exited non-zero.
Then run: uv run tools/qa/check_logs.py logs/qa/multi_<timestamp>/user_logs
"""

from __future__ import annotations

import argparse
import json
import re
import shlex
import shutil
import subprocess
import sys
import time
from pathlib import Path

from godot_qa import QA_OUT_ROOT, REPO_ROOT, find_godot, ignore_qa_logs, scan_errors, timestamp, user_data_dir

TILE_W, TILE_H = 640, 360  # 2x2 grid on a 1280x720-or-larger screen


def split_args(text: str) -> tuple[list[str], list[str]]:
    """Split a command-line string into (engine args, game args after `--`)."""
    parts = shlex.split(text, posix=True)
    if "--" in parts:
        i = parts.index("--")
        return parts[:i], parts[i + 1 :]
    return parts, []


def build_command(godot: str, index: int, common: str, own: str, headless: bool, frames: int | None, tile: bool, sound: bool = False) -> list[str]:
    engine: list[str] = []
    game: list[str] = []
    for text in (common, own):
        e, g = split_args(text)
        engine += e
        game += g
    cmd = [godot, "--path", str(REPO_ROOT)]
    if not sound:
        cmd += ["--audio-driver", "Dummy"]  # windowed test runs stay silent on the developer's headphones
    if headless:
        cmd.append("--headless")
    elif tile:
        x, y = ((index - 1) % 2) * TILE_W, ((index - 1) // 2) * TILE_H
        cmd += ["--windowed", "--resolution", f"{TILE_W}x{TILE_H}", "--position", f"{x},{y}"]
    if frames:
        cmd += ["--quit-after", str(frames)]
    cmd += engine
    game.append("--free-mouse")  # test windows never capture the developer's mouse
    cmd += ["--", *game]
    return cmd


def snapshot(logs_root: Path) -> dict[Path, tuple[float, int]]:
    if not logs_root.is_dir():
        return {}
    return {p: (p.stat().st_mtime, p.stat().st_size) for p in logs_root.rglob("*.jsonl")}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-n", "--instances", type=int, default=2, choices=(2, 3, 4, 5, 6), help="number of instances (2 to 6)")
    parser.add_argument("--args", action="append", default=[], metavar="ARGS", help="one instance's arguments; repeat in instance order")
    parser.add_argument("--common", default="", metavar="ARGS", help="arguments for every instance")
    parser.add_argument("--headless", action="store_true", help="no windows (bots, automated runs)")
    parser.add_argument("--sound", action="store_true", help="play audio; default is the Dummy driver, silent")
    parser.add_argument("--no-tile", action="store_true", help="don't arrange windows in a 2x2 grid")
    parser.add_argument("--frames", type=int, help="each instance quits after this many frames (--quit-after)")
    parser.add_argument("--duration", type=float, help="kill instances still running after this many seconds")
    parser.add_argument("--timeout", type=float, default=1800.0, help="hard limit in seconds if --duration is not set (default 1800)")
    parser.add_argument("--stagger", type=float, default=1.0, help="seconds between launches so the host is listening first (default 1)")
    parser.add_argument("--godot", help="Godot executable (default: $GODOT, then the CONTRACTS path)")
    parser.add_argument("--allow", action="append", default=[], metavar="REGEX", help="ignore error lines matching REGEX")
    parser.add_argument("--out", help="output folder (default logs/qa/multi_<timestamp>)")
    args = parser.parse_args(argv)

    if len(args.args) > args.instances:
        parser.error(f"{len(args.args)} --args given for {args.instances} instances")
    godot = str(find_godot(args.godot))
    allow = [re.compile(p) for p in args.allow]
    out_dir = Path(args.out).resolve() if args.out else QA_OUT_ROOT / f"multi_{timestamp()}"
    out_dir.mkdir(parents=True, exist_ok=True)
    ignore_qa_logs()

    logs_root = user_data_dir(Path(godot)) / "logs"
    before = snapshot(logs_root)
    print(f"Godot: {godot}\nuser://logs = {logs_root}\nOutput: {out_dir}")

    procs: list[tuple[int, list[str], subprocess.Popen[bytes], Path]] = []
    handles = []
    start = time.time()
    for i in range(1, args.instances + 1):
        own = args.args[i - 1] if i <= len(args.args) else ""
        cmd = build_command(godot, i, args.common, own, args.headless, args.frames, not args.no_tile, args.sound)
        log_path = out_dir / f"instance_{i}.log"
        handle = log_path.open("wb")
        handles.append(handle)
        print(f"[{i}] {subprocess.list2cmdline(cmd)}")
        procs.append((i, cmd, subprocess.Popen(cmd, stdout=handle, stderr=subprocess.STDOUT, cwd=REPO_ROOT), log_path))
        if i < args.instances:
            time.sleep(args.stagger)

    limit = args.duration if args.duration is not None else args.timeout
    killed: set[int] = set()
    while any(p.poll() is None for _, _, p, _ in procs):
        if time.time() - start > limit:
            for i, _, p, _ in procs:
                if p.poll() is None:
                    p.kill()
                    killed.add(i)
            if args.duration is None:
                print(f"Timeout after {limit:.0f} s: killed instance(s) {sorted(killed)}")
            break
        time.sleep(0.25)
    for _, _, p, _ in procs:
        p.wait()
    for handle in handles:
        handle.close()

    # Copy every section 10 log written or grown during the run.
    copied: list[str] = []
    for path, stat in snapshot(logs_root).items():
        if before.get(path) == stat:
            continue
        rel = path.relative_to(logs_root)
        dest = out_dir / "user_logs" / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)
        copied.append(rel.as_posix())

    all_ok = True
    manifest = {"started": time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(start)), "user_logs_root": str(logs_root), "instances": [], "copied_logs": sorted(copied)}
    for i, cmd, p, log_path in procs:
        errors = scan_errors(log_path.read_bytes().decode("utf-8", errors="replace"), allow)
        was_killed = i in killed
        # A kill by --duration is the expected end; a non-zero exit otherwise is a failure.
        ok = not errors and (was_killed and args.duration is not None or p.returncode == 0)
        all_ok = all_ok and ok
        status = "PASS" if ok else "FAIL"
        end = "killed" if was_killed else f"exit {p.returncode}"
        print(f"[{status}] instance {i}: {end}, {len(errors)} error line(s), log {log_path.name}")
        for line in errors:
            print(f"         {line}")
        manifest["instances"].append({"index": i, "command": cmd, "exit_code": p.returncode, "killed": was_killed, "errors": errors, "log": log_path.name})
    print(f"Collected {len(copied)} section 10 log file(s) into {out_dir / 'user_logs'}")
    for rel in sorted(copied):
        print(f"         {rel}")
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("MULTI PASS" if all_ok else "MULTI FAIL")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())

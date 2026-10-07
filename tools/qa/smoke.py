# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
"""Headless smoke run: import, parse check, timed run. Fails on any ERROR / SCRIPT ERROR line.

    uv run tools/qa/smoke.py                 # import + parse check + 120-frame run
    uv run tools/qa/smoke.py --frames 600    # longer run
    uv run tools/qa/smoke.py --clean-import  # delete .godot/ first (close the editor before)

--clean-import seeds .godot/extension_list.cfg with every addons/*/*.gdextension, as a fresh
checkout opened in the editor ends up with. Without it the first headless import segfaults while
registering TwoVoIP mid-scan (Q-008, Q-010). --no-seed-extensions reproduces that crash.

Steps (CONTRACTS section 1 headless checks, plus a parse check):
  1. import      "$GODOT" --headless --editor --quit --path .
  2. parse_check "$GODOT" --headless --path . res://tests/qa/parse_check.tscn
  3. run         "$GODOT" --headless --path . --quit-after <frames> [scene] [-- user args]
A step fails on: any ERROR / SCRIPT ERROR / crash line, a non-zero exit code, or a timeout.
Outputs go to logs/qa/smoke_<timestamp>/<step>.log. Exit code 0 = pass, 1 = fail.
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys

from godot_qa import QA_OUT_ROOT, REPO_ROOT, find_godot, run_godot, timestamp


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", help="Godot executable (default: $GODOT, then the CONTRACTS path)")
    parser.add_argument("--frames", type=int, default=120, help="frames for the timed run (default 120, CONTRACTS section 1)")
    parser.add_argument("--scene", help="run this scene instead of the main scene, e.g. res://game/world/farm.tscn")
    parser.add_argument("--timeout", type=float, default=300.0, help="seconds per step before it counts as hung (default 300)")
    parser.add_argument("--clean-import", action="store_true", help="delete .godot/ before importing (a pass after a fail with no edit: rerun with this)")
    parser.add_argument("--no-seed-extensions", action="store_true", help="with --clean-import: don't seed .godot/extension_list.cfg (reproduces the Q-008 first-import crash)")
    parser.add_argument("--skip-parse-check", action="store_true", help="skip step 2")
    parser.add_argument("--allow", action="append", default=[], metavar="REGEX", help="ignore error lines matching REGEX (repeatable; say why in the task handoff)")
    parser.add_argument("--out", help="output folder (default logs/qa/smoke_<timestamp>)")
    parser.add_argument("user_args", nargs="*", help="after `--`: passed to the game (OS.get_cmdline_user_args())")
    args = parser.parse_args(argv)

    godot = str(find_godot(args.godot))
    allow = [re.compile(p) for p in args.allow]
    out_dir = QA_OUT_ROOT / f"smoke_{timestamp()}" if not args.out else REPO_ROOT / args.out
    root = str(REPO_ROOT)

    if args.clean_import:
        cache = REPO_ROOT / ".godot"
        if cache.exists():
            print(f"Deleting {cache}")
            shutil.rmtree(cache)
        if not args.no_seed_extensions:
            extensions = sorted(p.relative_to(REPO_ROOT).as_posix() for p in (REPO_ROOT / "addons").glob("*/*.gdextension"))
            if extensions:
                cache.mkdir()
                lines = "".join(f"res://{e}\n" for e in extensions)
                (cache / "extension_list.cfg").write_bytes(lines.encode("utf-8"))
                print(f"Seeded .godot/extension_list.cfg: {', '.join(extensions)} (Q-010)")

    steps: list[tuple[str, list[str]]] = [("import", [godot, "--headless", "--editor", "--quit", "--path", root])]
    if not args.skip_parse_check:
        steps.append(("parse_check", [godot, "--headless", "--path", root, "res://tests/qa/parse_check.tscn"]))
    run_cmd = [godot, "--headless", "--path", root, "--quit-after", str(args.frames)]
    if args.scene:
        run_cmd.append(args.scene)
    if args.user_args:
        run_cmd += ["--", *args.user_args]
    steps.append(("run", run_cmd))

    print(f"Godot: {godot}\nOutput: {out_dir}")
    all_ok = True
    for name, cmd in steps:
        result = run_godot(name, cmd, out_dir / f"{name}.log", args.timeout, allow)
        if name == "parse_check" and "QA_PARSE_CHECK" not in result.log_path.read_text(encoding="utf-8", errors="replace"):
            result.errors.append("parse_check.gd printed no QA_PARSE_CHECK summary (did it run?)")
        status = "PASS" if result.ok else "FAIL"
        detail = "timed out" if result.timed_out else f"exit {result.exit_code}"
        print(f"[{status}] {name:<12} {detail}, {len(result.errors)} error line(s), {result.seconds:.1f} s")
        for line in result.errors:
            print(f"         {line}")
        all_ok = all_ok and result.ok
        if name == "import" and not result.ok:
            print("Import failed; later steps would run against a stale import. Stopping.")
            break

    print("SMOKE PASS" if all_ok else "SMOKE FAIL")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())

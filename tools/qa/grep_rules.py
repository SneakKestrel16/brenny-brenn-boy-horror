# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
"""Review greps that need no Godot (docs/09_playtest_plan.md section 9).

    uv run tools/qa/grep_rules.py                 # check game/ and the tracked files; exit 1 on a violation
    uv run tools/qa/grep_rules.py --root <repo>   # another checkout (the self-test uses a temp one)

Rules:
  flicker          doc 07 s4.4 rule 1: `flicker` (any case) in game/ only inside game/ghost/, plus the
                   message names `request_flicker` / `apply_flicker` inside game/net/.
  energy_override  doc 07 s4.4 rule 2: only game/render/light_rig.gd and game/ghost/light_flicker.gd.
  light_energy     doc 07 s4.4 rule 3: only under game/render/. A match in a .tscn/.tres is a scene-authored
                   static value, reported as a warning (inference, doc 09 section 9), not a failure; .gd fails.
                   `ambient_light_energy` is Environment, not a light, and does not match (D-036).
  rpc_outside_net  doc 06 s14, doc 05 s22: `rpc(` / `rpc_id(` calls (with or without a receiver) and
                   `@rpc` annotations only inside game/net/ (Q-039 item 1).
  voice_files      CONTRACTS s11 bans real voice recordings in the repo. The extension list is QA's
                   (inference, Q-039 item 2; CONTRACTS s11 names no extensions): no tracked .vclip or .opus
                   anywhere; no tracked .wav/.ogg/.mp3/.flac outside assets/audio/ and tests/ (generated
                   placeholders and fixtures only). spikes/ gets no exception: test voice input lives
                   outside the repo (CONTRACTS s11).

A missing game/ folder passes with a note (nothing to check yet).
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

SCAN_SUFFIXES = {".gd", ".tscn", ".tres", ".gdshader", ".cfg", ".json"}
SCENE_SUFFIXES = {".tscn", ".tres"}
NET_TOKENS = re.compile(r"\b(request_flicker|apply_flicker)\b")


def _rel(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def _game_files(root: Path) -> list[Path]:
    game = root / "game"
    if not game.is_dir():
        return []
    return sorted(p for p in game.rglob("*") if p.is_file() and p.suffix in SCAN_SUFFIXES)


def _grep(files: list[Path], root: Path, pattern: re.Pattern[str]):
    for path in files:
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for n, line in enumerate(lines, 1):
            if pattern.search(line):
                yield _rel(path, root), n, line.strip()


def check_flicker(root: Path, files: list[Path]) -> list[str]:
    out = []
    for rel, n, line in _grep(files, root, re.compile("flicker", re.I)):
        if rel.startswith("game/ghost/"):
            continue
        if rel.startswith("game/net/") and not re.search("flicker", NET_TOKENS.sub("", line), re.I):
            continue
        out.append(f"{rel}:{n}: {line}")
    return out


def check_energy_override(root: Path, files: list[Path]) -> list[str]:
    ok = {"game/render/light_rig.gd", "game/ghost/light_flicker.gd"}
    return [f"{r}:{n}: {l}" for r, n, l in _grep(files, root, re.compile("energy_override")) if r not in ok]


def check_light_energy(root: Path, files: list[Path]) -> tuple[list[str], list[str]]:
    fails, warns = [], []
    for r, n, l in _grep(files, root, re.compile(r"(?<!ambient_)light_energy")):
        if r.startswith("game/render/"):
            continue
        (warns if Path(r).suffix in SCENE_SUFFIXES else fails).append(f"{r}:{n}: {l}")
    return fails, warns


def check_rpc(root: Path, files: list[Path]) -> list[str]:
    pat = re.compile(r"(?<!\w)rpc(_id)?\(|^\s*@rpc\b")
    return [f"{r}:{n}: {l}" for r, n, l in _grep([f for f in files if f.suffix == ".gd"], root, pat)
            if not r.startswith("game/net/")]


def check_voice_files(root: Path) -> list[str]:
    try:
        tracked = subprocess.run(["git", "-C", str(root), "ls-files"], capture_output=True, text=True,
                                 check=True).stdout.splitlines()
    except (OSError, subprocess.CalledProcessError):
        return ["git ls-files failed: voice file check not run"]
    out = []
    for f in tracked:
        ext = Path(f).suffix.lower()
        if ext in {".vclip", ".opus"}:
            out.append(f)
        elif ext in {".wav", ".ogg", ".mp3", ".flac"} and not f.startswith(("assets/audio/", "tests/")):
            out.append(f)
    return out


def run(root: Path) -> int:
    files = _game_files(root)
    if not files:
        print("note: no game/ files yet; code greps have nothing to check")
    le_fail, le_warn = check_light_energy(root, files)
    results = {
        "flicker": check_flicker(root, files),
        "energy_override": check_energy_override(root, files),
        "light_energy": le_fail,
        "rpc_outside_net": check_rpc(root, files),
        "voice_files": check_voice_files(root),
    }
    bad = 0
    for name, hits in results.items():
        print(f"{'FAIL' if hits else 'ok  '} {name}: {len(hits)} violation(s)")
        for h in hits:
            print(f"       {h}")
        bad += len(hits)
    for w in le_warn:
        print(f"warn light_energy in a scene (static value; doc 09 section 9): {w}")
    return 1 if bad else 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    return run(ap.parse_args(argv).root.resolve())


if __name__ == "__main__":
    sys.exit(main())

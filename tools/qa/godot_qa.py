"""Shared helpers for the QA harness: find Godot, run it, scan its output for errors.

Stdlib only. Used by smoke.py and multi.py; imported by tests/qa/test_harness.py.
"""

from __future__ import annotations

import os
import re
import subprocess
import time
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
QA_OUT_ROOT = REPO_ROOT / "logs" / "qa"  # `logs/` is gitignored

# CONTRACTS section 1: Godot 4.7.2 console build installed by winget.
_CONTRACT_GODOT = (
    Path(os.environ.get("LOCALAPPDATA", ""))
    / "Microsoft"
    / "WinGet"
    / "Packages"
    / "GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
    / "Godot_v4.7.2-stable_win64_console.exe"
)

_ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
# Godot prints "ERROR: ...", "SCRIPT ERROR: ...", "SHADER ERROR: ...", "USER ERROR: ..." at the
# start of a line. Anything of that shape fails the run (PP-03 acceptance: any ERROR or SCRIPT ERROR).
_ERROR_LINE = re.compile(r"^\s*(?:[A-Z]+ )?ERROR:")
# A crash may not print an ERROR line first.
_CRASH_LINE = re.compile(r"CrashHandlerException|Program crashed with signal|Dumping the backtrace")


def find_godot(explicit: str | None = None) -> Path:
    """--godot flag, then $GODOT, then the CONTRACTS section 1 path."""
    for candidate in (explicit, os.environ.get("GODOT")):
        if candidate:
            path = Path(candidate)
            if path.is_file():
                return path
            raise SystemExit(f"Godot not found at {path}")
    if _CONTRACT_GODOT.is_file():
        return _CONTRACT_GODOT
    raise SystemExit(
        f"Godot not found at the CONTRACTS section 1 path ({_CONTRACT_GODOT}). "
        "Set $GODOT or pass --godot."
    )


def strip_ansi(text: str) -> str:
    return _ANSI.sub("", text)


def scan_errors(text: str, allow: list[re.Pattern[str]] | None = None) -> list[str]:
    """Return every ERROR / SCRIPT ERROR / crash line in Godot output, minus allowed ones."""
    found: list[str] = []
    for raw in strip_ansi(text).splitlines():
        line = raw.rstrip("\r")
        if not (_ERROR_LINE.match(line) or _CRASH_LINE.search(line)):
            continue
        if allow and any(p.search(line) for p in allow):
            continue
        found.append(line.strip())
    return found


@dataclass
class StepResult:
    name: str
    command: list[str]
    exit_code: int | None
    timed_out: bool
    seconds: float
    log_path: Path
    errors: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return self.exit_code == 0 and not self.timed_out and not self.errors


def run_godot(
    name: str,
    command: list[str],
    log_path: Path,
    timeout_s: float,
    allow: list[re.Pattern[str]] | None = None,
) -> StepResult:
    """Run one Godot command to completion, saving its combined output to log_path."""
    log_path.parent.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    timed_out = False
    with log_path.open("wb") as out:
        proc = subprocess.Popen(command, stdout=out, stderr=subprocess.STDOUT, cwd=REPO_ROOT)
        try:
            exit_code: int | None = proc.wait(timeout=timeout_s)
        except subprocess.TimeoutExpired:
            timed_out = True
            proc.kill()
            proc.wait()
            exit_code = None
    text = log_path.read_bytes().decode("utf-8", errors="replace")
    return StepResult(
        name=name,
        command=command,
        exit_code=exit_code,
        timed_out=timed_out,
        seconds=time.monotonic() - start,
        log_path=log_path,
        errors=scan_errors(text, allow),
    )


def timestamp() -> str:
    return time.strftime("%Y%m%d_%H%M%S")


def user_data_dir(godot: Path) -> Path:
    """The project's real user:// folder, asked from Godot itself.

    Falls back to Godot's Windows default (%APPDATA%/Godot/app_userdata/<config/name>) if the probe
    prints nothing. A later `application/config/use_custom_user_dir` setting is picked up by the probe.
    """
    probe = subprocess.run(
        [str(godot), "--headless", "--path", str(REPO_ROOT), "-s", "res://tests/qa/print_user_dir.gd"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=120,
        cwd=REPO_ROOT,
    )
    for line in strip_ansi(probe.stdout).splitlines():
        if line.startswith("QA_USER_DATA_DIR="):
            return Path(line.split("=", 1)[1].strip())
    name = "Godot"
    for line in (REPO_ROOT / "project.godot").read_text(encoding="utf-8").splitlines():
        if line.startswith("config/name="):
            name = line.split("=", 1)[1].strip().strip('"')
    return Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata" / name

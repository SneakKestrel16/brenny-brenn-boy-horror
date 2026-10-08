# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
"""Export the game for Windows and zip it for a playtester on another network (doc 09 s2).

    uv run tools/qa/package_playtest.py [--out builds/playtest_<build id>.zip] [--allow-dirty]

The tester needs no Godot. The zip holds the exported game (project packed inside the .exe), the
TwoVoIP DLL Godot copies next to it, the console wrapper exe, the addon's license files, START HERE.txt,
the tester brief, Host.bat and Join.bat (the exe needs `-- --host --phase1` or `-- --join=<ip> --phase1`;
there is no menu yet, so a bare double-click shows only a solo session), and send_logs.bat, which zips
the tester's recent section 10 logs and godot.log onto their Desktop. It uses the
"Playtest (Windows)" export preset (D-029), whose main scene is the game's boot.tscn. Needs Godot
4.7.2's export templates (Q-009). Same approach as spikes/voice/package_for_friend.py (PP-02).

The build id is `git describe --always --dirty`. A dirty tree is refused: doc 09 s2 matches logs to
a build by its id, and a dirty id names no commit. Standard library only.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from godot_qa import REPO_ROOT, find_godot, scan_errors  # noqa: E402

PRESET = "Playtest (Windows)"
TOP = "brenny_playtest"
EXPORT_DIR = REPO_ROOT / "builds" / "playtest"
EXE = "Brenny Brenn Boy Horror.exe"
BRIEF = Path(__file__).resolve().parent / "playtest" / "tester_brief.md"

START_HERE = """Brenny Brenn Boy Horror: playtest build {build_id} (gray box, not the finished game)

1. Wear stereo headphones, left on left. Turn Windows spatial sound off. Close other voice chat.
2. Host: double-click Host.bat. It starts the game as host on UDP port {port} and shows
   this PC's Tailscale address (100.x.y.z) to give to the other player.
   Joiner: double-click Join.bat and type the host's Tailscale address (D-024).
   Both machines must run this same zip: a different build refuses the join.
   Do not double-click the .exe itself: with no options it starts a solo session
   without the Phase 1 night.
   If Windows Firewall asks, allow it on Private networks.
   If SmartScreen says "Windows protected your PC", choose More info, then Run anyway
   (the build isn't signed).
3. Gray screen or a crash: run "Brenny Brenn Boy Horror.console.exe" from Host.bat's
   folder to see the error, or send the logs (step 4); they include godot.log.
4. Afterwards, double-click send_logs.bat. It writes brenny_logs.zip to your Desktop.
   Send that file to the host. It holds game events and connection statistics only:
   no audio, no names, no volume values.

Controls: W A S D move, mouse look, Shift sprint, C crouch, hold X stand still, hold E interact,
left/right mouse use tool, G drop, F lantern, Q whistle, V push to talk, F3 debug (host), Esc pause.

Your voice setting (Off or Lobby lines) is on your machine and you can change it any time.
Anything the game keeps of your voice stays on your disk; Off deletes it.

More: TESTER BRIEF.md. Third-party licenses: licenses/ (TwoVoIP, libopus, RNNoise, SpeexDSP, godot-cpp).
"""

PORT = 45120  # Net.DEFAULT_PORT (doc 06 section 2); Net tries the next ports if it is taken

# The exe ignores user arguments unless they follow `--`. `--phase1` loads the Phase 1 night
# (data/phase1.json, D-023); host and joiner must both pass it or the data hash refuses the join.
# Playtest pacing (D-030): phase lengths in seconds, passed as --day-s, --dusk-s, --night-s. The game's
# own lengths are day 540, dusk 60, night 300. Night stays 300: the Phase 1 traps are set 40 to 220 s
# into it and the scripted stalk starts at 60 s. Host and joiner pass the same values (edit both files).
PACING = {"DAY_S": 180, "DUSK_S": 30, "NIGHT_S": 300}
_PACING_SET = "".join(f"set {k}={v}\n" for k, v in PACING.items())
_PACING_ARGS = "--day-s=%DAY_S% --dusk-s=%DUSK_S% --night-s=%NIGHT_S%"

HOST_BAT = r"""@echo off
cd /d "%~dp0"
rem Phase lengths in seconds; Join.bat must match. Normal game: 540, 60, 300.
""" + _PACING_SET + r"""echo Hosting on UDP port {port}. Day %DAY_S% s, dusk %DUSK_S% s, night %NIGHT_S% s.
echo Give the other player this PC's Tailscale address:
tailscale ip -4 2>nul || echo   (tailscale not found: open Tailscale and copy the 100.x.y.z address)
start "" "{exe}" -- --host --phase1 --port={port} """ + _PACING_ARGS + r"""
pause
"""

JOIN_BAT = r"""@echo off
cd /d "%~dp0"
rem Phase lengths in seconds; must match Host.bat. Normal game: 540, 60, 300.
""" + _PACING_SET + r"""set /p HOSTIP=Host's Tailscale address (100.x.y.z): 
if "%HOSTIP%"=="" exit /b 1
start "" "{exe}" -- --join=%HOSTIP%:{port} --phase1 """ + _PACING_ARGS + r"""
"""

# Zips the section 10 log folders written in the last 12 hours (CONTRACTS s10: user://logs/<session_id>/)
# plus Godot's own godot*.log from the same folder (engine errors, e.g. behind a gray screen).
# No % signs: cmd.exe would expand them.
SEND_LOGS = r"""@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$l = Join-Path $env:APPDATA 'Godot\app_userdata\Brenny Brenn Boy Horror\logs';" ^
  "if (-not (Test-Path -LiteralPath $l)) { Write-Host ('No logs at ' + $l); exit 1 };" ^
  "$d = @(Get-ChildItem -LiteralPath $l | Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-12) -and ($_.PSIsContainer -or $_.Name -like 'godot*.log') });" ^
  "if (-not $d) { Write-Host 'No logs from the last 12 hours.'; exit 1 };" ^
  "$z = Join-Path ([Environment]::GetFolderPath('Desktop')) 'brenny_logs.zip';" ^
  "Compress-Archive -LiteralPath $d.FullName -DestinationPath $z -Force;" ^
  "Write-Host ('Wrote ' + $z + '. Send it to the host.')"
pause
"""


def build_id() -> str:
    out = subprocess.run(["git", "-C", str(REPO_ROOT), "describe", "--always", "--dirty"], capture_output=True, text=True, check=True)
    return out.stdout.strip()


def export(godot: Path) -> None:
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    # A clean checkout must register TwoVoIP before the import, or the import crashes (Q-008, Q-010).
    ext_list = REPO_ROOT / ".godot" / "extension_list.cfg"
    if not ext_list.exists():
        ext_list.parent.mkdir(exist_ok=True)
        ext_list.write_bytes(b"".join(f"res://{p.relative_to(REPO_ROOT).as_posix()}\n".encode() for p in sorted((REPO_ROOT / "addons").glob("*/*.gdextension"))))
    cmd = [str(godot), "--headless", "--path", str(REPO_ROOT), "--export-release", PRESET, str(EXPORT_DIR / EXE)]
    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
    errors = scan_errors(result.stdout + "\n" + result.stderr)
    if result.returncode != 0 or errors or not (EXPORT_DIR / EXE).exists():
        print(result.stdout + result.stderr, file=sys.stderr)
        sys.exit(f"Export failed (exit {result.returncode}).")


def write_zip(out: Path, bid: str) -> list[str]:
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(EXPORT_DIR.iterdir()):
            if p.suffix in {".exe", ".dll"}:  # includes the .console.exe wrapper (preset option)
                z.write(p, f"{TOP}/{p.name}")
        for p in sorted((REPO_ROOT / "addons").glob("*/LICENSE*")):
            z.write(p, f"{TOP}/licenses/{p.name}")
        z.writestr(f"{TOP}/START HERE.txt", START_HERE.format(build_id=bid, exe=EXE, port=PORT).replace("\n", "\r\n"))
        z.writestr(f"{TOP}/Host.bat", HOST_BAT.format(exe=EXE, port=PORT).replace("\n", "\r\n"))
        z.writestr(f"{TOP}/Join.bat", JOIN_BAT.format(exe=EXE, port=PORT).replace("\n", "\r\n"))
        z.writestr(f"{TOP}/TESTER BRIEF.md", BRIEF.read_text(encoding="utf-8").replace("\n", "\r\n"))
        z.writestr(f"{TOP}/send_logs.bat", SEND_LOGS.replace("\n", "\r\n"))
        z.writestr(f"{TOP}/BUILD.txt", bid + "\r\n")
        return z.namelist()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, help="default: builds/playtest_<build id>.zip")
    ap.add_argument("--godot", help="Godot console executable (else $GODOT, else CONTRACTS s1)")
    ap.add_argument("--allow-dirty", action="store_true", help="package uncommitted changes (the build id ends -dirty)")
    a = ap.parse_args()
    bid = build_id()
    if bid.endswith("-dirty") and not a.allow_dirty:
        print(f"Working tree has uncommitted changes ({bid}). Commit first, or --allow-dirty.", file=sys.stderr)
        return 2
    out = (a.out or REPO_ROOT / "builds" / f"playtest_{bid}.zip").resolve()
    if (out == REPO_ROOT or REPO_ROOT in out.parents) and (REPO_ROOT / "builds") not in out.parents:
        print("Write the zip under builds/ (gitignored) or outside the repo.", file=sys.stderr)
        return 2
    export(find_godot(a.godot))
    names = write_zip(out, bid)
    print(f"wrote {out} ({out.stat().st_size / 1e6:.1f} MB, {len(names)} files)")
    for n in names:
        print("  " + n)
    print(f"Build id {bid}: pass it to `playtest.py new --build-id {bid}` if the session runs from this zip.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

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
UPDATER = Path(__file__).resolve().parent / "playtest" / "update.ps1"
REPO = "SneakKestrel16/brenny-brenn-boy-horror"
ASSET = "brenny_playtest.zip"  # update.ps1 looks for this asset name on the latest release

START_HERE = """Brenny Brenn Boy Horror: playtest build {build_id} (gray box, not the finished game)

1. Wear stereo headphones, left on left. Turn Windows spatial sound off. Close other voice chat.
2. Host: double-click Host.bat. It starts the game as host on UDP port {port} and shows
   this PC's Tailscale address (100.x.y.z) to give to the other player.
   Joiner: double-click Join.bat and type the host's Tailscale address (D-024).
   Both machines must run the same build: a different build refuses the join. Host.bat and
   Join.bat update the game from GitHub first; Update.bat does only that.
   Do not double-click the .exe itself: with no options it starts a solo session
   without the Phase 1 night.
   If Windows Firewall asks, allow it on Private networks.
   If SmartScreen says "Windows protected your PC", choose More info, then Run anyway
   (the build isn't signed).
3. Gray screen or a crash: run "Brenny Brenn Boy Horror.console.exe" from Host.bat's
   folder to see the error, or send the logs (step 5); they include godot.log.
4. Spatial audio test (once per tester, on your own, about 5 minutes): double-click SpatialTest.bat
   with headphones on and follow the screen.
5. Afterwards, double-click send_logs.bat. It writes brenny_logs.zip to your Desktop.
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
# Phase lengths are the game's own (D-032): the host changes them in play with the dev console
# (`skip`, `phase`, `length`). `--day-s`, `--dusk-s`, `--night-s` still exist for scripted runs.

HOST_BAT = r"""@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1"
echo Hosting on UDP port {port}.
echo Dev console: press the backquote key (`), then type help.
echo Give the other player this PC's Tailscale address:
tailscale ip -4 2>nul || echo   (tailscale not found: open Tailscale and copy the 100.x.y.z address)
start "" "{exe}" -- --host --phase1 --dev --port={port}
pause
"""

UPDATE_BAT = r"""@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1"
pause
"""

JOIN_BAT = r"""@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1"
set /p HOSTIP=Host's Tailscale address (100.x.y.z): 
if "%HOSTIP%"=="" exit /b 1
start "" "{exe}" -- --join=%HOSTIP%:{port} --phase1
"""

# Doc 09 s5 spatial audio test, one per tester, solo (no host or join). An exported build runs a scene
# given as a res:// path on the command line, the same as the editor build (P1-12 handoff).
SPATIAL_BAT = r"""@echo off
cd /d "%~dp0"
echo Spatial audio test: stereo headphones on, left on left, Windows spatial sound off.
echo 36 sounds, rest after 18, about 5 minutes. Turn to face each sound with the mouse, then press 1, 2 or 3.
echo When it says Done, run send_logs.bat and send brenny_logs.zip to the host.
start "" "{exe}" res://game/debug/spatial_audio_test.tscn
pause
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
        z.writestr(f"{TOP}/SpatialTest.bat", SPATIAL_BAT.format(exe=EXE).replace("\n", "\r\n"))
        z.writestr(f"{TOP}/TESTER BRIEF.md", BRIEF.read_text(encoding="utf-8").replace("\n", "\r\n"))
        z.writestr(f"{TOP}/send_logs.bat", SEND_LOGS.replace("\n", "\r\n"))
        z.writestr(f"{TOP}/update.ps1", UPDATER.read_text(encoding="utf-8").replace("\n", "\r\n"))
        z.writestr(f"{TOP}/Update.bat", UPDATE_BAT.replace("\n", "\r\n"))
        z.writestr(f"{TOP}/BUILD.txt", bid + "\r\n")
        return z.namelist()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, help="default: builds/playtest_<build id>.zip")
    ap.add_argument("--godot", help="Godot console executable (else $GODOT, else CONTRACTS s1)")
    ap.add_argument("--allow-dirty", action="store_true", help="package uncommitted changes (the build id ends -dirty)")
    ap.add_argument("--release", action="store_true", help=f"publish the zip as GitHub release <build id> with asset {ASSET} (needs a clean tree whose commit is on origin/main); players' Update.bat then fetches it")
    a = ap.parse_args()
    bid = build_id()
    if bid.endswith("-dirty") and not a.allow_dirty:
        print(f"Working tree has uncommitted changes ({bid}). Commit first, or --allow-dirty.", file=sys.stderr)
        return 2
    if a.release:
        if bid.endswith("-dirty"):
            print("--release needs a clean tree.", file=sys.stderr)
            return 2
        subprocess.run(["git", "-C", str(REPO_ROOT), "fetch", "-q", "origin", "main"], check=True)
        if subprocess.run(["git", "-C", str(REPO_ROOT), "merge-base", "--is-ancestor", "HEAD", "origin/main"]).returncode != 0:
            print("--release needs HEAD pushed to origin/main (players download what the release says it is).", file=sys.stderr)
            return 2
    out = (a.out or REPO_ROOT / "builds" / ("release" if a.release else ".") / (ASSET if a.release else f"playtest_{bid}.zip")).resolve()
    if (out == REPO_ROOT or REPO_ROOT in out.parents) and (REPO_ROOT / "builds") not in out.parents:
        print("Write the zip under builds/ (gitignored) or outside the repo.", file=sys.stderr)
        return 2
    export(find_godot(a.godot))
    names = write_zip(out, bid)
    print(f"wrote {out} ({out.stat().st_size / 1e6:.1f} MB, {len(names)} files)")
    for n in names:
        print("  " + n)
    if a.release:
        if out.name != ASSET:
            print(f"--release needs the zip named {ASSET} (update.ps1 looks for it).", file=sys.stderr)
            return 2
        head = subprocess.run(["git", "-C", str(REPO_ROOT), "rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
        subprocess.run(["gh", "release", "create", bid, str(out), "-R", REPO, "--target", head, "--title", f"Build {bid}",
                        "--notes", f"Playtest build {bid}. Players: run Update.bat or Host.bat / Join.bat. See docs/install.md."], check=True)
        print(f"Released {bid}: https://github.com/{REPO}/releases/tag/{bid}")
    print(f"Build id {bid}: pass it to `playtest.py new --build-id {bid}` if the session runs from this zip.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

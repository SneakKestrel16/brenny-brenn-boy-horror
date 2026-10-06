"""Zip the voice spike so a friend on another network can run it (PP-02, STOP 1).

There is no Windows export: Godot's export templates are not installed on the CEO's machine (and
are a download, which needs the CEO's say-so). Instead the friend runs this folder with the same
official Godot 4.7.2 the studio uses. See spikes/voice/README.md "Sending it to a friend".

    uv run spikes/voice/package_for_friend.py [--out builds/voice_spike_friend.zip]

The zip holds only what the spike needs: project.godot, the TwoVoIP addon with its licenses, the
spike scene and scripts, the main-scene stub, a launcher .bat, and a seeded
.godot/extension_list.cfg. Without that file a plain run (no editor import) never loads the
GDExtension and the spike fails to parse (measured in PP-02); with it, the first editor import
also does not crash (Q-008). No voices, logs or WAVs go in. Standard library only.
"""

from __future__ import annotations

import argparse
import sys
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TOP = "voice_spike"
GODOT_EXE = "Godot_v4.7.2-stable_win64.exe"

LAUNCHER = rf"""@echo off
rem Voice spike launcher (PP-02). Put {GODOT_EXE} (official, from godotengine.org) in this folder,
rem or set GODOT_EXE to its full path. Extra words after the .bat name go to the spike, e.g.
rem   "Voice spike.bat" --join SC07-21W2
setlocal
if not defined GODOT_EXE set "GODOT_EXE=%~dp0{GODOT_EXE}"
if not exist "%GODOT_EXE%" (
  echo Could not find "%GODOT_EXE%".
  echo Download Godot 4.7.2 for Windows from https://godotengine.org/download/archive/4.7.2-stable/
  echo and put {GODOT_EXE} in this folder: %~dp0
  pause
  exit /b 1
)
"%GODOT_EXE%" --path "%~dp0." res://spikes/voice/voice_spike.tscn -- %*
"""

START_HERE = f"""Voice spike for Brenny Brenn Boy Horror (test build, not the game)

1. Download Godot 4.7.2 for Windows (the standard build, not .NET) from
   https://godotengine.org/download/archive/4.7.2-stable/ and unzip {GODOT_EXE}
   into this folder, next to "Voice spike.bat".
2. Double-click "Voice spike.bat". If Windows Firewall asks, allow it on Private networks.
3. To join: type the host's join code (like SC07-21W2) in the first box, or their IP (also a
   Tailscale 100.x.y.z address) in the second box, and press Join.
4. Wear headphones. WASD moves, Q/E turns, T toggles push-to-talk (hold V to talk), M mutes,
   Esc quits.
5. Afterwards, send the host the newest folder from
   %APPDATA%\\Godot\\app_userdata\\Brenny Brenn Boy Horror\\logs
   (it holds connection and voice statistics only: no audio, no volume values).

Third-party licenses: addons/twovoip/LICENSE* (TwoVoIP, libopus, RNNoise, SpeexDSP, godot-cpp).
"""


def files_to_pack() -> list[tuple[Path, str]]:
    out: list[tuple[Path, str]] = []
    out.append((REPO / "project.godot", "project.godot"))
    out.append((REPO / "game" / "core" / "boot.tscn", "game/core/boot.tscn"))
    for p in sorted((REPO / "addons" / "twovoip").rglob("*")):
        if p.is_file():
            out.append((p, p.relative_to(REPO).as_posix()))
    for p in sorted((REPO / "spikes" / "voice").iterdir()):
        if p.is_file() and p.suffix in {".gd", ".tscn", ".md"}:
            out.append((p, p.relative_to(REPO).as_posix()))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=REPO / "builds" / "voice_spike_friend.zip")
    a = ap.parse_args()
    out = a.out.resolve()
    if (out == REPO or REPO in out.parents) and (REPO / "builds") not in out.parents:
        print("Write the zip under builds/ (gitignored) or outside the repo.", file=sys.stderr)
        return 2
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for src, rel in files_to_pack():
            z.write(src, f"{TOP}/{rel}")
        z.writestr(f"{TOP}/.godot/extension_list.cfg", "res://addons/twovoip/twovoip.gdextension\n")
        z.writestr(f"{TOP}/Voice spike.bat", LAUNCHER.replace("\n", "\r\n"))
        z.writestr(f"{TOP}/START HERE.txt", START_HERE.replace("\n", "\r\n"))
        names = z.namelist()
    print(f"wrote {out} ({out.stat().st_size / 1e6:.1f} MB, {len(names)} files)")
    for n in names:
        print("  " + n)
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Export the voice spike for Windows and zip it so a friend on another network can run it (PP-02, STOP 1).

The friend needs no Godot: the zip holds the exported `Voice spike.exe` (project packed inside),
the TwoVoIP DLL Godot copies next to it, the addon's five license files and START HERE.txt. The
export uses the "Voice spike (Windows)" preset, whose `voice_spike` feature makes the spike the
main scene (D-014). Needs Godot 4.7.2's export templates (Q-009). An exported build never runs the
editor import, so it can't hit the first-import crash (Q-008). Standard library only.

    uv run spikes/voice/package_for_friend.py [--out builds/voice_spike_friend.zip]

Set GODOT to the Godot console executable if it isn't the winget install (CONTRACTS section 1).
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TOP = "voice_spike"
PRESET = "Voice spike (Windows)"
EXPORT_DIR = REPO / "builds" / "voice_spike"
EXE = "Voice spike.exe"

START_HERE = """Voice spike for Brenny Brenn Boy Horror (test build, not the game)

1. Double-click "Voice spike.exe". If Windows Firewall asks, allow it on Private networks.
   If SmartScreen says "Windows protected your PC", choose More info, then Run anyway
   (the build isn't signed).
2. To join: type the host's join code (like SC07-21W2) in the first box, or their IP (also a
   Tailscale 100.x.y.z address) in the second box, and press Join.
3. Wear headphones. WASD moves, Q/E turns, T toggles push-to-talk (hold V to talk), M mutes,
   Esc quits.
4. Afterwards, send the host the newest folder from
   %APPDATA%\\Godot\\app_userdata\\Brenny Brenn Boy Horror\\logs
   (it holds connection and voice statistics only: no audio, no volume values).

Third-party licenses: licenses/ (TwoVoIP, libopus, RNNoise, SpeexDSP, godot-cpp).
"""


def godot() -> str:
    if os.environ.get("GODOT"):
        return os.environ["GODOT"]
    packages = Path(os.environ["LOCALAPPDATA"]) / "Microsoft" / "WinGet" / "Packages"
    found = sorted(packages.glob("GodotEngine.GodotEngine_*/Godot_v4.7.2-stable_win64_console.exe"))
    if not found:
        sys.exit("Godot 4.7.2 console executable not found; set GODOT.")
    return str(found[-1])


def export() -> None:
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    # A clean checkout must register TwoVoIP before the import, or the import crashes (Q-008).
    ext_list = REPO / ".godot" / "extension_list.cfg"
    if not ext_list.exists():
        ext_list.parent.mkdir(exist_ok=True)
        ext_list.write_bytes(b"res://addons/twovoip/twovoip.gdextension\n")
    cmd = [godot(), "--headless", "--path", str(REPO), "--export-release", PRESET, str(EXPORT_DIR / EXE)]
    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
    errors = [line for line in result.stdout.splitlines() + result.stderr.splitlines() if "ERROR" in line]
    if result.returncode != 0 or errors or not (EXPORT_DIR / EXE).exists():
        print(result.stdout + result.stderr, file=sys.stderr)
        sys.exit(f"Export failed (exit {result.returncode}).")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=REPO / "builds" / "voice_spike_friend.zip")
    a = ap.parse_args()
    out = a.out.resolve()
    if (out == REPO or REPO in out.parents) and (REPO / "builds") not in out.parents:
        print("Write the zip under builds/ (gitignored) or outside the repo.", file=sys.stderr)
        return 2
    export()
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(EXPORT_DIR.iterdir()):
            if p.suffix in {".exe", ".dll"}:
                z.write(p, f"{TOP}/{p.name}")
        for p in sorted((REPO / "addons" / "twovoip").glob("LICENSE*")):
            z.write(p, f"{TOP}/licenses/{p.name}")
        z.writestr(f"{TOP}/START HERE.txt", START_HERE.replace("\n", "\r\n"))
        names = z.namelist()
    print(f"wrote {out} ({out.stat().st_size / 1e6:.1f} MB, {len(names)} files)")
    for n in names:
        print("  " + n)
    return 0


if __name__ == "__main__":
    sys.exit(main())

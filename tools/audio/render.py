# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
"""Render placeholder sounds from SuperCollider sources, then normalize and check them (D-015).

    uv run tools/audio/render.py                          # every assets/audio/src/*.scd
    uv run tools/audio/render.py sfx_taint_heartbeat      # only these sound ids
    uv run tools/audio/render.py --spectrogram            # also write a PNG per sound to look at

Each assets/audio/src/<sound_id>.scd renders through tools/audio/render_nrt.scd (SuperCollider in
non-real-time mode: no audio device, no window) to 48 kHz 16-bit WAV, then SoX normalizes the peak
to --peak dBFS and the result goes to assets/audio/<sound_id>.wav. Sound ids follow CONTRACTS
section 3: <bus>_<name>[_<variant>].

Every sound is checked: it must exist, not be silent (peak above -60 dBFS) and not clip. The
report lists length, channels, peak and RMS. Raw renders, logs and spectrograms go to
logs/audio/render_<timestamp>/ (gitignored). Exit code 0 = all passed, 1 = any failed.

sclang is found through --sclang, then $SCLANG, then PATH, then C:/Program Files/SuperCollider*/.
sox through --sox, then $SOX, then PATH, then C:/Program Files (x86)/sox-*/, then
winget's ChrisBagwell.SoX package folder under %LOCALAPPDATA%. Standard library only.
"""

from __future__ import annotations

import argparse
import array
import glob
import math
import os
import re
import shutil
import subprocess
import sys
import wave
from datetime import datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SRC_DIR = REPO_ROOT / "assets" / "audio" / "src"
OUT_DIR = REPO_ROOT / "assets" / "audio"
DRIVER = Path(__file__).resolve().parent / "render_nrt.scd"
LOG_ROOT = REPO_ROOT / "logs" / "audio"
SOUND_ID = re.compile(r"^[a-z]+_[a-z0-9_]+$")
SILENT_DBFS = -60.0


def find_tool(name: str, explicit: str | None, env: str, windows_globs: list[str]) -> Path | None:
    for candidate in (explicit, os.environ.get(env), shutil.which(name)):
        if candidate and Path(candidate).is_file():
            return Path(candidate)
    for pattern in windows_globs:
        hits = sorted(glob.glob(pattern))
        if hits:
            return Path(hits[-1])
    return None


def dbfs(x: float) -> float:
    return 20 * math.log10(x) if x > 0 else -math.inf


def analyse(path: Path) -> dict:
    with wave.open(str(path), "rb") as w:
        channels, width, rate, frames = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(frames)
    if width != 2:
        raise ValueError(f"expected 16-bit samples, got {width * 8}-bit")
    samples = array.array("h", raw)
    if sys.byteorder == "big":
        samples.byteswap()
    peak = max((abs(s) for s in samples), default=0) / 32768
    rms = math.sqrt(sum(s * s for s in samples) / len(samples)) / 32768 if samples else 0.0
    clipped = sum(1 for s in samples if s >= 32767 or s <= -32768)
    return {"seconds": frames / rate, "rate": rate, "channels": channels,
            "peak_dbfs": dbfs(peak), "rms_dbfs": dbfs(rms), "clipped": clipped}


def render_one(sound_id: str, sclang: Path, sox: Path | None, run_dir: Path, args) -> list[str]:
    src = SRC_DIR / f"{sound_id}.scd"
    raw = run_dir / f"{sound_id}.raw.wav"
    final = OUT_DIR / f"{sound_id}.wav"
    errors: list[str] = []
    if not SOUND_ID.match(sound_id):
        errors.append("name must be <bus>_<name>[_<variant>] in snake_case (CONTRACTS section 3)")
    env = dict(os.environ)
    if sys.platform != "win32":
        # sclang's Qt layer on Linux: no display, and Chromium refuses to start as root without this.
        # Not on Windows: SuperCollider 3.14.1 ships only Qt's qwindows plugin, and sclang crashes
        # while compiling the class library (exit 0xC0000409) when asked for "offscreen".
        env["QT_QPA_PLATFORM"] = "offscreen"
        env.setdefault("QTWEBENGINE_CHROMIUM_FLAGS", "--no-sandbox")
    cmd = [str(sclang), str(DRIVER), str(src.resolve()), str(raw.resolve())]
    try:
        # cwd = sclang's folder so it finds scsynth and its class library on Windows.
        proc = subprocess.run(cmd, cwd=sclang.parent, env=env, stdin=subprocess.DEVNULL,
                              capture_output=True, text=True, errors="replace", timeout=args.timeout)
        output, code = proc.stdout + proc.stderr, proc.returncode
    except subprocess.TimeoutExpired as e:
        output = (e.stdout or b"").decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
        code = None
        errors.append(f"sclang still running after {args.timeout:.0f} s (an error in the source usually leaves it waiting)")
    (run_dir / f"{sound_id}.sclang.log").write_text(output, encoding="utf-8")
    errors += [line.strip() for line in output.splitlines() if line.startswith("ERROR")]
    if code not in (0, None):
        errors.append(f"sclang exited with {code}")
    if not raw.exists():
        errors.append(f"no file rendered; see {run_dir.name}/{sound_id}.sclang.log")
        return errors

    if sox:
        subprocess.run([str(sox), str(raw), "-b", "16", str(final), "gain", "-n", str(args.peak)], check=True)
    else:
        shutil.copyfile(raw, final)
    stats = analyse(final)
    if stats["peak_dbfs"] < SILENT_DBFS:
        errors.append(f"silent: peak {stats['peak_dbfs']:.1f} dBFS")
    if stats["clipped"]:
        errors.append(f"{stats['clipped']} clipped samples")
    if args.spectrogram and sox:
        png = run_dir / f"{sound_id}.png"
        subprocess.run([str(sox), str(final), "-n", "spectrogram", "-t", sound_id, "-o", str(png)], check=True)
    print(f"  {sound_id:<32} {stats['seconds']:6.2f} s  {stats['channels']} ch  "
          f"peak {stats['peak_dbfs']:6.1f} dBFS  rms {stats['rms_dbfs']:6.1f} dBFS")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("ids", nargs="*", help="sound ids to render (default: every assets/audio/src/*.scd)")
    parser.add_argument("--sclang", help="SuperCollider sclang executable")
    parser.add_argument("--sox", help="SoX executable")
    parser.add_argument("--peak", type=float, default=-1.0, help="normalize peaks to this dBFS (default -1)")
    parser.add_argument("--spectrogram", action="store_true", help="write a spectrogram PNG per sound to the log folder")
    parser.add_argument("--timeout", type=float, default=120.0, help="seconds per sound before sclang counts as hung")
    args = parser.parse_args(argv)

    sclang = find_tool("sclang", args.sclang, "SCLANG", ["C:/Program Files/SuperCollider*/sclang.exe"])
    sox = find_tool("sox", args.sox, "SOX", [
        "C:/Program Files (x86)/sox-*/sox.exe",
        "C:/Program Files/sox-*/sox.exe",
        os.path.expandvars("%LOCALAPPDATA%/Microsoft/WinGet/Packages/ChrisBagwell.SoX_*/sox-*/sox.exe"),
    ])
    if not sclang:
        print("sclang not found. Install SuperCollider (tools/audio/README.md) or pass --sclang.", file=sys.stderr)
        return 1
    if not sox:
        print("Warning: SoX not found, so sounds are not normalized and --spectrogram is skipped.", file=sys.stderr)

    ids = args.ids or sorted(p.stem for p in SRC_DIR.glob("*.scd"))
    missing = [i for i in ids if not (SRC_DIR / f"{i}.scd").exists()]
    if missing:
        print(f"No source for: {', '.join(missing)} (looked in {SRC_DIR.relative_to(REPO_ROOT)})", file=sys.stderr)
        return 1
    if not ids:
        print(f"No sources in {SRC_DIR.relative_to(REPO_ROOT)}", file=sys.stderr)
        return 1

    run_dir = LOG_ROOT / f"render_{datetime.now():%Y%m%d_%H%M%S}"
    run_dir.mkdir(parents=True, exist_ok=True)
    print(f"sclang: {sclang}\nsox: {sox or 'not found'}\nLogs: {run_dir}")
    failed = 0
    for sound_id in ids:
        errors = render_one(sound_id, sclang, sox, run_dir, args)
        for e in errors:
            print(f"  FAIL {sound_id}: {e}")
        failed += bool(errors)
    print(f"{len(ids) - failed} of {len(ids)} rendered and passed checks.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

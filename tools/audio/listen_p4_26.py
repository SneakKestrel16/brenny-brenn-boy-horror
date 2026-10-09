"""P4-26 listen files for the CEO: footstep walk and run sequences per surface, and 60 s night ambience.
Run: uv run --no-project python tools/audio/listen_p4_26.py [--old-bed <old amb_insect_bed_night.wav>]
Writes logs/qa/p4_26/*.wav (48 kHz, 16-bit). Mirrors soundscape.gd: the local player's steps (play_2d),
one per 1.6 m stride (walk 3.0 m/s, sprint 5.0 m/s, data/labor.json), sprint +6 dB, a random variant never
repeated back to back, pitch 0.9 to 1.1 (resampled, like pitch_scale), level -2.5 to +1 dB. Night ambience:
wind at pitch 0.5 and -23.1 dB plus the insect bed at -28 dB, both through the Ambience bus (-8 dB).
Levels are relative to full scale, before Master; footstep files add the SFX bus (-4 dB) and catalog -8 dB.
Standard library only."""
import argparse
import array
import math
import random
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / "assets" / "audio"
OUT = ROOT / "logs" / "qa" / "p4_26"
SR = 48000


def read(path: Path) -> list[array.array]:
    with wave.open(str(path)) as w:
        assert w.getsampwidth() == 2 and w.getframerate() == SR, path
        ch = w.getnchannels()
        a = array.array("h", w.readframes(w.getnframes()))
    return [array.array("f", (x / 32768 for x in a[c::ch])) for c in range(ch)]


def resample(x: array.array, pitch: float) -> array.array:
    n = int(len(x) / pitch)
    out = array.array("f", bytes(4 * n))
    for i in range(n):
        p = i * pitch
        j = int(p)
        f = p - j
        out[i] = x[j] * (1 - f) + (x[j + 1] if j + 1 < len(x) else 0.0) * f
    return out


def write(path: Path, chans: list[array.array]) -> None:
    n = len(chans[0])
    pcm = array.array("h", bytes(2 * n * len(chans)))
    for c, x in enumerate(chans):
        for i in range(n):
            pcm[i * len(chans) + c] = max(-32767, min(32767, int(x[i] * 32767)))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(len(chans))
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def db(x: float) -> float:
    return 10 ** (x / 20)


def steps(surface: str, speed: float, sprint: bool, seconds: float, rng: random.Random) -> array.array:
    files = [read(AUDIO / f"sfx_step_{surface}_{v:02d}.wav")[0] for v in range(1, 7)]
    out = array.array("f", bytes(4 * int((seconds + 1) * SR)))
    t, last = 0.3, 0
    while t < seconds:
        v = rng.randint(1, 6)
        if v == last:
            v = v % 6 + 1
        last = v
        g = db(-8 - 4 - 8 + (6 if sprint else 0) + rng.uniform(-2.5, 1.0))  # catalog, SFX bus, local -8
        x = resample(files[v - 1], rng.uniform(0.9, 1.1))
        s = int(t * SR)
        for i, y in enumerate(x):
            out[s + i] += y * g
        t += 1.6 / speed
    return out


def loop(x: array.array, n: int, start: int) -> array.array:
    return array.array("f", (x[(start + i) % len(x)] for i in range(n)))


def night(bed_path: Path, seconds: float) -> list[array.array]:
    n = int(seconds * SR)
    wind = [loop(resample(c, 0.5), n, 0) for c in read(AUDIO / "amb_wind_loop.wav")]
    bed = [loop(c, n, SR) for c in read(bed_path)]
    gw, gb = db(-23.1 - 8), db(-28 - 8)
    fade = int(2 * SR)
    out = []
    for c in range(2):
        o = array.array("f", (wind[c][i] * gw + bed[c][i] * gb for i in range(n)))
        for i in range(fade):
            o[i] *= i / fade
            o[n - 1 - i] *= i / fade
        out.append(o)
    return out


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--old-bed", type=Path, help="the previous amb_insect_bed_night.wav, for an A/B file")
    args = ap.parse_args()
    rng = random.Random(26)
    for surface in ("dirt", "corn", "wood"):
        for name, speed, sprint in (("walk", 3.0, False), ("run", 5.0, True)):
            x = steps(surface, speed, sprint, 8.0, rng)
            write(OUT / f"steps_{surface}_{name}.wav", [x])
    write(OUT / "night_ambience_60s.wav", night(AUDIO / "amb_insect_bed_night.wav", 60))
    if args.old_bed:
        write(OUT / "night_ambience_60s_OLD.wav", night(args.old_bed, 60))
    for p in sorted(OUT.glob("*.wav")):
        chans = read(p)
        peak = max(max(abs(v) for v in c) for c in chans)
        rms = math.sqrt(sum(sum(v * v for v in c) for c in chans) / sum(len(c) for c in chans))
        print(f"{p.relative_to(ROOT)}  {len(chans[0]) / SR:5.1f} s  peak {20 * math.log10(peak):6.1f} dBFS  "
              f"rms {20 * math.log10(rms):6.1f} dBFS")

"""Synthetic test voice for the voice spike's --voice-wav input (doc 06 section 8 "Capture").

Not a recording of anyone: a few harmonics of a gliding pitch, weighted by two moving "formant"
bumps, cut into syllables (smooth raised-cosine envelopes) and phrases with pauses, so voice
activity detection opens and closes like speech. CONTRACTS section 11: test voices are synthetic and
kept outside the repo, so this script refuses to write inside it.

    uv run spikes/voice/make_test_wav.py <out.wav> [--f0 140] [--seed 1] [--seconds 24]

Standard library only. Mono, 16-bit, 48 kHz.
"""

from __future__ import annotations

import argparse
import math
import random
import struct
import sys
import wave
from pathlib import Path

RATE = 48000
PEAK = 0.35  # about -9 dBFS peak, roughly -18 dBFS RMS while "speaking"
MAX_HARMONIC_HZ = 4000.0


def synth(f0: float, seed: int, seconds: float) -> list[float]:
    rng = random.Random(seed)
    n_total = int(seconds * RATE)
    out = [0.0] * n_total
    t = 0
    phase = 0.0
    while t < n_total:
        phrase = int(rng.uniform(1.2, 2.8) * RATE)
        end = min(n_total, t + phrase)
        while t < end:
            syl = int(rng.uniform(0.14, 0.26) * RATE)
            syl = min(syl, end - t)
            loud = rng.uniform(0.45, 1.0)
            f1 = rng.uniform(450, 800)
            f2 = rng.uniform(1100, 1900)
            step = rng.uniform(-0.08, 0.08)
            weights = []
            for k in range(1, 40):
                fk = k * f0
                if fk > MAX_HARMONIC_HZ:
                    break
                w = (1.0 / k) * (
                    1.0
                    + 3.0 * math.exp(-(((fk - f1) / 150.0) ** 2))
                    + 2.0 * math.exp(-(((fk - f2) / 200.0) ** 2))
                )
                weights.append(w)
            norm = sum(weights)
            for i in range(syl):
                env = 0.5 - 0.5 * math.cos(2.0 * math.pi * i / syl)
                glide = 1.0 + step + 0.12 * math.sin(2.0 * math.pi * 0.7 * (t + i) / RATE)
                phase += 2.0 * math.pi * f0 * glide / RATE
                s = 0.0
                for k, w in enumerate(weights, start=1):
                    s += w * math.sin(k * phase)
                out[t + i] = loud * env * s / norm
            t += syl
        t += int(rng.uniform(0.5, 1.4) * RATE)  # pause: silence
    peak = max(abs(x) for x in out) or 1.0
    return [x * PEAK / peak for x in out]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out", type=Path)
    ap.add_argument("--f0", type=float, default=140.0, help="base pitch in Hz")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--seconds", type=float, default=24.0)
    a = ap.parse_args()

    repo = Path(__file__).resolve().parents[2]
    out = a.out.resolve()
    if out == repo or repo in out.parents:
        print(f"Refusing to write inside the repo ({repo}): keep test voices outside it "
              "(CONTRACTS section 11).", file=sys.stderr)
        return 2
    samples = synth(a.f0, a.seed, a.seconds)
    out.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767)) for x in samples))
    max_delta = max(abs(samples[i] - samples[i - 1]) for i in range(1, len(samples)))
    print(f"wrote {out} ({a.seconds:.0f} s, f0 {a.f0:.0f} Hz, seed {a.seed}); "
          f"max sample-to-sample step {max_delta:.4f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

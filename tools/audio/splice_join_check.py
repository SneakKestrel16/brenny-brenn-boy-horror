# /// script
# dependencies = ["numpy"]
# ///
"""P5-07 splice join check, analysis half (doc 08 section 10.8). Reads what splice_join_capture.gd wrote.

    uv run tools/audio/splice_join_check.py <outdir>

The join is the cut frame times 960 samples, after the playback onset (the mixer latency). Around it the script
measures, against the rest of the same signal (first and last 80 ms left out, where the decoder starts and stops):
  step    largest sample-to-sample jump in a +-10 ms window vs the largest elsewhere
  hf      energy above 4 kHz in the 20 ms blocks around the join vs the loudest such block elsewhere
  rms     RMS of the 20 ms before and after the join (a level jump)
Thresholds are placeholders (inference); a listening test settles them.
"""

import json
import sys
from pathlib import Path

import numpy as np

RATE = 48000
BLK = 960  # 20 ms, one Opus frame


def hf_energy(x: np.ndarray) -> float:
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    return float(spec[freqs > 4000].sum())


def db(x: float) -> float:
    return 20 * np.log10(x + 1e-9)


def main() -> int:
    d = Path(sys.argv[1])
    info = json.loads((d / "info.json").read_text())
    sp = np.fromfile(d / "splice.f32", dtype=np.float32)
    onset = int(np.argmax(np.abs(sp) > 1e-7))  # first nonzero sample: the decoder's own start, not the first loud one
    join = onset + int(info["join_sample"])
    print(f"cut frames a={info['break_a']} b={info['break_b']}  playback onset {onset}  join sample {join}")
    if join + 2 * BLK > len(sp):
        print("FAIL: capture ends before the join")
        return 1
    step = np.abs(np.diff(sp))
    mask = np.ones(len(step), bool)
    mask[:onset + 4 * BLK] = False
    mask[-4 * BLK:] = False
    mask[join - 480:join + 480] = False
    near = float(step[join - 480:join + 480].max())
    print(f"step: max within +-10 ms of the join {near:.4f}; elsewhere max {step[mask].max():.4f}")
    hf_join = max(hf_energy(sp[join - BLK:join]), hf_energy(sp[join:join + BLK]))
    hfs = [hf_energy(sp[i:i + BLK]) for i in range(onset + 4 * BLK, len(sp) - 5 * BLK, BLK) if abs(i - join) > 2 * BLK]
    print(f"hf>4k: 20 ms blocks at the join {hf_join:.3g}; elsewhere median {np.median(hfs):.3g}, max {max(hfs):.3g}")
    rb = float(np.sqrt(np.mean(sp[join - BLK:join] ** 2)))
    ra = float(np.sqrt(np.mean(sp[join:join + BLK] ** 2)))
    print(f"rms 20 ms before {db(rb):.1f} dBFS, after {db(ra):.1f} dBFS")
    bad = []
    if near > step[mask].max() * 1.5:
        bad.append("step")
    if hf_join > max(hfs) * 1.5 and hf_join > 1e-3:
        bad.append("hf")
    print("VERDICT: " + ("measured glitch in " + ", ".join(bad) if bad else "no glitch measured at the join"))
    return 0


if __name__ == "__main__":
    sys.exit(main())

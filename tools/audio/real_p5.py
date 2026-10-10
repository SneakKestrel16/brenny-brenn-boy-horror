"""P5-07 / D-149: the four Phase 5 UI cues rebuilt from real FilmCow recordings, three options (A, B, C) each.
Source: the FilmCow Recorded SFX library on the CEO's PC (D-149), read in place, never copied into the repo.
From the repo root:
  uv run --no-project --with numpy --with pyloudnorm python -I tools/audio/real_p5.py [sound_id ...]
Writes assets/audio/<id>.wav (option A, the CATALOG file) and assets/audio/alt/<id>_B.wav, <id>_C.wav (not loaded by
game code). Mono, 48 kHz, 16-bit, peak at most -1 dBFS. Each file is set so its loudness at playback (integrated LUFS
plus the CATALOG trim in game/audio/soundscape.gd) equals PLAY_LUFS below. ui_confirm plays at -21.7 LUFS (QA
measurement); the sting must be no louder than that (QA P5-07), so every cue sits at or under it. Loudness is
inference from a meter, not an ear: the CEO picks by listening. No melody, no Phase 1 day music."""
import sys, wave
from pathlib import Path
import numpy as np
import pyloudnorm as pyln

ROOT = Path(__file__).resolve().parents[2]
FC = Path(r"C:\Users\Ockey\fc_dl\recorded\FilmCow Recorded SFX")
_h = (ROOT / "tools/audio/process_downloads.py").read_text(encoding="utf-8").split("\n# name: (audio")[0]
exec(compile(_h, "process_downloads.py", "exec"))  # R, seg, fade, filt, mix, slow, lead


def fc(name):  # FilmCow 24-bit mono wav as float
    with wave.open(str(FC / f"{name}.wav")) as w:
        assert w.getnchannels() == 1 and w.getframerate() == R, name
        u = np.frombuffer(w.readframes(w.getnframes()), np.uint8).reshape(-1, 3).astype(np.int32)
    return ((u[:, 0] | (u[:, 1] << 8) | (u[:, 2] << 16)) << 8 >> 8) / 8388608.0


def c(name, t0=0.0, t1=99.0, rate=None, hp=0, lp=0):  # cut, lead-in trimmed, filtered, optional pitch change
    a = lead(seg(fc(name), t0, t1))
    a = filt(a, hp=hp, lp=lp) if hp or lp else a
    a = slow(a, rate) if rate else a
    return a - a.mean()  # DC removed here, before fit() fades the edges to exactly zero


def fit(a, secs, fo):  # exactly secs long, tail faded out
    n = int(secs * R); a = a[:n] if len(a) >= n else np.pad(a, (0, n - len(a)))
    return fade(a, 0.002, fo)


# sound id -> (CATALOG trim dB, playback LUFS target, {option: audio}). Sources are logged in doc 08 section 13.3.
def recipes():
    s = {}
    s["ui_season_start_sting"] = (-6.0, -24.0, {
        "A": fit(mix((c("ding 3", rate=0.5), 0, 1.0), (c("clothing movement 7", lp=500), 0.1, 0.5)), 3.0, 1.2),
        "B": fit(c("ding 1", rate=0.6, lp=2500), 3.0, 1.2),
        "C": fit(mix((c("glass ding 8", rate=0.4), 0, 1.0), (c("boxes knocked over 1", lp=300), 0, 0.6)), 3.0, 1.2)})
    s["ui_cosmetic_buy"] = (-6.0, -25.0, {
        "A": fit(mix((c("clothes ruffle 1", 0, 0.7), 0, 1.0), (c("glass ding 5", rate=1.2), 0.3, 0.5)), 1.0, 0.4),
        "B": fit(mix((c("clothing movement 3", 0, 0.6), 0, 1.0), (c("glass ding 1", rate=1.1), 0.3, 0.45)), 1.0, 0.4),
        "C": fit(mix((c("clothes ruffle 2", 0, 0.6), 0, 1.0), (c("ding 3", rate=1.5), 0.3, 0.4)), 1.0, 0.4)})
    s["ui_trait_gained"] = (-10.0, -26.0, {
        "A": fit(c("glass ding 1", rate=0.7), 1.6, 0.7),
        "B": fit(c("glass ding 3", rate=0.6, lp=3000), 1.6, 0.7),
        "C": fit(c("ding 2", rate=0.8, lp=2500), 1.6, 0.7)})
    s["ui_imposter_reveal"] = (-8.0, -24.0, {
        "A": fit(mix((c("door knock 1"), 0, 1.0), (c("ding 1", rate=0.4, lp=2000), 0.3, 0.5)), 1.8, 0.8),
        "B": fit(mix((c("door knock 3", hp=60), 0, 1.0), (c("boxes knocked over 1", lp=250), 0.05, 0.5)), 1.8, 0.8),
        "C": fit(mix((c("door knock 2"), 0, 1.0), (c("glass ding 8", rate=0.35), 0.35, 0.6)), 1.8, 0.8)})
    return s


def lufs(a): return pyln.Meter(R).integrated_loudness(a)


def finish(a, file_lufs):  # scale to the target file loudness; peak ceiling -1 dBFS, soft-limited only if the meter asks for more
    a = a * 10 ** ((file_lufs - lufs(a)) / 20)
    for _ in range(8):  # a soft limit moves the loudness a little, so iterate
        pkv = 10 ** (-1 / 20)
        if abs(a).max() <= pkv: break
        a = pkv * np.tanh(a / pkv); a = a * 10 ** ((file_lufs - lufs(a)) / 20)
    return a * min(1.0, 10 ** (-1 / 20) / abs(a).max())


def write(p, a):
    p.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(p), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(R)
        w.writeframes((np.clip(a, -1, 1) * 32767).astype("<i2").tobytes())


if __name__ == "__main__":
    only = sys.argv[1:]
    for sid, (trim, play, opts) in recipes().items():
        if only and sid not in only: continue
        for o, a in opts.items():
            a = finish(a, play - trim)
            write(ROOT / "assets/audio" / (f"{sid}.wav" if o == "A" else f"alt/{sid}_{o}.wav"), a)
            print(f"{sid} {o}: {len(a)/R:.2f}s peak {20*np.log10(abs(a).max()):.1f} dBFS file {lufs(a):.1f} LUFS playback {lufs(a)+trim:.1f} LUFS")

"""Measure the cre_jumpscare_hit_<body> files (no listening, D-077): length, RMS, peak, head silence, seam, and
per-window band energy and spectral centroid. uv run --no-project --with numpy python tools/audio/measure_jumpscare.py"""
import wave, pathlib, numpy as np
R = 48000; A = pathlib.Path(__file__).parent.parent.parent / "assets" / "audio"
def db(x): return float(round(10*np.log10(x + 1e-12), 1))
for b in ("gaunt", "scarecrow", "boar", "husk"):
    w = wave.open(str(A/f"cre_jumpscare_hit_{b}.wav")); x = np.frombuffer(w.readframes(w.getnframes()), "<i2")/32768
    assert w.getframerate() == R and w.getnchannels() == 1 and abs(x[0]) < 1e-3 and abs(x[-1]) < 1e-3
    lead = np.argmax(abs(x) > 0.01)/R; line = f"{b}: {len(x)/R:.2f}s rms {db((x**2).mean())} peak {db(abs(x).max()**2)} lead {lead:.2f}s"
    for nm, a, c in (("scare", .3, .9), ("thud", .92, 1.25), ("steps", 1.4, 2.4)):
        s = x[int(a*R):int(c*R)]; F = abs(np.fft.rfft(s*np.hanning(len(s))))**2; fr = np.fft.rfftfreq(len(s), 1/R); T = F.sum()
        bands = [db(F[(fr >= lo) & (fr < hi)].sum()/T) for lo, hi in ((0, 150), (150, 1000), (1000, 4000), (4000, 24000))]
        line += f"\n  {nm} {a}-{c}s: rms {db((s**2).mean())} centroid {int((fr*F).sum()/T)} Hz bands(<150,150-1k,1-4k,>4k) {bands}"
    print(line)

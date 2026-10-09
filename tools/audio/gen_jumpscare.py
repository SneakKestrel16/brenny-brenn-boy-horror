"""P4-17 redo of the day jumpscare hit, one file per creature body (doc 08 s5.4, s10.7). Synthetic scare and thud
(D-015, no downloads); the approved running steps (CEO listen 4, option 03) are read from the fallback
assets/audio/cre_jumpscare_hit.wav, 1.27 s on (rerunning process_downloads.py rewrites that file; rerun this after).
  uv run --no-project --with numpy python tools/audio/gen_jumpscare.py [gaunt scarecrow boar husk]
Writes assets/audio/cre_jumpscare_hit_<body>.wav (mono 48 kHz 16-bit, RMS -9.4 dB like the old file, peak -1 dBFS).
Body size and mass from assets/models/creature_*.glb bounds (x,y,z m): gaunt 0.47x2.75x0.61 (tall, thin),
scarecrow 0.82x1.65x0.83 (small, light), boar 1.08x1.56x2.04 (heavy), corn_husk 0.93x3.21x0.97 (tall, hollow, light)."""
import wave, sys, pathlib, numpy as np
R = 48000; HERE = pathlib.Path(__file__).parent; OUT = HERE.parent.parent / "assets" / "audio"
rng = np.random.default_rng(7)
def rd(p):
    w = wave.open(str(p)); return np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(float)/32768
def t(d): return np.arange(int(d*R))/R
def env(n, a, d):  # linear attack a s then exponential decay, time constant d s
    x = t(n); return np.minimum(x/a, 1)*np.exp(-x/d)
def fftf(a, hp=0, lpf=0):  # smooth 4th-order rolloff in the FFT domain
    F = np.fft.rfft(a); fr = np.fft.rfftfreq(len(a), 1/R)
    if hp: F *= 1/(1+(hp/np.maximum(fr, 1e-3))**4)
    if lpf: F *= 1/(1+(fr/lpf)**4)
    return np.fft.irfft(F, len(a))
def pk(a, v=1.0): return a/(abs(a).max()+1e-9)*v
def resample(a, r): return np.interp(np.arange(0, len(a)-1, r), np.arange(len(a)), a)  # r > 1: faster and higher
def thud(f0, f1, dec, noise_lp, noise_g, length=0.9):  # pitch-dropping sine body + low-passed noise slap
    x = t(length); ph = 2*np.pi*np.cumsum(f1 + (f0-f1)*np.exp(-x/0.05))/R
    return np.tanh(1.6*np.sin(ph))*np.exp(-x/dec) + fftf(rng.standard_normal(len(x)), 20, noise_lp)*np.exp(-x/(dec*0.4))*noise_g
def sweep(f0, f1, n, wob=0.0):  # phase of a glide f0 to f1 with random wobble
    x = t(n); f = f0*(f1/f0)**(x/n)*(1 + wob*fftf(rng.standard_normal(len(x)), 0, 25)*8); return 2*np.pi*np.cumsum(f)/R
def saw(ph, k): return sum(np.sin(h*ph)/h for h in range(1, k+1))
# Each body returns (scare, thud, step rate). Step rate resamples the running steps: <1 slower and deeper (heavy).
def gaunt():  # tall, thin: a high rasping shriek, a light dry thud, long fast stride
    n = 0.8; x = t(n); ph = sweep(1500, 2900, n, 0.5)
    s = np.tanh(2*np.sin(ph + 1.8*np.sin(ph*1.5)))*0.7 + fftf(rng.standard_normal(len(x)), 1200, 6000)*0.5
    return s*env(n, 0.01, 0.4)*(1 + 0.5*np.sin(2*np.pi*38*x)), thud(110, 75, 0.12, 700, 0.5)*0.6, 1.0
def scarecrow():  # small, light, ragged: a hoarse mid scream through burlap flaps, a dry straw thump, quick steps
    n = 0.85; x = t(n); ph = sweep(520, 1050, n, 0.6)
    s = np.tanh(3*saw(ph, 5))*0.6 + fftf(rng.standard_normal(len(x)), 800, 4500)*0.6
    s = s*env(n, 0.02, 0.5)*(1 + 0.6*np.sin(2*np.pi*11*x))
    flap = fftf(rng.standard_normal(len(x)), 150, 900)*(np.sin(2*np.pi*3*x) > 0.7)*0.9*env(n, 0.02, 0.6)
    return s + flap, thud(140, 95, 0.1, 2500, 0.9)*0.55, 1.12
def boar():  # heavy: a low bellow-squeal, iron chain clatter, a deep long thud, slow heavy steps
    n = 0.9; x = t(n); ph = sweep(180, 420, n, 0.25)
    s = (np.tanh(4*saw(ph, 10))*0.8 + fftf(rng.standard_normal(len(x)), 300, 2500)*0.4)*env(n, 0.015, 0.55)
    ch = np.zeros(len(x)); c = t(0.05)
    for k in range(14):  # chain links: short bright clinks
        i = int((0.04 + k*0.055 + rng.uniform(0, 0.02))*R)
        ch[i:i+len(c)] += np.sin(2*np.pi*rng.uniform(2800, 5200)*c)*np.exp(-c/0.012)*rng.uniform(0.3, 1)
    return s + ch*0.45, thud(75, 38, 0.3, 500, 0.9, 1.1)*1.4, 0.82
def husk():  # tall, hollow, light: a dry husk-pulse rattle (18 Hz comb, 4 to 7 kHz) under a breathy hollow wail
    n = 0.9; x = t(n); comb = fftf((np.sin(2*np.pi*18*x) > 0.2).astype(float), 0, 120)
    rat = fftf(rng.standard_normal(len(x)), 4000, 7000)*comb*np.minimum(x/0.25, 1)
    wail = np.sin(sweep(260, 190, n, 0.2))*0.5 + fftf(rng.standard_normal(len(x)), 500, 1100)*0.5
    return pk(rat)*0.9 + pk(wail)*0.7*env(n, 0.2, 0.45), thud(85, 55, 0.2, 1800, 0.7, 1.0)*0.6, 0.92
BODIES = {"gaunt": gaunt, "scarecrow": scarecrow, "boar": boar, "husk": husk}
def build(name):
    scare, th, rate = BODIES[name]()
    steps = resample(rd(OUT/"cre_jumpscare_hit.wav")[int(1.27*R):], rate)
    steps[:int(0.02*R)] *= np.linspace(0, 1, int(0.02*R))
    steps_t = 1.27
    o = np.zeros(int((steps_t + len(steps)/R + 0.05)*R))
    for a, d, g in ((scare, 0.3, 0.9), (th, 0.92, 1.0 if name == "boar" else 0.9), (steps, steps_t, 0.55)):
        o[int(d*R):int(d*R)+len(a)] += (pk(a) if a is not steps else a)*g
    o = fftf(o, 25); tgt = 10**(-9.4/20); lo, hi = 0.0, 100.0  # soft limit at -1 dBFS, gain found for RMS -9.4
    for _ in range(50):
        m = (lo+hi)/2; r = np.sqrt(((0.891*np.tanh(m*o/0.891))**2).mean()); lo, hi = (m, hi) if r < tgt else (lo, m)
    o = pk(0.891*np.tanh(m*o/0.891), 0.891); f = int(0.4*R); o[-f:] *= np.linspace(1, 0, f)**2
    o[:int(0.004*R)] *= np.linspace(0, 1, int(0.004*R))
    return o
if __name__ == "__main__":
    for b in sys.argv[1:] or BODIES:
        o = build(b); w = wave.open(str(OUT/f"cre_jumpscare_hit_{b}.wav"), "wb")
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(R); w.writeframes((o*32767).astype("<i2").tobytes()); w.close()
        print(b, round(len(o)/R, 2), "s rms", round(20*np.log10(np.sqrt((o**2).mean())), 1), "peak", round(20*np.log10(abs(o).max()), 2))

"""D-066 processing of the CC0 downloads (doc 08 section 13). From a scratch dir holding wav/ and out/:
  uv run --with miniaudio --with numpy --with scipy python <repo>/tools/audio/decode_downloads.py <repo>/assets/audio/src/dl wav
  uv run --with numpy python <repo>/tools/audio/process_downloads.py [sound_id ...]   (writes out/<sound_id>.wav)"""
import wave, numpy as np, sys
R = 48000
def load(i):
    w = wave.open(f"wav/{i}.wav"); return np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float64)/32768
def seg(a, t0, t1): return a[int(t0*R):int(t1*R)].copy()
def fade(a, fi=0.004, fo=0.1):
    a = a.copy(); n = int(fi*R); m = int(fo*R)
    if n: a[:n] *= np.linspace(0, 1, n)
    if m: a[-m:] *= np.linspace(1, 0, m)**2
    return a
def filt(a, hp=0, lp=0):  # smooth 4th-order magnitude rolloff in the FFT domain (no brickwall ringing)
    F = np.fft.rfft(a); fr = np.fft.rfftfreq(len(a), 1/R)
    if hp: F *= 1/(1+(hp/np.maximum(fr, 1e-3))**4)
    if lp: F *= 1/(1+(fr/lp)**4)
    return np.fft.irfft(F, len(a))
def gate(a, floor_db=-38, hold=0.03, smooth=0.01):  # silence the gaps between events, keep the events
    h = int(0.005*R); e = np.sqrt(np.convolve(a**2, np.ones(h)/h, "same"))
    m = (e > abs(a).max()*10**(floor_db/20)).astype(float)
    k = int(hold*R); m = np.convolve(m, np.ones(2*k+1), "same") > 0
    s = int(smooth*R); return a*np.convolve(m.astype(float), np.ones(s)/s, "same")
def lead(a, pre=0.004):  # start 4 ms before the first sample above 10 percent of the peak
    i = int(np.argmax(abs(a) > 0.1*abs(a).max())); return a[max(0, i-int(pre*R)):]
def mix(*parts):  # (audio, delay_s, gain)
    n = max(int(d*R)+len(a) for a, d, g in parts); o = np.zeros(n)
    for a, d, g in parts: o[int(d*R):int(d*R)+len(a)] += a*g
    return o
def norm(a, rms_db):
    a = a - a.mean(); pk = 10**(-1/20); t = 10**(rms_db/20)
    lim = lambda g: pk*np.tanh(g*a/pk)  # soft limit at pk
    lo, hi = 0.0, 1000.0
    for _ in range(60):
        g = (lo+hi)/2; r = np.sqrt((lim(g)**2).mean())
        lo, hi = (g, hi) if r < t else (lo, g)
    o = lim(g); return o*(pk/abs(o).max()) if abs(o).max() > pk else o
def caw(i, t0, t1): return fade(gate(filt(seg(load(i), t0, t1), hp=150)), 0.004, 0.09)
def declick(a):  # duck the lip/chew clicks: short 2-9 kHz bursts far above their surroundings
    h = filt(a, hp=2000, lp=9000); w = int(0.004*R)
    e = np.sqrt(np.convolve(h**2, np.ones(w)/w, "same"))
    sl = int(0.3*R); med = np.sqrt(np.convolve(h**2, np.ones(sl)/sl, "same"))
    m = (e > 3*med+1e-4).astype(float); k = int(0.015*R)
    m = np.clip(np.convolve(m, np.hanning(2*k+1)/np.hanning(2*k+1).sum(), "same")*3, 0, 1)
    return a*(1-0.9*m)
def breath():  # pig breathing (Jarred Gibb), no slow-down: low-passed so the hiss goes, smooth swell
    a = filt(declick(seg(load(233111), 2.5, 5.45)), hp=60, lp=1100); n = len(a)
    env = np.minimum(np.minimum(np.linspace(0,1,n)/0.2, 1), np.linspace(1,0,n)/0.25)
    return a*np.clip(env, 0, 1)
S = {
 "sfx_crow_caw_01": (caw(182090, 1.97, 2.5), -16.2),
 "sfx_crow_caw_02": (caw(673545, 5.33, 5.72), -16.2),
 "sfx_crow_caw_03": (caw(556221, 3.3, 3.75), -16.2),
 "sfx_crow_burst": (fade(seg(load(536732), 0.05, 1.3), 0.003, 0.2), -18.0),
 "vox_emote_scream": (fade(seg(load(850699), 0.2, 2.66), 0.02, 0.06), -16.4),
 "sfx_door_slam": (fade(mix((lead(seg(load(529396), 0.0, 0.7)), 0.0, 0.8), (lead(seg(load(452609), 0.0, 1.9)), 0.14, 1.0), (lead(load(216872)), 0.14, 0.9)), 0.001, 0.4), -14.0),
 "cre_door_bang_01": (fade(mix((lead(seg(load(623701), 0.0, 1.6)), 0.0, 1.0), (lead(seg(load(529396), 0.0, 0.7)), 0.0, 0.7)), 0.001, 0.3), -13.8),
 "cre_jumpscare_hit": (fade(filt(mix((seg(load(562189), 0.0, 1.0), 0, 1.0), (lead(seg(load(553886), 0.88, 2.3)), 0.0, 0.9), (lead(seg(load(115917), 1.8, 3.0)), 0.0, 0.6), (seg(load(673424), 1.0, 1.6), 0.05, 0.8)), hp=30), 0.001, 0.4), -9.4),
 "cre_lunge": (fade(mix((fade(seg(load(613567), 8.0, 8.5), 0.25, 0.05)*4, 0, 1.0), (seg(load(673424), 1.05, 1.5), 0.45, 1.0)), 0.01, 0.2), -13.9),
 "cre_presence_swell": (breath(), -16.6),
 "ui_paper_slide": (fade(seg(load(46631), 1.82, 2.55), 0.003, 0.1), -20.8),
}
only = sys.argv[1:] or list(S)
for k in only:
    a, db = S[k]
    # trim leading silence below -50 dB
    i = np.argmax(abs(a) > 10**(-50/20)); a = a[i:]
    a = norm(a, db)
    with wave.open(f"out/{k}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(R)
        w.writeframes((a*32767).astype("<i2").tobytes())
    print(k, f"{len(a)/R:.2f}s pk{20*np.log10(abs(a).max()):.1f} rms{20*np.log10(np.sqrt((a**2).mean())):.1f}")

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
    pk = 10**(-1/20); t = 10**(rms_db/20)
    lim = lambda g: pk*np.tanh(g*a/pk)  # soft limit at pk
    lo, hi = 0.0, 1000.0
    for _ in range(60):
        g = (lo+hi)/2; r = np.sqrt((lim(g)**2).mean())
        lo, hi = (g, hi) if r < t else (lo, g)
    o = lim(g); return o*(pk/abs(o).max()) if abs(o).max() > pk else o
def caw(i, t0, t1): return gate(filt(seg(load(i), t0, t1), hp=150))
def declick(a):  # duck the lip/chew clicks: short 2-9 kHz bursts far above their surroundings
    h = filt(a, hp=2000, lp=9000); w = int(0.004*R)
    e = np.sqrt(np.convolve(h**2, np.ones(w)/w, "same"))
    sl = int(0.3*R); med = np.sqrt(np.convolve(h**2, np.ones(sl)/sl, "same"))
    m = (e > 3*med+1e-4).astype(float); k = int(0.015*R)
    m = np.clip(np.convolve(m, np.hanning(2*k+1)/np.hanning(2*k+1).sum(), "same")*3, 0, 1)
    return a*(1-0.9*m)
def slow(a, r):  # play at speed r (pitch and length change together), linear interpolation: the source is band-limited low
    return np.interp(np.arange(0, len(a)-1, r), np.arange(len(a)), a)
def even(a, top_db=-12.0, ratio=0.9, win=0.12):  # duck the loud breaths: above top_db (re the peak) the gain follows env^-ratio
    h = int(win*R); e = np.sqrt(np.convolve(a**2, np.hanning(h)/np.hanning(h).sum(), "same")) + 1e-9
    thr = e.max()*10**(top_db/20); g = np.where(e > thr, (thr/e)**ratio, 1.0)
    return a*np.convolve(g, np.hanning(h)/np.hanning(h).sum(), "same")
def dog():  # sleeping dog (15GPanskaCepelak_Adam): three slow breaths, played at 0.85x so it reads bigger, loud breaths ducked
    a = filt(seg(load(461839), 3.8, 9.0), hp=40, lp=1800)
    return even(slow(a, 0.85))
def paper():  # sheet of paper scritching across wood (kyles), one clean pull
    return filt(seg(load(451411), 2.3, 2.85), hp=600, lp=10000)
def pk(a, db): return a*(10**(db/20)/abs(a).max())
def clip(i, t0, t1, hp, rate=None, cap=0.65, fo=0.12):  # trim the lead-in silence, high-pass, peak -3 dB, optional pitch-down, cap with a fade
    a = seg(load(i), t0, t1); a = a[int(np.argmax(abs(a) > 0.01*abs(a).max())):]
    a = pk(filt(a, hp=hp), -3)
    if rate: a = slow(a, rate)
    return fade(a[:int(cap*R)], 0.001, fo)
def grains(i, n, glen, hp, t1=None, gap=0.3):  # the n strongest onsets (energy rise over 2.5x the 25 ms before) as short footfall grains
    x = load(i); h = 120; m = len(x)//h; e = np.sqrt((x[:m*h].reshape(m, h)**2).mean(1)) + 1e-6
    sc = [(e[k:k+8].max(), k*h/R) for k in range(12, min(m-12, int(t1*R/h)-4)) if e[k] > 2.5*e[k-12:k-2].mean()]
    picks = []
    for _, t in sorted(sc, reverse=True):
        if all(abs(t-u) > gap for u in picks): picks.append(t)
        if len(picks) == n: break
    return [fade(pk(filt(seg(x, t-0.008, t+glen), hp=hp), -6), 0, 0.06) for t in picks]
def jumpscare():  # option 03: kea + bat scare, soft body fall, 13 running steps on grass fading away (scare + thud are placeholders)
    import random
    rng = random.Random(3); pool = grains(635052, 12, 0.14, 600, t1=40); rn = np.random.default_rng(3)
    thud = fade(pk(filt(seg(load(346694), 0.435, 1.35), hp=30), -4), 0, 0.3)*0.9*2.4
    n = int(0.2*R); leaf = filt(rn.standard_normal(n), hp=2500, lp=9000)*np.exp(-np.arange(n)/(0.05*R)); leaf = pk(leaf, 0)*0.45
    parts = [(leaf, 0.3, 1.0), (clip(456802, 1.1, 1.78, 300), 0.3, 1.0), (clip(456802, 3.4, 3.98, 150, 0.7), 0.6, 0.7),
             (clip(667579, 3.45, 4.25, 500, 0.8), 0.35, 0.7), (thud, 0.92, 1.0)]
    t = 1.3
    for j in range(13):
        f = j/12; g = pool[rng.randrange(len(pool))]; r = rng.uniform(0.92, 1.08)
        parts.append((filt(slow(g, r), lp=7000 + (2200-7000)*f), t, 1.0*0.16**f))
        t += 0.14*(1 + rng.uniform(-0.12, 0.12))
    return filt(mix(*parts), hp=25)
# name: (audio before the end fades, rms dB, fade-in s, fade-out s). The main loop trims the leading silence,
# removes DC, then fades, so the first and last sample are 0 whatever the trim cut.
S = {
 "sfx_crow_caw_01": (caw(182090, 1.97, 2.5), -16.2, 0.004, 0.09),
 "sfx_crow_caw_02": (caw(673545, 5.33, 5.72), -16.2, 0.004, 0.09),
 "sfx_crow_caw_03": (caw(556221, 3.3, 3.75), -16.2, 0.004, 0.09),
 "sfx_crow_burst": (seg(load(536732), 0.05, 1.3), -18.0, 0.003, 0.2),
 "vox_emote_scream": (seg(load(850699), 0.2, 2.66), -16.4, 0.02, 0.06),
 "sfx_door_slam": (mix((lead(seg(load(529396), 0.0, 0.7)), 0.0, 0.8), (lead(seg(load(452609), 0.0, 1.9)), 0.14, 1.0), (lead(load(216872)), 0.14, 0.9)), -14.0, 0.001, 0.4),
 "cre_door_bang_01": (mix((lead(seg(load(623701), 0.0, 1.6)), 0.0, 1.0), (lead(seg(load(529396), 0.0, 0.7)), 0.0, 0.7)), -13.8, 0.001, 0.3),
 "cre_jumpscare_hit": (jumpscare(), -9.4, 0.001, 0.4),
 "cre_lunge": (mix((fade(seg(load(613567), 8.0, 8.5), 0.25, 0.05)*4, 0, 1.0), (seg(load(673424), 1.05, 1.5), 0.45, 1.0)), -13.9, 0.01, 0.2),
 "cre_presence_swell": (dog(), -16.6, 0.15, 0.4),
 "ui_paper_slide": (paper(), -20.8, 0.004, 0.08),
}
only = sys.argv[1:] or list(S)
for k in only:
    a, db, fi, fo = S[k]
    if k != "cre_jumpscare_hit":  # the jumpscare keeps its 0.3 s head silence (the scare lands on cue)
        i = np.argmax(abs(a) > 10**(-50/20)); a = a[i:]  # trim leading silence below -50 dB
    a = a - a.mean()
    a = norm(fade(a, fi, fo), db)
    with wave.open(f"out/{k}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(R)
        w.writeframes((a*32767).astype("<i2").tobytes())
    print(k, f"{len(a)/R:.2f}s pk{20*np.log10(abs(a).max()):.1f} rms{20*np.log10(np.sqrt((a**2).mean())):.1f} first{a[0]*32767:.0f} last{a[-1]*32767:.0f}")

"""D-066 processing of the CC0 downloads (doc 08 section 13). Run from a scratch dir: decode_downloads.py <dl dir of .mp3 named <id>.mp3> wav; then this script writes out/<sound_id>.wav.
uv run --with numpy python tools/audio/process_downloads.py"""
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
def speed(a, f):  # f<1 slower and lower
    x = np.arange(0, len(a)-1, f); return np.interp(x, np.arange(len(a)), a)
def hp(a, fc):
    F = np.fft.rfft(a); fr = np.fft.rfftfreq(len(a), 1/R); F[fr < fc] = 0; return np.fft.irfft(F, len(a))
def mix(*parts):  # (audio, delay_s, gain)
    n = max(int(d*R)+len(a) for a, d, g in parts); o = np.zeros(n)
    for a, d, g in parts: o[int(d*R):int(d*R)+len(a)] += a*g
    return o
def norm(a, rms_db):
    a = a - a.mean(); pk = 10**(-1/20); t = 10**(rms_db/20)
    lim = lambda g: pk*np.tanh(g*a/pk)/np.tanh(1.0)*np.tanh(1.0)  # soft limit at pk
    lo, hi = 0.0, 1000.0
    for _ in range(60):
        g = (lo+hi)/2; r = np.sqrt((lim(g)**2).mean())
        lo, hi = (g, hi) if r < t else (lo, g)
    o = lim(g); return o*(pk/abs(o).max()) if abs(o).max() > pk else o
def breath():
    a = speed(seg(load(350414), 2.0, 6.0), 0.65)[:6*R]
    a = hp(a, 70); n = len(a)
    env = np.minimum(np.minimum(np.linspace(0,1,n)/0.25, 1), np.linspace(1,0,n)/0.3)
    return a*np.clip(env, 0, 1)
S = {
 "sfx_crow_caw_01": (fade(seg(load(813115), 0.0, 0.62), 0.003, 0.15), -16.2),
 "sfx_crow_caw_02": (fade(seg(load(611150), 0.0, 0.6), 0.003, 0.15), -16.2),
 "sfx_crow_caw_03": (fade(seg(load(361470), 0.0, 0.43), 0.003, 0.12), -16.2),
 "sfx_crow_burst": (fade(seg(load(536732), 0.05, 1.3), 0.003, 0.2), -18.0),
 "vox_emote_scream": (fade(seg(load(850699), 0.25, 2.2), 0.02, 0.25), -16.4),
 "sfx_door_slam": (fade(seg(load(413274), 0.48, 1.7), 0.001, 0.4), -19.0),
 "cre_door_bang_01": (fade(seg(load(277165), 0.0, 1.0), 0.002, 0.3), -16.8),
 "cre_jumpscare_hit": (fade(mix((seg(load(814884), 0.0, 1.6), 0, 1.0), (seg(load(673424), 1.0, 1.6), 0.05, 0.8)), 0.001, 0.4), -11.4),
 "cre_lunge": (fade(mix((fade(seg(load(613567), 8.0, 8.5), 0.25, 0.05)*4, 0, 1.0), (seg(load(673424), 1.05, 1.5), 0.45, 1.0)), 0.01, 0.2), -13.9),
 "cre_presence_swell": (breath(), -16.6),
 "ui_paper_slide": (fade(speed(seg(load(464302), 0.1, 1.45), 1.3), 0.003, 0.06), -20.8),
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

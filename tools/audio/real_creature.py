"""D-149 candidates: the creature sounds rebuilt from real recordings, three options (A, B, C) per sound for the CEO
to pick by ear. Sources: FilmCow Recorded SFX (D-149) and Freesound CC0 HQ previews (D-066), decoded to 48 kHz mono
wav outside the repo with decode_downloads.py. Source list: production/handoffs/real_creature.md and doc 08 section 13.
Nothing here writes assets/audio: candidates go to logs/listen/real_creature/, listen files to the CEO's folder.
  uv run --no-project --with numpy --with soundfile python -I tools/audio/real_creature.py [name_prefix ...]"""
import os, sys, numpy as np, soundfile as sf
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(os.path.dirname(HERE))
with open(os.path.join(HERE, "process_downloads.py"), encoding="utf8") as f:
    exec(f.read().split("\n# name:")[0])  # the D-066 helpers (seg fade filt mix norm slow even pk dog ...), not its build
FS = "C:/Users/Ockey/fc_dl/fs_creature_wav"  # Freesound downloads for this task
REPO = "C:/Users/Ockey/fc_dl/repo_dl_wav"  # assets/audio/src/dl (earlier D-066 downloads), decoded
FC = "C:/Users/Ockey/fc_dl/recorded/FilmCow Recorded SFX"
OUT = os.path.join(ROOT, "logs", "listen", "real_creature"); LISTEN = "C:/Users/Ockey/Music/ceo_listen/creature"
_cache = {}
def load(k):  # int: Freesound id; str: FilmCow file name; a path ending .wav: that file
    if k not in _cache:
        p = k if str(k).endswith(".wav") else f"{FC}/{k}.wav" if isinstance(k, str) else \
            f"{FS}/{k}.wav" if os.path.exists(f"{FS}/{k}.wav") else f"{REPO}/{k}.wav"
        x, sr = sf.read(p, always_2d=True); x = x.mean(1)
        if sr != R: x = np.interp(np.arange(0, len(x)-1, sr/R), np.arange(len(x)), x)
        _cache[k] = x
    return _cache[k]
def events(k, thr=-30, t0=0.0, t1=1e9):  # (start, end, peak) of each run above thr dB re the loudest 10 ms
    x = load(k); h = R//100; n = len(x)//h
    e = np.sqrt((x[:n*h].reshape(n, h)**2).mean(1)) + 1e-9; db = 20*np.log10(e/e.max()); on = db > thr
    ev = []; i = 0
    while i < n:
        if on[i]:
            j = i
            while j < n and on[j:j+5].any(): j += 1
            if t0 <= i*0.01 < t1: ev.append((i*0.01, j*0.01, db[i:j].max()))
            i = j
        else: i += 1
    return ev
def grain(k, t0, t1, hp=0, lp=0, rate=1.0, fo=0.04):  # one event, 10 ms lead-in, filtered, pitched, peak -6 dB
    a = seg(load(k), max(0.0, t0-0.01), t1+0.03)
    if rate != 1: a = slow(a, rate)
    if hp or lp: a = filt(a, hp, lp)
    return fade(pk(a, -6), 0.003, min(fo, len(a)/R/2))
def pool(k, n=8, thr=-30, t0=0.0, t1=1e9, maxlen=0.6, **kw):  # the n loudest events of k, each cut to maxlen
    ev = sorted(events(k, thr, t0, t1), key=lambda e: -e[2])[:n]
    return [grain(k, a, min(b, a+maxlen), **kw) for a, b, _ in sorted(ev)]
def near(k, t, maxlen=0.6, thr=-30, **kw):  # the event of k starting nearest t
    a, b, _ = min(events(k, thr), key=lambda e: abs(e[0]-t)); return grain(k, a, min(b, a+maxlen), **kw)
def fit(a, n_s):  # pad or cut to exactly n_s seconds
    n = int(round(n_s*R)); return np.pad(a, (0, max(0, n-len(a))))[:n]
def loop(hits, n_s):  # seamless loop: what runs past the end wraps onto the start, then the loop starts at its quietest 10 ms
    o = mix(*hits); n = int(round(n_s*R)); w = np.zeros(n)
    for i in range(0, len(o), n): w[:len(o[i:i+n])] += o[i:i+n]
    h = R//100; e = (w[:n//h*h].reshape(-1, h)**2).mean(1); return np.roll(w, -int(np.argmin(e))*h)
def pulsed(a, f, decay=0.022, depth=1.0, ph=0.0):  # periodic shake: each period a 2 ms attack and exponential decay
    t = (np.arange(len(a))/R*f + ph) % 1.0/f
    env = np.minimum(t/0.002, 1.0)*np.exp(-t/decay); return a*(1-depth+depth*env)
def flat(a, win=0.04):  # level a texture: divide by its 40 ms RMS envelope (shake-to-shake swells out, grain kept)
    h = int(win*R); e = np.sqrt(np.convolve(a**2, np.hanning(h)/np.hanning(h).sum(), "same"))
    return a/(e+0.05*e.max())
def env_peak(a):  # envelope modulation peak (3-80 Hz) of the band above 2 kHz, and the share of 14-22 Hz in it
    F = np.fft.rfft(a); F[np.fft.rfftfreq(len(a), 1/R) < 2000] = 0; h = np.abs(np.fft.irfft(F, len(a)))
    e = np.convolve(h, np.ones(144)/144, "same")[::48]; e = e-e.mean()
    E = np.abs(np.fft.rfft(e*np.hanning(len(e))))**2; f = np.fft.rfftfreq(len(e), 48/R); b = (f >= 3) & (f <= 80)
    return f[np.argmax(E*b)], E[(f >= 14) & (f <= 22)].sum()/E[b].sum()

# ---- signature sets: pools and timing per body ------------------------------------------------------------------
P = {}  # (body, option) -> dict of grain pools, built on first use
def pools(body, o):
    if (body, o) in P: return P[body, o]
    fl = lambda name, t0, t1, r: grain(name, t0, min(t1, t0+0.35), hp=60, lp=14000, rate=r, fo=0.1)  # the snap only: doc 08 s6 wants single events
    d = {
     ("gaunt", "A"): dict(a=pool(500797, 6, hp=250, rate=0.8, maxlen=0.15), b=pool(390962, 8, thr=-35, hp=250, rate=0.8, maxlen=0.15)),
     ("gaunt", "B"): dict(a=pool("marionette movement sounds", 16, hp=300, maxlen=0.12), b=pool(146339, 11, hp=400, rate=0.85, maxlen=0.12)),
     ("gaunt", "C"): dict(a=pool(621977, 5, hp=250, maxlen=0.2), b=pool(831713, 7, hp=300, maxlen=0.1)),
     ("scarecrow", "A"): dict(a=[fl("flag 3", .21, .82, .8), fl("flag 1", .10, .61, .8), fl("flag 5", .23, .85, .8),
                                 fl("flag 6", .14, .90, .8), fl("flag 7", .19, .72, .8), fl("flag 4", .62, .91, .8)]),
     ("scarecrow", "B"): dict(a=[fl(701647, 2.31, 2.55, .85), fl(701647, 2.61, 2.85, .85), fl(701647, 4.79, 5.17, .85),
                                 fl(386796, 2.18, 2.34, .85), fl(386796, 2.39, 2.88, .85), fl(386796, 3.0, 3.37, .85), fl(386796, 3.59, 3.91, .85)]),
     ("scarecrow", "C"): dict(a=[fl(244982, 0.03, 0.25, .8)] + [near(f"umbrella opening {i}", 0.85, 0.35, hp=60, rate=0.8) for i in (1, 2, 3, 4, 5, 6)],
                              b=[grain("fiber bundle moved 1", 0.43, 1.2, hp=200), grain("fiber bundle moved 2", 0.0, 1.5, hp=200)]),
     ("boar", "A"): dict(chain=pool("chain 3", 3, maxlen=0.7), hoof=[mix((grain(f"land in dirt {i}", 0, 0.5, lp=600, rate=0.6), 0, 1.0), (fade(pk(filt(seg(load(f"body fall with lots of bass {j}"), t, t+0.3), lp=250), -6), 0.002, 0.25), 0, 0.8))
                               for i, j, t in ((1, 2, 0.30), (2, 4, 0.04), (3, 5, 0.07), (4, 1, 0.14))],
                         grunt=pool(158746, 5, maxlen=0.7, hp=50, rate=0.85)),
     ("boar", "B"): dict(chain=[grain(191513, a, b, lp=8000) for a, b in ((6.39, 6.84), (7.12, 7.57), (15.86, 16.40), (20.29, 20.86), (21.03, 21.68))],
                         hoof=[grain(f"footstep dirt {i}", 0, 0.4, lp=600, rate=0.55) for i in (2, 7, 12, 17)],
                         grunt=pool(352698, 6, maxlen=0.6, hp=50)),
     ("boar", "C"): dict(chain=[near(f"metal dragged on floor {i}", 0.0, 0.6) for i in (1, 5, 9)] + [grain(235959, 0.74, 1.34), grain(235959, 3.15, 3.75)],
                         hoof=[grain(f"body fall with lots of bass {i}", 0, 0.35, lp=900) for i in (1, 3, 4, 5)],
                         grunt=[grain(612995, a, min(b, a+0.8), hp=50, rate=0.9) for a, b in ((1.34, 2.20), (12.49, 14.01), (15.93, 17.31), (33.91, 35.01))]),
     # husk: real dry rattles, levelled by flat() then shaken at 17-19 Hz by pulsed() so the doc 08 s6 14-22 Hz
     # envelope rule holds (none of the recordings pulses there on its own). The rattlesnake at 0.35x has its
     # own buzz near 18.7 Hz (53 Hz at 1x), so A is pulsed at that rate and only 70 percent deep.
     ("husk", "A"): dict(tex=flat(filt(slow(load(855914), 0.35), hp=300, lp=6500)), f=18.7, depth=0.7),
     ("husk", "B"): dict(tex=flat(filt(seg(load(434881), 1.5, 5.8), hp=400)), under=flat(filt(seg(load(610143), 7.0, 9.25), hp=400)), f=17.0),
     ("husk", "C"): dict(tex=flat(filt(np.concatenate([seg(load(f"glass full of beads {i}"), 0.0, 1.0) for i in (3, 9, 17)]), hp=400)),
                         crack=pool(127385, 6, hp=400, maxlen=0.08), f=19.0),
    }[body, o]
    P[body, o] = d; return d
def husk_burst(d, rng, n_s, ph=0.0):  # n_s seconds of pulsed rattle cut from the texture at a random offset
    tex = d["tex"]; i = rng.integers(0, max(1, len(tex)-int(n_s*R))); a = tex[i:i+int(n_s*R)]
    a = np.pad(a, (0, int(n_s*R)-len(a))) / (abs(tex).max()+1e-9)
    if "f" in d:
        a = pulsed(a, d["f"], depth=d.get("depth", 1.0), ph=ph)
        if "under" in d:
            u = d["under"]; j = rng.integers(0, max(1, len(u)-len(a))); b = np.pad(u[j:j+len(a)], (0, max(0, len(a)-len(u[j:j+len(a)]))))
            a = a + 0.5*pulsed(b/(abs(u).max()+1e-9), d["f"], ph=ph)
    return fade(a, 0.01, min(0.15, n_s/3))
def sig(body, o, rng, chase=False):  # hits (audio, t, gain) for one 1.75 s variant, or the 4 s chase loop
    d = pools(body, o); pick = lambda p: p[rng.integers(len(p))]; hits = []
    if body == "gaunt":  # irregular joint clicks, no low thump: lurk 1-3/s with the odd double click, chase 6-14/s
        t = rng.uniform(0.05, 0.15); end = 4.0 if chase else 1.5
        while t < end:
            src = d["a"] if rng.random() < 0.6 else d["b"]
            hits.append((slow(pick(src), rng.uniform(0.9, 1.08)), t, rng.uniform(0.55, 1.0)))
            t += rng.uniform(0.06, 0.14) if chase else (rng.uniform(0.05, 0.1) if rng.random() < 0.3 else rng.uniform(0.3, 0.65))
    elif body == "scarecrow":  # sudden single coat snaps: 2-3 per lurk variant, 10 per chase loop (2.5/s)
        ts = [0.4*i + rng.uniform(-0.02, 0.02) for i in range(10)] if chase else []
        if not chase:
            t = rng.uniform(0.06, 0.14)
            while t < 1.3: ts.append(t); t += rng.uniform(0.45, 0.9)
        for t in ts:
            hits.append((pick(d["a"]), max(0.0, t), rng.uniform(0.75, 1.0)))
            if "b" in d: hits.append((pick(d["b"]), max(0.0, t-0.05), 0.3))
    elif body == "boar":  # chain scrape/clatter + hoof thud per stride + grunts: 2 drags per lurk variant (~1.2/s), 10 strides per chase loop
        if chase:
            for i in range(10):
                t = 0.4*i
                hits += [(fit(pick(d["chain"]), 0.25), t, 0.8), (pick(d["hoof"]), t+0.02, 1.0)]
            for i in rng.choice(10, 3, replace=False): hits.append((pick(d["grunt"]), 0.4*i+0.1, 0.8))
        else:
            for t in (rng.uniform(0.06, 0.12), rng.uniform(0.85, 0.98)):
                hits += [(pick(d["chain"]), t, 1.0), (pick(d["hoof"]), t+0.03, 0.9)]
            hits.append((pick(d["grunt"]), rng.uniform(0.3, 0.7), 0.75))
    else:  # husk: 1-2 bright pulsed rattle bursts per lurk variant; chase = four 0.85 s bursts a second apart
        if chase:
            hits = [(husk_burst(d, rng, 0.85), float(i), 1.0) for i in range(4)]
        else:
            n1 = rng.uniform(0.6, 1.0); hits.append((husk_burst(d, rng, n1), 0.05, 1.0))
            t = 0.05+n1+rng.uniform(0.1, 0.2)
            if t < 1.25: hits.append((husk_burst(d, rng, min(1.65-t, rng.uniform(0.35, 0.6))), t, 0.85))
        if "crack" in d:
            for t in rng.uniform(0.05, 3.8 if chase else 1.5, 6 if chase else 2): hits.append((pick(d["crack"]), t, 0.6))
    return hits

# ---- one-shots ----------------------------------------------------------------------------------------------------
BASS = lambda i, n=0.9: fade(pk(filt(seg(load(f"body fall with lots of bass {i}"), 0, 2.6), hp=30), -4)[:int(n*R)], 0.001, 0.3)
def lead_in(a): return a[max(0, int(np.argmax(abs(a) > 0.05*abs(a).max()))-int(0.004*R)):]
JS = load(os.path.join(ROOT, "assets", "audio", "cre_jumpscare_hit.wav"))
def jumpscare(scare, thud, n_s):  # keeps the approved 0.3 s lead and running steps (cre_jumpscare_hit from 1.36 s); scare at 0.3, thud at 0.92
    steps = fade(JS[int(1.36*R):], 0.01, 0.3)
    return fit(mix(*[(lead_in(a), 0.3+t, g) for a, t, g in scare], (thud, 0.92, 1.0), (steps, 1.36, 1.0)), n_s)
JUMP = {
 "gaunt": {"A": [(near(634005, 5.56, 0.7, hp=120), 0, 1.0), (pools("gaunt", "A")["a"][0], 0.0, 0.8), (pools("gaunt", "A")["a"][2], 0.09, 0.7)],
           "B": [(grain(485952, 0, 0.67, hp=200, rate=0.85), 0, 1.0)] + [(c, 0.04*i, 0.7) for i, c in enumerate(pools("gaunt", "B")["a"][:4])],
           "C": [(near(832436, 1.07, 0.5, hp=150, rate=0.8), 0, 1.0), (pools("gaunt", "C")["a"][0], 0.0, 0.9)]},
 "scarecrow": {"A": [(grain("flag 3", 0.21, 0.82, hp=50, rate=0.7), 0, 1.0), (near("umbrella opening 2", 0.86, 0.4, rate=0.8), 0.02, 0.8), (lead_in(load("woosh 5")), 0.0, 0.6)],
               "B": [(grain(701647, 4.79, 5.17, hp=50, rate=0.75), 0, 1.0), (grain(386796, 2.39, 2.88, hp=50), 0.05, 0.7), (lead_in(load("swoosh 2")), 0.0, 0.8)],
               "C": [(grain(244982, 0.03, 0.25, hp=50, rate=0.7), 0, 1.0), (grain("flag 6", 0.14, 0.90, hp=50, rate=0.75), 0.03, 0.9), (grain("fiber bundle moved 1", 0.8, 1.5, hp=200), 0.0, 0.5)]},
 "boar": {"A": [(grain(612995, 12.49, 13.6, hp=60), 0, 1.0), (pool("chain 10", 1, maxlen=0.6)[0], 0.0, 0.8)],
          "B": [(grain(352698, 2.31, 3.16, hp=60), 0, 1.0), (grain(191513, 27.38, 28.2, lp=8000), 0.0, 0.7)],
          "C": [(grain(425241, 3.48, 4.58, hp=60), 0, 1.0), (seg(load(764944), 0.0, 1.0)*0.5, 0.05, 0.6), (pool("chain basket falling 3", 1, maxlen=0.6)[0], 0.0, 0.8)]},
 "husk": {"A": [(fade(pk(filt(load(855914), hp=300), -6), 0.002, 0.2), 0, 1.0), (grain(755839, 10.4, 11.0, hp=100), 0.0, 1.0)],
          "B": [(pool(434881, 1, maxlen=0.8, hp=400)[0], 0, 1.0), (pool(454368, 1, maxlen=0.7, hp=100)[0], 0.0, 0.9)],
          "C": [(grain("harpoon rattle", 0.30, 0.55, hp=300), 0, 1.0), (grain("harpoon rattle", 1.08, 1.4, hp=300), 0.12, 0.8),
                (fade(seg(load(613567), 8.0, 8.5), 0.05, 0.05), 0.0, 4.0), (pools("husk", "C")["crack"][0], 0.05, 0.6)]},
}
JS_LEN = {"gaunt": 3.20, "scarecrow": 3.00, "boar": 3.62, "husk": 3.37}
def best_window(k, n_s, t0=0.0, t1=1e9, hp=0):  # the loudest n_s seconds of k
    x = load(k)[int(t0*R):int(min(t1, len(load(k))/R)*R)]; x = filt(x, hp) if hp else x
    h = R//20; e = np.convolve((x[:len(x)//h*h].reshape(-1, h)**2).mean(1), np.ones(int(n_s*20)), "valid")
    i = int(np.argmax(e))*h; return x[i:i+int(n_s*R)]
def door(o, v):  # v = variant 0..2
    if o == "A":
        k = f"door knock {v+1}"; a, b, _ = max(events(k), key=lambda e: e[2])
        return mix((grain(k, a, b+0.4, rate=0.75), 0, 1.0), (BASS(v+2, 0.8), 0.0, 0.6))
    if o == "B":
        return mix((lead_in(load(411694))*0.9, 0, 1.0), (slow(lead_in(seg(load(452609), 0, 1.6)), (1.0, 0.9, 0.8)[v]), 0.0, 1.0))
    k = (f"closet door close {v+1}", f"screen door close {v+1}", "closet door close 4")[v]
    return mix((lead_in(seg(load(623701), 0, 1.6)), 0, 1.0), (lead_in(load(k)), 0.0, 0.8))
def corn(o, v):
    if o == "A": a = pool(755839, 3, thr=-14, maxlen=1.0, hp=80)[v]
    elif o == "B": a = fade(seg(load(613567), (8.0, 20.0, 30.0)[v], (9.0, 21.0, 31.0)[v]), 0.2, 0.25)
    else:
        b = pool(f"bushes {(3, 8, 15)[v]}", 1, maxlen=1.0, hp=80)[0]
        a = mix((b, 0, 1.0), (pool(f"branch moved {(2, 5, 7)[v]}", 1, maxlen=0.3, hp=200)[0], 0.15, 0.35))
    return fit(a, 1.0)
ONE = {  # name -> {option: (audio, rms dB, fade-in, fade-out)}
 "cre_gnaw": {"A": (best_window(260880, 2.5, hp=60), -15.9, 0.05, 0.2), "B": (best_window(854169, 2.5, hp=60), -15.9, 0.05, 0.2),
              "C": (slow(best_window(861818, 2.2, hp=60), 0.88), -15.9, 0.05, 0.2)},
 "cre_lunge": {"A": (mix((fade(seg(load(613567), 8.0, 8.5), 0.25, 0.05), 0, 4.0), (BASS(2, 0.44), 0.45, 1.0)), -13.9, 0.01, 0.2),
               "B": (mix((lead_in(seg(load("crashing through debris 3"), 0, 0.5)), 0, 1.0), (lead_in(load("woosh 5")), 0.05, 0.5), (BASS(4, 0.44), 0.45, 1.0)), -13.9, 0.01, 0.2),
               "C": (mix((pool(755839, 1, thr=-14, maxlen=0.45, hp=80)[0], 0, 1.0), (lead_in(load("swoosh 4")), 0.0, 1.0), (grain("land in dirt 3", 0.08, 0.4, rate=0.7), 0.45, 1.0)), -13.9, 0.01, 0.2)},
 "cre_flare_hit": {"A": (mix((near(634005, 5.56, 0.6, hp=120), 0, 1.0), (grain("land in dirt 3", 0.08, 0.4, rate=0.7), 0.72, 1.0)), -16.8, 0.003, 0.15),
                   "B": (mix((near(832436, 3.66, 0.6, hp=120, rate=0.9), 0, 1.0), (BASS(1, 0.45), 0.72, 0.8)), -16.8, 0.003, 0.15),
                   "C": (mix((grain(485952, 0, 0.67, hp=200), 0, 0.9), (near(634005, 6.56, 0.5, hp=120), 0.12, 1.0), (BASS(5, 0.45), 0.75, 0.7)), -16.8, 0.003, 0.15)},
 "cre_presence_swell": {"A": (dog(), -16.6, 0.15, 0.4),
                        "B": (even(slow(filt(best_window(439216, 4.6), hp=40, lp=1800), 0.8)), -16.6, 0.15, 0.4),
                        "C": (even(slow(filt(best_window(170567, 4.0), hp=40, lp=1800), 0.7)), -16.6, 0.15, 0.4)},
}

# ---- build --------------------------------------------------------------------------------------------------------
SIG_DB = {"gaunt": (-36.1, -35.7, -33.3, -28.0), "scarecrow": (-25.2, -25.4, -25.8, -21.7),
          "boar": (-20.6, -21.5, -21.3, -18.3), "husk": (-20.3, -20.9, -19.3, -19.3)}  # current _01 _02 _03 _chase
CHASE = {"gaunt": "B", "scarecrow": "A", "boar": "A", "husk": "B"}  # the option ranked first per body (handoff)
GAP = np.zeros(int(0.6*R))
BODY_HP = {"gaunt": 150, "scarecrow": 80, "boar": 45, "husk": 300}  # rumble below each body's band (doc 08 s6: coat 90-140 Hz, hoof 60-90 Hz)
def finish(a, db, fi, fo, is_loop=False):
    a = filt(a, hp=15)  # DC and rumble out (FFT filter: circular, so a loop stays seamless)
    if is_loop: return norm(fade(a, 0.001, 0.001), db)  # the loop starts at its quietest 10 ms, so 1 ms fades don't click
    return norm(fade(a, fi, fo), db)
def write(path, a):
    sf.write(path, np.round(a*32767).astype("<i2"), R, subtype="PCM_16")
def report(name, a):
    s = f"{name} {len(a)/R:.3f}s pk{20*np.log10(abs(a).max()):.1f} rms{20*np.log10(np.sqrt((a**2).mean())):.1f} first{a[0]*32767:.0f} last{a[-1]*32767:.0f}"
    if "husk" in name or "cornstand" in name: f, sh = env_peak(a); s += f" env_peak {f:.1f}Hz share14-22 {sh:.2f}"
    print(s, flush=True)
def build(only):
    os.makedirs(OUT, exist_ok=True); os.makedirs(LISTEN, exist_ok=True)
    want = lambda n: not only or any(n.startswith(p) for p in only)
    corn_ref = finish(seg(load(613567), 20.0, 21.75), -20.3, 0.05, 0.1)  # stand-in: no sfx_corn_rustle file exists yet
    for bi, body in enumerate(SIG_DB):
        for oi, o in enumerate("ABC"):
            name = f"cre_{body}_sig_{o}"
            if want(name):
                vs = []
                for v in range(3):
                    a = finish(filt(fit(mix(*sig(body, o, np.random.default_rng(100*bi+10*oi+v))), 1.75), hp=BODY_HP[body]), SIG_DB[body][v], 0.002, 0.08)
                    write(f"{OUT}/cre_{body}_sig_{o}_0{v+1}.wav", a); report(f"cre_{body}_sig_{o}_0{v+1}", a); vs.append(a)
                write(f"{LISTEN}/{body}_sig_{o}.wav", np.concatenate([vs[0], GAP, vs[1], GAP, vs[2]]))
                if body == "husk":
                    write(f"{LISTEN}/husk_vs_corn_rustle_{o}.wav", np.concatenate([x for v in vs for x in (v, GAP, corn_ref, GAP)]))
            if o == CHASE[body] and want(f"cre_{body}_sig_chase"):
                a = finish(filt(loop(sig(body, o, np.random.default_rng(1000+bi), chase=True), 4.0), hp=BODY_HP[body]), SIG_DB[body][3], 0, 0, True)
                write(f"{OUT}/cre_{body}_sig_chase_{o}.wav", a); report(f"cre_{body}_sig_chase_{o}", a)
                write(f"{LISTEN}/{body}_sig_chase_{o}_x3.wav", np.concatenate([a, a, a]))
            if want(f"cre_jumpscare_hit_{body}"):
                a = finish(jumpscare(JUMP[body][o], BASS(oi*2+1), JS_LEN[body]), -9.4, 0.001, 0.3)
                write(f"{OUT}/cre_jumpscare_hit_{body}_{o}.wav", a); report(f"cre_jumpscare_hit_{body}_{o}", a)
                write(f"{LISTEN}/jumpscare_{body}_{o}.wav", a)
    if want("cornstand"): report("cornstand_613567_20s", corn_ref)
    for o in "ABC":
        for name, fn, db, n_s in (("cre_door_bang", door, -13.8, 1.6), ("cre_corn_part", corn, -10.2, 1.0)):
            if not want(name): continue
            vs = []
            for v in range(3):
                a = finish(fit(fn(o, v), n_s), db, 0.001, 0.25 if n_s > 1 else 0.15)
                write(f"{OUT}/{name}_{o}_0{v+1}.wav", a); report(f"{name}_{o}_0{v+1}", a); vs.append(a)
            write(f"{LISTEN}/{name[4:]}_{o}.wav", np.concatenate([vs[0], GAP, vs[1], GAP, vs[2]]))
        for name, opts in ONE.items():
            if not want(name): continue
            a, db, fi, fo = opts[o]
            a = a[max(0, int(np.argmax(abs(a) > 0.01*abs(a).max()))-int(0.004*R)):]  # trim the lead-in below -40 dB re the peak
            a = fit(a, {"cre_gnaw": 2.5, "cre_lunge": 0.89, "cre_flare_hit": 1.2, "cre_presence_swell": 5.69}[name])
            a = finish(a, db, fi, fo)
            write(f"{OUT}/{name}_{o}.wav", a); report(f"{name}_{o}", a); write(f"{LISTEN}/{name[4:]}_{o}.wav", a)
build(sys.argv[1:])

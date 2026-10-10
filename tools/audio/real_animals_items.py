"""D-149 candidates: animals, items, radio and UI sounds rebuilt from real recordings, three options (A, B, C) each.
Sources: the FilmCow Recorded SFX library (D-149) and Freesound CC0 (D-066). Downloads stay outside the repo.
Run Python on the downloads isolated (-I). From the repo root:
  uv run --no-project python -I tools/audio/real_animals_items.py search "<query>"   (CC0 results: id, length, downloads, user, title)
  uv run --no-project python -I tools/audio/real_animals_items.py fetch <id> ...     (page + HQ preview; refuses anything not CC0)
  uv run --no-project --with miniaudio --with numpy --with scipy python -I tools/audio/decode_downloads.py <DL> <DL>/wav
  uv run --no-project --with numpy python -I tools/audio/real_animals_items.py onsets <file.wav|fs id> ...
  uv run --no-project --with numpy python -I tools/audio/real_animals_items.py build [sound_id ...]
build writes logs/listen/real_items/<sound_id>_<A|B|C>[_nn].wav (mono, 48 kHz, 16-bit, peak at most -1 dBFS, RMS matched
to the current assets/audio file) and one CEO listen file per sound, options back to back with 0.8 s gaps, to LISTEN.
It does not touch assets/audio: the CEO picks first (D-149). The helpers come from process_downloads.py (not imported:
importing it would run its build)."""
import sys, os, re, wave, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DL = Path(r"C:\Users\Ockey\fc_dl\fs_items")
FC = Path(r"C:\Users\Ockey\fc_dl\recorded\FilmCow Recorded SFX")
OUT = ROOT / "logs" / "listen" / "real_items"
LISTEN = Path(r"C:\Users\Ockey\Music\ceo_listen\items")
UA = {"User-Agent": "Mozilla/5.0"}


def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()


def search(q):
    u = "https://freesound.org/search/?q=" + urllib.parse.quote_plus(q) + "&f=license%3A%22Creative+Commons+0%22&s=Rating+highest+first"
    h = get(u).decode("utf-8", "replace")
    for m in re.finditer(r'data-mp3="https://cdn\.freesound\.org/previews/\d+/(\d+)_\d+-lq\.mp3".*?data-title="([^"]*)"\s*data-duration="([\d.]+)".*?data-num-downloads="(\d+)".*?href="/people/([^/]+)/sounds/', h, re.S):
        i, t, d, n, user = m.groups()
        print(f"{i:>7} {float(d):6.1f}s {n:>6}dl  {user:24.24} {t}")


def fetch(i):
    pages = DL / "pages"; pages.mkdir(parents=True, exist_ok=True)
    h = get(f"https://freesound.org/s/{i}/").decode("utf-8", "replace")
    (pages / f"p_{i}.html").write_text(h, encoding="utf-8", newline="\n")
    cc0 = "creativecommons.org/publicdomain/zero/1.0" in h
    mp3 = re.search(rf'https://cdn\.freesound\.org/previews/\d+/{i}_\d+-lq\.mp3', h)
    user = re.search(rf'href="/people/([^/]+)/sounds/{i}/"', h)
    title = re.search(r"<h1><a[^>]*>([^<]*)</a></h1>", h)
    desc = re.search(r'twitter:description" content="([^"]*)"', h, re.S)
    remix = re.search(r'data-remix-group="true"', h) is not None or "Sources" in h
    print(f"{i} cc0={cc0} remix_or_sources={remix} user={user and user.group(1)} title={title and title.group(1)!r}")
    print("   desc:", (desc.group(1) if desc else "")[:400].replace("\n", " "))
    if not cc0 or not mp3:
        print("   SKIPPED: not CC0 or no preview"); return
    (DL / f"freesound_{i}.mp3").write_bytes(get(mp3.group(0).replace("-lq.mp3", "-hq.mp3")))


if len(sys.argv) > 1 and sys.argv[1] in ("search", "fetch"):
    import urllib.parse
    for a in sys.argv[2:]:
        search(a) if sys.argv[1] == "search" else fetch(a)
    sys.exit()

import numpy as np
_h = (ROOT / "tools/audio/process_downloads.py").read_text(encoding="utf-8").split("\n# name: (audio")[0]
exec(compile(_h, "process_downloads.py", "exec"))  # R, seg, fade, filt, gate, lead, mix, norm, slow, even, pk, declick


def read(p):  # any PCM wav (16 or 24 bit, mono or stereo) as mono float at R
    with wave.open(str(p)) as w:
        ch, sw, sr, b = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.readframes(w.getnframes())
    if sw == 3:
        u = np.frombuffer(b, np.uint8).reshape(-1, 3).astype(np.int32)
        a = ((u[:, 0] | (u[:, 1] << 8) | (u[:, 2] << 16)) << 8 >> 8) / 8388608.0
    else:
        a = np.frombuffer(b, "<i2") / 32768.0
    a = a.reshape(-1, ch).mean(1)
    assert sr == R, (p, sr)
    return a


def load(i):  # an int is a decoded Freesound id, a str a FilmCow file name without .wav
    return read(DL / "wav" / f"{i}.wav") if isinstance(i, int) else read(FC / f"{i}.wav")


def onsets(i, n=12, gap=0.25):  # the strongest onsets (energy rise) with their peak level, to choose cuts by measurement
    x = load(i); h = 240; m = len(x)//h; e = np.sqrt((x[:m*h].reshape(m, h)**2).mean(1)) + 1e-7
    sc = [(e[k:k+10].max(), k*h/R) for k in range(6, m-2) if e[k] > 2.0*e[max(0, k-8):k-1].mean()]
    picks = []
    for v, t in sorted(sc, reverse=True):
        if all(abs(t-u) > gap for u, _ in picks): picks.append((t, v))
        if len(picks) == n: break
    print(f"{i}: {len(x)/R:.2f}s rms{20*np.log10(np.sqrt((x**2).mean())+1e-9):.1f} pk{20*np.log10(abs(x).max()+1e-9):.1f}")
    for t, v in sorted(picks):
        print(f"   {t:7.2f}s {20*np.log10(v):6.1f} dB")


def cut(i, t0, t1, hp=0, lp=0, rate=None, fi=0.003, fo=0.06):  # a cut, filtered, optional speed change, faded
    a = seg(load(i), t0, t1)
    a = filt(a, hp=hp, lp=lp) if hp or lp else a
    if rate: a = slow(a, rate)
    return fade(a, fi, fo)


def trim(a, db=-45):  # drop leading and trailing samples below db re the peak
    k = np.nonzero(abs(a) > abs(a).max()*10**(db/20))[0]
    return a[max(0, k[0]-int(0.003*R)):k[-1]+1] if len(k) else a


def loop(a, n):  # a seamless loop of n samples: crossfade the tail over the head (equal power over 0.25 s)
    x = int(0.25*R); a = a[:n+x].copy(); t = np.linspace(0, np.pi/2, x)
    a[:x] = a[:x]*np.sin(t) + a[n:n+x]*np.cos(t)
    return a[:n]


def squash(a, db):  # soft-limit peaks to about db above the RMS; memoryless, so a loop seam stays seamless
    t = np.sqrt((a**2).mean())*10**(db/20); return t*np.tanh(a/t)


def rms_db(a): return 20*np.log10(np.sqrt((a**2).mean())+1e-12)


def current(sid):
    return read(ROOT / "assets/audio" / f"{sid}.wav")


# sound -> {option: [(sound_id, audio), ...]}; filled by the recipes below.
B = {}
TRIM = {("cart_squeak_loop", "B"): -6}  # dB below the current file's RMS, from CEO listen notes


def opt(name, o, *pairs): B.setdefault(name, {})[o] = list(pairs)


def finish(sid, a, is_loop=False):  # level to the current file's RMS; loops keep their seam (no fades, no trim)
    if not is_loop:
        a = trim(a); a = a - a.mean(); a = fade(a, 0.002, min(0.08, len(a)/R/4))
    return norm(a, rms_db(current(sid)))


def write(p, a):
    p.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(p), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(R)
        w.writeframes((np.clip(a, -1, 1)*32767).astype("<i2").tobytes())


def build(only):
    recipes()
    gap = np.zeros(int(0.8*R)); short = np.zeros(int(0.35*R))
    for name, opts in B.items():
        if only and name not in only and not any(s in only for o in opts.values() for s, _ in o): continue
        listen = []
        for o in "ABC":
            parts = opts[o]
            for k, (sid, a) in enumerate(parts):
                lp = sid.endswith("_loop"); a = finish(sid, a, lp)*10**(TRIM.get((name, o), 0)/20)
                write(OUT / f"{sid}_{o}.wav", a)
                listen += [np.tile(a, 2) if lp else a, short]  # a loop plays twice to expose the seam
                print(f"{name} {o} {sid}: {len(a)/R:.2f}s rms{rms_db(a):.1f} pk{20*np.log10(abs(a).max()):.1f} first{a[0]*32767:.0f} last{a[-1]*32767:.0f}")
            listen[-1] = gap
        write(LISTEN / f"{name}_ABC.wav", np.concatenate(listen[:-1]))


def one(i, cap, hp=0, lp=0, t0=0.0):  # a single-event file from its first loud sample, filtered, capped with a fade
    a = load(i)[int(t0*R):]; a = lead(a, 0.003)[:int(cap*R)]
    return fade(filt(a, hp=hp, lp=lp) if hp or lp else a, 0.002, min(0.08, cap/4))


def m(*parts):  # mix (audio, delay s, gain), each part peak-normalised first so the gains are relative
    return mix(*[(pk(a, 0), d, g) for a, d, g in parts])


def lp_(sid, a, t0, hp=0, lp=0):  # a seamless loop the length of the current file, cut from t0
    n = len(current(sid)); x = seg(a, t0, t0 + n/R + 0.3)
    return loop(filt(x, hp=hp, lp=lp) if hp or lp else x, n)


def vars_(prefix, cuts):  # numbered variants: [(prefix_01, audio), ...]
    return [(f"{prefix}_{k+1:02d}", a) for k, a in enumerate(cuts)]


def recipes():
    # Animals. Cut times read off spectrograms; each cut is one call (idle) or one alarm run (panic).
    ck = "sfx_animal_chicken"
    opt("animal_chicken", "A", *vars_(ck, [cut(456803, 0.05, 0.95, hp=150), cut(456803, 0.75, 1.75, hp=150), cut(456803, 4.55, 5.35, hp=150)]))
    opt("animal_chicken", "B", *vars_(ck, [cut(316921, 0.4, 0.9, hp=150), cut(316921, 2.2, 3.0, hp=150), cut(316921, 4.15, 5.1, hp=150)]))
    opt("animal_chicken", "C", *vars_(ck, [cut(494613, 1.75, 2.45, hp=150), cut(494613, 4.2, 5.2, hp=150), cut(494613, 7.2, 8.15, hp=150)]))
    opt("animal_chicken_panic", "A", ("sfx_animal_panic_01", cut(316920, 0, 99, hp=150)))
    opt("animal_chicken_panic", "B", ("sfx_animal_panic_01", cut(494613, 0.3, 1.6, hp=150)))
    opt("animal_chicken_panic", "C", ("sfx_animal_panic_01", cut(232495, 4.15, 5.0, hp=150)))
    pg = "sfx_animal_pig"
    opt("animal_pig", "A", *vars_(pg, [cut(158746, 3.0, 3.85, hp=60), cut(158746, 10.25, 11.1, hp=60)]))
    opt("animal_pig", "B", *vars_(pg, [cut(652361, 1.0, 1.9, hp=60), cut(652361, 9.1, 9.9, hp=60)]))
    opt("animal_pig", "C", *vars_(pg, [cut(442906, 0, 99, hp=60), cut(352698, 1.5, 2.2, hp=60)]))
    opt("animal_pig_panic", "A", ("sfx_animal_panic_02", cut(344972, 3.1, 4.3, hp=60)))
    opt("animal_pig_panic", "B", ("sfx_animal_panic_02", cut(260640, 0.0, 1.3, hp=60)))
    opt("animal_pig_panic", "C", ("sfx_animal_panic_02", cut(352698, 2.3, 3.35, hp=60)))
    cw = "sfx_animal_cow"
    opt("animal_cow", "A", *vars_(cw, [cut(163727, 0.25, 2.35, hp=50, lp=3500, fo=0.2), cut(59245, 0, 99, hp=50, lp=4000, fo=0.2)]))
    opt("animal_cow", "B", *vars_(cw, [cut(401636, 0.05, 2.15, hp=50, fo=0.2), cut(401636, 2.15, 3.75, hp=50, fo=0.2)]))
    opt("animal_cow", "C", *vars_(cw, [filt(cut(513565, 2.9, 4.85, hp=90, lp=2500, fo=0.2), lp=2500), filt(cut(513565, 6.9, 9.3, hp=90, lp=2500, fo=0.2), lp=2500)]))
    opt("animal_cow_panic", "A", ("sfx_animal_panic_03", cut(827111, 0.0, 2.7, hp=50, fo=0.25)))
    opt("animal_cow_panic", "B", ("sfx_animal_panic_03", cut(194899, 133.8, 136.3, hp=50, fo=0.25)))
    opt("animal_cow_panic", "C", ("sfx_animal_panic_03", cut(194899, 126.4, 129.4, hp=50, fo=0.25)))
    # Items.
    whoosh = cut(404434, 5.75, 6.3, hp=200)
    opt("flare_shot", "A", ("sfx_flare_shot", m((one(163455, 0.7, hp=30, lp=2500), 0, 1.0), (whoosh, 0.05, 0.6))))
    opt("flare_shot", "B", ("sfx_flare_shot", m((one(151713, 0.75, hp=30), 0, 1.0), (whoosh, 0.08, 0.5))))
    opt("flare_shot", "C", ("sfx_flare_shot", cut(404434, 8.2, 9.4, hp=30, fi=0.001, fo=0.3)))
    sid = "sfx_flare_hiss_loop"
    opt("flare_hiss_loop", "A", (sid, lp_(sid, load(348767), 0.6, hp=150)))
    opt("flare_hiss_loop", "B", (sid, lp_(sid, load(348766), 5.0, hp=150)))
    opt("flare_hiss_loop", "C", (sid, lp_(sid, load(316682), 4.0, hp=150)))
    sid = "sfx_cart_squeak_loop"
    opt("cart_squeak_loop", "A", (sid, lp_(sid, load(635488), 2.5, hp=60)))
    opt("cart_squeak_loop", "B", (sid, squash(lp_(sid, load(577320), 1.95, hp=60), 2)))  # CEO 2026-10-09: "reduce the max sound ... the peak loud sound was too much"
    opt("cart_squeak_loop", "C", (sid, lp_(sid, load(389687), 0.9, hp=60)))
    opt("beartrap_snap", "A", ("sfx_beartrap_snap", cut(644245, 0.78, 1.75, hp=40, fi=0.001, fo=0.25)))
    opt("beartrap_snap", "B", ("sfx_beartrap_snap", one(278203, 0.5, hp=40)))
    opt("beartrap_snap", "C", ("sfx_beartrap_snap", cut(752070, 0.4, 1.0, hp=40, fi=0.001, fo=0.2)))
    opt("pit_fall", "A", ("sfx_pit_fall", m((one("crashing through debris 2", 1.0), 0, 1.0), (one("land in dirt 1", 0.6), 0.45, 1.0))))
    opt("pit_fall", "B", ("sfx_pit_fall", m((one("crashing through debris 1", 0.6), 0, 0.7), (one("land in leaves 2", 0.55), 0.25, 0.9), (one("body fall with lots of bass 3", 0.8), 0.4, 1.0))))
    opt("pit_fall", "C", ("sfx_pit_fall", m((cut(461697, 0.1, 1.3, hp=30), 0, 1.0), (cut(853591, 11.95, 12.6, hp=30), 0.35, 0.9))))
    tick = one("glass clink 1", 0.3, hp=800)
    opt("lantern_blow_out", "A", ("sfx_lantern_blow_out", m((cut(242867, 0.25, 0.8, hp=80), 0, 1.0), (tick, 0.45, 0.25))))
    opt("lantern_blow_out", "B", ("sfx_lantern_blow_out", cut(204531, 2.8, 3.6, hp=80)))
    opt("lantern_blow_out", "C", ("sfx_lantern_blow_out", m((one("air duster 1", 0.44, hp=150), 0, 1.0), (tick, 0.4, 0.25))))
    opt("whistle", "A", ("sfx_whistle", cut(255835, 2.85, 3.8, hp=300, fo=0.1)))
    opt("whistle", "B", ("sfx_whistle", cut(35397, 5.2, 6.5, hp=300, fo=0.12)))
    opt("whistle", "C", ("sfx_whistle", cut(568995, 12.75, 13.7, hp=300, fo=0.1)))
    fs = lambda name, cap, hp, ks: [one(f"{name} {k}", cap, hp=hp) for k in ks]
    opt("step_dirt", "A", *vars_("sfx_step_dirt", fs("footstep dirt", 0.35, 60, range(1, 7))))
    opt("step_dirt", "B", *vars_("sfx_step_dirt", [fade(g, 0, 0.06) for g in grains(452633, 6, 0.33, 60, t1=60)]))
    opt("step_dirt", "C", *vars_("sfx_step_dirt", [fade(g, 0, 0.06) for g in grains(682127, 6, 0.33, 60, t1=3.5, gap=0.2)]))
    opt("step_corn", "A", *vars_("sfx_step_corn", fs("footstep grass and leaves", 0.5, 80, range(1, 7))))
    opt("step_corn", "B", *vars_("sfx_step_corn", fs("footstep leaves", 0.5, 80, range(1, 7))))
    opt("step_corn", "C", *vars_("sfx_step_corn", [fade(g, 0, 0.1) for g in grains(613567, 6, 0.48, 120, t1=38)]))
    opt("step_wood", "A", *vars_("sfx_step_wood", [fade(g, 0, 0.08) for g in grains(543685, 6, 0.38, 50, t1=24)]))
    opt("step_wood", "B", *vars_("sfx_step_wood", [fade(g, 0, 0.08) for g in grains(523273, 6, 0.38, 50, t1=31)]))
    opt("step_wood", "C", *vars_("sfx_step_wood", [fade(g, 0, 0.08) for g in grains(521589, 6, 0.38, 50, t1=2.5, gap=0.2)]))
    opt("emote_cloth", "A", ("sfx_emote_cloth", one("clothes ruffle 1", 0.7, hp=150)))
    opt("emote_cloth", "B", ("sfx_emote_cloth", one("clothing movement 1", 0.7, hp=150)))
    opt("emote_cloth", "C", ("sfx_emote_cloth", one("flag 1", 0.7, hp=150)))
    rg = "sfx_ragdoll_thud"
    opt("ragdoll_thud", "A", *vars_(rg, [one("body fall 1", 0.7, hp=30), one("body fall 2", 0.7, hp=30)]))
    opt("ragdoll_thud", "B", *vars_(rg, [one("body fall with lots of bass 1", 0.7, hp=25), one("body fall with lots of bass 2", 0.7, hp=25)]))
    opt("ragdoll_thud", "C", *vars_(rg, [cut(504626, 0.4, 1.1, hp=30), cut(853591, 10.7, 11.4, hp=30)]))
    # Walkie. Static bands at 300 to 3400 Hz like the old file; the crackle layer is the static's clicks above 1.5 kHz.
    sid = "vox_radio_static_loop"
    opt("radio_static_loop", "A", (sid, lp_(sid, load(154654), 4.5, hp=300, lp=3400)))
    opt("radio_static_loop", "B", (sid, lp_(sid, load(760335), 12.0, hp=300, lp=3400)))
    opt("radio_static_loop", "C", (sid, lp_(sid, load(110739), 20.0, hp=300, lp=3400)))
    sid = "vox_crackle_loop"  # only the clicks: the static's band above 1.5 kHz where it jumps over its own 0.1 s level
    def ck(i, k):
        h = filt(load(i), hp=1500, lp=4000); w = int(0.002*R); sl = int(0.1*R)
        e = np.sqrt(np.convolve(h**2, np.ones(w)/w, "same")); med = np.sqrt(np.convolve(h**2, np.ones(sl)/sl, "same"))
        g = np.convolve((e > k*med).astype(float), np.hanning(int(0.003*R))/np.hanning(int(0.003*R)).sum(), "same")
        return h*np.clip(g*2, 0, 1)
    opt("crackle_loop", "A", (sid, lp_(sid, ck(154654, 1.8), 7.5)))
    opt("crackle_loop", "B", (sid, lp_(sid, ck(316682, 1.8), 4.0)))
    opt("crackle_loop", "C", (sid, lp_(sid, ck(110739, 1.8), 30.0)))
    opt("radio_squelch_on", "A", ("vox_radio_squelch_on", cut(454259, 0.08, 0.34, hp=200, fi=0.001, fo=0.03)))
    opt("radio_squelch_on", "B", ("vox_radio_squelch_on", cut(701314, 0.0, 0.22, hp=200, fi=0.001, fo=0.03)))
    opt("radio_squelch_on", "C", ("vox_radio_squelch_on", cut(612722, 0.62, 0.99, hp=200, fi=0.001, fo=0.03)))
    opt("radio_squelch_off", "A", ("vox_radio_squelch_off", cut(524205, 0.0, 0.22, hp=200, fi=0.001, fo=0.03)))
    opt("radio_squelch_off", "B", ("vox_radio_squelch_off", cut(760245, 0.0, 0.33, hp=200, fi=0.001, fo=0.03)))
    opt("radio_squelch_off", "C", ("vox_radio_squelch_off", cut(47646, 0.0, 0.37, hp=200, fi=0.001, fo=0.03)))
    b3 = one("beep 3", 0.18, hp=200)
    opt("radio_low_battery", "A", ("vox_radio_low_battery", m((b3, 0, 1.0), (b3, 0.3, 1.0))))
    opt("radio_low_battery", "B", ("vox_radio_low_battery", cut(701327, 0.0, 0.42, hp=200, fi=0.001, fo=0.04)))
    opt("radio_low_battery", "C", ("vox_radio_low_battery", cut(701326, 0.0, 0.3, hp=200, fi=0.001, fo=0.04)))
    opt("radio_dead", "A", ("vox_radio_dead", cut("tube tv turn off 1", 0.05, 0.5, hp=100, fi=0.001, fo=0.1)))
    opt("radio_dead", "B", ("vox_radio_dead", m((one("light switch off", 0.3, hp=200), 0, 1.0), (cut(760245, 0.24, 0.3, hp=200, fi=0.001, fo=0.03), 0.015, 0.5))))
    opt("radio_dead", "C", ("vox_radio_dead", cut(454259, 8.45, 8.7, hp=200, rate=0.7, fi=0.001, fo=0.08)))
    # UI.
    opt("ui_click", "A", ("ui_click", one("mouse click 1", 0.1, t0=0.08)))
    opt("ui_click", "B", ("ui_click", one("switch press 1", 0.1, t0=0.36)))
    opt("ui_click", "C", ("ui_click", one("knob clicky turn 1", 0.1, t0=0.18)))
    opt("ui_confirm", "A", ("ui_confirm", one("ding 1", 0.45)))
    opt("ui_confirm", "B", ("ui_confirm", one("glass ding 1", 0.4)))
    opt("ui_confirm", "C", ("ui_confirm", one("clicky button 1", 0.3)))
    opt("ui_deny", "A", ("ui_deny", cut("door knock 1", 0.1, 0.75, fi=0.001, fo=0.12)))
    th = one("punch soft thud 1", 0.2)
    opt("ui_deny", "B", ("ui_deny", m((th, 0, 1.0), (th, 0.15, 0.8))))
    opt("ui_deny", "C", ("ui_deny", one("table hit 1", 0.4, t0=0.1)))
    opt("ui_coins", "A", ("ui_coins", one(847350, 0.5, hp=300)))
    opt("ui_coins", "B", ("ui_coins", one(223343, 0.5, hp=300)))
    opt("ui_coins", "C", ("ui_coins", cut(336481, 0.1, 0.85, hp=300)))
    stamps = [one(470710, 0.45, hp=40, t0=0.4), one(448474, 0.45, hp=40, t0=1.0), one(683031, 0.45, hp=40)]
    for o, s in zip("ABC", stamps): opt("ui_stamp", o, ("ui_stamp", s))
    bells = [one(709925, 0.7, hp=300, t0=1.3), one("glass ding 1", 0.7, hp=300), one("ding 1", 0.7, hp=300)]
    for o, s, b in zip("ABC", stamps, bells): opt("ui_award_reveal", o, ("ui_award_reveal", m((s, 0, 1.0), (b, 0.3, 0.45))))
    opt("ui_shop_bell", "A", ("ui_shop_bell", one(57743, 1.2, hp=300)))
    opt("ui_shop_bell", "B", ("ui_shop_bell", one(192761, 0.93, hp=300)))
    ring = one(709925, 0.6, hp=300, t0=1.3)
    opt("ui_shop_bell", "C", ("ui_shop_bell", m((ring, 0, 1.0), (ring, 0.28, 0.8))))


def spec(paths, t0=0.0, t1=None):  # spectrogram + envelope PNGs (one row per file) for choosing cuts by eye
    import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
    fig, ax = plt.subplots(len(paths), 1, figsize=(16, 2.6*len(paths)), squeeze=False)
    for k, i in enumerate(paths):
        x = (read(i) if str(i).endswith(".wav") else load(i))[int(t0*R):int(t1*R) if t1 else None]
        ax[k, 0].specgram(x + 1e-9, NFFT=1024, Fs=R, noverlap=768, cmap="magma", vmin=-130, xextent=(t0, t0+len(x)/R))
        ax[k, 0].set_ylim(0, 12000); ax[k, 0].set_title(str(i)[-60:], fontsize=8)
        ax[k, 0].set_xticks(np.arange(np.ceil(t0*10)/10, t0+len(x)/R, 0.1 if len(x)/R < 4 else 0.5), minor=False)
        ax[k, 0].tick_params(labelsize=6); ax[k, 0].grid(axis="x", alpha=0.3)
    fig.tight_layout(); p = OUT / "spec" / "view.png"; p.parent.mkdir(parents=True, exist_ok=True); fig.savefig(p, dpi=70); print(p)


if __name__ == "__main__":
    if sys.argv[1] == "spec":  # spec <t0> <t1> <id|name|file.wav> ...  (t1 0 = to the end)
        spec([int(a) if a.isdigit() else a for a in sys.argv[4:]], float(sys.argv[2]), float(sys.argv[3]) or None)
    elif sys.argv[1] == "onsets":
        for a in sys.argv[2:]: onsets(int(a) if a.isdigit() else a)
    elif sys.argv[1] == "build":
        build(set(sys.argv[2:]))

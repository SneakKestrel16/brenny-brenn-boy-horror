"""P4-17: writes the Phase 4 SuperCollider sources (assets/audio/src/<id>.scd) from templates (doc 08 s12.1 item 4).
Run: uv run tools/audio/gen_p4.py   then   uv run tools/audio/render.py <ids> --spectrogram
Plain @NAME@ substitution (SuperCollider code is full of braces). Every sound is a placeholder."""
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "assets" / "audio" / "src"

# --- templates: header comment, then the Event. @X@ values come from the V rows below. ---------------------------
T = {}

T["gaunt"] = """// @ID@ (placeholder). Gaunt lurk signature variant: sparse dry tongue/joint clicks, @G0@ to @G1@ s apart, each with a
// short hollow ~220 Hz knock (doc 08 section 6). Mono, 3D, 1.75 s, last click before 1.5 s.
(
var times = List.new, t = 0.1;
thisThread.randSeed = @SEED@;
while { t < 1.5 } { times.add(t); t = t + rrand(@G0@, @G1@) };
(
	channels: 1,
	duration: 1.75,
	defs: [
		SynthDef(\\click, { |out = 0, freq = 2600, amp = 0.7, knock = 220|
			var env = EnvGen.ar(Env.perc(0.0003, 0.003), doneAction: 2);
			var tick = BPF.ar(WhiteNoise.ar, freq, 0.35) * env * 7;
			var hollow = SinOsc.ar(knock) * EnvGen.ar(Env.perc(0.001, 0.035)) * 0.25;
			Out.ar(out, (tick + hollow) * amp);
		})
	],
	events: times.collect { |tt| [tt, [\\s_new, \\click, -1, 0, 0, \\freq, rrand(1800, 3400), \\amp, rrand(0.4, 0.9), \\knock, rrand(200, 245)]] }
)
)
"""

T["scarecrow"] = """// @ID@ (placeholder). Scarecrow lurk signature variant: slow heavy cloth flaps, @G0@ to @G1@ s apart, 90 to 140 Hz body
// (doc 08 section 6). Mono, 3D, 1.75 s, last flap ends before 1.7 s.
(
var times = List.new, t = 0.1;
thisThread.randSeed = @SEED@;
while { t < 1.3 } { times.add(t); t = t + rrand(@G0@, @G1@) };
(
	channels: 1,
	duration: 1.75,
	defs: [
		SynthDef(\\flap, { |out = 0, body = 110, len = 0.12, amp = 0.8|
			var env = EnvGen.ar(Env.perc(0.004, len, curve: -4), doneAction: 2);
			var cloth = LPF.ar(BPF.ar(WhiteNoise.ar, 700, 0.8) + (PinkNoise.ar * 0.4), 1800) * env * 3;
			var snap = HPF.ar(WhiteNoise.ar, 2500) * EnvGen.ar(Env.perc(0.001, 0.012)) * 0.25;
			var thud = SinOsc.ar(body) * EnvGen.ar(Env.perc(0.004, 0.1)) * 0.6;
			Out.ar(out, (cloth + snap + thud) * amp);
		})
	],
	events: times.collect { |tt| [tt, [\\s_new, \\flap, -1, 0, 0, \\body, rrand(90, 140), \\len, rrand(0.09, 0.2), \\amp, rrand(0.6, 0.85)]] }
)
)
"""

T["boar"] = """// @ID@ (placeholder). Boar lurk signature variant: the iron collar chain dragging, one drag about @P@ s apart
// (1.2 per s), a hoof thud of 60 to 90 Hz under each (doc 08 section 6). Mono, 3D, 1.75 s.
(
thisThread.randSeed = @SEED@;
(
	channels: 1,
	duration: 1.75,
	defs: [
		SynthDef(\\drag, { |out = 0, thud = 75, len = 0.45, amp = 0.8|
			var hoof = SinOsc.ar(thud * (1 + (EnvGen.ar(Env.perc(0, 0.04)) * 0.6))) * EnvGen.ar(Env.perc(0.002, 0.14, curve: -5)) * 0.9;
			var ex = (Dust.ar(40) * 3) + (WhiteNoise.ar * EnvGen.ar(Env.perc(0.001, 0.02)));
			var ring = Klank.ar(`[[720, 1180, 1960, 2900, 3900], [1, 0.8, 0.6, 0.4, 0.3], [0.25, 0.2, 0.18, 0.15, 0.12]], ex * 0.1)
				* EnvGen.ar(Env([1, 1, 0], [len * 0.7, len * 0.3]));
			var scrape = BPF.ar(WhiteNoise.ar, LFNoise1.kr(9).range(1800, 3200), 0.4)
				* EnvGen.ar(Env([0, 1, 0.6, 0], [0.02, len * 0.5, len * 0.5], -3), doneAction: 2) * 0.9;
			Out.ar(out, (hoof + ring + scrape) * amp);
		})
	],
	events: [0.1, 0.1 + @P@].collect { |tt| [tt, [\\s_new, \\drag, -1, 0, 0, \\thud, rrand(60, 90), \\len, rrand(0.35, 0.55), \\amp, rrand(0.7, 0.9)]] }
)
)
"""

T["husk"] = """// @ID@ (placeholder). Husk lurk signature variant: three short bursts of the dry pulsed rattle at @RATE@ pulses per s
// (inside 14 to 22 Hz), 4 to 7 kHz pods over a hollow 800 Hz resonance. NOT corn rustle (doc 08 section 6).
// Mono, 3D, 1.75 s, bursts at 0.05, 0.6 and 1.1 s, each 0.55 s.
(
(
	channels: 1,
	duration: 1.75,
	defs: [
		SynthDef(\\rattle, { |out = 0, rate = 18, amp = 0.8|
			var burst = EnvGen.ar(Env([0, 1, 1, 0], [0.04, 0.4, 0.11]), doneAction: 2);
			var pulse = Decay2.kr(Impulse.kr(rate), 0.001, 0.025);
			var pods = BPF.ar(WhiteNoise.ar, LFNoise1.kr(rate).range(4000, 7000), 0.25) * pulse.min(1) * 14;
			var hollow = Resonz.ar(WhiteNoise.ar, 800, 0.08) * pulse.min(1) * 10;
			Out.ar(out, (pods + hollow) * burst * amp * 0.5);
		})
	],
	events: [0.05, 0.6, 1.1].collect { |tt, i| [tt, [\\s_new, \\rattle, -1, 0, 0, \\rate, @RATE@ + [0, 1, -1][i], \\amp, [0.8, 0.9, 0.7][i]]] }
)
)
"""

T["cart"] = """// sfx_cart_squeak_loop (placeholder). The festival cart's wheel: a 600 to 720 Hz squeak with a wobble and a chassis
// rattle, one cycle every 0.75 s, four cycles, 3 s loop. Each squeak ends 0.6 s into its cycle so the seam is quiet.
// The game plays it faster with more pushers (pitch_scale, doc 01 "The Harvest Moon"). Mono, 3D. Doc 08 section 11.2.
(
thisThread.randSeed = 77;
(
	channels: 1,
	duration: 3,
	defs: [
		SynthDef(\\squeak, { |out = 0, f0 = 640, amp = 0.7|
			var env = EnvGen.ar(Env([0, 1, 0.75, 0], [0.04, 0.32, 0.2]), doneAction: 2);
			var f = XLine.kr(f0, f0 * 1.12, 0.56) + (SinOsc.kr(13) * 18);
			var tone = (SinOsc.ar(f) + (SinOsc.ar(f * 2.01) * 0.3)) * env * 0.6;
			var rattle = BPF.ar(WhiteNoise.ar, 900, 0.5) * Decay2.kr(Dust.kr(30), 0.001, 0.02).min(1) * env * 4;
			var clunk = SinOsc.ar(85 * (1 + EnvGen.ar(Env.perc(0, 0.03)))) * EnvGen.ar(Env.perc(0.003, 0.09, curve: -5)) * 0.6;
			Out.ar(out, (tone + (rattle * 0.5) + clunk) * amp);
		})
	],
	events: 4.collect { |i| [i * 0.75, [\\s_new, \\squeak, -1, 0, 0, \\f0, rrand(610, 690), \\amp, rrand(0.65, 0.8)]] }
)
)
"""

T["gnaw"] = """// cre_gnaw (placeholder). Something gnawing a pumpkin: four groups of wet crunches, 60 to 120 ms apart inside a group,
// each a bright crack, a low wet thump and a short slurp. Mono, 3D, 2.5 s, last crunch before 2.2 s. Doc 08 section 11.4.
(
var times = List.new, t = 0.1;
thisThread.randSeed = 91;
4.do {
	rrand(3, 5).do { times.add(t); t = t + rrand(0.06, 0.12) };
	t = t + rrand(0.25, 0.4);
};
(
	channels: 1,
	duration: 2.5,
	defs: [
		SynthDef(\\crunch, { |out = 0, amp = 0.7, f = 2200|
			var crack = BPF.ar(WhiteNoise.ar, f, 0.8) * EnvGen.ar(Env.perc(0.002, 0.05, curve: -4), doneAction: 2) * 4;
			var wet = BPF.ar(PinkNoise.ar, 900, 0.5) * EnvGen.ar(Env.perc(0.01, 0.09, curve: -3)) * 2;
			var thump = LPF.ar(BrownNoise.ar, 300) * EnvGen.ar(Env.perc(0.003, 0.07)) * 2;
			Out.ar(out, (crack + wet + thump) * amp);
		})
	],
	events: times.select { |tt| tt < 2.3 }.collect { |tt| [tt, [\\s_new, \\crunch, -1, 0, 0, \\amp, rrand(0.5, 0.9), \\f, rrand(1500, 3200)]] }
)
)
"""

T["flare_shot"] = """// sfx_flare_shot (placeholder). A flare pistol: a flat bang (noise burst + 70 Hz boom), then a rising whoosh as the
// flare climbs. Mono, 3D, 1.2 s. The loudest noise on the farm (doc 01 "Warden"; doc 08 section 3.2). Doc 08 section 11.2.
(
(
	channels: 1,
	duration: 1.2,
	defs: [
		SynthDef(\\shot, { |out = 0|
			var bang = LPF.ar(WhiteNoise.ar, 4500) * EnvGen.ar(Env.perc(0.0005, 0.14, curve: -5)) * 1.6;
			var boom = SinOsc.ar(XLine.kr(110, 45, 0.25)) * EnvGen.ar(Env.perc(0.001, 0.3, curve: -4)) * 1.2;
			var wh = BPF.ar(PinkNoise.ar, XLine.kr(500, 3500, 0.9), 0.7) * EnvGen.ar(Env([0, 0, 1, 0.5, 0], [0.04, 0.3, 0.4, 0.4]), doneAction: 2) * 2;
			Out.ar(out, bang + boom + wh);
		})
	],
	events: [[0, [\\s_new, \\shot, -1, 0, 0]]]
)
)
"""

T["flare_hiss"] = """// sfx_flare_hiss_loop (placeholder). A burning flare: steady bright hiss with sparse pops. Stationary noise (constant
// level, no slow changes), so any whole length loops: 2 s. Mono, 3D. Doc 08 section 11.2.
(
(
	channels: 1,
	duration: 2,
	defs: [
		SynthDef(\\hiss, { |out = 0|
			var hiss = HPF.ar(PinkNoise.ar, 2500) * 0.8;
			var bright = BPF.ar(WhiteNoise.ar, 7000, 0.6) * 0.5;
			var pops = HPF.ar(Decay2.ar(Dust.ar(35), 0.0005, 0.01), 1500) * 1.2;
			Out.ar(out, hiss + bright + pops);
		})
	],
	events: [[0, [\\s_new, \\hiss, -1, 0, 0]]]
)
)
"""

T["flare_hit"] = """// cre_flare_hit (placeholder). The creature struck by a flare: a falling shriek (2.2 kHz down to 350 Hz with a fast
// wobble, a 1.8 kHz formant and breath), then a stomp at 0.75 s. Synthetic, never a voice. Mono, 3D, 1.2 s.
// Plays at the start of Retreat (doc 01 "Store" flare gun). Doc 08 section 11.4.
(
(
	channels: 1,
	duration: 1.2,
	defs: [
		SynthDef(\\shriek, { |out = 0|
			var f = XLine.kr(2200, 350, 0.7) * (1 + (SinOsc.kr(28) * 0.04));
			var env = EnvGen.ar(Env([0, 1, 0.8, 0], [0.03, 0.45, 0.25]), doneAction: 2);
			var tone = Saw.ar(f) + Pulse.ar(f * 1.01, 0.3);
			var voiced = BPF.ar(tone, 1800, 0.5) * env * 0.6;
			var breath = BPF.ar(WhiteNoise.ar, 3000, 0.4) * env * 0.35;
			Out.ar(out, voiced + breath);
		}),
		SynthDef(\\stomp, { |out = 0|
			var body = SinOsc.ar(XLine.kr(120, 40, 0.15)) * EnvGen.ar(Env.perc(0.002, 0.3, curve: -5), doneAction: 2);
			var dirt = LPF.ar(WhiteNoise.ar, 900) * EnvGen.ar(Env.perc(0.001, 0.08)) * 0.8;
			Out.ar(out, (body + dirt) * 0.9);
		})
	],
	events: [[0, [\\s_new, \\shriek, -1, 0, 0]], [0.75, [\\s_new, \\stomp, -1, 0, 0]]]
)
)
"""

T["sq_on"] = """// vox_radio_squelch_on (placeholder). Walkie key-up: a 60 ms band-passed noise burst under a rising 1 to 1.8 kHz chirp.
// Mono, local. 0.2 s. Doc 08 sections 7.2, 11.6.
(
(
	channels: 1,
	duration: 0.2,
	defs: [
		SynthDef(\\sq, { |out = 0|
			var n = BPF.ar(WhiteNoise.ar, 1800, 0.5) * EnvGen.ar(Env([0, 1, 0.4, 0], [0.004, 0.05, 0.05]), doneAction: 2) * 1.6;
			var c = SinOsc.ar(XLine.kr(1000, 1800, 0.05)) * EnvGen.ar(Env.perc(0.003, 0.05)) * 0.5;
			Out.ar(out, n + c);
		})
	],
	events: [[0, [\\s_new, \\sq, -1, 0, 0]]]
)
)
"""

T["sq_off"] = """// vox_radio_squelch_off (placeholder). Walkie key-down: a falling 1.8 to 900 Hz chirp, then a 100 ms noise tail that
// dies away (the carrier dropping). Mono, local. 0.2 s. Doc 08 sections 7.2, 11.6.
(
(
	channels: 1,
	duration: 0.2,
	defs: [
		SynthDef(\\sq, { |out = 0|
			var c = SinOsc.ar(XLine.kr(1800, 900, 0.04)) * EnvGen.ar(Env.perc(0.002, 0.04)) * 0.5;
			var n = BPF.ar(WhiteNoise.ar, 1500, 0.5) * EnvGen.ar(Env([0, 1, 0.3, 0], [0.002, 0.03, 0.09]), doneAction: 2) * 1.4;
			Out.ar(out, n + c);
		})
	],
	events: [[0, [\\s_new, \\sq, -1, 0, 0]]]
)
)
"""

T["low_batt"] = """// vox_radio_low_battery (placeholder). Two flat 1.2 kHz beeps, 90 ms each, 250 ms apart. Mono, local. 0.6 s.
// Doc 08 sections 7.2, 11.6.
(
(
	channels: 1,
	duration: 0.6,
	defs: [
		SynthDef(\\beep, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 1, 0], [0.005, 0.08, 0.01]), doneAction: 2);
			Out.ar(out, (SinOsc.ar(1200) + (SinOsc.ar(2400) * 0.15)) * env * 0.6);
		})
	],
	events: [0, 0.25].collect { |t| [t, [\\s_new, \\beep, -1, 0, 0]] }
)
)
"""

T["dead"] = """// vox_radio_dead (placeholder). The walkie dying: a click, then a short falling tone and a gasp of static. Mono, local.
// 0.2 s. Doc 08 sections 7.2, 11.6.
(
(
	channels: 1,
	duration: 0.2,
	defs: [
		SynthDef(\\dead, { |out = 0|
			var click = HPF.ar(WhiteNoise.ar, 1500) * EnvGen.ar(Env.perc(0.0003, 0.004)) * 1.5;
			var fall = SinOsc.ar(XLine.kr(900, 200, 0.12)) * EnvGen.ar(Env.perc(0.004, 0.1)) * 0.5;
			var gasp = BPF.ar(WhiteNoise.ar, 1400, 0.6) * EnvGen.ar(Env.perc(0.01, 0.1), doneAction: 2) * 0.5;
			Out.ar(out, click + fall + gasp);
		})
	],
	events: [[0, [\\s_new, \\dead, -1, 0, 0]]]
)
)
"""

T["radio_static"] = """// vox_radio_static_loop (placeholder). The walkie's carrier hiss while the creature is near (doc 01 "Walkie-talkies":
// "static when the creature is near"): noise band-limited to 300 to 3400 Hz (a small speaker), an upper hiss and dense
// crackle (about 28 pops per s, the proximity crackle at higher density). Stationary, so 4 s loops. Mono, local.
// Doc 08 sections 7.2, 11.6.
(
(
	channels: 1,
	duration: 4,
	defs: [
		SynthDef(\\static, { |out = 0|
			var band = BPF.ar(PinkNoise.ar, 1300, 0.9) * 1.4;
			var hiss = HPF.ar(WhiteNoise.ar, 3000) * 0.18;
			var pops = BPF.ar(Decay2.ar(Dust.ar(28), 0.0005, 0.008), 2200, 0.7) * 3;
			Out.ar(out, HPF.ar(LPF.ar(band + hiss + pops, 3400), 300));
		})
	],
	events: [[0, [\\s_new, \\static, -1, 0, 0]]]
)
)
"""

T["chicken"] = """// @ID@ (placeholder). A hen's cluck group: @N@ clucks, each a short falling 700-ish Hz buzz through a 1.4 kHz formant.
// Mono, 3D, @DUR@ s. Species are inference (doc 08 section 11.1). Doc 08 section 11.1.
(
thisThread.randSeed = @SEED@;
(
	channels: 1,
	duration: @DUR@,
	defs: [
		SynthDef(\\cluck, { |out = 0, f = 700, amp = 0.7|
			var env = EnvGen.ar(Env([0, 1, 0.6, 0], [0.008, 0.04, 0.05]), doneAction: 2);
			var src = Saw.ar(XLine.kr(f * 1.2, f * 0.7, 0.09) * (1 + (SinOsc.kr(45) * 0.05)));
			Out.ar(out, (BPF.ar(src, 1400, 0.35) * 2 + (BPF.ar(WhiteNoise.ar, 2500, 0.5) * 0.12)) * env * amp);
		})
	],
	events: (0..@N@ - 1).collect { |i| [0.05 + (i * rrand(0.13, 0.2)), [\\s_new, \\cluck, -1, 0, 0, \\f, rrand(@F0@, @F1@), \\amp, rrand(0.5, 0.8)]] }
)
)
"""

T["pig"] = """// @ID@ (placeholder). A pig's grunt: two low 'oink' phrases, a 90 to 130 Hz pulsed voice rising then falling through
// 450 and 1100 Hz formants, with a nasal noise edge. Mono, 3D, 1 s. Doc 08 section 11.1 (pig replaces the sheep: P4-08).
(
thisThread.randSeed = @SEED@;
(
	channels: 1,
	duration: 1,
	defs: [
		SynthDef(\\oink, { |out = 0, f = 105, amp = 0.7, len = 0.22|
			var env = EnvGen.ar(Env([0, 1, 0.8, 0], [0.02, len * 0.5, len * 0.5]), doneAction: 2);
			var pitch = f * Env([0.85, 1.25, 0.8], [len * 0.4, len * 0.6]).kr;
			var src = Pulse.ar(pitch, 0.3) + (Saw.ar(pitch * 0.5) * 0.5);
			var voiced = (Resonz.ar(src, 450, 0.25) * 3 + (Resonz.ar(src, 1100, 0.2) * 2)) * env;
			var nasal = BPF.ar(PinkNoise.ar, 1800, 0.4) * env * 0.25;
			Out.ar(out, (voiced + nasal) * amp);
		})
	],
	events: [[0.05, [\\s_new, \\oink, -1, 0, 0, \\f, rrand(@F0@, @F1@), \\len, 0.22]], [0.4, [\\s_new, \\oink, -1, 0, 0, \\f, rrand(@F0@, @F1@) * 0.92, \\len, 0.3, \\amp, 0.6]]]
)
)
"""

T["cow"] = """// @ID@ (placeholder). A cow's low moo: a 100 to 125 Hz voice with a slow formant glide (400 to 720 Hz) and breath,
// swelling over 0.3 s and trailing off. Mono, 3D, 2 s. Doc 08 section 11.1.
(
thisThread.randSeed = @SEED@;
(
	channels: 1,
	duration: 2,
	defs: [
		SynthDef(\\moo, { |out = 0, f = 115|
			var env = EnvGen.ar(Env([0, 1, 0.9, 0], [0.3, 0.9, 0.6]), doneAction: 2);
			var pitch = f * XLine.kr(1.1, 0.88, 1.6) * (1 + (SinOsc.kr(5) * 0.015));
			var src = Saw.ar(pitch) + (Pulse.ar(pitch * 2.003, 0.4) * 0.3);
			var form = XLine.kr(400, 720, 0.7);
			var voiced = (Resonz.ar(src, form, 0.2) * 4 + (Resonz.ar(src, form * 2.2, 0.25) * 2)) * env;
			var breath = BPF.ar(PinkNoise.ar, 600, 0.6) * env * 0.4;
			Out.ar(out, (voiced + breath) * 0.8);
		})
	],
	events: [[0.05, [\\s_new, \\moo, -1, 0, 0, \\f, rrand(@F0@, @F1@)]]]
)
)
"""

T["panic_chicken"] = """// sfx_animal_panic_01 (placeholder). A hen's alarm: a rapid burst of high squawks, 900 to 1300 Hz, 7 in 0.8 s.
// Mono, 3D, 1 s. Animals react before the creature arrives (doc 01 "Daytime Threats"). Doc 08 section 11.1.
(
thisThread.randSeed = 31;
(
	channels: 1,
	duration: 1,
	defs: [
		SynthDef(\\squawk, { |out = 0, f = 1000, amp = 0.7|
			var env = EnvGen.ar(Env([0, 1, 0.7, 0], [0.006, 0.05, 0.05]), doneAction: 2);
			var src = Saw.ar(XLine.kr(f * 1.25, f * 0.75, 0.1) * (1 + (SinOsc.kr(60) * 0.06)));
			Out.ar(out, (BPF.ar(src, 1800, 0.3) * 2 + (BPF.ar(WhiteNoise.ar, 3500, 0.5) * 0.15)) * env * amp);
		})
	],
	events: 7.collect { |i| [0.03 + (i * rrand(0.09, 0.13)), [\\s_new, \\squawk, -1, 0, 0, \\f, rrand(900, 1300), \\amp, rrand(0.55, 0.9)]] }
)
)
"""

T["panic_pig"] = """// sfx_animal_panic_02 (placeholder). A pig's squeal: a 700 to 1500 Hz voice sweeping up and down with a fast tremor
// through a 2 kHz formant, 0.8 s. Mono, 3D, 1 s. Doc 08 section 11.1.
(
(
	channels: 1,
	duration: 1,
	defs: [
		SynthDef(\\squeal, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 0.9, 0], [0.04, 0.5, 0.25]), doneAction: 2);
			var f = Env([700, 1500, 1100, 1400, 800], [0.15, 0.2, 0.2, 0.25], \\sin).kr * (1 + (SinOsc.kr(32) * 0.03));
			var src = Saw.ar(f) + Pulse.ar(f * 1.005, 0.2);
			var voiced = BPF.ar(src, 2000, 0.35) * env * 1.2;
			var breath = BPF.ar(WhiteNoise.ar, 4000, 0.4) * env * 0.12;
			Out.ar(out, (voiced + breath) * 0.8);
		})
	],
	events: [[0.03, [\\s_new, \\squeal, -1, 0, 0]]]
)
)
"""

T["panic_cow"] = """// sfx_animal_panic_03 (placeholder). A cow's alarmed bellow: higher (170 to 210 Hz), louder and shorter than the moo, with
// a fast tremolo and a rising formant. Mono, 3D, 1 s. Doc 08 section 11.1.
(
(
	channels: 1,
	duration: 1,
	defs: [
		SynthDef(\\bellow, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 0.8, 0], [0.06, 0.5, 0.3]), doneAction: 2);
			var pitch = XLine.kr(170, 210, 0.3) * (1 + (SinOsc.kr(7) * 0.03));
			var src = Saw.ar(pitch) + (Pulse.ar(pitch * 2.004, 0.4) * 0.35);
			var form = XLine.kr(500, 900, 0.5);
			var voiced = (Resonz.ar(src, form, 0.2) * 5 + (Resonz.ar(src, form * 2.3, 0.25) * 2.5)) * env * (0.8 + (SinOsc.kr(14) * 0.2));
			var breath = BPF.ar(PinkNoise.ar, 900, 0.6) * env * 0.4;
			Out.ar(out, (voiced + breath) * 0.8);
		})
	],
	events: [[0.03, [\\s_new, \\bellow, -1, 0, 0]]]
)
)
"""

T["ui_click"] = """// ui_click (placeholder). A short wood tick: a 1.9 kHz band-limited noise tick over a 700 Hz knock. Mono, UI, 0.1 s.
// Doc 08 section 11.5.
(
(
	channels: 1,
	duration: 0.1,
	defs: [
		SynthDef(\\tick, { |out = 0|
			var tick = BPF.ar(WhiteNoise.ar, 1900, 0.6) * EnvGen.ar(Env.perc(0.0005, 0.012), doneAction: 2) * 3;
			var knock = SinOsc.ar(700) * EnvGen.ar(Env.perc(0.001, 0.03)) * 0.5;
			Out.ar(out, tick + knock);
		})
	],
	events: [[0, [\\s_new, \\tick, -1, 0, 0]]]
)
)
"""

T["ui_confirm"] = """// ui_confirm (placeholder). A soft up-chirp, 600 to 1000 Hz in 90 ms, with a quiet octave, then a short fade. Mono, UI,
// 0.25 s. Used for buying at the store (doc 02 section 10). Doc 08 section 11.5.
(
(
	channels: 1,
	duration: 0.25,
	defs: [
		SynthDef(\\chirp, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 0.5, 0], [0.01, 0.07, 0.12]), doneAction: 2);
			var f = XLine.kr(600, 1000, 0.09);
			Out.ar(out, (SinOsc.ar(f) + (SinOsc.ar(f * 2) * 0.2)) * env * 0.6);
		})
	],
	events: [[0, [\\s_new, \\chirp, -1, 0, 0]]]
)
)
"""

T["ui_deny"] = """// ui_deny (placeholder). Two low down-chirps, 420 to 260 Hz, 110 ms each, through a low-pass (can't afford it, gated).
// Mono, UI, 0.35 s. Doc 08 section 11.5.
(
(
	channels: 1,
	duration: 0.35,
	defs: [
		SynthDef(\\buzz, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 0.8, 0], [0.006, 0.08, 0.025]), doneAction: 2);
			var f = XLine.kr(420, 260, 0.11);
			Out.ar(out, LPF.ar(Saw.ar(f) + SinOsc.ar(f), 1400) * env * 0.5);
		})
	],
	events: [0, 0.16].collect { |t| [t, [\\s_new, \\buzz, -1, 0, 0]] }
)
)
"""

T["ui_coins"] = """// ui_coins (placeholder). A cascade of five coin ticks (resonators at 3.1 to 4.8 kHz), spread over 0.3 s: money paid or
// earned. Mono, UI, 0.5 s. Doc 08 section 11.2.
(
thisThread.randSeed = 63;
(
	channels: 1,
	duration: 0.5,
	defs: [
		SynthDef(\\coin, { |out = 0, base = 3300, amp = 0.6|
			var ex = WhiteNoise.ar * EnvGen.ar(Env.perc(0.0003, 0.004), doneAction: 2);
			Out.ar(out, Klank.ar(`[[base, base * 1.51, base * 2.08], [1, 0.6, 0.35], [0.09, 0.07, 0.05]], ex * 0.2) * amp);
		})
	],
	events: 5.collect { |i| [i * 0.07 + rrand(0, 0.02), [\\s_new, \\coin, -1, 0, 0, \\base, rrand(3100, 4800), \\amp, rrand(0.45, 0.8)]] }
)
)
"""

T["ui_stamp"] = """// ui_stamp (placeholder). A rubber stamp on paper: a 110 Hz thump dropping to 50 Hz, a short paper-noise slap
// (low-passed 1.2 kHz). Mono, UI, 0.4 s. Doc 08 section 11.5.
(
(
	channels: 1,
	duration: 0.4,
	defs: [
		SynthDef(\\stamp, { |out = 0|
			var thump = SinOsc.ar(XLine.kr(110, 50, 0.1)) * EnvGen.ar(Env.perc(0.002, 0.18, curve: -4), doneAction: 2) * 1.1;
			var slap = LPF.ar(WhiteNoise.ar, 1200) * EnvGen.ar(Env.perc(0.001, 0.05)) * 0.9;
			var paper = HPF.ar(PinkNoise.ar, 2500) * EnvGen.ar(Env.perc(0.004, 0.09)) * 0.15;
			Out.ar(out, thump + slap + paper);
		})
	],
	events: [[0, [\\s_new, \\stamp, -1, 0, 0]]]
)
)
"""

T["ui_award"] = """// ui_award_reveal (placeholder). A Season Award card revealed: a stamp, then one warm 660 Hz bell tick (decaying
// partials, not a melody: no music, doc 08 section 2.1). Mono, UI, 1 s. Doc 08 section 11.5.
(
(
	channels: 1,
	duration: 1,
	defs: [
		SynthDef(\\stamp, { |out = 0|
			var thump = SinOsc.ar(XLine.kr(110, 50, 0.1)) * EnvGen.ar(Env.perc(0.002, 0.18, curve: -4), doneAction: 2);
			var slap = LPF.ar(WhiteNoise.ar, 1200) * EnvGen.ar(Env.perc(0.001, 0.05)) * 0.8;
			Out.ar(out, thump + slap);
		}),
		SynthDef(\\bell, { |out = 0|
			var ex = WhiteNoise.ar * EnvGen.ar(Env.perc(0.0005, 0.006), doneAction: 2);
			Out.ar(out, Klank.ar(`[[660, 1320, 1981, 2680], [1, 0.5, 0.3, 0.15], [0.7, 0.45, 0.3, 0.2]], ex * 0.25) * 0.8);
		})
	],
	events: [[0, [\\s_new, \\stamp, -1, 0, 0]], [0.18, [\\s_new, \\bell, -1, 0, 0]]]
)
)
"""

T["shop_bell"] = """// ui_shop_bell (placeholder). The town stand's door bell: one small brass ding (resonators at 2.1, 3.3 and 4.7 kHz)
// with a quick second strike. Mono, UI, 0.9 s. Doc 08 section 11.2.
(
(
	channels: 1,
	duration: 0.9,
	defs: [
		SynthDef(\\ding, { |out = 0, amp = 0.7|
			var ex = WhiteNoise.ar * EnvGen.ar(Env.perc(0.0003, 0.004), doneAction: 2);
			Out.ar(out, Klank.ar(`[[2100, 3340, 4710, 5900], [1, 0.6, 0.35, 0.2], [0.55, 0.4, 0.3, 0.2]], ex * 0.25) * amp);
		})
	],
	events: [[0, [\\s_new, \\ding, -1, 0, 0]], [0.11, [\\s_new, \\ding, -1, 0, 0, \\amp, 0.45]]]
)
)
"""

# --- which files to write: (id, template, substitutions) -------------------------------------------------------------
V = []
for n, (seed, g0, g1) in enumerate([(51, 0.3, 0.6), (52, 0.4, 0.8), (53, 0.25, 0.5)], 1):
    V.append((f"cre_gaunt_sig_{n:02d}", "gaunt", dict(SEED=seed, G0=g0, G1=g1)))
for n, (seed, g0, g1) in enumerate([(61, 0.5, 0.8), (62, 0.6, 0.9), (63, 0.45, 0.7)], 1):
    V.append((f"cre_scarecrow_sig_{n:02d}", "scarecrow", dict(SEED=seed, G0=g0, G1=g1)))
for n, (seed, p) in enumerate([(71, 0.83), (72, 0.75), (73, 0.9)], 1):
    V.append((f"cre_boar_sig_{n:02d}", "boar", dict(SEED=seed, P=p)))
for n, rate in enumerate([18, 15, 21], 1):
    V.append((f"cre_husk_sig_{n:02d}", "husk", dict(RATE=rate)))
V += [("sfx_cart_squeak_loop", "cart", {}), ("cre_gnaw", "gnaw", {}), ("sfx_flare_shot", "flare_shot", {}),
      ("sfx_flare_hiss_loop", "flare_hiss", {}), ("cre_flare_hit", "flare_hit", {}),
      ("vox_radio_squelch_on", "sq_on", {}), ("vox_radio_squelch_off", "sq_off", {}),
      ("vox_radio_low_battery", "low_batt", {}), ("vox_radio_dead", "dead", {}), ("vox_radio_static_loop", "radio_static", {})]
for n, (seed, cnt, f0, f1, dur) in enumerate([(81, 3, 650, 750, 0.7), (82, 2, 600, 700, 0.5), (83, 4, 700, 820, 0.9)], 1):
    V.append((f"sfx_animal_chicken_{n:02d}", "chicken", dict(SEED=seed, N=cnt, F0=f0, F1=f1, DUR=dur)))
for n, (seed, f0, f1) in enumerate([(84, 95, 115), (85, 110, 130)], 1):
    V.append((f"sfx_animal_pig_{n:02d}", "pig", dict(SEED=seed, F0=f0, F1=f1)))
for n, (seed, f0, f1) in enumerate([(86, 108, 118), (87, 120, 128)], 1):
    V.append((f"sfx_animal_cow_{n:02d}", "cow", dict(SEED=seed, F0=f0, F1=f1)))
V += [("sfx_animal_panic_01", "panic_chicken", {}), ("sfx_animal_panic_02", "panic_pig", {}),
      ("sfx_animal_panic_03", "panic_cow", {}), ("ui_click", "ui_click", {}), ("ui_confirm", "ui_confirm", {}),
      ("ui_deny", "ui_deny", {}), ("ui_coins", "ui_coins", {}), ("ui_stamp", "ui_stamp", {}),
      ("ui_award_reveal", "ui_award", {}), ("ui_shop_bell", "shop_bell", {})]

if __name__ == "__main__":
    for sid, tpl, sub in V:
        s = T[tpl].replace("@ID@", sid)
        for k, v in sub.items():
            s = s.replace(f"@{k}@", str(v))
        (OUT / f"{sid}.scd").write_bytes(s.encode())
    print(" ".join(sid for sid, _, _ in V))

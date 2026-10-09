// cre_boar_sig_02 (placeholder). Boar lurk signature variant: the iron collar chain dragging, one drag about 0.75 s apart
// (1.2 per s), a hoof thud of 60 to 90 Hz under each (doc 08 section 6). Mono, 3D, 1.75 s.
(
thisThread.randSeed = 72;
(
	channels: 1,
	duration: 1.75,
	defs: [
		SynthDef(\drag, { |out = 0, thud = 75, len = 0.45, amp = 0.8|
			var hoof = SinOsc.ar(thud * (1 + (EnvGen.ar(Env.perc(0, 0.04)) * 0.6))) * EnvGen.ar(Env.perc(0.002, 0.14, curve: -5)) * 0.9;
			var ex = (Dust.ar(40) * 3) + (WhiteNoise.ar * EnvGen.ar(Env.perc(0.001, 0.02)));
			var ring = Klank.ar(`[[720, 1180, 1960, 2900, 3900], [1, 0.8, 0.6, 0.4, 0.3], [0.25, 0.2, 0.18, 0.15, 0.12]], ex * 0.1)
				* EnvGen.ar(Env([1, 1, 0], [len * 0.7, len * 0.3]));
			var scrape = BPF.ar(WhiteNoise.ar, LFNoise1.kr(9).range(1800, 3200), 0.4)
				* EnvGen.ar(Env([0, 1, 0.6, 0], [0.02, len * 0.5, len * 0.5], -3), doneAction: 2) * 0.9;
			Out.ar(out, (hoof + ring + scrape) * amp);
		})
	],
	events: [0.1, 0.1 + 0.75].collect { |tt| [tt, [\s_new, \drag, -1, 0, 0, \thud, rrand(60, 90), \len, rrand(0.35, 0.55), \amp, rrand(0.7, 0.9)]] }
)
)

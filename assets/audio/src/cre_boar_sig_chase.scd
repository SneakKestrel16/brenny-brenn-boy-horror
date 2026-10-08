// cre_boar_sig_chase (placeholder). Boar chase signature: iron collar chain clattering on the ground and a
// hoof thud per stride at 2.5 per s (10 per loop). Metallic ring partials 700 Hz to 4 kHz bursting into a
// 1 to 5 kHz scrape, 60 to 90 Hz thud. Mono, 3D, 4 s loop. Doc 08 section 6.
(
thisThread.randSeed = 43;
(
	channels: 1,
	duration: 4,
	defs: [
		SynthDef(\stride, { |out = 0, thud = 75, amp = 0.8|
			var hoof = SinOsc.ar(thud * (1 + (EnvGen.ar(Env.perc(0, 0.04)) * 0.6))) * EnvGen.ar(Env.perc(0.002, 0.14, curve: -5)) * 0.9;
			var ex = WhiteNoise.ar * EnvGen.ar(Env.perc(0.001, 0.02));
			var ring = Klank.ar(`[[720, 1180, 1960, 2900, 3900], [1, 0.8, 0.6, 0.4, 0.3], [0.25, 0.2, 0.18, 0.15, 0.12]], ex * 0.15);
			var scrape = BPF.ar(WhiteNoise.ar, 2600, 0.4) * EnvGen.ar(Env([0, 1, 0.5, 0], [0.01, 0.1, 0.18], -3)) * 1.2;
			var sig = (hoof + ring + scrape) * amp;
			DetectSilence.ar(sig, 0.0003, 0.2, doneAction: 2);
			Out.ar(out, sig);
		})
	],
	events: 10.collect { |i| [i * 0.4, [\s_new, \stride, -1, 0, 0, \thud, rrand(60, 90), \amp, rrand(0.7, 0.95)]] }
)
)

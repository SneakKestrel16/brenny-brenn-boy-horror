// ui_click (placeholder). A short wood tick: a 1.9 kHz band-limited noise tick over a 700 Hz knock. Mono, UI, 0.1 s.
// Doc 08 section 11.5.
(
(
	channels: 1,
	duration: 0.1,
	defs: [
		SynthDef(\tick, { |out = 0|
			var tick = BPF.ar(WhiteNoise.ar, 1900, 0.6) * EnvGen.ar(Env.perc(0.0005, 0.012), doneAction: 2) * 3;
			var knock = SinOsc.ar(700) * EnvGen.ar(Env.perc(0.001, 0.03)) * 0.5;
			Out.ar(out, tick + knock);
		})
	],
	events: [[0, [\s_new, \tick, -1, 0, 0]]]
)
)

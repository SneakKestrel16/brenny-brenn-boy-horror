// ui_stamp (placeholder). A rubber stamp on paper: a 110 Hz thump dropping to 50 Hz, a short paper-noise slap
// (low-passed 1.2 kHz). Mono, UI, 0.4 s. Doc 08 section 11.5.
(
(
	channels: 1,
	duration: 0.4,
	defs: [
		SynthDef(\stamp, { |out = 0|
			var thump = SinOsc.ar(XLine.kr(110, 50, 0.1)) * EnvGen.ar(Env.perc(0.002, 0.18, curve: -4), doneAction: 2) * 1.1;
			var slap = LPF.ar(WhiteNoise.ar, 1200) * EnvGen.ar(Env.perc(0.001, 0.05)) * 0.9;
			var paper = HPF.ar(PinkNoise.ar, 2500) * EnvGen.ar(Env.perc(0.004, 0.09)) * 0.15;
			Out.ar(out, thump + slap + paper);
		})
	],
	events: [[0, [\s_new, \stamp, -1, 0, 0]]]
)
)

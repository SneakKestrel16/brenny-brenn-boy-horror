// vox_radio_squelch_on (placeholder). Walkie key-up: a 60 ms band-passed noise burst under a rising 1 to 1.8 kHz chirp.
// Mono, local. 0.2 s. Doc 08 sections 7.2, 11.6.
(
(
	channels: 1,
	duration: 0.2,
	defs: [
		SynthDef(\sq, { |out = 0|
			var n = BPF.ar(WhiteNoise.ar, 1800, 0.5) * EnvGen.ar(Env([0, 1, 0.4, 0], [0.004, 0.05, 0.05]), doneAction: 2) * 1.6;
			var c = SinOsc.ar(XLine.kr(1000, 1800, 0.05)) * EnvGen.ar(Env.perc(0.003, 0.05)) * 0.5;
			Out.ar(out, n + c);
		})
	],
	events: [[0, [\s_new, \sq, -1, 0, 0]]]
)
)

// vox_radio_squelch_off (placeholder). Walkie key-down: a falling 1.8 to 900 Hz chirp, then a 100 ms noise tail that
// dies away (the carrier dropping). Mono, local. 0.2 s. Doc 08 sections 7.2, 11.6.
(
(
	channels: 1,
	duration: 0.2,
	defs: [
		SynthDef(\sq, { |out = 0|
			var c = SinOsc.ar(XLine.kr(1800, 900, 0.04)) * EnvGen.ar(Env.perc(0.002, 0.04)) * 0.5;
			var n = BPF.ar(WhiteNoise.ar, 1500, 0.5) * EnvGen.ar(Env([0, 1, 0.3, 0], [0.002, 0.03, 0.09]), doneAction: 2) * 1.4;
			Out.ar(out, n + c);
		})
	],
	events: [[0, [\s_new, \sq, -1, 0, 0]]]
)
)

// ui_confirm (placeholder). A soft up-chirp, 600 to 1000 Hz in 90 ms, with a quiet octave, then a short fade. Mono, UI,
// 0.25 s. Used for buying at the store (doc 02 section 10). Doc 08 section 11.5.
(
(
	channels: 1,
	duration: 0.25,
	defs: [
		SynthDef(\chirp, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 0.5, 0], [0.01, 0.07, 0.12]), doneAction: 2);
			var f = XLine.kr(600, 1000, 0.09);
			Out.ar(out, (SinOsc.ar(f) + (SinOsc.ar(f * 2) * 0.2)) * env * 0.6);
		})
	],
	events: [[0, [\s_new, \chirp, -1, 0, 0]]]
)
)

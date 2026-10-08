// ui_paper_slide (placeholder). The Dawn Report card sliding in, stereo, non-positional (UI), 0.8 s.
// Doc 08 section 11.5: a filtered noise swell (high-passed paper hiss) with a light crinkle (Dust through
// a band-pass), each channel with its own noise so it reads wide.
(
(
	channels: 2,
	duration: 0.8,
	defs: [
		SynthDef(\slide, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 0], [0.3, 0.42], [3, -4]), doneAction: 2);
			var hiss = BPF.ar(WhiteNoise.ar ! 2, XLine.kr(2500, 5000, 0.7), 0.9) * 0.7;
			var crinkle = BPF.ar(Dust.ar(40 ! 2), 3200, 0.5) * 3 * EnvGen.ar(Env([0, 1, 0], [0.4, 0.3]));
			Out.ar(out, (hiss + crinkle) * env);
		})
	],
	events: [[0.01, [\s_new, \slide, -1, 0, 0]]]
)
)

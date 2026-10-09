// ui_award_reveal (placeholder). A Season Award card revealed: a stamp, then one warm 660 Hz bell tick (decaying
// partials, not a melody: no music, doc 08 section 2.1). Mono, UI, 1 s. Doc 08 section 11.5.
(
(
	channels: 1,
	duration: 1,
	defs: [
		SynthDef(\stamp, { |out = 0|
			var thump = SinOsc.ar(XLine.kr(110, 50, 0.1)) * EnvGen.ar(Env.perc(0.002, 0.18, curve: -4), doneAction: 2);
			var slap = LPF.ar(WhiteNoise.ar, 1200) * EnvGen.ar(Env.perc(0.001, 0.05)) * 0.8;
			Out.ar(out, thump + slap);
		}),
		SynthDef(\bell, { |out = 0|
			var ex = WhiteNoise.ar * EnvGen.ar(Env.perc(0.0005, 0.006), doneAction: 2);
			Out.ar(out, Klank.ar(`[[660, 1320, 1981, 2680], [1, 0.5, 0.3, 0.15], [0.7, 0.45, 0.3, 0.2]], ex * 0.25) * 0.8);
		})
	],
	events: [[0, [\s_new, \stamp, -1, 0, 0]], [0.18, [\s_new, \bell, -1, 0, 0]]]
)
)

// sfx_pit_fall (placeholder). Pit trap: stalks crunching, a soil slide, then a heavy thud at 0.45 s.
// Mono, 3D, 1.2 s. Doc 08 section 11.3.
(
(
	channels: 1,
	duration: 1.2,
	defs: [
		SynthDef(\pit, { |out = 0|
			var crunch = BPF.ar(Dust.ar(120), 2200, 0.4) * 4 * EnvGen.ar(Env([0, 1, 0.6, 0], [0.02, 0.3, 0.2]));
			var slide = LPF.ar(PinkNoise.ar, XLine.kr(2500, 400, 0.5)) * EnvGen.ar(Env([0, 0.5, 0], [0.1, 0.5]));
			var thud = (SinOsc.ar(55 * (1 + EnvGen.ar(Env.perc(0, 0.06)))) + LPF.ar(BrownNoise.ar, 200))
				* EnvGen.ar(Env([0, 0, 1, 0], [0.45, 0.004, 0.4], -4)) * 1.2;
			DetectSilence.ar(crunch + slide + thud, 0.0003, 0.2, doneAction: 2);
			Out.ar(out, crunch + slide + thud);
		})
	],
	events: [[0, [\s_new, \pit, -1, 0, 0]]]
)
)

// mus_sting_chase (placeholder). Chase sting, stereo, 3.2 s: detuned saw cluster (root, semitone, tritone,
// octave) that stabs up in 0.15 s after a short riser, a sub hit at 0.15 s, the cluster dying over 2 s,
// FreeVerb tail. Doc 08 sections 5.3, 11.4. A cluster, not a tune: there is no day music or score.
(
(
	channels: 2,
	duration: 3.2,
	defs: [
		SynthDef(\sting, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 0.45, 0], [0.15, 0.5, 1.5], [3, -2, -3]));
			var rise = EnvGen.ar(Env([0, 1, 0], [0.14, 0.01]));
			var base = 110;
			var cluster = [1, 2.pow(1/12), 2.pow(6/12), 2].collect { |r|
				Saw.ar(base * r * [0.995, 1.005]) * 0.12
			}.sum;
			var riser = BPF.ar(WhiteNoise.ar, XLine.kr(300, 4000, 0.15), 0.5) * rise * 0.5;
			var sub = SinOsc.ar(45 * (1 + (EnvGen.ar(Env.perc(0, 0.1)) * 0.5))) * EnvGen.ar(Env([0, 0, 1, 0], [0.15, 0.005, 0.9], -4)) * 0.9;
			var dry = LPF.ar(cluster, 2200) * env;
			var mix = dry + [riser, riser] + [sub, sub];
			var wet = FreeVerb.ar(mix, 0.35, 0.7, 0.5);
			var fade = EnvGen.ar(Env([1, 1, 0], [2.9, 0.3]));
			Out.ar(out, wet * fade);
		})
	],
	events: [[0, [\s_new, \sting, -1, 0, 0]]]
)
)

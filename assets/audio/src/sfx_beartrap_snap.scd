// sfx_beartrap_snap (placeholder). Bear trap jaws: metal slam (inharmonic resonators) plus a noise
// crack and a low thump, mono, 3D, 0.8 s. Doc 08 section 11.3.
(
(
	channels: 1,
	duration: 0.9,
	defs: [
		SynthDef(\snap, { |out = 0|
			var hit = EnvGen.ar(Env.perc(0.0005, 0.01));
			var ex = (WhiteNoise.ar * hit) + (PinkNoise.ar * EnvGen.ar(Env.perc(0.001, 0.05)) * 0.4);
			var ring = Klank.ar(`[[420, 910, 1530, 2380, 3300], [1, 0.8, 0.6, 0.4, 0.3], [0.5, 0.4, 0.3, 0.25, 0.2]], ex * 0.2);
			var thump = SinOsc.ar(70 * (1 + EnvGen.ar(Env.perc(0, 0.05)))) * EnvGen.ar(Env.perc(0.002, 0.2)) * 0.8;
			DetectSilence.ar(ring + thump, 0.0003, 0.2, doneAction: 2);
			Out.ar(out, ring + thump + (ex * 0.5));
		})
	],
	events: [[0, [\s_new, \snap, -1, 0, 0]]]
)
)

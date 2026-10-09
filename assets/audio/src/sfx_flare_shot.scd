// sfx_flare_shot (placeholder). A flare pistol: a flat bang (noise burst + 70 Hz boom), then a rising whoosh as the
// flare climbs. Mono, 3D, 1.2 s. The loudest noise on the farm (doc 01 "Warden"; doc 08 section 3.2). Doc 08 section 11.2.
(
(
	channels: 1,
	duration: 1.2,
	defs: [
		SynthDef(\shot, { |out = 0|
			var bang = LPF.ar(WhiteNoise.ar, 4500) * EnvGen.ar(Env.perc(0.0005, 0.14, curve: -5)) * 1.6;
			var boom = SinOsc.ar(XLine.kr(110, 45, 0.25)) * EnvGen.ar(Env.perc(0.001, 0.3, curve: -4)) * 1.2;
			var wh = BPF.ar(PinkNoise.ar, XLine.kr(500, 3500, 0.9), 0.7) * EnvGen.ar(Env([0, 0, 1, 0.5, 0], [0.04, 0.3, 0.4, 0.4]), doneAction: 2) * 2;
			Out.ar(out, bang + boom + wh);
		})
	],
	events: [[0, [\s_new, \shot, -1, 0, 0]]]
)
)

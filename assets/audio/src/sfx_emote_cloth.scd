// sfx_emote_cloth (placeholder). A cloth rustle under the wave, point and shrug emotes, mono, 3D, 0.7 s.
// Doc 08 section 11.2: band-passed noise (1.5 to 4 kHz) gated by dense random grains, swelling and fading.
(
(
	channels: 1,
	duration: 0.7,
	defs: [
		SynthDef(\cloth, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 0.6, 0], [0.12, 0.2, 0.3], [2, -1, -3]), doneAction: 2);
			var grains = Decay.ar(Dust.ar(140), 0.012);
			var rub = BPF.ar(WhiteNoise.ar, LFNoise1.kr(6).range(1500, 4000), 0.8) * (0.3 + grains);
			Out.ar(out, HPF.ar(rub, 600) * env);
		})
	],
	events: [[0.01, [\s_new, \cloth, -1, 0, 0]]]
)
)

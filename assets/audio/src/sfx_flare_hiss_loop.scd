// sfx_flare_hiss_loop (placeholder). A burning flare: steady bright hiss with sparse pops. Stationary noise (constant
// level, no slow changes), so any whole length loops: 2 s. Mono, 3D. Doc 08 section 11.2.
(
(
	channels: 1,
	duration: 2,
	defs: [
		SynthDef(\hiss, { |out = 0|
			var hiss = HPF.ar(PinkNoise.ar, 2500) * 0.8;
			var bright = BPF.ar(WhiteNoise.ar, 7000, 0.6) * 0.5;
			var pops = HPF.ar(Decay2.ar(Dust.ar(35), 0.0005, 0.01), 1500) * 1.2;
			Out.ar(out, hiss + bright + pops);
		})
	],
	events: [[0, [\s_new, \hiss, -1, 0, 0]]]
)
)

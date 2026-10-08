// vox_crackle_loop (placeholder). The faint radio crackle under every proximity voice (D-011; doc 06 s9;
// doc 08 7.2): sparse clicks, about 12 per s, band-passed 1.5 to 4 kHz, lightly bit-crushed. Mono, 4 s
// loop, ends faded so the seam is clean. A fake with the no_crackle tell lacks this layer.
(
(
	channels: 1,
	duration: 4,
	defs: [
		SynthDef(\crackle, { |out = 0|
			var trig = Dust.ar(12);
			var click = Decay2.ar(trig, 0.0004, 0.004) * WhiteNoise.ar;
			var f = BPF.ar(click, TRand.kr(1500, 4000, Dust.kr(12)), 0.6) * 6;
			var crushed = (f * 6).round / 6;
			var win = EnvGen.ar(Env([0, 1, 1, 0], [0.02, 3.96, 0.02]));
			Out.ar(out, crushed * win);
		})
	],
	events: [[0, [\s_new, \crackle, -1, 0, 0]]]
)
)

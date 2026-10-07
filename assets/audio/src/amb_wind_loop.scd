// amb_wind_loop (placeholder). Stereo wind bed, 24 s exact loop: stationary pink noise through two
// slowly swept band-passes; every LFO completes a whole number of cycles in 24 s so the seam is
// level-matched. Left and right are independent noise. Doc 08 sections 4.1, 11.1.
(
(
	channels: 2,
	duration: 24,
	defs: [
		SynthDef(\wind, { |out = 0|
			var sig = 2.collect { |i|
				var n = PinkNoise.ar;
				var f1 = LinExp.kr(SinOsc.kr(2 / 24, i * pi), -1, 1, 200, 600);
				var f2 = LinExp.kr(SinOsc.kr(3 / 24, 1 + i), -1, 1, 350, 900);
				var gust = 0.65 + (0.2 * SinOsc.kr(2 / 24, 2 + i)) + (0.15 * SinOsc.kr(5 / 24, 4 * i));
				((BPF.ar(n, f1, 0.6) + BPF.ar(n, f2, 0.8)) * gust)
			};
			Out.ar(out, LPF.ar(sig, 1400));
		})
	],
	events: [[0, [\s_new, \wind, -1, 0, 0]]]
)
)

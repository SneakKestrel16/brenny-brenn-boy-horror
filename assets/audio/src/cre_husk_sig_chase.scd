// cre_husk_sig_chase (placeholder). Husk chase signature: dry rattle, "seed pods in a gourd". Narrow
// band-passed noise at 4 to 7 kHz gated by 18 per s pulses (inside 14 to 22), a hollow 800 Hz resonance
// underneath. Pulsed and bright: NOT the smooth, unpulsed, gust-shaped corn rustle (doc 08 section 6).
// Mono, 3D, 4 s loop; 72 whole pulses, a 0.5 Hz swell of whole cycles.
(
(
	channels: 1,
	duration: 4,
	defs: [
		SynthDef(\rattle, { |out = 0|
			var pulse = Decay2.kr(Impulse.kr(18), 0.001, 0.025);
			var swell = 0.75 + (0.25 * SinOsc.kr(0.5));
			var pods = BPF.ar(WhiteNoise.ar, LFNoise1.kr(18).range(4000, 7000), 0.25) * pulse.min(1) * 14;
			var hollow = Resonz.ar(WhiteNoise.ar, 800, 0.08) * pulse.min(1) * 10;
			Out.ar(out, (pods + hollow) * swell * 0.5);
		})
	],
	events: [[0, [\s_new, \rattle, -1, 0, 0]]]
)
)

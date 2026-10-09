// cre_husk_sig_01 (placeholder). Husk lurk signature variant: three short bursts of the dry pulsed rattle at 18 pulses per s
// (inside 14 to 22 Hz), 4 to 7 kHz pods over a hollow 800 Hz resonance. NOT corn rustle (doc 08 section 6).
// Mono, 3D, 1.75 s, bursts at 0.05, 0.6 and 1.1 s, each 0.55 s.
(
(
	channels: 1,
	duration: 1.75,
	defs: [
		SynthDef(\rattle, { |out = 0, rate = 18, amp = 0.8|
			var burst = EnvGen.ar(Env([0, 1, 1, 0], [0.04, 0.4, 0.11]), doneAction: 2);
			var pulse = Decay2.kr(Impulse.kr(rate), 0.001, 0.025);
			var pods = BPF.ar(WhiteNoise.ar, LFNoise1.kr(rate).range(4000, 7000), 0.25) * pulse.min(1) * 14;
			var hollow = Resonz.ar(WhiteNoise.ar, 800, 0.08) * pulse.min(1) * 10;
			Out.ar(out, (pods + hollow) * burst * amp * 0.5);
		})
	],
	events: [0.05, 0.6, 1.1].collect { |tt, i| [tt, [\s_new, \rattle, -1, 0, 0, \rate, 18 + [0, 1, -1][i], \amp, [0.8, 0.9, 0.7][i]]] }
)
)

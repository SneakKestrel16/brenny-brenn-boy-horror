// sfx_lantern_blow_out (placeholder). A breath across a lantern glass: soft noise puff that falls in
// pitch, a small glass tick, a short sizzle of the wick. Mono, 0.8 s. Doc 08 section 11.2, P2-03 staging.
(
(
	channels: 1,
	duration: 0.8,
	defs: [
		SynthDef(\puff, { |out = 0|
			var env = EnvGen.ar(Env.perc(0.03, 0.3, curve: -3));
			var puff = BPF.ar(PinkNoise.ar, XLine.kr(1100, 300, 0.35), 0.7) * env * 2.2;
			var tick = SinOsc.ar(2400) * EnvGen.ar(Env.perc(0.001, 0.025)) * 0.12;
			var sizzle = HPF.ar(WhiteNoise.ar, 5500) * EnvGen.ar(Env.perc(0.08, 0.35)) * 0.05;
			var sig = puff + tick + sizzle;
			DetectSilence.ar(sig, 0.0003, 0.2, doneAction: 2);
			Out.ar(out, sig);
		})
	],
	events: [[0, [\s_new, \puff, -1, 0, 0]]]
)
)

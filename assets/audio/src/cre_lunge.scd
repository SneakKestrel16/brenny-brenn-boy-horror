// cre_lunge (placeholder). The disarm lunge at the cut to black, mono, non-positional, 0.9 s. Doc 08
// sections 5.3, 5.4, 11.4: a fast whoosh (noise through a band-pass sweeping up 300 Hz to 3.5 kHz over
// 0.4 s) that lands on a low thump at 0.4 s.
(
(
	channels: 1,
	duration: 0.9,
	defs: [
		SynthDef(\lunge, { |out = 0|
			var sweep = XLine.kr(300, 3500, 0.4);
			var whoosh = BPF.ar(WhiteNoise.ar, sweep, 0.6) * EnvGen.ar(Env([0, 1, 0], [0.38, 0.06], [4, -4])) * 1.5;
			var hitEnv = EnvGen.ar(Env([0, 0, 1, 0], [0.4, 0.002, 0.35], -5));
			var thump = SinOsc.ar(60 * (1 + (EnvGen.ar(Env([0, 0, 1, 0], [0.4, 0, 0.05])) * 1.5))) * hitEnv * 1.2;
			var knock = LPF.ar(WhiteNoise.ar, 1200) * EnvGen.ar(Env([0, 0, 1, 0], [0.4, 0.001, 0.04])) * 0.7;
			var sig = (whoosh + thump + knock) * EnvGen.ar(Env([1, 1], [0.9]), doneAction: 2);
			Out.ar(out, sig);
		})
	],
	events: [[0, [\s_new, \lunge, -1, 0, 0]]]
)
)

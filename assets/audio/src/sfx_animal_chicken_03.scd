// sfx_animal_chicken_03 (placeholder). A hen's cluck group: 4 clucks, each a short falling 700-ish Hz buzz through a 1.4 kHz formant.
// Mono, 3D, 0.9 s. Species are inference (doc 08 section 11.1). Doc 08 section 11.1.
(
thisThread.randSeed = 83;
(
	channels: 1,
	duration: 0.9,
	defs: [
		SynthDef(\cluck, { |out = 0, f = 700, amp = 0.7|
			var env = EnvGen.ar(Env([0, 1, 0.6, 0], [0.008, 0.04, 0.05]), doneAction: 2);
			var src = Saw.ar(XLine.kr(f * 1.2, f * 0.7, 0.09) * (1 + (SinOsc.kr(45) * 0.05)));
			Out.ar(out, (BPF.ar(src, 1400, 0.35) * 2 + (BPF.ar(WhiteNoise.ar, 2500, 0.5) * 0.12)) * env * amp);
		})
	],
	events: (0..4 - 1).collect { |i| [0.05 + (i * rrand(0.13, 0.2)), [\s_new, \cluck, -1, 0, 0, \f, rrand(700, 820), \amp, rrand(0.5, 0.8)]] }
)
)

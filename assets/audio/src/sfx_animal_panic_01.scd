// sfx_animal_panic_01 (placeholder). A hen's alarm: a rapid burst of high squawks, 900 to 1300 Hz, 7 in 0.8 s.
// Mono, 3D, 1 s. Animals react before the creature arrives (doc 01 "Daytime Threats"). Doc 08 section 11.1.
(
thisThread.randSeed = 31;
(
	channels: 1,
	duration: 1,
	defs: [
		SynthDef(\squawk, { |out = 0, f = 1000, amp = 0.7|
			var env = EnvGen.ar(Env([0, 1, 0.7, 0], [0.006, 0.05, 0.05]), doneAction: 2);
			var src = Saw.ar(XLine.kr(f * 1.25, f * 0.75, 0.1) * (1 + (SinOsc.kr(60) * 0.06)));
			Out.ar(out, (BPF.ar(src, 1800, 0.3) * 2 + (BPF.ar(WhiteNoise.ar, 3500, 0.5) * 0.15)) * env * amp);
		})
	],
	events: 7.collect { |i| [0.03 + (i * rrand(0.09, 0.13)), [\s_new, \squawk, -1, 0, 0, \f, rrand(900, 1300), \amp, rrand(0.55, 0.9)]] }
)
)

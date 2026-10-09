// sfx_animal_panic_02 (placeholder). A pig's squeal: a 700 to 1500 Hz voice sweeping up and down with a fast tremor
// through a 2 kHz formant, 0.8 s. Mono, 3D, 1 s. Doc 08 section 11.1.
(
(
	channels: 1,
	duration: 1,
	defs: [
		SynthDef(\squeal, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 0.9, 0], [0.04, 0.5, 0.25]), doneAction: 2);
			var f = Env([700, 1500, 1100, 1400, 800], [0.15, 0.2, 0.2, 0.25], \sin).kr * (1 + (SinOsc.kr(32) * 0.03));
			var src = Saw.ar(f) + Pulse.ar(f * 1.005, 0.2);
			var voiced = BPF.ar(src, 2000, 0.35) * env * 1.2;
			var breath = BPF.ar(WhiteNoise.ar, 4000, 0.4) * env * 0.12;
			Out.ar(out, (voiced + breath) * 0.8);
		})
	],
	events: [[0.03, [\s_new, \squeal, -1, 0, 0]]]
)
)

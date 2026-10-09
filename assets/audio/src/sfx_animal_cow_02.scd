// sfx_animal_cow_02 (placeholder). A cow's low moo: a 100 to 125 Hz voice with a slow formant glide (400 to 720 Hz) and breath,
// swelling over 0.3 s and trailing off. Mono, 3D, 2 s. Doc 08 section 11.1.
(
thisThread.randSeed = 87;
(
	channels: 1,
	duration: 2,
	defs: [
		SynthDef(\moo, { |out = 0, f = 115|
			var env = EnvGen.ar(Env([0, 1, 0.9, 0], [0.3, 0.9, 0.6]), doneAction: 2);
			var pitch = f * XLine.kr(1.1, 0.88, 1.6) * (1 + (SinOsc.kr(5) * 0.015));
			var src = Saw.ar(pitch) + (Pulse.ar(pitch * 2.003, 0.4) * 0.3);
			var form = XLine.kr(400, 720, 0.7);
			var voiced = (Resonz.ar(src, form, 0.2) * 4 + (Resonz.ar(src, form * 2.2, 0.25) * 2)) * env;
			var breath = BPF.ar(PinkNoise.ar, 600, 0.6) * env * 0.4;
			Out.ar(out, (voiced + breath) * 0.8);
		})
	],
	events: [[0.05, [\s_new, \moo, -1, 0, 0, \f, rrand(120, 128)]]]
)
)

// sfx_animal_panic_03 (placeholder). A cow's alarmed bellow: higher (170 to 210 Hz), louder and shorter than the moo, with
// a fast tremolo and a rising formant. Mono, 3D, 1 s. Doc 08 section 11.1.
(
(
	channels: 1,
	duration: 1,
	defs: [
		SynthDef(\bellow, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 0.8, 0], [0.06, 0.5, 0.3]), doneAction: 2);
			var pitch = XLine.kr(170, 210, 0.3) * (1 + (SinOsc.kr(7) * 0.03));
			var src = Saw.ar(pitch) + (Pulse.ar(pitch * 2.004, 0.4) * 0.35);
			var form = XLine.kr(500, 900, 0.5);
			var voiced = (Resonz.ar(src, form, 0.2) * 5 + (Resonz.ar(src, form * 2.3, 0.25) * 2.5)) * env * (0.8 + (SinOsc.kr(14) * 0.2));
			var breath = BPF.ar(PinkNoise.ar, 900, 0.6) * env * 0.4;
			Out.ar(out, (voiced + breath) * 0.8);
		})
	],
	events: [[0.03, [\s_new, \bellow, -1, 0, 0]]]
)
)

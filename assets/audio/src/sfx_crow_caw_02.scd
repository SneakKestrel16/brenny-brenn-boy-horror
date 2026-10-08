// sfx_crow_caw_02 (placeholder, synthetic). One crow caw, mono, 3D, 0.7 s. Doc 08 section 11.1. Same recipe
// as sfx_crow_caw_01, higher (700 to 480 Hz) and longer.
(
(
	channels: 1,
	duration: 0.7,
	defs: [
		SynthDef(\caw, { |out = 0, f0a = 620, f0b = 430, dur = 0.35, amp = 1|
			var env = EnvGen.ar(Env([0, 1, 0.7, 0], [0.02, dur * 0.6, dur * 0.4], [2, -1, -3]), doneAction: 2);
			var f0 = XLine.kr(f0a, f0b, dur) * (1 + (LFNoise1.kr(60) * 0.04));
			var rasp = 1 + (SinOsc.ar(f0 * 0.5) * 0.6);
			var src = (Saw.ar(f0) * rasp) + (WhiteNoise.ar * 0.3);
			var v = (BPF.ar(src, 900, 0.25) * 2) + (BPF.ar(src, 1800, 0.2) * 1.4) + (BPF.ar(src, 3000, 0.3) * 0.3);
			Out.ar(out, HPF.ar(v, 250) * env * amp);
		})
	],
	events: [[0.02, [\s_new, \caw, -1, 0, 0, \f0a, 700, \f0b, 480, \dur, 0.45]]]
)
)

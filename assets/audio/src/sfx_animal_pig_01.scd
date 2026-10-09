// sfx_animal_pig_01 (placeholder). A pig's grunt: two low 'oink' phrases, a 90 to 130 Hz pulsed voice rising then falling through
// 450 and 1100 Hz formants, with a nasal noise edge. Mono, 3D, 1 s. Doc 08 section 11.1 (pig replaces the sheep: P4-08).
(
thisThread.randSeed = 84;
(
	channels: 1,
	duration: 1,
	defs: [
		SynthDef(\oink, { |out = 0, f = 105, amp = 0.7, len = 0.22|
			var env = EnvGen.ar(Env([0, 1, 0.8, 0], [0.02, len * 0.5, len * 0.5]), doneAction: 2);
			var pitch = f * Env([0.85, 1.25, 0.8], [len * 0.4, len * 0.6]).kr;
			var src = Pulse.ar(pitch, 0.3) + (Saw.ar(pitch * 0.5) * 0.5);
			var voiced = (Resonz.ar(src, 450, 0.25) * 3 + (Resonz.ar(src, 1100, 0.2) * 2)) * env;
			var nasal = BPF.ar(PinkNoise.ar, 1800, 0.4) * env * 0.25;
			Out.ar(out, (voiced + nasal) * amp);
		})
	],
	events: [[0.05, [\s_new, \oink, -1, 0, 0, \f, rrand(95, 115), \len, 0.22]], [0.4, [\s_new, \oink, -1, 0, 0, \f, rrand(95, 115) * 0.92, \len, 0.3, \amp, 0.6]]]
)
)

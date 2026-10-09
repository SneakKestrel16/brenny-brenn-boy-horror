// ui_deny (placeholder). Two low down-chirps, 420 to 260 Hz, 110 ms each, through a low-pass (can't afford it, gated).
// Mono, UI, 0.35 s. Doc 08 section 11.5.
(
(
	channels: 1,
	duration: 0.35,
	defs: [
		SynthDef(\buzz, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 0.8, 0], [0.006, 0.08, 0.025]), doneAction: 2);
			var f = XLine.kr(420, 260, 0.11);
			Out.ar(out, LPF.ar(Saw.ar(f) + SinOsc.ar(f), 1400) * env * 0.5);
		})
	],
	events: [0, 0.16].collect { |t| [t, [\s_new, \buzz, -1, 0, 0]] }
)
)

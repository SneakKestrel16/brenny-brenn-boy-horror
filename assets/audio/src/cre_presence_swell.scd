// cre_presence_swell (placeholder). The private "something's there" for the hallucination and the wrong
// count, mono, non-positional, 6 s. Doc 08 sections 5.4, 11.4: a very low swell (sines at 41 and 44 Hz
// beating, with a 70 Hz partial) that rises over 3 s and sinks over 3 s, and a thin high partial
// (3.2 kHz, slow tremolo) far below it. Ends silent.
(
(
	channels: 1,
	duration: 6.0,
	defs: [
		SynthDef(\swell, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 0], [3.0, 2.9], [2, -2]), doneAction: 2);
			var low = (SinOsc.ar(41) + SinOsc.ar(44) + (SinOsc.ar(70) * 0.4)) * 0.4;
			var air = LPF.ar(BrownNoise.ar, 90) * 0.5;
			var thin = SinOsc.ar(3200 + SinOsc.kr(0.3, 0, 12)) * (0.5 + (0.5 * SinOsc.kr(2.7))) * 0.025;
			Out.ar(out, (low + air + thin) * env);
		})
	],
	events: [[0, [\s_new, \swell, -1, 0, 0]]]
)
)

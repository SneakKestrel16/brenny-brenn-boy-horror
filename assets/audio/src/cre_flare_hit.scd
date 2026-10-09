// cre_flare_hit (placeholder). The creature struck by a flare: a falling shriek (2.2 kHz down to 350 Hz with a fast
// wobble, a 1.8 kHz formant and breath), then a stomp at 0.75 s. Synthetic, never a voice. Mono, 3D, 1.2 s.
// Plays at the start of Retreat (doc 01 "Store" flare gun). Doc 08 section 11.4.
(
(
	channels: 1,
	duration: 1.2,
	defs: [
		SynthDef(\shriek, { |out = 0|
			var f = XLine.kr(2200, 350, 0.7) * (1 + (SinOsc.kr(28) * 0.04));
			var env = EnvGen.ar(Env([0, 1, 0.8, 0], [0.03, 0.45, 0.25]), doneAction: 2);
			var tone = Saw.ar(f) + Pulse.ar(f * 1.01, 0.3);
			var voiced = BPF.ar(tone, 1800, 0.5) * env * 0.6;
			var breath = BPF.ar(WhiteNoise.ar, 3000, 0.4) * env * 0.35;
			Out.ar(out, voiced + breath);
		}),
		SynthDef(\stomp, { |out = 0|
			var body = SinOsc.ar(XLine.kr(120, 40, 0.15)) * EnvGen.ar(Env.perc(0.002, 0.3, curve: -5), doneAction: 2);
			var dirt = LPF.ar(WhiteNoise.ar, 900) * EnvGen.ar(Env.perc(0.001, 0.08)) * 0.8;
			Out.ar(out, (body + dirt) * 0.9);
		})
	],
	events: [[0, [\s_new, \shriek, -1, 0, 0]], [0.75, [\s_new, \stomp, -1, 0, 0]]]
)
)

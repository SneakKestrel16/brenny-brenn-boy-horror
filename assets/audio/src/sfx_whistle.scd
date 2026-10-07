// sfx_whistle (placeholder). Warning whistle, mono, 3D, 1.1 s: a bright 2.6 to 3.4 kHz tone with an
// 80 ms rising chirp onset, breathy noise and 6 Hz vibrato. Broadband attack plus the chirp makes it
// easier to place (doc 08 section 9.3, inference). Tail dies before the end.
(
(
	channels: 1,
	duration: 1.3,
	defs: [
		SynthDef(\whistle, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 0.85, 0.85, 0], [0.02, 0.1, 0.8, 0.2]), doneAction: 2);
			var chirp = XLine.kr(2000, 3000, 0.08) * (1 + (0.02 * SinOsc.kr(6)));
			var f = Select.kr(Line.kr(0, 1, 0.08) >= 1, [chirp, 3000 * (1 + (0.02 * SinOsc.kr(6)))]);
			var tone = SinOsc.ar(f) + (SinOsc.ar(f * 2) * 0.15);
			var breath = BPF.ar(WhiteNoise.ar, 3200, 0.3) * 0.5;
			var click = WhiteNoise.ar * EnvGen.ar(Env.perc(0.0005, 0.01)) * 0.6;
			Out.ar(out, ((tone * 0.6) + breath + click) * env);
		})
	],
	events: [[0, [\s_new, \whistle, -1, 0, 0]]]
)
)

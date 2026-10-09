// sfx_ragdoll_thud_02 (placeholder; reworked after CEO listen 1). A body hitting the dirt, mono, 3D, 0.7 s. Doc 08
// sections 5.4, 11.2. Same recipe as sfx_ragdoll_thud_01, lower, with a rolling second and third settle.
(
(
	channels: 1,
	duration: 0.7,
	defs: [
		SynthDef(\thud, { |out = 0, pitch = 1, amp = 1, len = 0.6|
			var drop = SinOsc.ar(XLine.kr(130 * pitch, 42 * pitch, 0.12)) * EnvGen.ar(Env.perc(0.002, 0.28, curve: -4));
			var body = (drop * 1.8).tanh * 0.9;
			var flesh = LPF.ar(PinkNoise.ar, 500 * pitch) * EnvGen.ar(Env.perc(0.001, 0.12, curve: -5)) * 1.3;
			var slap = BPF.ar(WhiteNoise.ar, 1200, 0.8) * EnvGen.ar(Env.perc(0.0005, 0.025, curve: -6)) * 0.5;
			var dirt = HPF.ar(LPF.ar(Dust2.ar(1800), 3500), 400) * EnvGen.ar(Env.perc(0.01, 0.18, curve: -3)) * 0.5;
			Out.ar(out, (body + flesh + slap + dirt) * amp * EnvGen.ar(Env([1, 1], [len]), doneAction: 2));
		}),
		SynthDef(\rattle, { |out = 0, freq = 700, amp = 0.2|
			var exc = LPF.ar(WhiteNoise.ar, 3000) * EnvGen.ar(Env.perc(0.001, 0.01));
			var ring = Klank.ar(`[[freq, freq * 1.6, freq * 2.7], [1, 0.5, 0.3], [0.03, 0.025, 0.02]], exc);
			DetectSilence.ar(ring, 0.0002, 0.05, doneAction: 2);
			Out.ar(out, ring * amp);
		})
	],
	events: [
		[0, [\s_new, \thud, -1, 0, 0, \pitch, 0.85, \amp, 1.0]],
		[0.16, [\s_new, \thud, -1, 0, 0, \pitch, 1.1, \amp, 0.35, \len, 0.4]],
		[0.24, [\s_new, \rattle, -1, 0, 0, \freq, 740, \amp, 0.22]],
		[0.32, [\s_new, \thud, -1, 0, 0, \pitch, 1.4, \amp, 0.12, \len, 0.25]]
	]
)
)

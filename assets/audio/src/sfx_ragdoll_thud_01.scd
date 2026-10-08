// sfx_ragdoll_thud_01 (placeholder). A body hitting the dirt, mono, 3D, 0.7 s. Doc 08 sections 5.4, 11.2:
// a low sine dropping 90 to 40 Hz, a dull noise thud, and a rattle of dropped items (a few metal ticks).
(
(
	channels: 1,
	duration: 0.7,
	defs: [
		SynthDef(\thud, { |out = 0, pitch = 1|
			var drop = SinOsc.ar(XLine.kr(90 * pitch, 40 * pitch, 0.2)) * EnvGen.ar(Env.perc(0.003, 0.3, curve: -4)) * 1.2;
			var dirt = LPF.ar(BrownNoise.ar, 600 * pitch) * EnvGen.ar(Env.perc(0.002, 0.15, curve: -5)) * 0.9;
			Out.ar(out, (drop + dirt) * EnvGen.ar(Env([1, 1], [0.65]), doneAction: 2));
		}),
		SynthDef(\tick, { |out = 0, freq = 2400, amp = 0.3|
			var exc = WhiteNoise.ar * EnvGen.ar(Env.perc(0.0005, 0.004));
			var ring = Klank.ar(`[[freq, freq * 1.47, freq * 2.3], [1, 0.5, 0.3], [0.08, 0.06, 0.04]], exc);
			DetectSilence.ar(ring, 0.0002, 0.05, doneAction: 2);
			Out.ar(out, ring * amp);
		})
	],
	events: [
		[0, [\s_new, \thud, -1, 0, 0, \pitch, 1.0]],
		[0.09, [\s_new, \tick, -1, 0, 0, \freq, 2400, \amp, 0.25]],
		[0.17, [\s_new, \tick, -1, 0, 0, \freq, 3100, \amp, 0.15]],
		[0.28, [\s_new, \tick, -1, 0, 0, \freq, 2700, \amp, 0.08]]
	]
)
)

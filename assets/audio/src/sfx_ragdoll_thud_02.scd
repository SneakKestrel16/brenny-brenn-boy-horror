// sfx_ragdoll_thud_02 (placeholder). A body hitting the dirt, mono, 3D, 0.7 s. Doc 08 sections 5.4, 11.2.
// Same recipe as sfx_ragdoll_thud_01, a little lower, a second bounce, two ticks.
(
(
	channels: 1,
	duration: 0.7,
	defs: [
		SynthDef(\thud, { |out = 0, pitch = 1, amp = 1|
			var drop = SinOsc.ar(XLine.kr(90 * pitch, 40 * pitch, 0.2)) * EnvGen.ar(Env.perc(0.003, 0.3, curve: -4)) * 1.2;
			var dirt = LPF.ar(BrownNoise.ar, 600 * pitch) * EnvGen.ar(Env.perc(0.002, 0.15, curve: -5)) * 0.9;
			Out.ar(out, (drop + dirt) * amp * EnvGen.ar(Env([1, 1], [0.45]), doneAction: 2));
		}),
		SynthDef(\tick, { |out = 0, freq = 2400, amp = 0.3|
			var exc = WhiteNoise.ar * EnvGen.ar(Env.perc(0.0005, 0.004));
			var ring = Klank.ar(`[[freq, freq * 1.47, freq * 2.3], [1, 0.5, 0.3], [0.08, 0.06, 0.04]], exc);
			DetectSilence.ar(ring, 0.0002, 0.05, doneAction: 2);
			Out.ar(out, ring * amp);
		})
	],
	events: [
		[0, [\s_new, \thud, -1, 0, 0, \pitch, 0.88]],
		[0.14, [\s_new, \thud, -1, 0, 0, \pitch, 1.1, \amp, 0.4]],
		[0.2, [\s_new, \tick, -1, 0, 0, \freq, 2100, \amp, 0.2]],
		[0.33, [\s_new, \tick, -1, 0, 0, \freq, 2900, \amp, 0.1]]
	]
)
)

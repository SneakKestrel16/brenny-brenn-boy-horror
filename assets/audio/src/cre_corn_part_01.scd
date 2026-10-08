// cre_corn_part_01 (placeholder). Heavy stalks parting and breaking, mono, 3D, 1.0 s. Doc 08 sections 5.4,
// 11.4: a loud leaf-noise swell (band-passed noise 1.5 to 3 kHz, a heavier body than a footstep's brush)
// with wooden cracks (impulses through stalk resonators). Variant 01: two cracks. The disarm lunge's warning.
(
(
	channels: 1,
	duration: 1.0,
	defs: [
		SynthDef(\part, { |out = 0, pitch = 1|
			var swell = BPF.ar(WhiteNoise.ar, LFNoise1.kr(8).range(1500, 3000) * pitch, 0.7)
				* EnvGen.ar(Env([0, 1, 0.4, 0], [0.15, 0.3, 0.4], [2, -2, -3])) * 1.2;
			var body = LPF.ar(BrownNoise.ar, 500 * pitch) * EnvGen.ar(Env([0, 1, 0], [0.1, 0.6], [2, -4])) * 0.8;
			Out.ar(out, (swell + body) * EnvGen.ar(Env([1, 1], [0.95]), doneAction: 2));
		}),
		SynthDef(\crack, { |out = 0, freq = 900, amp = 0.8|
			var exc = WhiteNoise.ar * EnvGen.ar(Env.perc(0.0005, 0.008));
			var wood = Klank.ar(`[[freq, freq * 1.73, freq * 2.61], [1, 0.6, 0.35], [0.06, 0.05, 0.04]], exc);
			var snap = HPF.ar(exc, 2000) * 2;
			DetectSilence.ar(wood, 0.0002, 0.05, doneAction: 2);
			Out.ar(out, (wood * 0.4 + snap) * amp);
		})
	],
	events: [
		[0, [\s_new, \part, -1, 0, 0, \pitch, 1.0]],
		[0.12, [\s_new, \crack, -1, 0, 0, \freq, 850, \amp, 0.9]],
		[0.31, [\s_new, \crack, -1, 0, 0, \freq, 620, \amp, 0.7]]
	]
)
)

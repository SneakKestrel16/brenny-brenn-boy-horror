// sfx_step_corn_01 (placeholder). One footstep on corn, mono, 3D, 0.3 s. Variant pitch 1.0. Doc 08 section 11.2.
// LPF noise thump at 100 to 400 Hz plus HPF grit, plus a stalk-brush noise burst (BPF 1 to 3 kHz).
(
(
	channels: 1,
	duration: 0.35,
	defs: [
		SynthDef(\step, { |out = 0, pitch = 1, brush = 0|
			var thump = LPF.ar(BrownNoise.ar, 400 * pitch) * EnvGen.ar(Env.perc(0.003, 0.09, curve: -5));
			var body = SinOsc.ar(110 * pitch * (1 + EnvGen.ar(Env.perc(0, 0.05)))) * EnvGen.ar(Env.perc(0.002, 0.1, curve: -5)) * 0.6;
			var grit = HPF.ar(Dust.ar(900), 2500) * EnvGen.ar(Env.perc(0.002, 0.07)) * 0.5;
			var bru = BPF.ar(WhiteNoise.ar, 2000 * pitch, 0.5) * EnvGen.ar(Env.perc(0.04, 0.2, curve: -3)) * brush;
			DetectSilence.ar(thump + bru, 0.0001, 0.1, doneAction: 2);
			Out.ar(out, thump + body + grit + bru);
		})
	],
	events: [[0, [\s_new, \step, -1, 0, 0, \pitch, 1.0, \brush, 0.6]]]
)
)

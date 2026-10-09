// vox_radio_dead (placeholder). The walkie dying: a click, then a short falling tone and a gasp of static. Mono, local.
// 0.2 s. Doc 08 sections 7.2, 11.6.
(
(
	channels: 1,
	duration: 0.2,
	defs: [
		SynthDef(\dead, { |out = 0|
			var click = HPF.ar(WhiteNoise.ar, 1500) * EnvGen.ar(Env.perc(0.0003, 0.004)) * 1.5;
			var fall = SinOsc.ar(XLine.kr(900, 200, 0.12)) * EnvGen.ar(Env.perc(0.004, 0.1)) * 0.5;
			var gasp = BPF.ar(WhiteNoise.ar, 1400, 0.6) * EnvGen.ar(Env.perc(0.01, 0.1), doneAction: 2) * 0.5;
			Out.ar(out, click + fall + gasp);
		})
	],
	events: [[0, [\s_new, \dead, -1, 0, 0]]]
)
)

// ui_shop_bell (placeholder). The town stand's door bell: one small brass ding (resonators at 2.1, 3.3 and 4.7 kHz)
// with a quick second strike. Mono, UI, 0.9 s. Doc 08 section 11.2.
(
(
	channels: 1,
	duration: 0.9,
	defs: [
		SynthDef(\ding, { |out = 0, amp = 0.7|
			var ex = WhiteNoise.ar * EnvGen.ar(Env.perc(0.0003, 0.004), doneAction: 2);
			Out.ar(out, Klank.ar(`[[2100, 3340, 4710, 5900], [1, 0.6, 0.35, 0.2], [0.55, 0.4, 0.3, 0.2]], ex * 0.25) * amp);
		})
	],
	events: [[0, [\s_new, \ding, -1, 0, 0]], [0.11, [\s_new, \ding, -1, 0, 0, \amp, 0.45]]]
)
)

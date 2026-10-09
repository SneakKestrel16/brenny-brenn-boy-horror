// vox_radio_static_loop (placeholder). The walkie's carrier hiss while the creature is near (doc 01 "Walkie-talkies":
// "static when the creature is near"): noise band-limited to 300 to 3400 Hz (a small speaker), an upper hiss and dense
// crackle (about 28 pops per s, the proximity crackle at higher density). Stationary, so 4 s loops. Mono, local.
// Doc 08 sections 7.2, 11.6.
(
(
	channels: 1,
	duration: 4,
	defs: [
		SynthDef(\static, { |out = 0|
			var band = BPF.ar(PinkNoise.ar, 1300, 0.9) * 1.4;
			var hiss = HPF.ar(WhiteNoise.ar, 3000) * 0.18;
			var pops = BPF.ar(Decay2.ar(Dust.ar(28), 0.0005, 0.008), 2200, 0.7) * 3;
			Out.ar(out, HPF.ar(LPF.ar(band + hiss + pops, 3400), 300));
		})
	],
	events: [[0, [\s_new, \static, -1, 0, 0]]]
)
)

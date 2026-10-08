// cre_jumpscare_hit (placeholder). The day jumpscare's hit, mono, non-positional, 1.6 s. Doc 08 sections 5.4,
// 11.4: a noise burst, a 50 Hz boom with a falling pitch, and a screech gliding 3 kHz down to 400 Hz,
// all through a short FreeVerb; dead by 1.5 s.
(
(
	channels: 1,
	duration: 1.6,
	defs: [
		SynthDef(\hit, { |out = 0|
			var burst = HPF.ar(WhiteNoise.ar, 300) * EnvGen.ar(Env.perc(0.001, 0.18, curve: -6)) * 0.9;
			var boom = SinOsc.ar(50 * (1 + (EnvGen.ar(Env.perc(0, 0.12)) * 2))) * EnvGen.ar(Env.perc(0.002, 0.7, curve: -4)) * 1.2;
			var glide = XLine.kr(3000, 400, 1.0);
			var screech = (Saw.ar(glide * [1, 1.013, 1.41]).sum * 0.3) + (BPF.ar(WhiteNoise.ar, glide * 1.5, 0.3) * 0.6);
			var scr = BPF.ar(screech, glide, 0.6) * EnvGen.ar(Env([0, 1, 0.5, 0], [0.02, 0.4, 0.7], -3)) * 0.8;
			var dry = burst + boom + scr;
			var fade = EnvGen.ar(Env([1, 1, 0], [1.2, 0.3]), doneAction: 2);
			Out.ar(out, FreeVerb.ar(dry, 0.25, 0.5, 0.4) * fade);
		})
	],
	events: [[0, [\s_new, \hit, -1, 0, 0]]]
)
)

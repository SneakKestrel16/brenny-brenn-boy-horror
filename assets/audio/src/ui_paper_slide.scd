// ui_paper_slide (placeholder; reworked after CEO listen 1, level -2.5 dB). The Dawn Report card sliding in,
// stereo, non-positional (UI), 0.8 s. Doc 08 section 11.5. A sheet of paper sliding over wood: soft broadband
// friction noise (no resonant filter, so no tonal ring), brightness and level follow the sheet's speed
// (a quick start, then slowing), with irregular stick-slip grain and a few fibre ticks. Each channel has its own noise.
(
(
	channels: 2,
	duration: 0.8,
	defs: [
		SynthDef(\slide, { |out = 0|
			var speed = EnvGen.kr(Env([0, 1, 0.55, 0.15, 0], [0.07, 0.22, 0.3, 0.15], [2, -1, -1, -3]));
			var sig = 2.collect { |i|
				var grit = (LFNoise1.kr(55 + (i * 9)).range(0.35, 1) * LFNoise0.kr(140 + (i * 20)).range(0.6, 1));
				var n = PinkNoise.ar + (WhiteNoise.ar * 0.35);
				var bright = OnePole.ar(n, 0.55);  // gentle one-pole slope, no resonance
				var hp = HPF.ar(bright, 500);
				var lp = LPF.ar(hp, speed.linexp(0, 1, 2500, 9000));
				var ticks = LPF.ar(HPF.ar(Dust2.ar(50 * speed), 1500), 7000) * 0.1;
				(lp * grit + ticks) * speed
			};
			Out.ar(out, sig * 0.6 * EnvGen.ar(Env([1, 1], [0.78]), doneAction: 2));
		})
	],
	events: [[0.01, [\s_new, \slide, -1, 0, 0]]]
)
)

// sfx_cart_squeak_loop (placeholder). The festival cart's wheel: a 600 to 720 Hz squeak with a wobble and a chassis
// rattle, one cycle every 0.75 s, four cycles, 3 s loop. Each squeak ends 0.6 s into its cycle so the seam is quiet.
// The game plays it faster with more pushers (pitch_scale, doc 01 "The Harvest Moon"). Mono, 3D. Doc 08 section 11.2.
(
thisThread.randSeed = 77;
(
	channels: 1,
	duration: 3,
	defs: [
		SynthDef(\squeak, { |out = 0, f0 = 640, amp = 0.7|
			var env = EnvGen.ar(Env([0, 1, 0.75, 0], [0.04, 0.32, 0.2]), doneAction: 2);
			var f = XLine.kr(f0, f0 * 1.12, 0.56) + (SinOsc.kr(13) * 18);
			var tone = (SinOsc.ar(f) + (SinOsc.ar(f * 2.01) * 0.3)) * env * 0.6;
			var rattle = BPF.ar(WhiteNoise.ar, 900, 0.5) * Decay2.kr(Dust.kr(30), 0.001, 0.02).min(1) * env * 4;
			var clunk = SinOsc.ar(85 * (1 + EnvGen.ar(Env.perc(0, 0.03)))) * EnvGen.ar(Env.perc(0.003, 0.09, curve: -5)) * 0.6;
			Out.ar(out, (tone + (rattle * 0.5) + clunk) * amp);
		})
	],
	events: 4.collect { |i| [i * 0.75, [\s_new, \squeak, -1, 0, 0, \f0, rrand(610, 690), \amp, rrand(0.65, 0.8)]] }
)
)

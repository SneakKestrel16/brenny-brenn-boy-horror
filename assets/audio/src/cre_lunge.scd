// cre_lunge (placeholder; reworked after CEO listen 1). The disarm lunge at the cut to black, mono,
// non-positional, 0.9 s. Doc 08 sections 5.3, 5.4, 11.4. A violent rush that lands at 0.4 s: a leaf-and-stalk
// rush (dense crackle grains and band noise climbing 250 Hz to 3.5 kHz with a throaty growl riding it), then
// a heavy impact (saturated sub drop, body slam, stalk crash grains) and a short gasp of breath after it.
(
(
	channels: 1,
	duration: 0.9,
	defs: [
		SynthDef(\lunge, { |out = 0|
			var rise = EnvGen.ar(Env([0, 0.3, 1, 0], [0.2, 0.18, 0.02], [2, 3, -4]));
			var sweep = XLine.kr(250, 3500, 0.4);
			var rush = BPF.ar(PinkNoise.ar, sweep, 0.5) * rise * 1.7;
			var crackle = HPF.ar(LPF.ar(Dust2.ar(XLine.kr(300, 1500, 0.4)), 7000), 700) * rise * 1.3;
			var gf = XLine.kr(70, 160, 0.4);
			var growl = Formlet.ar(Impulse.ar(gf * (1 + (LFNoise1.kr(30) * 0.1))) + (PinkNoise.ar * 0.05), XLine.kr(300, 700, 0.4), 0.001, 0.015) * rise * 0.9;
			var hitEnv = EnvGen.ar(Env([0, 0, 1, 0], [0.4, 0.002, 0.4], -5));
			var thump = (SinOsc.ar(60 * (1 + (EnvGen.ar(Env([0, 0, 1, 0], [0.4, 0, 0.1])) * 1.8))) * hitEnv * 1.8).tanh;
			var slam = LPF.ar(PinkNoise.ar, 1400) * EnvGen.ar(Env([0, 0, 1, 0], [0.4, 0.001, 0.12], -4)) * 1.2;
			var crash = HPF.ar(Dust2.ar(2000), 900) * EnvGen.ar(Env([0, 0, 1, 0], [0.4, 0.002, 0.25], -3)) * 0.9;
			var gasp = BPF.ar(PinkNoise.ar, 1200, 0.6) * EnvGen.ar(Env([0, 0, 0.5, 0], [0.5, 0.06, 0.25], \sin)) * 0.5;
			var sig = (rush + crackle + growl + thump + slam + crash + gasp).softclip;
			Out.ar(out, sig * EnvGen.ar(Env([1, 1], [0.9]), doneAction: 2));
		})
	],
	events: [[0, [\s_new, \lunge, -1, 0, 0]]]
)
)

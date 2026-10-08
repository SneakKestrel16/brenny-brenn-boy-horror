// sfx_crow_burst (placeholder, synthetic). The fake-out: a crow bursting out of the corn, mono, 3D, 1.2 s.
// Doc 08 sections 4.4 rule 4, 11.1: wing flaps (low-passed noise bursts at about 8 per s, thinning out)
// and one caw at 0.15 s (the sfx_crow_caw recipe).
(
(
	channels: 1,
	duration: 1.2,
	defs: [
		SynthDef(\flap, { |out = 0, amp = 1|
			var sig = LPF.ar(WhiteNoise.ar, 1400) * EnvGen.ar(Env.perc(0.01, 0.07, curve: -4), doneAction: 2);
			Out.ar(out, (sig + (BPF.ar(WhiteNoise.ar, 3500, 0.5) * 0.2 * EnvGen.ar(Env.perc(0.005, 0.03)))) * amp);
		}),
		SynthDef(\caw, { |out = 0, f0a = 620, f0b = 430, dur = 0.35, amp = 1|
			var env = EnvGen.ar(Env([0, 1, 0.7, 0], [0.02, dur * 0.6, dur * 0.4], [2, -1, -3]), doneAction: 2);
			var f0 = XLine.kr(f0a, f0b, dur) * (1 + (LFNoise1.kr(60) * 0.04));
			var rasp = 1 + (SinOsc.ar(f0 * 0.5) * 0.6);
			var src = (Saw.ar(f0) * rasp) + (WhiteNoise.ar * 0.3);
			var v = (BPF.ar(src, 900, 0.25) * 2) + (BPF.ar(src, 1800, 0.2) * 1.4) + (BPF.ar(src, 3000, 0.3) * 0.3);
			Out.ar(out, HPF.ar(v, 250) * env * amp);
		})
	],
	events: (
		8.collect { |i| [i * 0.12, [\s_new, \flap, -1, 0, 0, \amp, 1.0 - (i * 0.11)]] }
		++ [[0.15, [\s_new, \caw, -1, 0, 0, \f0a, 680, \f0b, 450, \dur, 0.4, \amp, 0.8]]]
	).sort { |a, b| a[0] <= b[0] }
)
)

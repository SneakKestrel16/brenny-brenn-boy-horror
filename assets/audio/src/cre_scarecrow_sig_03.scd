// cre_scarecrow_sig_03 (placeholder). Scarecrow lurk signature variant: slow heavy cloth flaps, 0.45 to 0.7 s apart, 90 to 140 Hz body
// (doc 08 section 6). Mono, 3D, 1.75 s, last flap ends before 1.7 s.
(
var times = List.new, t = 0.1;
thisThread.randSeed = 63;
while { t < 1.3 } { times.add(t); t = t + rrand(0.45, 0.7) };
(
	channels: 1,
	duration: 1.75,
	defs: [
		SynthDef(\flap, { |out = 0, body = 110, len = 0.12, amp = 0.8|
			var env = EnvGen.ar(Env.perc(0.004, len, curve: -4), doneAction: 2);
			var cloth = LPF.ar(BPF.ar(WhiteNoise.ar, 700, 0.8) + (PinkNoise.ar * 0.4), 1800) * env * 3;
			var snap = HPF.ar(WhiteNoise.ar, 2500) * EnvGen.ar(Env.perc(0.001, 0.012)) * 0.25;
			var thud = SinOsc.ar(body) * EnvGen.ar(Env.perc(0.004, 0.1)) * 0.6;
			Out.ar(out, (cloth + snap + thud) * amp);
		})
	],
	events: times.collect { |tt| [tt, [\s_new, \flap, -1, 0, 0, \body, rrand(90, 140), \len, rrand(0.09, 0.2), \amp, rrand(0.6, 0.85)]] }
)
)

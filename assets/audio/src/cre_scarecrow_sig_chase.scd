// cre_scarecrow_sig_chase (placeholder). Scarecrow chase signature: heavy cloth snapping, one flap per
// stride at 2.5 per s (period 0.4 s, 10 per loop), each a little different in length, low-passed noise
// with a 90 to 140 Hz body. Mono, 3D, 4 s loop. Doc 08 section 6.
(
thisThread.randSeed = 42;
(
	channels: 1,
	duration: 4,
	defs: [
		SynthDef(\flap, { |out = 0, body = 110, len = 0.12, amp = 0.8|
			var env = EnvGen.ar(Env.perc(0.004, len, curve: -4), doneAction: 2);
			var cloth = LPF.ar(BPF.ar(WhiteNoise.ar, 700, 0.8) + (PinkNoise.ar * 0.4), 1800) * env * 3;
			var snap = HPF.ar(WhiteNoise.ar, 2500) * EnvGen.ar(Env.perc(0.001, 0.012)) * 0.25;
			var thud = SinOsc.ar(body) * EnvGen.ar(Env.perc(0.004, 0.1)) * 0.6;
			Out.ar(out, (cloth + snap + thud) * amp);
		})
	],
	events: 10.collect { |i| [i * 0.4, [\s_new, \flap, -1, 0, 0, \body, rrand(90, 140), \len, rrand(0.09, 0.2), \amp, rrand(0.65, 0.9)]] }
)
)

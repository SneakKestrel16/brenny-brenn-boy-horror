// cre_gaunt_sig_chase (placeholder). Gaunt chase signature: dry tongue and joint clicks, irregular,
// about 10 per s, band-passed 1.8 to 3.4 kHz, each with a short hollow ~220 Hz knock. Mono, 3D, 4 s loop;
// the last click is before 3.8 s, so the tail dies before the seam. Doc 08 section 6.
(
var times, t = 0;
thisThread.randSeed = 41;
times = List.new;
while { t < 3.8 } { times.add(t); t = t + rrand(0.05, 0.17) };
(
	channels: 1,
	duration: 4,
	defs: [
		SynthDef(\click, { |out = 0, freq = 2600, amp = 0.7, knock = 220|
			var env = EnvGen.ar(Env.perc(0.0003, 0.003), doneAction: 2);
			var tick = BPF.ar(WhiteNoise.ar, freq, 0.35) * env * 7;
			var hollow = SinOsc.ar(knock) * EnvGen.ar(Env.perc(0.001, 0.035)) * 0.25;
			Out.ar(out, (tick + hollow) * amp);
		})
	],
	events: times.collect { |tt| [tt, [\s_new, \click, -1, 0, 0, \freq, rrand(1800, 3400), \amp, rrand(0.4, 0.9), \knock, rrand(200, 245)]] }
)
)

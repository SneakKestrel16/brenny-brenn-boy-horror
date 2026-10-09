// cre_gaunt_sig_02 (placeholder). Gaunt lurk signature variant: sparse dry tongue/joint clicks, 0.4 to 0.8 s apart, each with a
// short hollow ~220 Hz knock (doc 08 section 6). Mono, 3D, 1.75 s, last click before 1.5 s.
(
var times = List.new, t = 0.1;
thisThread.randSeed = 52;
while { t < 1.5 } { times.add(t); t = t + rrand(0.4, 0.8) };
(
	channels: 1,
	duration: 1.75,
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

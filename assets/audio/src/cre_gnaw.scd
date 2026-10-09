// cre_gnaw (placeholder). Something gnawing a pumpkin: four groups of wet crunches, 60 to 120 ms apart inside a group,
// each a bright crack, a low wet thump and a short slurp. Mono, 3D, 2.5 s, last crunch before 2.2 s. Doc 08 section 11.4.
(
var times = List.new, t = 0.1;
thisThread.randSeed = 91;
4.do {
	rrand(3, 5).do { times.add(t); t = t + rrand(0.06, 0.12) };
	t = t + rrand(0.25, 0.4);
};
(
	channels: 1,
	duration: 2.5,
	defs: [
		SynthDef(\crunch, { |out = 0, amp = 0.7, f = 2200|
			var crack = BPF.ar(WhiteNoise.ar, f, 0.8) * EnvGen.ar(Env.perc(0.002, 0.05, curve: -4), doneAction: 2) * 4;
			var wet = BPF.ar(PinkNoise.ar, 900, 0.5) * EnvGen.ar(Env.perc(0.01, 0.09, curve: -3)) * 2;
			var thump = LPF.ar(BrownNoise.ar, 300) * EnvGen.ar(Env.perc(0.003, 0.07)) * 2;
			Out.ar(out, (crack + wet + thump) * amp);
		})
	],
	events: times.select { |tt| tt < 2.3 }.collect { |tt| [tt, [\s_new, \crunch, -1, 0, 0, \amp, rrand(0.5, 0.9), \f, rrand(1500, 3200)]] }
)
)

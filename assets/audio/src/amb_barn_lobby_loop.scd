// amb_barn_lobby_loop (placeholder). Barn lobby / recording-spot room tone, stereo, 8 s exact loop:
// low brown-noise room hum, wind finding the gaps in the boards (slow band-pass sweeps, whole cycles
// in 8 s), two timber creaks well inside the file. No insects, no frogs, no music. Doc 08 section 4.5.
(
(
	channels: 2,
	duration: 8,
	defs: [
		SynthDef(\barn, { |out = 0|
			var sig = 2.collect { |i|
				var room = LPF.ar(BrownNoise.ar, 260) * 0.9;
				var gap = BPF.ar(PinkNoise.ar, LinExp.kr(SinOsc.kr(1 / 8, i * pi), -1, 1, 420, 760), 0.15)
					* (0.18 + (0.1 * SinOsc.kr(2 / 8, i)));
				room + gap
			};
			Out.ar(out, sig * 0.5);
		}),
		SynthDef(\creak, { |out = 0, f0 = 210, pan = 0|
			var env = EnvGen.ar(Env([0, 1, 0.6, 0], [0.12, 0.3, 0.4]), doneAction: 2);
			var f = XLine.kr(f0, f0 * 0.78, 0.8);
			var sig = BPF.ar(Saw.ar(f), f * 2, 0.08) * env * 0.5;
			Out.ar(out, Pan2.ar(sig, pan));
		})
	],
	events: [
		[0, [\s_new, \barn, -1, 0, 0]],
		[2.3, [\s_new, \creak, -1, 0, 0, \f0, 230, \pan, -0.5]],
		[5.4, [\s_new, \creak, -1, 0, 0, \f0, 180, \pan, 0.6]]
	]
)
)

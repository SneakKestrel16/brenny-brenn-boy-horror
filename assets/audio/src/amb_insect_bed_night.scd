// amb_insect_bed_night (placeholder). Stereo cricket bed, 20 s loop: 20 voices each repeat a
// 3-chirp train at 4.2 to 5.4 kHz every 0.9 to 1.6 s, random pan and phase; a faint high-noise floor.
// No train crosses the end. Doc 08 sections 4.1, 11.1. The bed carries the Stalk tell (it must never
// be silent in the loop), so voices are dense and the floor is steady.
(
var dur = 20;
thisThread.randSeed = 1701;
(
	channels: 2,
	duration: dur,
	defs: [
		SynthDef(\cricket, { |out = 0, freq = 4800, amp = 0.2, pan = 0|
			var env = EnvGen.ar(Env([0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0],
				[0.004, 0.035, 0.004, 0.03, 0.004, 0.035, 0.004, 0.03, 0.004, 0.035, 0.01]), doneAction: 2);
			var sig = SinOsc.ar(freq) * env * amp;
			Out.ar(out, Pan2.ar(sig, pan));
		}),
		SynthDef(\floor, { |out = 0|
			Out.ar(out, [HPF.ar(PinkNoise.ar, 5000), HPF.ar(PinkNoise.ar, 5000)] * 0.004);
		})
	],
	events: [[0, [\s_new, \floor, -1, 0, 0]]] ++ 20.collect { |v|
		var f = rrand(4200, 5400), p = rrand(-0.9, 0.9), a = rrand(0.08, 0.2), t = rrand(0.0, 1.5), out = List.new;
		while { t < (dur - 0.5) } {
			out.add([t, [\s_new, \cricket, -1, 0, 0, \freq, f * rrand(0.995, 1.005), \amp, a, \pan, p]]);
			t = t + rrand(0.9, 1.6);
		};
		out.asArray
	}.flatten(1).sort { |a, b| a[0] <= b[0] }
)
)

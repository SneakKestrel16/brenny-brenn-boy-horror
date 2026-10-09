// amb_insect_bed_night (placeholder). Stereo cricket bed, 20 s loop: 20 voices at 4.2 to 5.4 kHz take turns
// chirping a 3-chirp train, one train every 0.15 to 0.27 s across the bed (about 4.7 a second); the next voice
// is a random one that has rested at least 3 s, so each voice repeats every 3 to about 5 s (P4-26, CEO: chirps
// too often; voices used to repeat every 0.9 to 1.6 s, 16 trains a second). Shared turns, not independent
// timers: independent timers cluster and leave gaps near 0.9 s, and doc 08 s4.2
// keeps the layer above -4 dB from its base (P4-26 QA). Random pan; a faint high-noise floor. No train
// crosses the end. Doc 08 sections 4.1, 4.2, 11.1.
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
	events: [[0, [\s_new, \floor, -1, 0, 0]]] ++ Routine {
		var vs = 20.collect { [rrand(4200, 5400), rrand(-0.9, 0.9), rrand(0.12, 0.2)] }, t = rrand(0.0, 0.15);
		var last = 20.collect { rrand(-5.0, 0.0) }; // seconds since each voice last chirped, at the start
		while { t < (dur - 0.25) } {
			// a random voice that has rested 3 s, or the one that has rested longest if it passed 5 s: no fixed order
			var idle = (0..19).select { |k| (t - last[k]) >= 3.0 };
			var old = (0..19).maxItem { |k| t - last[k] };
			var k = if ((t - last[old]) >= 5.0 or: { idle.isEmpty }) { old } { idle.choose };
			var v = vs[k];
			last[k] = t;
			[t, [\s_new, \cricket, -1, 0, 0, \freq, v[0] * rrand(0.995, 1.005), \amp, v[2], \pan, v[1]]].yield;
			t = t + rrand(0.15, 0.27);
		};
	}.all
)
)

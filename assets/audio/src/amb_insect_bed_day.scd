// amb_insect_bed_day (placeholder). Stereo cicada and grasshopper bed, 20 s loop: 14 buzzing voices
// (saw through a 3.5 to 7 kHz band-pass, amplitude pulsed at 28 to 60 Hz), each swelling in and out
// over 3 to 6 s, never crossing the end. Doc 08 sections 4.1, 11.1.
(
var dur = 20;
thisThread.randSeed = 2209;
(
	channels: 2,
	duration: dur,
	defs: [
		SynthDef(\cicada, { |out = 0, freq = 5000, amp = 0.2, pan = 0, pulse = 40, len = 4|
			var env = EnvGen.ar(Env.sine(len), doneAction: 2);
			var am = 0.55 + (0.45 * LFPulse.ar(pulse, 0, 0.6));
			var sig = BPF.ar(Saw.ar(freq * 0.5), freq, 0.15) * am * env * amp;
			Out.ar(out, Pan2.ar(sig, pan));
		})
	],
	events: 14.collect { |v|
		var f = rrand(3500, 7000), p = rrand(-0.9, 0.9), a = rrand(0.15, 0.35), pl = rrand(28, 60), t = rrand(0.0, 3.0), out = List.new;
		while { t < (dur - 6.5) } {
			var l = rrand(3.0, 6.0);
			out.add([t, [\s_new, \cicada, -1, 0, 0, \freq, f, \amp, a, \pan, p, \pulse, pl, \len, l]]);
			t = t + l + rrand(0.0, 1.5);
		};
		out.asArray
	}.flatten(1).sort { |a, b| a[0] <= b[0] }
)
)

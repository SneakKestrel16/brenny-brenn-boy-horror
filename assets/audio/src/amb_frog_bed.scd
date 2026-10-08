// amb_frog_bed (placeholder). Stereo frog bed, 24 s loop: 8 voices croak (pulsed saw, 25 Hz pulse
// train with a fast glide, resonant peak) at 400 to 900 Hz every 1.5 to 4 s; no croak crosses the
// end. Doc 08 sections 4.1, 11.1.
(
var dur = 24;
thisThread.randSeed = 880;
(
	channels: 2,
	duration: dur,
	defs: [
		SynthDef(\croak, { |out = 0, freq = 600, amp = 0.2, pan = 0, len = 0.35|
			var env = EnvGen.ar(Env([0, 1, 1, 0], [0.03, len, 0.08]), doneAction: 2);
			var f = freq * XLine.kr(1.25, 0.85, len + 0.1);
			var sig = Saw.ar(f) * (0.4 + (0.6 * LFPulse.ar(25, 0, 0.5)));
			sig = BPF.ar(sig, f * 2, 0.25) + (SinOsc.ar(f) * 0.3);
			Out.ar(out, Pan2.ar(sig * env * amp, pan));
		})
	],
	events: 8.collect { |v|
		var f = rrand(400, 900), p = rrand(-0.9, 0.9), a = rrand(0.1, 0.25), t = rrand(0.0, 3.0), out = List.new;
		while { t < (dur - 1.0) } {
			var n = rrand(1, 3).round.asInteger;
			n.do { |k| out.add([t + (k * 0.55), [\s_new, \croak, -1, 0, 0, \freq, f, \amp, a, \pan, p, \len, rrand(0.25, 0.4)]]) };
			t = t + (n * 0.55) + rrand(1.5, 4.0);
		};
		out.select { |e| e[0] < (dur - 0.6) }
	}.flatten(1).sort { |a, b| a[0] <= b[0] }
)
)

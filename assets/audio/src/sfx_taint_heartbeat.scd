// sfx_taint_heartbeat (placeholder). Low wet "lub-dub" at 70 bpm, four beats, loops seamlessly:
// the file is exactly four beat periods long and each beat's tail dies before the next.
// P3-08 makes it wet (doc 01 "The Taint": "a faint wet heartbeat"): each thump carries a short
// resonant squelch (low-passed noise through a falling resonant filter), a timbre the dry still
// heartbeat (sfx_still_heartbeat_loop) does not have. Played only for the Tainted player.
(
var bpm = 70, beats = 4, period = 60 / bpm;
(
	channels: 1,
	duration: beats * period,
	defs: [
		SynthDef(\thump, { |out = 0, freq = 50, amp = 0.8, decay = 0.18, wet = 0.5|
			var env = EnvGen.ar(Env.perc(0.004, decay, curve: -6), doneAction: 2);
			var pitch = freq * (1 + (EnvGen.ar(Env.perc(0, 0.04)) * 1.5));
			var body = SinOsc.ar(pitch) * env;
			var knock = LPF.ar(WhiteNoise.ar, 900) * EnvGen.ar(Env.perc(0.001, 0.015)) * 0.3;
			var squelch = RLPF.ar(BrownNoise.ar, XLine.kr(700, 160, 0.12), 0.08)
				* EnvGen.ar(Env.perc(0.01, 0.12, curve: -4)) * wet * 0.25;
			Out.ar(out, LPF.ar(body + knock + squelch, 600) * amp);
		})
	],
	events: beats.collect { |i|
		var t = i * period;
		[
			[t, [\s_new, \thump, -1, 0, 0, \freq, 52, \amp, 0.9, \wet, 0.6]],
			[t + 0.28, [\s_new, \thump, -1, 0, 0, \freq, 46, \amp, 0.6, \decay, 0.22, \wet, 0.9]]
		]
	}.flatten(1)
)
)

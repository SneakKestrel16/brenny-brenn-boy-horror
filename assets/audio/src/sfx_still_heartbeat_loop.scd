// sfx_still_heartbeat_loop (placeholder). Dry close "tum-tum" at 60 bpm, three beats, exact loop (3 s).
// Tighter attack and no noise knock than the wet Taint beat. Doc 08 section 8; also the chase
// kill-warning heartbeat (P2-08: pitch and level rise with the chase).
(
var bpm = 60, beats = 3, period = 60 / bpm;
(
	channels: 1,
	duration: beats * period,
	defs: [
		SynthDef(\tum, { |out = 0, freq = 62, amp = 0.8, decay = 0.1|
			var env = EnvGen.ar(Env.perc(0.002, decay, curve: -5), doneAction: 2);
			var pitch = freq * (1 + (EnvGen.ar(Env.perc(0, 0.025)) * 0.8));
			Out.ar(out, LPF.ar(SinOsc.ar(pitch) * env, 300) * amp);
		})
	],
	events: beats.collect { |i|
		var t = i * period;
		[
			[t, [\s_new, \tum, -1, 0, 0, \freq, 62, \amp, 0.95]],
			[t + 0.2, [\s_new, \tum, -1, 0, 0, \freq, 55, \amp, 0.65, \decay, 0.12]]
		]
	}.flatten(1)
)
)

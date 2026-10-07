// sfx_taint_heartbeat (placeholder). Low "lub-dub" at 70 bpm, four beats, loops seamlessly:
// the file is exactly four beat periods long and each beat's tail dies before the next.
// The game speeds it up with pitch_scale as Taint rises.
(
var bpm = 70, beats = 4, period = 60 / bpm;
(
	channels: 1,
	duration: beats * period,
	defs: [
		SynthDef(\thump, { |out = 0, freq = 50, amp = 0.8, decay = 0.18|
			var env = EnvGen.ar(Env.perc(0.004, decay, curve: -6), doneAction: 2);
			var pitch = freq * (1 + (EnvGen.ar(Env.perc(0, 0.04)) * 1.5));
			var body = SinOsc.ar(pitch) * env;
			var knock = LPF.ar(WhiteNoise.ar, 900) * EnvGen.ar(Env.perc(0.001, 0.015)) * 0.3;
			Out.ar(out, LPF.ar(body + knock, 400) * amp);
		})
	],
	events: beats.collect { |i|
		var t = i * period;
		[
			[t, [\s_new, \thump, -1, 0, 0, \freq, 52, \amp, 0.9]],
			[t + 0.28, [\s_new, \thump, -1, 0, 0, \freq, 46, \amp, 0.6, \decay, 0.22]]
		]
	}.flatten(1)
)
)

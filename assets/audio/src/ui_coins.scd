// ui_coins (placeholder). A cascade of five coin ticks (resonators at 3.1 to 4.8 kHz), spread over 0.3 s: money paid or
// earned. Mono, UI, 0.5 s. Doc 08 section 11.2.
(
thisThread.randSeed = 63;
(
	channels: 1,
	duration: 0.5,
	defs: [
		SynthDef(\coin, { |out = 0, base = 3300, amp = 0.6|
			var ex = WhiteNoise.ar * EnvGen.ar(Env.perc(0.0003, 0.004), doneAction: 2);
			Out.ar(out, Klank.ar(`[[base, base * 1.51, base * 2.08], [1, 0.6, 0.35], [0.09, 0.07, 0.05]], ex * 0.2) * amp);
		})
	],
	events: 5.collect { |i| [i * 0.07 + rrand(0, 0.02), [\s_new, \coin, -1, 0, 0, \base, rrand(3100, 4800), \amp, rrand(0.45, 0.8)]] }
)
)

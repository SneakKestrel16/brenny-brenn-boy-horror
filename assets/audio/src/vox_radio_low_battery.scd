// vox_radio_low_battery (placeholder). Two flat 1.2 kHz beeps, 90 ms each, 250 ms apart. Mono, local. 0.6 s.
// Doc 08 sections 7.2, 11.6.
(
(
	channels: 1,
	duration: 0.6,
	defs: [
		SynthDef(\beep, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 1, 0], [0.005, 0.08, 0.01]), doneAction: 2);
			Out.ar(out, (SinOsc.ar(1200) + (SinOsc.ar(2400) * 0.15)) * env * 0.6);
		})
	],
	events: [0, 0.25].collect { |t| [t, [\s_new, \beep, -1, 0, 0]] }
)
)

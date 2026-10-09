// sfx_crow_burst (placeholder, synthetic, reworked after CEO listen 1). The fake-out: a crow bursting out of the
// corn, mono, 3D, 1.2 s. Doc 08 sections 4.4 rule 4, 11.1: feathery wing beats (uneven timing and strength,
// soft noise bursts with a flutter of grain, a leaf-rustle in front) and two startled caws (the
// sfx_crow_caw organic recipe). +0.83 dB (10 percent amplitude) over the first version, via the Soundscape level.
(
(
	channels: 1,
	duration: 1.2,
	defs: [
		SynthDef(\caw, { |out = 0, f0a = 700, f0b = 420, dur = 0.35, amp = 1, rough = 0.5|
			var env = EnvGen.ar(Env([0, 1, 0.8, 0], [0.025, dur * 0.55, dur * 0.45], [2, -1, -3]), doneAction: 2);
			var bend = EnvGen.kr(Env([0.92, 1.06, 1, 0.9], [0.1, 0.25, 0.65] * dur, \sin));
			var f0 = XLine.kr(f0a, f0b, dur) * bend * (1 + (LFNoise2.kr(45) * 0.05) + (LFNoise1.kr(180) * 0.02));
			var pulses = Impulse.ar(f0 * (1 + (LFNoise0.kr(f0 * 0.7) * 0.045 * (0.5 + rough))));
			var shim = 1 + (LFNoise1.kr(90) * 0.35 * rough);
			var sub = 1 - (0.5 * rough * (LFNoise1.kr(30) + 1) * 0.5 * LFPulse.ar(f0 * 0.5, 0, 0.5));
			var src = (pulses * shim * sub) + (PinkNoise.ar * 0.12 * (0.6 + rough)) + (Dust.ar(f0 * 0.5) * 0.4);
			var f1 = XLine.kr(850, 620, dur), f2 = XLine.kr(1500, 1250, dur), f3 = XLine.kr(2700, 2300, dur);
			var v = (Formlet.ar(src, f1, 0.0005, 0.006) * 1.0) + (Formlet.ar(src, f2, 0.0005, 0.004) * 0.8)
				+ (Formlet.ar(src, f3, 0.0005, 0.003) * 0.5);
			var air = HPF.ar(BPF.ar(WhiteNoise.ar, 2200, 0.5), 800) * 0.15 * LFNoise1.kr(40).range(0.4, 1);
			Out.ar(out, (HPF.ar(v * 0.35 + air, 220) * env * 3).tanh * amp);  // soft saturation: throaty, and RMS closer to the old caw
		}),
		SynthDef(\flap, { |out = 0, amp = 1, len = 0.09|
			var env = EnvGen.ar(Env([0, 1, 0.3, 0], [0.012, len * 0.4, len * 0.6], [2, -2, -4]), doneAction: 2);
			var air = LPF.ar(PinkNoise.ar, LFNoise1.kr(30).range(900, 2200)) * env;
			var grain = HPF.ar(Dust2.ar(900), 1500) * env * 0.5;
			Out.ar(out, (air + grain) * amp);
		}),
		SynthDef(\rustle, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 0.4, 0], [0.04, 0.25, 0.3], -2), doneAction: 2);
			Out.ar(out, (HPF.ar(BPF.ar(WhiteNoise.ar, 3000, 0.4), 1200) + (HPF.ar(Dust2.ar(1500), 2500) * 0.6)) * env * 0.35);
		})
	],
	events: (
		[[0, [\s_new, \rustle, -1, 0, 0]]]
		++ [0.04, 0.15, 0.25, 0.37, 0.5, 0.64, 0.78, 0.9].collect { |t, i|
			[t, [\s_new, \flap, -1, 0, 0, \amp, 1.0 - (i * 0.1), \len, 0.08 + (i * 0.012)]] }
		++ [[0.1, [\s_new, \caw, -1, 0, 0, \f0a, 760, \f0b, 460, \dur, 0.3, \amp, 0.8, \rough, 0.8]],
			[0.45, [\s_new, \caw, -1, 0, 0, \f0a, 700, \f0b, 420, \dur, 0.35, \amp, 0.6, \rough, 0.9]]]
	).sort { |a, b| a[0] <= b[0] }
)
)

// SUPERSEDED (D-066): assets/audio/sfx_crow_burst.wav is now a CC0 recording, see doc 08 section 13. Do not render.

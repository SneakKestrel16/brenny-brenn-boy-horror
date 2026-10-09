// sfx_crow_caw_02 (placeholder, synthetic, reworked after CEO listen 1). One longer, higher caw, mono, 3D, 0.7 s.
// Organic caw: a jittered glottal pulse train (irregular period and amplitude), a rough subharmonic
// wobble, noise in the throat, and three formants that move through the caw (open, then closing) on
// Formlet resonators. Uneven pitch contour per caw. Doc 08 section 11.1.
(
(
	channels: 1,
	duration: 0.7,
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
		})
	],
	events: [
		[0.02, [\s_new, \caw, -1, 0, 0, \f0a, 820, \f0b, 500, \dur, 0.5, \rough, 0.7]]
	]
)
)

// SUPERSEDED (D-066): assets/audio/sfx_crow_caw_02.wav is now a CC0 recording, see doc 08 section 13. Do not render.

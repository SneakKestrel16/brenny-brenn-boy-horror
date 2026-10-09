// vox_emote_scream (placeholder, synthetic, never a person; reworked after CEO listen 1). The "scream"
// emote, mono, 3D, 1.5 s. Doc 08 section 11.6. More human than the first saw version: a jittered glottal
// pulse train (random period and amplitude, shimmer), uneven rising pitch with a short break near the peak,
// vowel formants that move (ah toward eh and back, F1 up with effort), breath noise that is strongest at the
// onset and the fall, and a throat-roughness subharmonic late on. Formlet resonators like the stranger lines.
(
(
	channels: 1,
	duration: 1.5,
	defs: [
		SynthDef(\scream, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 0.9, 0.7, 0], [0.06, 0.5, 0.4, 0.5], [3, 0, -1, -3]), doneAction: 2);
			var contour = EnvGen.kr(Env([560, 760, 1050, 1180, 900, 640], [0.12, 0.45, 0.25, 0.3, 0.38], [2, 1, -1, -2, -2]));
			var brk = 1 - (0.35 * EnvGen.kr(Env([0, 0, 1, 0], [0.82, 0.015, 0.03])));
			var wob = 1 + (SinOsc.kr(5.8 + LFNoise1.kr(2)) * 0.03 * Line.kr(0.3, 1, 1)) + (LFNoise2.kr(25) * 0.025) + (LFNoise1.kr(160) * 0.012);
			var f0 = contour * brk * wob;
			var rough = 1 - (LFPulse.ar(f0 * 0.5, 0, 0.5) * 0.45 * EnvGen.kr(Env([0, 0, 1], [0.7, 0.6])));
			var jit = 1 + (LFNoise0.kr(f0 * 0.5) * 0.02);
			var shim = 1 + (LFNoise1.kr(110) * 0.25);
			var breathy = LPF.ar(PinkNoise.ar, 6000) * (0.08 + (0.1 * EnvGen.kr(Env([1, 0.1, 0.1, 0.5], [0.15, 0.9, 0.45]))));
			var src = (Impulse.ar(f0 * jit) * shim * rough) + breathy;
			var effort = EnvGen.kr(Env([0.8, 1.0, 1.15, 0.85], [0.3, 0.6, 0.6]));
			var f1 = 800 * effort * (1 + (LFNoise1.kr(7) * 0.04));
			var f2 = XLine.kr(1250, 1700, 1.5) * (1 + (LFNoise1.kr(6) * 0.03));
			var f3 = 2800 + (LFNoise1.kr(5) * 150);
			var v = (Formlet.ar(src, f1, 0.0004, 0.008) * 1.0) + (Formlet.ar(src, f2, 0.0004, 0.005) * 0.9)
				+ (Formlet.ar(src, f3, 0.0004, 0.003) * 0.7) + (HPF.ar(breathy, 3000) * 0.5);
			Out.ar(out, HPF.ar(v * 0.3, 180) * env);
		})
	],
	events: [[0.02, [\s_new, \scream, -1, 0, 0]]]
)
)

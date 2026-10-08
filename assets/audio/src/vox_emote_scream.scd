// vox_emote_scream (placeholder, synthetic, never a person). The "scream" emote, mono, 3D, 1.5 s. Doc 08
// section 11.6: a rising saw (600 Hz to 1100 Hz) through strong "ah" formants (850, 1250, 2900 Hz), with
// vibrato, a breathy rasp and a falling, fading end. Formant synthesis like the stranger lines (section 7.4).
(
(
	channels: 1,
	duration: 1.5,
	defs: [
		SynthDef(\scream, { |out = 0|
			var env = EnvGen.ar(Env([0, 1, 0.85, 0], [0.08, 0.9, 0.42], [3, -1, -3]), doneAction: 2);
			var f0 = EnvGen.kr(Env([600, 1100, 820], [0.7, 0.7], [-2, 2])) * (1 + (SinOsc.kr(6.5) * 0.025) + (LFNoise1.kr(30) * 0.01));
			var src = Saw.ar(f0) + (Pulse.ar(f0 * 0.5, 0.4) * 0.15) + (WhiteNoise.ar * 0.25);
			var v = (BPF.ar(src, 850, 0.12) * 3) + (BPF.ar(src, 1250, 0.12) * 2.2) + (BPF.ar(src, 2900, 0.15) * 1.2);
			Out.ar(out, HPF.ar(v, 200) * env);
		})
	],
	events: [[0.02, [\s_new, \scream, -1, 0, 0]]]
)
)

// vox_stranger_anyone (placeholder, synthetic). Generic "stranger" line "is anyone out there" (doc 03 section 16): a glottal pulse
// source through three band-pass formants per syllable, an aspirated or fricative onset, gentle pitch
// glide, high-passed. Mono, 3D. Not speech-grade and never a recording of anyone (doc 08 section 7.4).
(
(
	channels: 1,
	duration: 1.6,
	defs: [
		SynthDef(\syl, { |out = 0, dur = 0.25, f1 = 500, f2 = 1500, f0a = 140, f0b = 130, hiss = 0, hf = 5000|
			var env = EnvGen.ar(Env([0, 1, 0.8, 0], [0.03, dur * 0.7, dur * 0.3]), doneAction: 2);
			var f0 = XLine.kr(f0a, f0b, dur) * (1 + (0.01 * SinOsc.kr(5.5)));
			var src = Pulse.ar(f0, 0.3) + (WhiteNoise.ar * 0.15);
			var v = (BPF.ar(src, f1, 0.15) * 2.5) + (BPF.ar(src, f2, 0.15) * 1.8) + (BPF.ar(src, 2700, 0.2) * 0.8);
			var s = BPF.ar(WhiteNoise.ar, hf, 0.3) * EnvGen.ar(Env.perc(0.01, 0.08)) * hiss * 3;
			Out.ar(out, HPF.ar((v * env) + s, 100));
		})
	],
	events: [
[0.05, [\s_new, \syl, -1, 0, 0, \dur, 0.12, \f1, 400, \f2, 2000, \f0a, 130, \f0b, 130, \hiss, 0, \hf, 5000]],
[0.25, [\s_new, \syl, -1, 0, 0, \dur, 0.2, \f1, 550, \f2, 1800, \f0a, 135, \f0b, 140, \hiss, 0, \hf, 5000]],
[0.48, [\s_new, \syl, -1, 0, 0, \dur, 0.15, \f1, 400, \f2, 2000, \f0a, 140, \f0b, 150, \hiss, 0, \hf, 5000]],
[0.7, [\s_new, \syl, -1, 0, 0, \dur, 0.2, \f1, 600, \f2, 1200, \f0a, 150, \f0b, 140, \hiss, 0, \hf, 5000]],
[0.95, [\s_new, \syl, -1, 0, 0, \dur, 0.2, \f1, 700, \f2, 1100, \f0a, 140, \f0b, 150, \hiss, 0.4, \hf, 6000]],
[1.2, [\s_new, \syl, -1, 0, 0, \dur, 0.3, \f1, 450, \f2, 1350, \f0a, 160, \f0b, 125, \hiss, 0.3, \hf, 6000]]
	]
)
)

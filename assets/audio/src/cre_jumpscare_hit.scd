// cre_jumpscare_hit (placeholder; reworked after CEO listen 1). The day jumpscare's hit, mono, non-positional,
// 1.6 s. Doc 08 sections 5.4, 11.4. A full-range slam instead of a single burst: a short noise crack, a saturated
// sub drop (110 to 28 Hz), a broken shriek (two detuned FM voices a tritone apart, pitch sliding down with random
// jumps, driven into tanh) over a snarling low growl (a 55 Hz pulse through moving formants), and a dark reverb
// tail. Dead by 1.5 s.
(
(
	channels: 1,
	duration: 1.6,
	defs: [
		SynthDef(\hit, { |out = 0|
			var crack = HPF.ar(WhiteNoise.ar, 400) * EnvGen.ar(Env.perc(0.0005, 0.09, curve: -8)) * 1.2;
			var slam = LPF.ar(PinkNoise.ar, 1500) * EnvGen.ar(Env.perc(0.001, 0.35, curve: -5)) * 0.9;
			var drop = SinOsc.ar(XLine.kr(110, 28, 0.5)) * EnvGen.ar(Env.perc(0.001, 0.9, curve: -4));
			var sub = (drop * 2.2).tanh * 0.9;
			var glide = XLine.kr(2400, 700, 1.1) * (1 + (LFNoise0.kr(18) * 0.09)) * (1 + (LFNoise2.kr(40) * 0.03));
			var shriek = ((SinOsc.ar(glide + (SinOsc.ar(glide * 1.41) * glide * 2.2)) * 0.6)
				+ (SinOsc.ar(glide * 1.414 + (SinOsc.ar(glide * 0.5) * glide * 1.5)) * 0.4)
				+ (BPF.ar(WhiteNoise.ar, glide, 0.5) * 0.5)).tanh
				* EnvGen.ar(Env([0, 1, 0.75, 0.3, 0], [0.01, 0.35, 0.5, 0.35], [-2, -1, -1, -3])) * 0.7;
			var gf = 55 * (1 + (LFNoise1.kr(12) * 0.08));
			var gsrc = Impulse.ar(gf) + (PinkNoise.ar * 0.1);
			var growl = ((Formlet.ar(gsrc, XLine.kr(400, 220, 1.2), 0.001, 0.02) * 0.5)
				+ (Formlet.ar(gsrc, 900, 0.001, 0.01) * 0.3)).tanh
				* EnvGen.ar(Env([0, 1, 0.7, 0], [0.02, 0.6, 0.6], -2)) * 0.8;
			var dry = crack + slam + sub + shriek + growl;
			var fade = EnvGen.ar(Env([1, 1, 0], [1.2, 0.3]), doneAction: 2);
			Out.ar(out, (FreeVerb.ar(dry, 0.3, 0.7, 0.6) * 0.8 + (dry * 0.5)).softclip * fade);
		})
	],
	events: [[0, [\s_new, \hit, -1, 0, 0]]]
)
)

// SUPERSEDED (D-066): assets/audio/cre_jumpscare_hit.wav is now a CC0 recording, see doc 08 section 13. Do not render.

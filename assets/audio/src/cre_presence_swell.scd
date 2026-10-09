// cre_presence_swell (placeholder; reworked after CEO listen 1). The private "something's there" for the
// hallucination and the wrong count, mono, non-positional, 6 s. Doc 08 sections 5.4, 11.4. No pitched tone
// above the floor: a huge slow breath (two inhales and exhales of dark noise whose filter opens and closes),
// a sub-bass pressure that never settles (two detuned drifting low sines), a close "mouth" layer of murmuring
// vowel-shaped noise barely above the breath, and slow irregular creaks of low brown noise. Rises 3 s, sinks 3 s,
// ends silent.
(
(
	channels: 1,
	duration: 6.0,
	defs: [
		SynthDef(\presence, { |out = 0|
			var swell = EnvGen.ar(Env([0, 1, 0], [3, 3], [2, -2]));
			var breath = EnvGen.kr(Env([0, 0.2, 1, 0.1, 0.9, 0.05, 0], [0.4, 1.0, 0.9, 1.1, 1.2, 1.4], \sin));
			var air = PinkNoise.ar * breath;
			var dark = LPF.ar(BrownNoise.ar, 90 + (breath * 400)) * 1.6 * breath;
			var chest = BPF.ar(air, 220 + (breath * 300), 0.9) * 1.2;
			var mouth = BPF.ar(PinkNoise.ar, LFNoise1.kr(0.7).range(500, 900), 0.35) * breath * LFNoise1.kr(3).range(0.1, 0.5) * 0.35;
			var sub = (SinOsc.ar(38 + (LFNoise1.kr(0.3) * 2)) + SinOsc.ar(40.6 + (LFNoise1.kr(0.4) * 2.5)) * 0.8) * 0.6;
			var creak = LPF.ar(BrownNoise.ar, 140) * LFNoise2.kr(1.3).abs * 1.2;
			var sig = (dark + chest + mouth + sub + creak) * swell;
			Out.ar(out, sig * 0.5 * EnvGen.ar(Env([1, 1], [5.98]), doneAction: 2));
		})
	],
	events: [[0, [\s_new, \presence, -1, 0, 0]]]
)
)

// SUPERSEDED (D-066): assets/audio/cre_presence_swell.wav is now a CC0 recording, see doc 08 section 13. Do not render.

// sfx_door_slam (placeholder). The shed scare's door slamming shut behind the player, mono, 3D, 1.2 s.
// Doc 08 sections 5.4, 11.2: a heavy bang (sharper and louder than cre_door_bang's fist), a latch click
// just after, the frame rattling (fast impulses through wood resonators), and a short room tail.
(
(
	channels: 1,
	duration: 1.2,
	defs: [
		SynthDef(\slam, { |out = 0|
			var hit = EnvGen.ar(Env.perc(0.0005, 0.02));
			var thump = SinOsc.ar(70 * (1 + (EnvGen.ar(Env.perc(0, 0.05)) * 1.5))) * EnvGen.ar(Env.perc(0.001, 0.35, curve: -5)) * 1.2;
			var crack = HPF.ar(WhiteNoise.ar, 800) * hit * 1.2;
			var wood = Klank.ar(`[[160, 270, 430, 690, 1020], [1, 0.8, 0.6, 0.4, 0.25], [0.4, 0.35, 0.3, 0.2, 0.15]], PinkNoise.ar * hit * 0.2);
			var rattle = Klank.ar(`[[310, 520, 880], [1, 0.6, 0.4], [0.03, 0.03, 0.02]],
				Dust.ar(EnvGen.ar(Env([60, 60, 0], [0.05, 0.4]))) * 0.5) * EnvGen.ar(Env([0, 0, 1, 0], [0.04, 0.01, 0.45], -3));
			var latch = HPF.ar(WhiteNoise.ar, 3000) * EnvGen.ar(Env([0, 0, 1, 0], [0.09, 0.0005, 0.006])) * 0.6;
			var dry = thump + crack + wood + rattle + latch;
			var fade = EnvGen.ar(Env([1, 1, 0], [0.9, 0.25]), doneAction: 2);
			Out.ar(out, FreeVerb.ar(dry, 0.2, 0.4, 0.5) * fade);
		})
	],
	events: [[0, [\s_new, \slam, -1, 0, 0]]]
)
)

// SUPERSEDED (D-066): assets/audio/sfx_door_slam.wav is now a CC0 recording, see doc 08 section 13. Do not render.

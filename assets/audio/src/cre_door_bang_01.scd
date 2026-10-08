// cre_door_bang_01 (placeholder). A fist on the barn door: low thump, noise knock, wood rattle, a weaker
// rebound at 0.2 s. Mono, 3D, 1.0 s. Doc 08 section 5.4 / 11.4, P2-03 staging.
(
(
	channels: 1,
	duration: 1.0,
	defs: [
		SynthDef(\bang, { |out = 0, amp = 1.0|
			var hit = EnvGen.ar(Env.perc(0.001, 0.03));
			var thump = SinOsc.ar(55 * (1 + (EnvGen.ar(Env.perc(0, 0.06)) * 1.2))) * EnvGen.ar(Env.perc(0.002, 0.28, curve: -5)) * 1.1;
			var knock = LPF.ar(WhiteNoise.ar, 900) * hit * 0.8;
			var wood = Klank.ar(`[[190, 330, 510, 790], [1, 0.7, 0.5, 0.3], [0.35, 0.3, 0.25, 0.2]], PinkNoise.ar * hit * 0.15);
			var sig = (thump + knock + wood) * amp;
			DetectSilence.ar(sig, 0.0003, 0.2, doneAction: 2);
			Out.ar(out, sig);
		})
	],
	events: [[0, [\s_new, \bang, -1, 0, 0]], [0.2, [\s_new, \bang, -1, 0, 0, \amp, 0.45]]]
)
)

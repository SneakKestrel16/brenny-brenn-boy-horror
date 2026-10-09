// cre_corn_part_01 (placeholder; reworked after CEO listen 1). Heavy stalks parting and breaking, mono, 3D, 1.0 s.
// Doc 08 sections 5.4, 11.4. Variant 01: two snaps. Many small leaf and husk crackles (dense Dust grains
// through moving filters) over a low shoulder-push, then loud green-wood snaps (a noise crack plus a woody
// low-mid body, no ringing resonators) and tearing leaf rasps. The disarm lunge's warning.
(
(
	channels: 1,
	duration: 1.0,
	defs: [
		SynthDef(\part, { |out = 0, pitch = 1|
			var env = EnvGen.ar(Env([0, 1, 0.6, 0.2, 0], [0.12, 0.3, 0.3, 0.25], [2, -1, -2, -3]));
			var leaf = BPF.ar(PinkNoise.ar, LFNoise1.kr(9).range(1800, 4200) * pitch, 0.5) * env * 0.9;
			var crackle = HPF.ar(LPF.ar(Dust2.ar(LFNoise1.kr(6).range(300, 900)), 6000), 800) * env * 1.4;
			var push = LPF.ar(BrownNoise.ar, 350 * pitch) * EnvGen.ar(Env([0, 1, 0.5, 0], [0.15, 0.4, 0.35], [2, -2, -3])) * 1.3;
			var rasp = HPF.ar(WhiteNoise.ar, 4500) * env * LFNoise1.kr(14).range(0, 0.4) * 0.5;
			Out.ar(out, (leaf + crackle + push + rasp) * EnvGen.ar(Env([1, 1], [0.97]), doneAction: 2));
		}),
		SynthDef(\snap, { |out = 0, freq = 500, amp = 0.8|
			var env = EnvGen.ar(Env.perc(0.0005, 0.07, curve: -7), doneAction: 2);
			var crack = HPF.ar(WhiteNoise.ar, 1500) * EnvGen.ar(Env.perc(0.0003, 0.012, curve: -6)) * 1.3;
			var wood = BPF.ar(PinkNoise.ar, freq, 1.2) * env * 2.5;
			var splinter = HPF.ar(Dust2.ar(1200), 2000) * EnvGen.ar(Env.perc(0.005, 0.12)) * 0.5;
			Out.ar(out, (crack + wood + splinter) * amp);
		})
	],
	events: [
		[0, [\s_new, \part, -1, 0, 0, \pitch, 1.0]],
		[0.12, [\s_new, \snap, -1, 0, 0, \freq, 550, \amp, 0.9]],
		[0.33, [\s_new, \snap, -1, 0, 0, \freq, 420, \amp, 0.75]]
	]
)
)

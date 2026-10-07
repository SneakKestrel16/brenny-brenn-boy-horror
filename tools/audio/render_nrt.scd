// Renders one sound source to a WAV file in non-real-time (no audio device, no window).
// Run by tools/audio/render.py, not by hand:
//   sclang tools/audio/render_nrt.scd <source.scd> <out.wav>
//
// A source file's last expression is an Event:
//   channels: 1 (default) or 2
//   duration: length of the file in seconds
//   defs:     array of SynthDefs
//   events:   array of [time, [OSC command]] in time order, e.g. [0.5, [\s_new, \thump, -1, 0, 0, \freq, 50]]
(
var src = thisProcess.argv[0], out = thisProcess.argv[1];
try {
	var spec = thisProcess.interpreter.executeFile(src);
	var score = Score.new, opts;
	if(spec.isNil or: { spec[\duration].isNil }) {
		Error("% must end with an Event that has duration, defs and events".format(src)).throw;
	};
	opts = ServerOptions.new
		.numOutputBusChannels_(spec[\channels] ? 1)
		.numInputBusChannels_(0)
		.memSize_(65536);
	// Defs first: in NRT, commands at the same time run in the order they were added.
	spec[\defs].do { |def| score.add([0.0, [\d_recv, def.asBytes]]) };
	spec[\events].do { |e| score.add(e) };
	score.add([spec[\duration], [\c_set, 0, 0]]);
	score.recordNRT(
		outputFilePath: out, sampleRate: 48000, headerFormat: "WAV", sampleFormat: "int16",
		options: opts, duration: spec[\duration],
		action: { "RENDERED %".format(out).postln; 0.exit }
	);
} { |err|
	err.reportError;
	"ERROR: render failed for %".format(src).postln;
	1.exit;
};
)

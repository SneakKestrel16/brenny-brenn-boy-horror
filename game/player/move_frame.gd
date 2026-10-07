extends RefCounted
## Wire format of the movement stream (doc 06 section 7, channel 1): byte 0 is the packet type, then
## frames. Pure functions so tests can run them without autoloads.

const MOVE := 1  ## client -> host: type, one frame
const MOVES := 2  ## host -> all: type, count u8, then (peer s32, frame) x count
const FRAME_BYTES := 25  ## seq u32, position 3 x f32, yaw f32, pitch f32, flags u8


static func pack(seq: int, pos: Vector3, yaw: float, pitch: float, crouch: bool, sprint: bool) -> PackedByteArray:
	var b := PackedByteArray([MOVE])
	b.resize(1 + FRAME_BYTES)
	write(b, 1, seq, pos, yaw, pitch, crouch, sprint)
	return b


static func write(b: PackedByteArray, o: int, seq: int, pos: Vector3, yaw: float, pitch: float, crouch: bool, sprint: bool) -> void:
	b.encode_u32(o, seq)
	b.encode_float(o + 4, pos.x)
	b.encode_float(o + 8, pos.y)
	b.encode_float(o + 12, pos.z)
	b.encode_float(o + 16, yaw)
	b.encode_float(o + 20, pitch)
	b.encode_u8(o + 24, (1 if crouch else 0) | (2 if sprint else 0))


static func unpack(b: PackedByteArray, o: int) -> Dictionary:
	var flags := b.decode_u8(o + 24)
	return {"seq": b.decode_u32(o), "pos": Vector3(b.decode_float(o + 4), b.decode_float(o + 8), b.decode_float(o + 12)),
			"yaw": b.decode_float(o + 16), "pitch": b.decode_float(o + 20),
			"crouch": flags & 1 != 0, "sprint": flags & 2 != 0}

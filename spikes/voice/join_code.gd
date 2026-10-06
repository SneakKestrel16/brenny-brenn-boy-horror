extends RefCounted
## Join codes, doc 06 section 4 "Format".
##
## Crockford base32. Short form: IPv4 (32 bits) + CRC-8 poly 0x07 = 8 characters, default port only.
## Long form: IPv4 + port (16 bits) + CRC-12 poly 0x80F = 12 characters. Both CRCs are MSB-first,
## init 0, no reflection, over the big-endian address (and port) bytes. Doc 06's examples
## (203.0.113.7 -> SC07-21W2, :45121 -> SC07-21XG-85AX) are checked by tests/net/test_join_code.gd.
## Spike code (DECISIONS D-004): DD Phase 1 rebuilds this in game/net/.

const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
## Doc 06 section 2: UDP 45120 (placeholder).
const DEFAULT_PORT := 45120


static func _crc(data: PackedByteArray, width: int, poly: int) -> int:
	var mask := (1 << width) - 1
	var top := 1 << (width - 1)
	var c := 0
	for b in data:
		c ^= b << (width - 8)
		for _i in 8:
			c = ((c << 1) ^ poly) & mask if c & top else (c << 1) & mask
	return c


static func _ip_bytes(ip: String) -> PackedByteArray:
	var parts := ip.split(".")
	var out := PackedByteArray()
	if parts.size() != 4:
		return out
	for p in parts:
		if not p.is_valid_int() or int(p) < 0 or int(p) > 255:
			return PackedByteArray()
		out.append(int(p))
	return out


static func _to_base32(value: int, chars: int) -> String:
	var s := ""
	for i in chars:
		s += ALPHABET[(value >> (5 * (chars - 1 - i))) & 31]
	return s


## Returns "" when `ip` is not an IPv4 address.
static func encode(ip: String, port: int = DEFAULT_PORT) -> String:
	var b := _ip_bytes(ip)
	if b.is_empty():
		return ""
	var addr := (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]
	if port == DEFAULT_PORT:
		var s := _to_base32((addr << 8) | _crc(b, 8, 0x07), 8)
		return s.substr(0, 4) + "-" + s.substr(4)
	var d := b.duplicate()
	d.append((port >> 8) & 0xFF)
	d.append(port & 0xFF)
	var l := _to_base32((((addr << 16) | port) << 12) | _crc(d, 12, 0x80F), 12)
	return l.substr(0, 4) + "-" + l.substr(4, 4) + "-" + l.substr(8)


## Normalises typed input: case-insensitive, O reads as 0, I and L read as 1, spaces and hyphens
## ignored. Returns "" if any other character is not in the alphabet.
static func normalise(code: String) -> String:
	var out := ""
	for typed in code.to_upper():
		var ch := typed
		if ch == " " or ch == "-":
			continue
		if ch == "O":
			ch = "0"
		elif ch == "I" or ch == "L":
			ch = "1"
		if ALPHABET.find(ch) < 0:
			return ""
		out += ch
	return out


## Returns {"ok": true, "ip": String, "port": int} or {"ok": false, "error": String}.
static func decode(code: String) -> Dictionary:
	var n := normalise(code)
	if n.length() != 8 and n.length() != 12:
		return {"ok": false, "error": "A join code has 8 or 12 characters"}
	var v := 0
	for ch in n:
		v = (v << 5) | ALPHABET.find(ch)
	var addr: int
	var port: int
	var b := PackedByteArray()
	if n.length() == 8:
		addr = v >> 8
		port = DEFAULT_PORT
		b = PackedByteArray([(addr >> 24) & 0xFF, (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF])
		if _crc(b, 8, 0x07) != v & 0xFF:
			return {"ok": false, "error": "That code has a typo"}
	else:
		addr = v >> 28
		port = (v >> 12) & 0xFFFF
		b = PackedByteArray([(addr >> 24) & 0xFF, (addr >> 16) & 0xFF, (addr >> 8) & 0xFF, addr & 0xFF,
				(port >> 8) & 0xFF, port & 0xFF])
		if _crc(b, 12, 0x80F) != v & 0xFFF:
			return {"ok": false, "error": "That code has a typo"}
	return {"ok": true, "ip": "%d.%d.%d.%d" % [b[0], b[1], b[2], b[3]], "port": port}


## Doc 06 section 3: private (10/8, 172.16/12, 192.168/16), carrier-grade NAT (100.64/10), public.
static func classify(ip: String) -> String:
	var b := _ip_bytes(ip)
	if b.is_empty():
		return "unknown"
	if b[0] == 10 or (b[0] == 172 and b[1] >= 16 and b[1] <= 31) or (b[0] == 192 and b[1] == 168):
		return "private"
	if b[0] == 100 and b[1] >= 64 and b[1] <= 127:
		return "cgnat"
	if b[0] == 127 or b[0] == 0 or (b[0] == 169 and b[1] == 254) or b[0] >= 224:
		return "unknown"
	return "public"

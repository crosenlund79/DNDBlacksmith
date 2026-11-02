## Audio — buses, sound effects, ambience and music with a template/override system.
## EN: play("sfx/hammer_1") resolves user://overrides/audio/<id>.(ogg|wav) first, then
##     res://assets/audio/<id>.(ogg|wav). Missing sounds are logged once and skipped silently.
##     Buses (Music, SFX, Ambience, UI) are created at runtime and follow Settings volumes.
## DA: play("sfx/hammer_1") slår først op i user://overrides/audio/ og derefter i
##     res://assets/audio/. Manglende lyde logges én gang og springes over. Busser oprettes ved
##     kørsel og følger lydstyrkerne i Settings.
extends Node

const BUSES := ["Music", "SFX", "Ambience", "UI"]
const AUDIO_ROOT := "res://assets/audio/"
const OVERRIDE_ROOT := "user://overrides/audio/"
const POOL := 12

var _cache := {}
var _missing := {}
var _pool: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_id := ""
var _amb := {}   # layer -> AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(OVERRIDE_ROOT)
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	apply_volumes()


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func apply_volumes() -> void:
	var map := {"Master": "audio/master", "Music": "audio/music", "SFX": "audio/sfx", "Ambience": "audio/ambience", "UI": "audio/ui"}
	for bus in map:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			var v: float = Settings.get_value(map[bus], 0.8)
			AudioServer.set_bus_volume_db(idx, linear_to_db(max(v, 0.0001)))
			AudioServer.set_bus_mute(idx, v <= 0.001)


func get_stream(id: String) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var stream: AudioStream = null
	for root in [OVERRIDE_ROOT, AUDIO_ROOT]:
		for ext in [".ogg", ".wav"]:
			var p: String = root + id + ext
			if root == AUDIO_ROOT and ResourceLoader.exists(p):
				stream = load(p)
			elif FileAccess.file_exists(p):
				stream = AudioStreamOggVorbis.load_from_file(p) if ext == ".ogg" else _load_wav(p)
			if stream:
				break
		if stream:
			break
	if stream == null:
		if not _missing.has(id):
			_missing[id] = true
			Log.warn("Missing audio '%s'" % id)
	else:
		_set_loop(stream, id.ends_with("_loop") or id.begins_with("music/"))
	_cache[id] = stream
	return stream


func _set_loop(stream: AudioStream, loop: bool) -> void:
	if stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		if loop:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			var bytes_per_frame := (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)
			w.loop_end = int(w.data.size() / bytes_per_frame)
		else:
			w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop


## Minimal RIFF/WAVE (PCM 8/16-bit) reader used when the file has not been imported.
func _load_wav(path: String) -> AudioStreamWAV:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var bytes := f.get_buffer(f.get_length())
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var channels := 1
	var rate := 22050
	var bits := 16
	var pos := 12
	var data := PackedByteArray()
	while pos + 8 <= bytes.size():
		var cid := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size := bytes.decode_u32(pos + 4)
		if cid == "fmt ":
			channels = bytes.decode_u16(pos + 10)
			rate = bytes.decode_u32(pos + 12)
			bits = bytes.decode_u16(pos + 22)
		elif cid == "data":
			data = bytes.slice(pos + 8, pos + 8 + size)
		pos += 8 + size + (size % 2)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
	if bits == 8:
		for i in data.size():
			data[i] = (data[i] - 128) & 0xFF
	s.stereo = channels == 2
	s.mix_rate = rate
	s.data = data
	return s


func play(id: String, volume_db := 0.0, pitch := 1.0, bus := "") -> void:
	var stream := get_stream(id)
	if stream == null:
		return
	var p: AudioStreamPlayer = null
	for cand in _pool:
		if not cand.playing:
			p = cand
			break
	if p == null:
		p = _pool[0]
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus if bus != "" else ("UI" if id.begins_with("sfx/ui_") or id == "sfx/page_turn" else "SFX")
	p.play()


func play_varied(id: String, volume_db := 0.0) -> void:
	play(id, volume_db, randf_range(0.92, 1.08))


## Positional one-shot in the world (falls off with distance).
func play_at(id: String, pos: Vector2, parent: Node, volume_db := 0.0) -> void:
	var stream := get_stream(id)
	if stream == null or parent == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.bus = "SFX"
	p.volume_db = volume_db
	p.max_distance = 1400
	p.position = pos
	p.pitch_scale = randf_range(0.94, 1.06)
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func play_music(id: String, fade := 2.0) -> void:
	if id == _music_id:
		return
	_music_id = id
	var stream := get_stream(id)
	var old := _music_a if _music_a.playing else _music_b
	var nxt := _music_b if old == _music_a else _music_a
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -40.0, fade)
		tw.tween_callback(old.stop)
	if stream:
		nxt.stream = stream
		nxt.volume_db = -40.0
		nxt.play()
		create_tween().tween_property(nxt, "volume_db", 0.0, fade)


func set_ambience(layer: String, id: String, volume_db := 0.0, fade := 1.5) -> void:
	var p: AudioStreamPlayer = _amb.get(layer)
	if p == null:
		p = _make_player("Ambience")
		_amb[layer] = p
	if id == "":
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -40.0, fade)
		tw.tween_callback(p.stop)
		p.set_meta("id", "")
		return
	if p.get_meta("id", "") == id and p.playing:
		create_tween().tween_property(p, "volume_db", volume_db, fade)
		return
	var stream := get_stream(id)
	if stream == null:
		return
	p.set_meta("id", id)
	p.stream = stream
	p.volume_db = -40.0
	p.play()
	create_tween().tween_property(p, "volume_db", volume_db, fade)

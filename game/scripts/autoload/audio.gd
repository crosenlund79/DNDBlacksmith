## Audio — buses, sound effects, ambience and music with a template/override system.
## EN: play("sfx/hammer_1") resolves, in order:
##       1. user://overrides/audio/<id>.(ogg|wav)        (player / modder override)
##       2. res://assets/audio/inbox/<id>.(ogg|wav)      (creator inbox: drop files named after the id,
##                                                         mirroring its path — see inbox/README.md)
##       3. res://assets/audio/<id>.(ogg|wav)            (the shipped procedural sound)
##     then the same three for ALIASES[id], so context ids such as "amb/harbour" or "music/lantern"
##     play a fitting shipped sound until someone provides a dedicated one.
##     Missing sounds are logged once and skipped silently.
##     Buses (Music, SFX, Ambience, UI) are created at runtime and follow Settings volumes.
## DA: play("sfx/hammer_1") slår først op i user://overrides/audio/ og derefter i
##     res://assets/audio/. Manglende lyde logges én gang og springes over. Busser oprettes ved
##     kørsel og følger lydstyrkerne i Settings.
extends Node

const BUSES := ["Music", "SFX", "Ambience", "UI"]
const AUDIO_ROOT := "res://assets/audio/"
const OVERRIDE_ROOT := "user://overrides/audio/"
const INBOX_ROOT := "res://assets/audio/inbox/"
const POOL := 12
## Context ids → the shipped sound that serves them until a dedicated file exists.
const ALIASES := {
	"amb/harbour": "amb/harbour_loop", "amb/pond": "amb/pond_loop", "amb/tavern": "amb/tavern_loop",
	"amb/inn": "amb/tavern_loop", "amb/lantern": "amb/tavern_loop", "amb/velvet_lantern": "amb/tavern_loop",
	"amb/ironfront": "amb/tavern_loop", "music/lantern": "music/village_evening", "music/harbour": "music/village_evening",
	"music/pond": "music/hearth_day", "sfx/ui_chip": "sfx/ui_click", "sfx/ui_toggle": "sfx/ui_click",
	"sfx/ui_confirm": "sfx/check_good", "sfx/ui_tab": "sfx/page_turn", "sfx/rest": "sfx/page_turn",
}

var inbox_root := INBOX_ROOT    # tests point this at user:// to check the resolution order

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


## Every path tried for an id, in resolution order (override → inbox → shipped).
func candidate_paths(id: String) -> Array:
	var out := []
	for root in [OVERRIDE_ROOT, inbox_root, AUDIO_ROOT]:
		for ext in [".ogg", ".wav"]:
			out.append(root + id + ext)
	return out


static func _present(p: String) -> bool:
	return (p.begins_with("res://") and ResourceLoader.exists(p)) or FileAccess.file_exists(p)


## The file that will play for `id` ("" if none), following ALIASES when the id itself has no file.
func resolve_path(id: String) -> String:
	for p: String in candidate_paths(id):
		if _present(p):
			return p
	if ALIASES.has(id):
		return resolve_path(ALIASES[id])
	return ""


func _load_path(p: String) -> AudioStream:
	if p.begins_with("res://") and ResourceLoader.exists(p):
		return load(p)
	if FileAccess.file_exists(p):
		return AudioStreamOggVorbis.load_from_file(p) if p.ends_with(".ogg") else _load_wav(p)
	return null


func get_stream(id: String) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var stream: AudioStream = null
	var path := resolve_path(id)
	if path != "":
		stream = _load_path(path)
	if stream == null:
		if not _missing.has(id):
			_missing[id] = true
			Log.warn("Missing audio '%s'" % id)
	else:
		_set_loop(stream, id.ends_with("_loop") or id.begins_with("music/") or id.begins_with("amb/"))
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

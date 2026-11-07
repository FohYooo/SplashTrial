extends Node
## Audio manager. Autoload name: Audio
##   Audio.play_music("trial")     # res://audio/music/trial.ogg|.wav (loops)
##   Audio.stop_music()
##   Audio.sfx("break")            # res://audio/sfx/break.ogg|.wav
##   Audio.blip(1.2)               # dialogue text blip at a pitch
## Missing files are ignored silently (one warning), so code never crashes on absent audio.

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _current := ""
var _sfx_pool: Array[AudioStreamPlayer] = []
var _cache := {}
var _warned := {}
var _last_blip_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_active = _music_a
	for i in 12:
		_sfx_pool.append(_make_player("SFX"))
	apply_volumes()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(Game.music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(Game.sfx_volume, 0.0001)))


func _load(base: String, loop: bool) -> AudioStream:
	var key := base + ("#loop" if loop else "")
	if _cache.has(key):
		return _cache[key]
	var s: AudioStream = null
	if FileAccess.file_exists(base + ".ogg"):
		var o := AudioStreamOggVorbis.load_from_file(base + ".ogg")
		if o:
			o.loop = loop
			s = o
	elif FileAccess.file_exists(base + ".wav"):
		var w := AudioStreamWAV.load_from_file(base + ".wav")
		if w:
			if loop:
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				w.loop_end = int(w.get_length() * w.mix_rate)
			s = w
	if s == null and not _warned.has(base):
		_warned[base] = true
		print_verbose("Audio: missing ", base)
	_cache[key] = s
	return s


func current_music() -> String:
	return _current


func play_music(id: String, fade: float = 1.0) -> void:
	if id == "" or id == "stop" or id == "none":
		stop_music(fade)
		return
	if id == _current and _active.playing:
		return
	_current = id
	var stream := _load("res://audio/music/" + id, true)
	var old := _active
	var nxt := _music_b if _active == _music_a else _music_a
	_active = nxt
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.tween_callback(old.stop)
	if stream == null:
		return
	nxt.stream = stream
	nxt.stream_paused = false
	nxt.volume_db = -40.0
	nxt.play()
	var tw2 := create_tween()
	tw2.tween_property(nxt, "volume_db", 0.0, maxf(fade * 0.6, 0.05))


## Freeze/resume the current music in place (e.g. while a timed cutscene is paused).
func set_music_paused(on: bool) -> void:
	for p in [_music_a, _music_b]:
		p.stream_paused = on


## Cut every playing sound effect immediately (e.g. when a cutscene is skipped).
func stop_all_sfx() -> void:
	for p in _sfx_pool:
		p.stop()


func stop_music(fade: float = 1.0) -> void:
	_current = ""
	for p in [_music_a, _music_b]:
		if p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -60.0, fade)
			tw.tween_callback(p.stop)


func sfx(id: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream := _load("res://audio/sfx/" + id, false)
	if stream == null:
		return
	var p: AudioStreamPlayer = null
	for cand in _sfx_pool:
		if not cand.playing:
			p = cand
			break
	if p == null:
		if _sfx_pool.size() >= 24:
			return  # everything busy: drop this one rather than cutting another sound off
		p = _make_player("SFX")
		_sfx_pool.append(p)
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## Text blip; rate-limited so fast text doesn't machine-gun.
func blip(pitch: float = 1.0) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_blip_ms < 55:
		return
	_last_blip_ms = now
	sfx("blip", pitch * randf_range(0.94, 1.06), -8.0)

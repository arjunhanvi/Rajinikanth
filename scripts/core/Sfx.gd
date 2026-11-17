extends Node
## Audio: one-shot pool, looping engine voices, crossfading music and ambience beds.

const DIR := "res://assets/audio/"
var _cache := {}
var _pool: Array = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name := ""
var _amb := {}            # name -> player
var _amb_target := {}
var duck := 1.0
## The intro soundtrack supplied by the production. Never substituted: if the file
## is missing the intro and menu simply run silent and the menu says so.
const INTRO_TRACK := "res://assets/audio/user/intro_theme.ogg"
var _intro: AudioStreamPlayer
## The BIG BANG LORE theme (the user's supplied track): loops on the main menu, and its
## whistle section is cut to the opening's blackout. The whistle begins at 20.47 s
## (measured: a 1.2 -> 1.4 kHz glide reaching full level by 20.6 s, running to the end).
const THEME_TRACK := "res://assets/audio/user/menu_theme.ogg"
const WHISTLE_T := 20.47
var _theme: AudioStreamPlayer
var _theme_tw: Tween
var _intro_tw: Tween           # slow-motion ducks everything but the cue

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["Music", "Sfx", "Amb", "Radio"]:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Sfx"
		add_child(p)
		_pool.append(p)
	_music_a = _mk("Music")
	_music_b = _mk("Music")
	for n in ["amb_city", "amb_night", "amb_rain", "amb_crowd"]:
		var p := _mk("Amb")
		p.stream = stream(n)
		p.volume_db = -60.0
		_amb[n] = p
		_amb_target[n] = 0.0
	_intro = _mk("Music")
	_theme = _mk("Music")
	_radio = _mk("Radio")
	_radio.finished.connect(func():
		if _radio_on:
			_radio_play(int(get_node("/root/Game").settings.radio_track) + 1))
	radio_scan()
	apply_volumes()

func intro_available() -> bool:
	return ResourceLoader.exists(INTRO_TRACK)

func intro_play() -> void:
	if not intro_available():
		push_warning("Intro soundtrack missing: " + INTRO_TRACK)
		return
	if _intro_tw != null:
		_intro_tw.kill()
	var st: AudioStream = load(INTRO_TRACK)
	if st is AudioStreamOggVorbis:
		st.loop = false
	_intro.stream = st
	_intro.volume_db = 0.0
	_intro.play()

func intro_playing() -> bool:
	return _intro.playing

func intro_time() -> float:
	return _intro.get_playback_position() if _intro.playing else -1.0

## Controlled fade-out; used when gameplay begins.
func intro_stop(fade := 1.2) -> void:
	if not _intro.playing:
		return
	if _intro_tw != null:
		_intro_tw.kill()
	_intro_tw = create_tween()
	_intro_tw.tween_property(_intro, "volume_db", -60.0, fade)
	_intro_tw.tween_callback(_intro.stop)

func _theme_stream(loop: bool) -> AudioStream:
	if not ResourceLoader.exists(THEME_TRACK):
		push_warning("Theme missing: " + THEME_TRACK)
		return null
	var st: AudioStream = load(THEME_TRACK)
	if st is AudioStreamOggVorbis:
		st = st.duplicate()
		st.loop = loop
	return st

## Main menu: the theme from the top, looping.
func theme_loop() -> void:
	if _theme.playing and _theme.stream != null and (_theme.stream as AudioStreamOggVorbis).loop:
		return
	if _theme_tw != null:
		_theme_tw.kill()
	_theme.stream = _theme_stream(true)
	_theme.volume_db = 0.0
	if _theme.stream != null:
		_theme.play()

## Start the theme at a given point (the whistle), once, with no fade-in: the cut is the cue.
func theme_at(t: float) -> void:
	if _theme_tw != null:
		_theme_tw.kill()
	_theme.stream = _theme_stream(false)
	_theme.volume_db = 0.0
	if _theme.stream != null:
		_theme.play(t)

func theme_time() -> float:
	return _theme.get_playback_position() if _theme.playing else -1.0

func theme_stop(fade := 1.0) -> void:
	if not _theme.playing:
		return
	if _theme_tw != null:
		_theme_tw.kill()
	_theme_tw = create_tween()
	_theme_tw.tween_property(_theme, "volume_db", -60.0, fade)
	_theme_tw.tween_callback(_theme.stop)

## Silence every ambience bed and one-shot at once (a hard cut to black).
func cut_all() -> void:
	for k in _amb:
		_amb_target[k] = 0.0
		_amb[k].volume_db = -80.0
		_amb[k].stop()
	for p in _pool:
		p.stop()

func _mk(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

func apply_volumes() -> void:
	var g = get_node("/root/Game")
	_set_bus("Music", float(g.settings.music))
	_set_bus("Sfx", float(g.settings.sfx))
	_set_bus("Amb", float(g.settings.sfx) * 0.8)
	_set_bus("Radio", 0.0 if g.settings.get("radio_mute", false) else float(g.settings.get("radio", 0.8)))

func _set_bus(n: String, v: float) -> void:
	var i := AudioServer.get_bus_index(n)
	if i >= 0:
		AudioServer.set_bus_mute(i, v <= 0.01)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))

func stream(n: String) -> AudioStream:
	if _cache.has(n):
		return _cache[n]
	var st: AudioStream = null
	if ResourceLoader.exists(DIR + n + ".ogg"):
		st = load(DIR + n + ".ogg")
		if st is AudioStreamOggVorbis and (n.begins_with("amb_") or n in ["music_city", "music_tension", "music_love"]):
			st.loop = true
	elif ResourceLoader.exists(DIR + n + ".wav"):
		st = load(DIR + n + ".wav")
		if st is AudioStreamWAV and (n.begins_with("eng_") or n == "siren"):
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_end = int(st.get_length() * st.mix_rate)
	_cache[n] = st
	return st

func play(n: String, vol := 1.0, pitch := 1.0) -> void:
	var st := stream(n)
	if st == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = st
			p.volume_db = linear_to_db(maxf(vol, 0.001))
			p.pitch_scale = pitch
			p.play()
			return

func make_loop(n: String, parent: Node3D) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(n)
	p.bus = "Sfx"
	p.unit_size = 6.0
	p.max_distance = 60.0
	p.autoplay = false
	parent.add_child(p)
	return p

## House rule: no background score. Walking, talking, exploring and missions are
## carried by the city's own sound. (Kept as a no-op so old call sites are harmless.)
func music(_n: String, _fade := 2.0) -> void:
	if _music_a.playing:
		_music_a.stop()
	if _music_b.playing:
		_music_b.stop()

# ------------------------------------------------------------------ vehicle radio
## Plays only user-supplied Kannada tracks, only while the player drives a car or
## an auto-rickshaw. Drop .ogg / .mp3 files in res://assets/audio/radio/ before
## building, or in user://radio/ on the device.
var radio_tracks: Array = []
var _radio: AudioStreamPlayer
var _radio_on := false

func radio_scan() -> void:
	radio_tracks.clear()
	for dir in ["res://assets/audio/radio/", "user://radio/"]:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			var base := f.trim_suffix(".import")
			if base.get_extension().to_lower() in ["ogg", "mp3"] and not radio_tracks.has(dir + base):
				radio_tracks.append(dir + base)
	radio_tracks.sort()

func _radio_stream(path: String) -> AudioStream:
	if path.begins_with("res://"):
		return load(path)
	if path.get_extension().to_lower() == "ogg":
		return AudioStreamOggVorbis.load_from_file(path)
	var st := AudioStreamMP3.new()
	st.data = FileAccess.get_file_as_bytes(path)
	return st

func radio_set(on: bool) -> void:
	if on == _radio_on:
		return
	_radio_on = on
	var g = get_node("/root/Game")
	if on:
		if radio_tracks.is_empty():
			g.toast.emit("Radio: no Kannada tracks installed yet.")
			return
		_radio_play(int(g.settings.radio_track))
	elif _radio.playing:
		var tw := create_tween()
		tw.tween_property(_radio, "volume_db", -60.0, 0.8)
		tw.tween_callback(_radio.stop)

func _radio_play(i: int) -> void:
	if radio_tracks.is_empty():
		return
	var g = get_node("/root/Game")
	i = posmod(i, radio_tracks.size())
	g.settings.radio_track = i
	_radio.stream = _radio_stream(radio_tracks[i])
	_radio.volume_db = 0.0
	_radio.play()
	g.toast.emit("Radio: " + str(radio_tracks[i]).get_file().get_basename().replace("_", " "))

func radio_next() -> void:
	if _radio_on:
		_radio_play(int(get_node("/root/Game").settings.radio_track) + 1)
		get_node("/root/Game").save_settings()

func ambience(targets: Dictionary) -> void:
	for k in _amb_target:
		_amb_target[k] = float(targets.get(k, 0.0))

func _process(delta: float) -> void:
	# the supplied soundtrack is let down gently over its last seconds rather than cut
	if _intro.playing and _intro.stream != null and (_intro_tw == null or not _intro_tw.is_running()):
		var left := _intro.stream.get_length() - _intro.get_playback_position()
		if left < 2.5:
			_intro.volume_db = linear_to_db(clampf(left / 2.5, 0.001, 1.0))
	for k in _amb:
		var p: AudioStreamPlayer = _amb[k]
		var cur := db_to_linear(p.volume_db)
		var tgt: float = _amb_target[k] * duck
		cur = move_toward(cur, tgt, delta * 0.4)
		if cur > 0.004 and not p.playing:
			p.play()
		elif cur <= 0.004 and p.playing and tgt <= 0.0:
			p.stop()
		p.volume_db = linear_to_db(maxf(cur, 0.001))

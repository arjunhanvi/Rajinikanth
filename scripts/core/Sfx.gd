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
var _intro_tw: Tween           # slow-motion ducks everything but the cue

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["Music", "Sfx", "Amb"]:
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
		if st is AudioStreamWAV and n.begins_with("eng_"):
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

func music(n: String, fade := 2.0) -> void:
	if n == _music_name:
		return
	_music_name = n
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.tween_callback(old.stop)
	if n != "":
		_music_a.stream = stream(n)
		_music_a.volume_db = -40.0
		_music_a.play()
		create_tween().tween_property(_music_a, "volume_db", -5.0, fade)

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

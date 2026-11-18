extends Node
## Global game state, save slots, settings and screen switching.

signal toast(text)
signal changed            # money / rep / heat / objectives changed -> HUD refresh
signal settings_changed

const SAVE_DIR := "user://saves_bbl/"     # BIG BANG LORE; the old RAJINIKANTH saves stay untouched in user://saves/
const SETTINGS_PATH := "user://settings.json"
const SLOTS := 4
const VERSION := 3
const START_DATE := [2007, 1, 1]     # the story runs 1 January 2007 .. 15 June 2007 (Sivaji release)
const END_DAY := 166

var settings := {
	"gfx": 1, "sens": 1.0, "btn_scale": 1.0, "btn_alpha": 0.75, "lefty": false,
	"music": 0.8, "sfx": 1.0, "subtitles": true, "grain": true, "fps60": false,
	"invert_y": false, "steer": 0, "intro_seen": false, "radio": 0.8, "radio_mute": false, "radio_track": 0,
	# controls overhaul: vertical camera sensitivity, stick size, RUN LOCK hold time, haptics, touch trace (test builds)
	"sens_y": 1.0, "stick_scale": 1.0, "runlock_hold": 0.6, "haptics": true, "touch_trace": false,
}
const CONTROL_DEFAULTS := {"sens": 1.0, "sens_y": 1.0, "btn_scale": 1.0, "btn_alpha": 0.75, "stick_scale": 1.0, "lefty": false, "runlock_hold": 0.6, "haptics": true, "invert_y": false}
var slot := -1
var s := {}               # the live save state (plain JSON-able data)
var world = null          # World node while in gameplay
var boot = null
var test_mode := false    # set by automated tests: skips long waits

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	load_settings()
	_setup_input()
	test_mode = OS.get_cmdline_user_args().has("--auto")

func _setup_input() -> void:
	var keys := {
		"mv_l": [KEY_A, KEY_LEFT], "mv_r": [KEY_D, KEY_RIGHT], "mv_u": [KEY_W, KEY_UP], "mv_d": [KEY_S, KEY_DOWN],
		"sprint": [KEY_SHIFT], "jump": [KEY_SPACE], "crouch": [KEY_C], "interact": [KEY_E, KEY_ENTER],
		"punch": [KEY_F], "phone": [KEY_P], "map": [KEY_M], "horn": [KEY_H], "handbrake": [KEY_SPACE],
		"cam": [KEY_V], "pause": [KEY_ESCAPE],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)

# ------------------------------------------------------------------ settings
func load_settings() -> void:
	var d = _read_json(SETTINGS_PATH)
	if d is Dictionary:
		for k in d:
			settings[k] = d[k]
	apply_settings()

func save_settings() -> void:
	_write_json(SETTINGS_PATH, settings)
	apply_settings()
	settings_changed.emit()

func apply_settings() -> void:
	Engine.max_fps = 60 if settings.fps60 else 30
	if has_node("/root/Sfx"):
		get_node("/root/Sfx").apply_volumes()

func gfx(key: String):
	# graphics presets: Low / Medium / High
	var presets := {
		"chunks": [2, 3, 4], "npcs": [9, 16, 26], "traffic": [7, 12, 18], "shadows": [false, true, true],
		"scale": [0.7, 0.85, 1.0], "shadow_dist": [0.0, 45.0, 90.0], "lamps": [2, 4, 8], "rain": [120, 300, 600],
	}
	return presets[key][clampi(int(settings.gfx), 0, 2)]

# ------------------------------------------------------------------ state
func new_state(mode: String, pname: String, look: Dictionary) -> Dictionary:
	return {
		"v": VERSION, "mode": mode, "name": pname, "look": look,
		"money": 85 if mode == "story" else 2500, "rep": 0, "heat": 0.0, "hp": 100.0,
		"time": 10.4 if mode == "story" else 7.0, "day": 1, "weather": "clear", "pos": [-175.0, 0.0, -1470.0] if mode == "story" else [125.0, 0.0, -11.0], "rot": 0.0, "interior": "",
		"flags": {}, "missions": {}, "active": "", "step": 0, "mvars": {},
		"rel": {}, "faction": {"police": 0},
		"npc_mem": {}, "discovered": ["msrit", "majestic"], "vehicles": [], "props": [], "wardrobe": [],
		"contacts": [], "messages": [], "calls": [], "log": [], "phone": mode != "story",
		"playtime": 0.0, "stats": {"tickets": 0, "km": 0.0, "talks": 0}, "politics": {"jpp": 50.0, "knv": 50.0, "day": 0},
		"waypoint": null,
	}

func slot_path(i: int) -> String:
	return SAVE_DIR + "slot%d.json" % i

func slot_info(i: int):
	var d = _read_json(slot_path(i))
	if d is Dictionary and d.has("name"):
		return {"name": d.name, "mode": d.mode, "day": int(d.day), "money": int(d.money), "playtime": float(d.playtime), "active": str(d.get("active", "")), "rep": int(d.rep)}
	return null

func start_new(i: int, mode: String, pname: String, look: Dictionary) -> void:
	slot = i
	s = new_state(mode, pname, look)
	save_game(false)

func save_game(announce := true) -> bool:
	if slot < 0 or s.is_empty():
		return false
	if world != null and is_instance_valid(world):
		world.write_state()
	var ok := _write_json(slot_path(slot), s)
	if announce:
		toast.emit("Game saved" if ok else "Save failed")
	return ok

func load_game(i: int) -> bool:
	var d = _read_json(slot_path(i))
	if not (d is Dictionary) or not d.has("look"):
		return false
	var base := new_state(str(d.get("mode", "story")), str(d.get("name", "Rajinikanth")), d.look)
	if int(d.get("v", 1)) < 3:
		return false       # a save from the retired RAJINIKANTH story: never loaded into BIG BANG LORE
	for k in d:
		base[k] = d[k]
	s = base
	slot = i
	return true

## v0.1 / v0.2 saves told a different Chapter One. The player's own things are
## carried over (money, standing, clothes, vehicles, statistics, calendar); the
## story restarts from the new opening.
func _migrate_v1(d: Dictionary, fresh: Dictionary) -> Dictionary:
	var out := {}
	for k in ["mode", "name", "look", "money", "rep", "day", "vehicles", "props", "wardrobe", "playtime", "stats", "politics", "phone"]:
		if d.has(k):
			out[k] = d[k]
	if str(d.get("mode", "story")) == "story":
		out["phone"] = false
	else:
		for k in ["pos", "rot", "time", "discovered", "contacts"]:
			if d.has(k):
				out[k] = d[k]
	out["flags"] = {"migrated": true}
	out["log"] = [{"d": int(d.get("day", 1)), "t": "An older diary ends here. The story begins again."}]
	out["v"] = VERSION
	return out

func delete_slot(i: int) -> void:
	if FileAccess.file_exists(slot_path(i)):
		DirAccess.remove_absolute(slot_path(i))

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())

func _write_json(path: String, data) -> bool:
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(path + ".tmp", path)   # atomic replace: never leaves a half-written save
	return true

# ------------------------------------------------------------------ progression helpers
func flag(k: String, default = false):
	return s.flags.get(k, default)

func set_flag(k: String, v = true) -> void:
	s.flags[k] = v

func add_money(n: int, why := "") -> void:
	s.money = int(s.money) + n
	if n != 0:
		toast.emit(("+ Rs %d  " % n if n > 0 else "- Rs %d  " % -n) + why)
		if has_node("/root/Sfx"):
			get_node("/root/Sfx").play("coin")
	changed.emit()

func can_pay(n: int) -> bool:
	return int(s.money) >= n

func add_rep(n: int) -> void:
	s.rep = int(s.rep) + n
	changed.emit()

func add_heat(n: float) -> void:
	s.heat = clampf(float(s.heat) + n, 0.0, 100.0)
	changed.emit()

func rel(id: String) -> int:
	return int(s.rel.get(id, 0))

func add_rel(id: String, n: int) -> void:
	s.rel[id] = clampi(rel(id) + n, -100, 100)
	var nm: String = People.NAMES.get(id, id)
	toast.emit("%s %s" % [nm, ("likes that." if n > 0 else "will remember that.")])

func add_faction(id: String, n: int) -> void:
	s.faction[id] = clampi(int(s.faction.get(id, 0)) + n, -100, 100)

func remember(npc: String, what: String) -> void:
	# lightweight contextual NPC memory: newest first, capped
	var m: Array = s.npc_mem.get(npc, [])
	m.push_front({"d": int(s.day), "w": what})
	if m.size() > 8:
		m.resize(8)
	s.npc_mem[npc] = m

func recalls(npc: String, what: String) -> bool:
	for e in s.npc_mem.get(npc, []):
		if e.w == what:
			return true
	return false

func log_event(text: String) -> void:
	s.log.push_front({"d": int(s.day), "t": text})
	if s.log.size() > 60:
		s.log.resize(60)

func add_message(from: String, text: String) -> void:
	s.messages.push_front({"from": from, "text": text, "d": int(s.day), "t": float(s.time), "read": false})
	if s.phone:
		toast.emit("Message from " + from)
		Sfx.play("sms")
	changed.emit()

func add_contact(id: String) -> void:
	if not s.contacts.has(id):
		s.contacts.append(id)

func discover(id: String) -> void:
	if not s.discovered.has(id):
		s.discovered.append(id)
		var p = City.PLACES.get(id)
		if p != null:
			toast.emit("Discovered: " + p.name)

func rank() -> String:
	var r := int(s.rep)
	if r < 10: return "Nobody yet"
	if r < 30: return "Known Face"
	if r < 60: return "Area Boy"
	if r < 100: return "Dada"
	return "Anna"

## The calendar date for a story day: day 1 is Monday, 1 January 2007.
func date_text(day := -1) -> String:
	if day < 0:
		day = int(s.get("day", 1))
	var t := Time.get_unix_time_from_datetime_dict({"year": START_DATE[0], "month": START_DATE[1], "day": START_DATE[2], "hour": 12}) + (day - 1) * 86400
	var d := Time.get_datetime_dict_from_unix_time(t)
	var months := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	return "%d %s %d" % [d.day, months[d.month - 1], d.year]

func clock_text() -> String:
	var h := int(s.time) % 24
	var m := int((float(s.time) - floor(float(s.time))) * 60.0)
	var ap := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0: h12 = 12
	return "%d:%02d %s" % [h12, m, ap]

# ------------------------------------------------------------------ screens
func goto(screen: String, args := {}) -> void:
	if boot != null:
		boot.call_deferred("show_screen", screen, args)

class_name Story
extends Node
## BIG BANG LORE. Bengaluru, 1 January to 15 June 2007.
## Only the opening sequence exists so far (scripts/story/Opening.gd); the rest of
## the story is waiting on the author's direction and is deliberately not invented.
## This node keeps the interface the world, HUD and shops call into.

const TITLES := {"": "Opening", "opening": "Opening: 1 January 2007", "opening_done": "Opening complete", "free": "exploring"}

var world
var clock_runs := false
var crowd_noise := false
var amb_override := {}         # a scene can take over the ambience mix
var opening: Opening = null

var hud: HUD:
	get: return world.hud
var pl: Player:
	get: return world.player
var s: Dictionary:
	get: return Game.s

# ------------------------------------------------------------------ lifecycle
func begin() -> void:
	if s.mode != "story":
		s.active = "free"
		return
	if str(s.active) in ["", "opening"]:
		start_opening()

func start_opening() -> void:
	s.active = "opening"
	opening = Opening.new()
	opening.world = world
	add_child(opening)
	opening.run()

func opening_finished() -> void:
	s.active = "opening_done"
	Game.set_flag("opening_done")
	Game.log_event("1 January 2007, M.S. Ramaiah Institute of Technology. The reel ran out. Then he turned up.")
	Game.settings["opening_seen"] = true
	Game.save_settings()
	Game.save_game(false)

func new_day() -> void:
	pass

func on_wake() -> void:
	pass

func on_player_down() -> void:
	pass

func objective_text() -> String:
	match str(s.get("active", "")):
		"opening": return ""
		"opening_done": return "BIG BANG LORE continues in the next update. Bengaluru is yours to walk."
	return ""

func objective_pos():
	return null

func hotspots() -> Array:
	return []

func on_hotspot(_key: String) -> void:
	pass

func on_talk(_n: NPC) -> bool:
	return false

func on_enter(_id: String) -> void:
	pass

func on_leave(_id: String) -> void:
	pass

func on_interior(_id: String, _key: String) -> bool:
	return false

func interior_cast(_id: String) -> Array:
	return []

func interior_absent(_id: String) -> Array:
	return []

func call_contact(_id: String) -> void:
	pass

func bus_signal(_kind: String) -> void:
	pass

func on_cinema() -> bool:
	return false

func street_event() -> void:
	pass

# ------------------------------------------------------------------ the city talking (early 2007)
## Lines are general talk of the period; see docs/2007_CULTURAL_BIBLE.md for what is verified.
func gossip(_bar := false) -> String:
	var lines := [
		"That Mungaru Male film, they are saying people are going twice, thrice. Rain-rain songs only, still houseful.",
		"Corporation is becoming Bruhat Bangalore something. More wards, more contractors.",
		"Rajini's Sivaji? Shooting is still going on, they say. Release date nobody knows.",
		"My nephew is on Orkut whole day. Scraps, testimonials. What is a testimonial, I ask him.",
		"World Cup is in West Indies this time. March. Sachin's last chance, people say. They said that last time also.",
		"Hutch connection only I have. Wherever you go, that dog follows.",
	]
	return lines[randi() % lines.size()]

func radio() -> String:
	return "This is Akashvani, Bangalore. The time is %s." % Game.clock_text()

func headlines() -> Array:
	return ["Bangalore welcomes 2007", "City corporation to expand: Bruhat Bangalore Mahanagara Palike on the way"]

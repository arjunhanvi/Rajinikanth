extends Node
## Root of the app: swaps between intro, menu, character creation and the world.

var current: Node = null

func _ready() -> void:
	Game.boot = self
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--harness="):
			var h: Node = load("res://tools/dev/Harness.gd").new()
			h.scenario = a.substr(10)
			add_child(h)
	if args.has("--menu"):
		show_screen("menu", {})
	elif args.has("--play") and not args.has("--harness=ui"):
		# dev/test shortcut: jump straight into a fresh story game in the last slot
		Game.start_new(Game.SLOTS - 1, "story" if not args.has("--free") else "free", "Raja", Human.default_look())
		show_screen("world", {})
	else:
		show_screen("intro", {})

func show_screen(screen: String, args: Dictionary) -> void:
	if current != null:
		current.queue_free()
		current = null
		await get_tree().process_frame
	get_tree().paused = false
	Engine.time_scale = 1.0
	match screen:
		"intro": current = Intro.new()
		"menu": current = MainMenu.new()
		"creator":
			current = Creator.new()
			current.args = args
		"world":
			Sfx.intro_stop(1.5)
			Sfx.theme_stop(1.2)
			var load_ui := UI.rect(Color.BLACK)
			var cl := CanvasLayer.new()
			cl.layer = 50
			cl.add_child(load_ui)
			var lb := UI.label("BENGALURU  -  1 JANUARY 2007" if str(Game.s.get("mode", "story")) == "story" else "BENGALURU, 2007", 30, UI.YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
			lb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			lb.offset_left = -300
			lb.offset_right = 300
			load_ui.add_child(lb)
			add_child(cl)
			await get_tree().process_frame
			await get_tree().process_frame
			current = World.new()
			add_child(current)
			await get_tree().process_frame
			cl.queue_free()
			return
	add_child(current)

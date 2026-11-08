extends Node
## Main flow controller. Owns the current screen, fades, the pause menu and debug options.
## Screens are Controls with:  signal finished(result: Dictionary)  and optional  setup(params).

const Style := preload("res://scripts/ui/style.gd")
const Clues := preload("res://scripts/data/clues.gd")
const Chapters := preload("res://scripts/data/chapters.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const Fx := preload("res://scripts/ui/fx.gd")

const SCREENS := {
	"title": "res://scripts/screens/title_screen.gd",
	"story": "res://scripts/screens/story_screen.gd",
	"freetime": "res://scripts/screens/freetime_screen.gd",
	"investigation": "res://scripts/screens/investigation_screen.gd",
	"trial": "res://scripts/screens/trial_screen.gd",
	"execution": "res://scripts/screens/execution_screen.gd",
	"gameover": "res://scripts/screens/gameover_screen.gd",
	"credits": "res://scripts/screens/credits_screen.gd",
	"drain": "res://scripts/screens/drain_screen.gd",
}

## Story steps are played by the story screen using the script with the same id (current chapter).
## The step order per chapter lives in scripts/data/chapters.gd ("next").
const STORY_STEPS := ["aftermath", "prologue", "motive", "evening", "night", "discovery", "investigation_end", "epilogue"]
const CHECKPOINTS := ["prologue", "freetime", "motive", "investigation", "trial"]
## Steps after which all clues are needed (debug --start gives them).
const LATE_STEPS := ["investigation_end", "trial", "execution", "epilogue", "gameover"]

var ui: Control
var _screen: Control
var _step := ""
var _fade: ColorRect
var _pause: Control
var _transitioning := false


func _ready() -> void:
	Game.main = self
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = Style.make_theme()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var fl := CanvasLayer.new()
	fl.layer = 50
	add_child(fl)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(_fade)
	var pl := CanvasLayer.new()
	pl.layer = 60
	add_child(pl)
	var pr := Control.new()
	pr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pr.theme = Style.make_theme()
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pl.add_child(pr)
	_pause = PauseMenu.new()
	_pause.quit_to_title.connect(func() -> void: goto("title"))
	pr.add_child(_pause)
	if Game.shot_path != "":
		_take_shot()
	_boot.call_deferred()


func _boot() -> void:
	if Game.debug_minigame != "":
		Game.new_game()
		_give_all_clues()
		Game.start_trial()
		_show("trial", {"script_text": "@bg trial\n@music trial\n@minigame %s\n@end" % Game.debug_minigame}, "debug_minigame")
	elif Game.debug_script != "":
		Game.new_game()
		_show("story", {"script": Game.debug_script}, "debug_script")
	elif Game.debug_start != "":
		Game.new_game()
		if Game.debug_start in LATE_STEPS:
			_give_all_clues()
		elif Game.debug_start == "investigation":
			for c in Chapters.get_value("inv_start_clues", []):
				Game.add_clue(str(c))
		goto(Game.debug_start)
	else:
		goto("title")


func _give_all_clues() -> void:
	for c in Clues.required():
		Game.add_clue(str(c))


## Go to a flow step (see NEXT). Public: screens may call Game.main.goto("title").
func goto(step: String) -> void:
	if step in CHECKPOINTS and not Game.autotest:
		Game.save_checkpoint(step)
	match step:
		"title":
			_show("title", {}, step)
		"freetime":
			_show("freetime", {"slots": 3}, step)
		"investigation":
			_show("investigation", {}, step)
		"trial":
			Game.start_trial()
			_show("trial", {}, step)
		"execution":
			_show("execution", {"path": str(Chapters.get_value("execution", ""))}, step)
		"drain", "gameover", "credits":
			_show(step, {}, step)
		_:
			if step in STORY_STEPS:
				_show("story", {"script": step}, step)
			else:
				push_error("Main: unknown step " + step)


## Fresh state for a chapter, then its first step (chapter 1: prologue, chapter 2: aftermath).
func start_chapter(ch: int) -> void:
	Game.chapter = ch
	Game.new_game()
	goto(str(Chapters.get_value("first_step", "prologue")))


func open_notebook(tab: String = "clues") -> void:
	_pause.open(tab)


func current_step() -> String:
	return _step


func _show(kind: String, params: Dictionary, step: String) -> void:
	_step = step
	_transitioning = true
	if _pause.is_open():
		_pause.close()
	# Transition: a short diagonal glitch/static wipe (~0.35 s). The black _fade still reaches full
	# opacity under the static before the swap, so the swap stays hidden even without shaders.
	var quick := (Game.autotest and not Game.autotest_slow) or DisplayServer.get_name() == "headless"
	var wipe := _wipe_overlay()
	if _wipe_tw:
		_wipe_tw.kill()
	var tw := create_tween().set_parallel(true)
	if quick:
		tw.tween_property(_fade, "color:a", 1.0, 0.01)
	else:
		Audio.sfx("static", 1.25, -16.0)
		tw.tween_property(_fade, "color:a", 1.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_wipe_tw = Fx.wipe_to(wipe, 1.0, 0.15)
	await tw.finished
	if _screen:
		_screen.queue_free()
		_screen = null
	var path: String = SCREENS.get(kind, "")
	if kind == "execution" and str(params.get("path", "")) != "" and ResourceLoader.exists(str(params["path"])):
		path = str(params["path"])   # chapter-specific execution screen
	if path == "" or not ResourceLoader.exists(path):
		push_error("Main: missing screen script " + path)
		_on_finished({}, step)
		return
	var scr: Script = load(path)
	var s: Control = scr.new()
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if s.has_method("setup"):
		s.setup(params)
	s.finished.connect(_on_finished.bind(step), CONNECT_ONE_SHOT)
	_screen = s
	ui.add_child(s)
	if quick:
		var tw2 := create_tween()
		tw2.tween_property(_fade, "color:a", 0.0, 0.01)
		await tw2.finished
	else:
		# hold the full static cover for one frame (new screen draws its first frame underneath),
		# then drop the black and let the static sweep off diagonally.
		Fx.set_wipe(wipe, 1.0, 1.0)
		await get_tree().process_frame
		_fade.color.a = 0.0
		if _wipe_tw:
			_wipe_tw.kill()
		_wipe_tw = Fx.wipe_to(wipe, 2.0, 0.2)
		await _wipe_tw.finished
		Fx.set_wipe(wipe, 0.0, 0.0)
	_transitioning = false


var _wipe: ColorRect
var _wipe_tw: Tween


## Lazily creates the static-wipe overlay on the fade layer (above screens, below the pause menu).
func _wipe_overlay() -> ColorRect:
	if _wipe == null or not is_instance_valid(_wipe):
		_wipe = Fx.wipe_overlay(_fade.get_parent())
	return _wipe


func _on_finished(result: Variant, step: String) -> void:
	var r: Dictionary = result if typeof(result) == TYPE_DICTIONARY else {}
	if Game.autotest:
		print("[autotest] finished step: ", step, " ", r)
	match step:
		"debug_minigame", "debug_script":
			print("[debug] done: ", r, " convince=", Game.convince, " flags=", Game.flags)
			if Game.autotest:
				get_tree().quit(0)
			else:
				goto("title")
		"title":
			match str(r.get("action", "new")):
				"continue":
					var s := Game.load_checkpoint()
					goto(s if s != "" else "prologue")
				"credits":
					_show("credits", {"from_title": true}, "credits_from_title")
				"quit":
					get_tree().quit()
				"chapter2":
					start_chapter(2)
				_:
					start_chapter(1)
		"credits_from_title":
			goto("title")
		"trial":
			goto("execution" if Game.get_flag("vote_correct", false) else "gameover")
		"gameover":
			if Game.autotest:
				print("[autotest] GAME OVER reached (convince=", Game.convince, ")")
				get_tree().quit(2)
				return
			if str(r.get("action", "retry")) == "retry":
				goto("trial")
			else:
				goto("title")
		"credits":
			var finished_ch := Game.chapter
			Game.unlock_chapter(finished_ch + 1)
			if Game.autotest:
				print("[autotest] COMPLETE chapter=", finished_ch, " convince=", Game.convince, " clues=", Game.clues.size(), " skills=", Game.skills)
				get_tree().quit(0)
				return
			# Chapter 1 flows straight on into Chapter 2; the last chapter returns to the title.
			if finished_ch < Chapters.LAST:
				start_chapter(finished_ch + 1)
			else:
				goto("title")
		_:
			var nx := Chapters.next_step(step)
			if nx != "":
				goto(nx)
			else:
				goto("title")


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		if _step != "title" and not _pause.is_open() and not _transitioning:
			_pause.open("clues")
			get_viewport().set_input_as_handled()


func _take_shot() -> void:
	await get_tree().create_timer(Game.shot_delay).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(Game.shot_path)
		print("[shot] saved ", Game.shot_path, " step=", _step, " fade=", _fade.color.a, " screen=", _screen, " paused=", get_tree().paused)
	get_tree().quit()

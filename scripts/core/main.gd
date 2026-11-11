extends Node
## Main flow controller. Owns the current screen, fades, the pause menu and debug options.
## Screens are Controls with:  signal finished(result: Dictionary)  and optional  setup(params).

const Style := preload("res://scripts/ui/style.gd")
const Clues := preload("res://scripts/data/clues.gd")
const Chapters := preload("res://scripts/data/chapters.gd")
const Story := preload("res://scripts/data/story.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const Fx := preload("res://scripts/ui/fx.gd")

## The notebook overlay has just closed.
signal notebook_closed

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
	"quake": "res://scripts/screens/quake_screen.gd",
	"caiman_kill": "res://scripts/screens/caiman_kill_screen.gd",
	# a chapter with "after_vote": "confession" plays story id "confession" on the courtroom stage
	"confession": "res://scripts/screens/trial_screen.gd",
	# a trial that breaks for a recess (Case 3): told as a story with --2d, walked in 3D otherwise (SCREENS_3D)
	"recess": "res://scripts/screens/story_screen.gd",
}
## 3D walk-around version: investigation and free time are played in 3D rooms (scripts/world3d/).
## Pass `--2d` on the command line to get the classic 2D screens back (debug / comparison).
const SCREENS_3D := {
	"freetime": "res://scripts/screens/freetime3d_screen.gd",
	"investigation": "res://scripts/screens/investigation3d_screen.gd",
	"recess": "res://scripts/screens/recess3d_screen.gd",
}

## Story steps are played by the story screen using the script with the same id (current chapter).
## The step order per chapter lives in scripts/data/chapters.gd ("next").
const STORY_STEPS := ["aftermath", "prologue", "day1", "day2", "day3", "day4", "day5", "motive", "evening", "night", "discovery", "investigation_end", "epilogue", "epilogue_after",
	"night1", "evening2", "night3", "night4"]
## Free Time steps: a chapter with Free Time on several days (Case 3) gives each day its own step, with its number of visits in
## chapters.gd "freetime_slots". All of them play the free-time screen, and each is a save checkpoint.
const FREETIME_STEPS := ["freetime", "freetime2", "freetime3", "freetime4", "freetime5"]
## Saved on arrival, along with each day's first step in a chapter that has days (Chapters.is_day_start) and every Free Time step.
const CHECKPOINTS := ["prologue", "freetime", "motive", "investigation", "trial"]
## Steps after which all clues are needed (debug --start gives them).
const LATE_STEPS := ["investigation_end", "trial", "recess", "confession", "execution", "epilogue", "caiman_kill", "epilogue_after", "gameover"]
## A trial can stop for a break: its script sets flag "trial_break" to a flow step and ends, Main plays that step, and the
## trial goes on from its last @checkpoint. Case 3's recess comes back at this label (the trial script's @checkpoint names
## it too); a debug run that starts at the recess, with no checkpoint yet, comes back there as well.
const RECESS_RESUME := "after_recess"
## Not part of a playthrough: no "Log [L]" tag, and the play-time clock stands still.
const OFF_PLAY_STEPS := ["", "title", "credits_from_title"]
const LOG_TAG_POS := Vector2(1206, 694)

var ui: Control
var _screen: Control
var _step := ""
var _fade: ColorRect
var _pause: Control
var _log_tag: Control
var _transitioning := false
## Case select: the case to enter once the previous case's ending has played (0 = none).
var _bridge_to := 0


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
	_pause.closed.connect(func() -> void: notebook_closed.emit())
	pr.add_child(_pause)
	_build_log_tag()
	if Game.shot_path != "":
		_take_shot()
	_boot.call_deferred()
	_debug_notebook.call_deferred()


func _boot() -> void:
	if Game.debug_minigame != "":
		Game.new_game()
		_give_all_clues()
		Game.start_trial()
		_show("trial", {"script_text": "@bg trial\n@music trial\n@minigame %s\n@end" % Game.debug_minigame}, "debug_minigame")
	elif Game.debug_trial != "":
		Game.new_game()
		_give_all_clues()
		Game.start_trial()
		var scripts: Dictionary = load("res://scripts/data/trial_data_test.gd").get_script_constant_map()["SCRIPTS"]
		_show("trial", {"script_text": str(scripts.get(Game.debug_trial, "@end"))}, "trial")
	elif Game.debug_script != "":
		Game.new_game()
		_show("story", {"script": Game.debug_script}, "debug_script")
	elif Game.debug_anim != "":
		Game.new_game()
		_show("story", {"script_text": "@anim %s\n@end" % Game.debug_anim}, "debug_script")
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


## Debug runs that start past the investigation (a minigame, a trial fixture, a late step) hold every Truth Drop of
## the chapter, optional and trial-delivered ones too, since a debate's tray only shows Drops in the notebook.
func _give_all_clues() -> void:
	for c in Clues.everything():
		Game.add_clue(str(c))


## Go to a flow step (see NEXT). Public: screens may call Game.main.goto("title").
func goto(step: String) -> void:
	# Free Time on several days: everyone can be visited again each day (the arcs themselves live in story flags)
	if step in FREETIME_STEPS and Chapters.daily_free_time():
		Game.hangouts_done.clear()
	if (step in CHECKPOINTS or step in FREETIME_STEPS or Chapters.is_day_start(step)) and not Game.autotest:
		Game.save_checkpoint(step)
	if step == "title":
		Game.flush_play_time()
	if step in FREETIME_STEPS:
		_show("freetime", {"slots": Chapters.freetime_slots(step)}, step)
		return
	match step:
		"title":
			_bridge_to = 0
			_show("title", {}, step)
		"investigation":
			_show("investigation", {}, step)
		"trial":
			Game.start_trial()
			_show("trial", {"start_label": str(Game.trial_resume.get("label", ""))}, step)
		"execution":
			_show("execution", {"path": str(Chapters.get_value("execution", ""))}, step)
		"gameover":
			_show("gameover", {"path": str(Chapters.get_value("gameover", ""))}, step)
		"recess":
			_show("recess", {"script": "recess_walk"}, step)
		"confession":
			# the confession is optional: a chapter that hasn't written one goes straight on
			if Story.has("confession"):
				_show("confession", {"script": "confession"}, step)
			else:
				goto(Chapters.next_step(step))
		"drain", "quake", "caiman_kill", "credits":
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
	if Game.autotest:
		print("[autotest] start chapter ", ch, " clues=", Game.clues.size(), " skills=", Game.skills.size())
	goto(str(Chapters.get_value("first_step", "prologue")))


## Case select. A case with a predecessor opens on that case's ending (execution and epilogue,
## no credits), which then flows into the chosen case; see _on_finished.
func start_case(ch: int) -> void:
	if ch <= 1:
		start_chapter(1)
		return
	_bridge_to = ch
	Game.chapter = ch - 1
	# the previous case isn't being played again, so its recorded play times stay (new_game would restart them)
	var clock := Game.phase_seconds.duplicate()
	Game.new_game()
	Game.phase_seconds = clock
	_give_all_clues()
	goto("execution")


func open_notebook(tab: String = "clues", log_section: String = "") -> void:
	_pause.open(tab, log_section)


## L from something that holds the tree paused itself (a zoomed picture), so that _unhandled_input can't hear it.
## From pictures opened in the notebook, the notebook is already open: it closes them and turns to the Log.
func open_log() -> void:
	if not Chapters.logbook():
		return
	if _pause.is_open():
		_pause.show_log()
	elif _can_open_notebook():
		_pause.open("log")


## The previous case's ending, replayed by Choose Case on the way in, isn't play of that case either.
func play_clock_running() -> bool:
	return not OFF_PLAY_STEPS.has(_step) and not _pause.is_open() and _bridge_to == 0


func _can_open_notebook() -> bool:
	return _step != "title" and not _pause.is_open() and not _transitioning


## The small corner tag that tells people L opens the Log. Below the screen wipe, so a transition covers it.
func _build_log_tag() -> void:
	var tl := CanvasLayer.new()
	tl.layer = 40
	add_child(tl)
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := Style.cut_box(Color(Style.INK, 0.62), 5, Color(Style.AQUA, 0.45), 1)
	st.content_margin_left = 9
	st.content_margin_right = 9
	st.content_margin_top = 2
	st.content_margin_bottom = 3
	tag.add_theme_stylebox_override("panel", st)
	tag.add_child(Style.label("Log [L]", 14, Color(Style.TEXT, 0.85)))
	tag.position = LOG_TAG_POS
	tag.visible = false
	tl.add_child(tag)
	_log_tag = tag


func current_step() -> String:
	return _step


func is_transitioning() -> bool:
	return _transitioning


func _show(kind: String, params: Dictionary, step: String) -> void:
	_step = step
	_log_tag.visible = not OFF_PLAY_STEPS.has(step) and Chapters.logbook()
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
	if SCREENS_3D.has(kind) and not OS.get_cmdline_user_args().has("--2d"):
		path = str(SCREENS_3D[kind])
	if kind in ["execution", "gameover"] and str(params.get("path", "")) != "" and ResourceLoader.exists(str(params["path"])):
		path = str(params["path"])   # chapter-specific execution / wrong-vote screen
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
	# Choose Case: the previous case's ending stops where its credits would start
	if _bridge_to > 0 and Chapters.next_step(step) == "credits":
		var ch := _bridge_to
		_bridge_to = 0
		start_chapter(ch)
		return
	match step:
		"debug_minigame", "debug_script":
			print("[debug] done: ", r, " convince=", Game.convince, " flags=", Game.flags)
			if Game.autotest:
				get_tree().quit(0)
			else:
				goto("title")
		"title":
			var act := str(r.get("action", "new"))
			if act.begins_with("case"):
				start_case(int(act.trim_prefix("case")))
				return
			match act:
				"continue":
					var s := Game.load_checkpoint()
					goto(s if s != "" else "prologue")
				"credits":
					_show("credits", {"from_title": true}, "credits_from_title")
				"quit":
					get_tree().quit()
				_:
					# autotest honours --chapter=N here; a player's New Game is always Case 1
					start_chapter(Game.chapter if Game.autotest else 1)
		"credits_from_title":
			goto("title")
		"trial":
			var brk := str(Game.get_flag("trial_break", ""))
			if brk != "" and brk != "false":
				# a break in the middle of the trial (Case 3's recess); the trial resumes at its last @checkpoint
				Game.set_flag("trial_break", "")
				goto(brk)
			elif Game.get_flag("vote_correct", false):
				Game.trial_resume = {}
				goto(str(Chapters.get_value("after_vote", "execution")))
			else:
				goto("gameover")
		"recess":
			if Game.trial_resume.is_empty():
				Game.trial_resume = {"label": RECESS_RESUME, "convince": Game.convince, "missing_paid": 0.0}
			goto("trial")
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
			# A finished chapter flows straight on into the next; the last chapter returns to the title.
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
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ESCAPE, KEY_L]:
		if e.keycode == KEY_L and not Chapters.logbook():
			return
		if _can_open_notebook():
			_pause.open("clues" if e.keycode == KEY_ESCAPE else "log")
			get_viewport().set_input_as_handled()


## Debug: --notebook=<tab> opens that notebook tab once the game is up; --evidence=<clue id> opens that Truth Drop's
## pictures from it (--evidence-zoom=<1-4> zooms in). Both are for screenshots and the autotest harness.
func _debug_notebook() -> void:
	var tab := ""
	var clue := ""
	var zoom := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--notebook="):
			tab = a.get_slice("=", 1)
		elif a.begins_with("--evidence="):
			clue = a.get_slice("=", 1)
		elif a.begins_with("--evidence-zoom="):
			zoom = float(a.get_slice("=", 1))
	if tab == "" and clue == "":
		return
	while _transitioning or _step == "":
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	if clue != "":
		Game.add_clue(clue)
	_pause.open(tab if tab != "" else "clues")
	if clue != "":
		_pause.open_viewer(clue, zoom)


func _take_shot() -> void:
	# a timed --anim shot is taken by the scene itself, on the exact frame; this is only the safety net
	await get_tree().create_timer(60.0 if Game.debug_anim_t >= 0.0 else Game.shot_delay).timeout
	save_shot()


## Saves the current frame to --shot=<path> and quits.
func save_shot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(Game.shot_path)
		print("[shot] saved ", Game.shot_path, " step=", _step, " fade=", _fade.color.a, " screen=", _screen, " paused=", get_tree().paused)
	get_tree().quit()

extends SceneTree
## Logbook test, with autotest OFF so that nothing plays itself: real key events go through the real game.
##   Godot --headless --path . -s tools/logtest.gd                         (exit code 1 if anything fails)
##   Godot --path . --resolution 1280x720 -s tools/logtest.gd -- --shots=/abs/dir   (also saves a picture of each section)
## Cases 1 and 2 have no Logbook (chapters.gd "logbook"): it checks that L, the tag, the Log tab and the recording are
## all absent there. Everything else runs in Case 3.
## It checks that L opens the Log in a story scene, Free Time, investigation, a cutscene and each kind of trial
## minigame; that it stays shut on the title screen and during a transition; that everything really stops while it's
## open (waits, auto-advancing cards, cutscene clocks, minigame countdowns, the play-time recorder); that only things
## actually looked at get written down; and that old or damaged saves load. Overwrites the save file.

const LogRules := preload("res://scripts/data/log_rules.gd")

const SAVE := "user://splash_trial_save.json"
## Minigame type -> a segment of that type. Each has a clock named in CLOCKS.
const MINIGAMES := {"debate": "debate_accident", "choice": "q_time", "present": "q_weapon", "character": "q_glitter_owner",
	"bubbles": "bubbles_garden", "rebuttal": "rebuttal_wisp", "rewind": "rewind_final", "vote": "vote_final"}
const CLOCKS := ["_st", "_time_left", "_lt", "_ft", "_time", "_t", "_clock"]
## A Case 3 story step with spoken lines, for the scenarios that need one.
const STORY := "day1"

var fails := 0
var checks := 0
var main: Node
var game: Node
var shots := ""
var ScriptPlayer: Script   # loaded in _run: at compile time the autoloads it uses don't exist yet


func _init() -> void:
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL ", what)


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.get_slice("=", 1)
	ScriptPlayer = load("res://scripts/core/script_player.gd")
	game = root.get_node("Game")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _settle()
	await _title_and_transition()
	await _story()
	await _waits_stop()
	await _commands()
	await _evening()
	await _notes_box()
	await _free_time()
	await _investigation()
	await _cutscene()
	await _minigames()
	await _nested_pause()
	await _idle_clock()
	_saves()
	if shots != "":
		await _pictures()
	print("logtest: %d checks, " % checks, "OK" if fails == 0 else "%d failure(s)" % fails)
	quit(1 if fails > 0 else 0)


# =================================================================== helpers
func _settle() -> void:
	await process_frame
	while main.get("_transitioning") or main.current_step() == "":
		await process_frame
	await process_frame


func _secs(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _until(cond: Callable, timeout: float, what: String) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not cond.call():
		if Time.get_ticks_msec() > end:
			_ok(false, "timed out waiting for " + what)
			return false
		await process_frame
	return true


func _key(code: int, unicode: int = 0) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code as Key
		e.physical_keycode = code as Key
		e.unicode = unicode
		e.pressed = down
		root.push_input(e)
	await process_frame


func _pause() -> Control:
	return main.get("_pause")


func _is_open() -> bool:
	return _pause().is_open()


func _find(n: Node, script: Script) -> Node:
	if n.get_script() == script:
		return n
	for c in n.get_children():
		var f := _find(c, script)
		if f:
			return f
	return null


func _player() -> Control:
	return _find(main.get("_screen"), ScriptPlayer)


func _goto(step: String) -> void:
	main.goto(step)
	await _settle()


## L opens the Log; a second L shuts it. `where` names the place in failure messages.
func _l_cycle(where: String) -> void:
	await _key(KEY_L)
	_ok(_is_open(), "L did not open the Log in " + where)
	_ok(paused, "the game is not paused with the Log open in " + where)
	_ok(str(_pause().get("_tab")) == "log", "L opened another tab in " + where)
	await _key(KEY_L)
	_ok(not _is_open(), "second L did not close the Log in " + where)
	_ok(not paused, "game still paused after closing the Log in " + where)


## Presses Space until cond holds (typing, then advancing).
func _click_until(cond: Callable, timeout: float, what: String) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not cond.call():
		if Time.get_ticks_msec() > end:
			_ok(false, "timed out clicking until " + what)
			return false
		await _key(KEY_SPACE)
		await _secs(0.03)
	return true


## Opens the Log and proves a clock on node `n` stands still, then runs again once it's shut.
func _clock_stops(n: Object, prop: String, where: String) -> void:
	await _key(KEY_L)
	_ok(_is_open(), "L did not open the Log in " + where)
	var v0: Variant = n.get(prop)
	await _secs(0.5)
	_ok(is_equal_approx(float(n.get(prop)), float(v0)), "%s kept running behind the Log in %s (%s -> %s)" % [prop, where, v0, n.get(prop)])
	await _key(KEY_L)
	_ok(not _is_open(), "L did not close the Log in " + where)
	await _secs(0.5)
	_ok(not is_equal_approx(float(n.get(prop)), float(v0)), "%s did not run again after closing the Log in %s" % [prop, where])


# =================================================================== scenarios
func _title_and_transition() -> void:
	_ok(main.current_step() == "title", "game did not boot to the title")
	await _key(KEY_L)
	_ok(not _is_open(), "L opened the Log on the title screen")
	_ok(not (main.get("_log_tag") as Control).visible, "the Log tag shows on the title screen")
	await _released_cases()
	game.chapter = 3
	game.new_game()
	main.goto(STORY)
	await process_frame
	await _key(KEY_L)
	_ok(not _is_open(), "L opened the Log during a screen wipe")
	await _settle()
	_ok((main.get("_log_tag") as Control).visible, "the Log tag is missing in a story scene")


## Cases 1 and 2 play as released: no Logbook at all. L opens nothing, the tag stays hidden, the notebook has no Log
## tab, and nothing is written down in the background, so a Case 3 Logbook can't inherit anything from them.
func _released_cases() -> void:
	var Clues: Script = load("res://scripts/data/clues.gd")
	for ch in [1, 2]:
		game.chapter = ch
		game.new_game()
		var where := "Case %d" % ch
		await _goto(str(load("res://scripts/data/chapters.gd").get_value("first_step", "prologue")))
		var sp := _player()
		_ok(sp != null, "no story scene at the start of " + where)
		if sp == null:
			continue
		await _until(func() -> bool: return sp.get("_state") == "typing" or sp.get("_state") == "wait_click", 8.0, "the first line of " + where)
		_ok(not (main.get("_log_tag") as Control).visible, "the Log tag shows in " + where)
		await _key(KEY_L)
		_ok(not _is_open(), "L opened something in " + where)
		main.open_log()
		_ok(not _is_open(), "open_log opened something in " + where)
		await _key(KEY_ESCAPE)
		_ok(_is_open() and str(_pause().get("_tab")) == "clues", "Esc no longer opens the notebook on Truth Drops in " + where)
		_ok(not bool(_pause().call("_has_tab", "log")), "the notebook has a Log tab in " + where)
		await _key(KEY_L)
		_ok(_is_open() and str(_pause().get("_tab")) == "clues", "L turned the notebook away from Truth Drops in " + where)
		_pause().call("show_log")
		_ok(str(_pause().get("_tab")) == "clues", "show_log turned the notebook to the Log in " + where)
		main.open_notebook("log", "notes")
		_ok(str(_pause().get("_tab")) == "clues", "the notebook opened on a Log page in " + where)
		# L inside a Truth Drop's pictures: nothing happens, the pictures stay open
		var pic := ""
		for c in Clues.everything():
			if not Clues.images(str(c)).is_empty():
				pic = str(c)
				break
		if pic != "":
			game.add_clue(pic)
			_pause().call("open_viewer", pic)
			await process_frame
			await _key(KEY_L)
			_ok(is_instance_valid(_pause().get("_viewer")) and str(_pause().get("_tab")) == "clues", "L inside a picture went to the Log in " + where)
			await _key(KEY_ESCAPE)
			await _until(func() -> bool: return not is_instance_valid(_pause().get("_viewer")), 3.0, "the picture to close in " + where)
		await _key(KEY_ESCAPE)
		_ok(not _is_open(), "Esc did not close the notebook in " + where)
		# nothing recorded: not the line on screen, not the story's commands, not a place walked into
		game.log_write("timeline 9:30 PM | Everyone met in the lobby.")
		game.log_place("Lobby")
		game.log_thing("Stone lantern")
		game.log_say("narr", "A line nobody should keep.")
		_ok(game.log.is_empty() and game.log_transcript.is_empty(), "%s wrote %d Log entries and %d Transcript lines" % [where, game.log.size(), game.log_transcript.size()])


func _story() -> void:
	var sp := _player()
	await _until(func() -> bool: return sp.get("_state") == "typing" or sp.get("_state") == "wait_click", 8.0, "the first story line")
	await _l_cycle("a story scene")
	await _key(KEY_ESCAPE)
	_ok(_is_open() and str(_pause().get("_tab")) == "clues", "Esc no longer opens the notebook on Truth Drops")
	await _key(KEY_L)
	_ok(_is_open() and str(_pause().get("_tab")) == "log", "L did not switch an open notebook to the Log")
	await _key(KEY_ESCAPE)
	_ok(not _is_open(), "Esc did not close the Log")
	sp.play_text("narr: A long enough line of narration that the typewriter is still going when the Log opens over it.\n@end")
	await _secs(0.05)
	await _clock_stops(sp, "_vis", "dialogue typing")
	sp.play_text("narr: x\n@end")
	var key := "%d:%s" % [game.chapter, main.current_step()]
	await _secs(0.2)
	_ok(float(game.phase_seconds.get(key, 0.0)) > 0.0, "no play time recorded for " + key)
	await _key(KEY_L)
	var t0 := float(game.phase_seconds.get(key, 0.0))
	await _secs(0.4)
	_ok(is_equal_approx(float(game.phase_seconds.get(key, 0.0)), t0), "play time kept counting behind the Log")
	await _key(KEY_L)
	await _secs(0.2)
	_ok(float(game.phase_seconds.get(key, 0.0)) > t0, "play time did not resume after the Log")


func _waits_stop() -> void:
	var sp := _player()
	sp.play_text("@wait 0.5\nnarr: after the wait\n@end")
	await _secs(0.1)
	await _key(KEY_L)
	await _secs(1.0)
	_ok(sp.get("_state") == "busy", "@wait ran out behind the Log")
	await _key(KEY_L)
	await _until(func() -> bool: return sp.get("_state") == "typing", 2.0, "@wait to finish after the Log")
	sp.play_text("@card A TITLE CARD | that dismisses itself\nnarr: after the card\n@end")
	await _secs(0.8)
	await _key(KEY_L)
	await _secs(3.2)
	_ok(sp.get("_state") == "await_click", "a title card dismissed itself behind the Log")
	await _key(KEY_L)
	await _until(func() -> bool: return sp.get("_state") == "typing", 4.0, "the card to finish after the Log")


func _commands() -> void:
	game.log = []
	game.log_transcript = []
	var sp := _player()
	sp.play_text("""@log timeline 9:30 PM | Everyone met in the lobby.
@log places The lift only goes down.
@log people nibs Told me he read until ten.
@log trial #door We all agreed the door was shut.
@log trial We all agreed it rained.
@log timeline Everyone met in the lobby.
@log timeline 9:30 PM | Everyone met in the lobby.
@log strike door
@log nosuchsection hello
narr: hold here
@end""")
	await _until(func() -> bool: return sp.get("_state") == "typing", 2.0, "the @log lines to run")
	var tl: Array = game.log_entries("timeline")
	_ok(tl.size() == 2, "@log timeline wrote %d entries, expected 2 (a repeat must not be written twice)" % tl.size())
	if tl.size() > 0:
		_ok(tl[0]["clock"] == "9:30 PM" and tl[0]["text"] == "Everyone met in the lobby.", "@log timeline time and text parsed wrong")
		_ok(tl[0]["when"] == LogRules.when(main.current_step()), "entry stamped with the wrong day heading")
	var pe: Array = game.log_entries("people")
	_ok(pe.size() == 1 and pe[0]["who"] == "nibs" and pe[0]["text"] == "Told me he read until ten.", "@log people parsed wrong")
	var tr: Array = game.log_entries("trial")
	_ok(tr.size() == 2 and bool(tr[0]["struck"]) and not bool(tr[1]["struck"]), "@log strike crossed out the wrong entries")
	_ok(game.log_entries("places").size() == 1, "@log places was not written")
	_ok(game.log.size() == 6, "an @log line with a bad section still wrote something")
	game.log_say("nibs", "A *highlight* and a {weak spot}.")
	var last: Dictionary = game.log_transcript.back()
	_ok(last["text"] == "A highlight and a weak spot.", "the Transcript keeps emphasis that would make a line stand out")
	for i in 230:
		game.log_say("nibs", "line %d" % i)
	_ok(game.log_transcript.size() == LogRules.TRANSCRIPT_MAX, "the Transcript is not capped at %d lines" % LogRules.TRANSCRIPT_MAX)
	_ok(game.log_transcript[0]["text"] == "line 30", "the Transcript cap dropped the wrong lines")
	game.log_say("zuzu", "said in a loop", true)
	game.log_say("zuzu", "said in a loop", true)
	_ok(game.log_transcript.filter(func(e: Variant) -> bool: return e["text"] == "said in a loop").size() == 1, "a looping statement filled the Transcript")


func _evening() -> void:
	var sp := _player()
	sp.play_text("@evening\nnarr: after the prompt\n@end")
	await _until(func() -> bool: return sp.get("_state") == "choice", 2.0, "the evening prompt")
	await _key(KEY_2, 50)
	_ok(not _is_open(), "'not tonight' opened the Log")
	await _until(func() -> bool: return sp.get("_state") == "typing", 2.0, "the story to go on after 'not tonight'")
	sp.play_text("@evening\nnarr: after the marks\n@end")
	await _until(func() -> bool: return sp.get("_state") == "choice", 2.0, "the second evening prompt")
	await _key(KEY_1, 49)
	await _until(_is_open, 2.0, "the evening prompt to open the marks")
	_ok(_is_open() and str(_pause().get("_tab")) == "log" and str(_pause().get("_log_section")) == "notes", "the evening prompt opened the wrong place")
	await _key(KEY_ESCAPE)
	await _until(func() -> bool: return sp.get("_state") == "typing", 2.0, "the story to go on after the marks")


func _notes_box() -> void:
	game.log_note = ""
	main.open_notebook("log", "notes")
	await process_frame
	var note := _find_type(_pause(), "TextEdit") as TextEdit
	_ok(note != null, "no text box in Your notes")
	if note == null:
		return
	note.grab_focus()
	await process_frame
	await _key(KEY_L, 108)
	_ok(_is_open(), "typing L in the notes closed the Log")
	_ok(game.log_note == "l", "the typed letter did not reach the note (got '%s')" % game.log_note)
	await _key(KEY_ESCAPE)
	_ok(not _is_open(), "Esc did not close the Log while typing in Your notes")
	if _is_open():
		note.release_focus()
		await _key(KEY_ESCAPE)


func _find_type(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var f := _find_type(c, cls)
		if f:
			return f
	return null


func _free_time() -> void:
	game.new_game()
	await _goto("freetime")
	var s: Control = main.get("_screen")
	await _l_cycle("the Free Time intro")
	await _click_until(func() -> bool: return s.get("_active"), 40.0, "Free Time is walkable")
	await _l_cycle("Free Time")
	await _key(KEY_L)
	_ok(not (s.get("_player") as Node).can_process(), "the player can still walk behind the Log")
	await _key(KEY_L)
	_ok(game.log_entries("places").size() == 1, "walking into a Free Time space wrote %d place entries, expected 1" % game.log_entries("places").size())


func _investigation() -> void:
	game.new_game()
	await _goto("investigation")
	var s: Control = main.get("_screen")
	await _l_cycle("the investigation intro")
	await _click_until(func() -> bool: return s.call("_can_hover"), 60.0, "the investigation is walkable")
	await _l_cycle("the investigation")
	var things: Array = (s.get("_targets") as Array).filter(func(t: Variant) -> bool: return t["kind"] == "hotspot")
	_ok(things.size() >= 2, "the test needs a room with two hotspots")
	if things.size() < 2:
		return
	var seen := LogRules.thing_line(str(things[0]["label"]))
	var unseen := LogRules.thing_line(str(things[1]["label"]))
	_ok(not _has_place(seen), "a thing was written down before it was examined")
	s.call("_activate", things[0])
	await _until(func() -> bool: return (s.get("_sp") as Control).call("is_running"), 3.0, "the examine script")
	_ok(_has_place(seen), "examining a thing wrote nothing")
	_ok(not _has_place(unseen), "a thing nobody looked at was written down")
	await _l_cycle("an examine conversation")
	await _click_until(func() -> bool: return s.call("_can_hover"), 30.0, "the examine script finished")


func _has_place(text: String) -> bool:
	return game.log_entries("places").any(func(e: Variant) -> bool: return e["text"] == text)


func _cutscene() -> void:
	game.new_game()
	await _goto("quake")
	await _secs(0.5)
	await _clock_stops(main.get("_screen"), "_t", "the quake cutscene")
	await _goto("execution")
	await _secs(0.5)
	await _clock_stops(main.get("_screen"), "_t", "an execution")
	game.new_game()


func _minigames() -> void:
	# The segments are Case 1's (the lookup falls back to them), played in Case 3, where the Log exists. They need
	# Case 1's Drops in the notebook, or a Case 3 trial stops to hand the missing ones over first.
	var Clues: Script = load("res://scripts/data/clues.gd")
	game.chapter = 1
	var drops: Array = Clues.everything()
	game.chapter = 3
	for type in MINIGAMES.keys():
		var id := str(MINIGAMES[type])
		game.new_game()
		for c in drops:
			game.add_clue(str(c))
		game.start_trial()
		main.call("_show", "trial", {"script_text": "@bg trial\n@music trial\n@minigame %s\n@end" % id}, "debug_minigame")
		await _settle()
		var sp := _player()
		await _until(func() -> bool: return sp.minigame_layer.get_child_count() > 0, 3.0, "minigame " + id)
		var mg: Node = sp.minigame_layer.get_child(0)
		await _secs(3.0)   # past the opening banner, so the minigame's own clock is the one being tested
		var clock := ""
		var end := Time.get_ticks_msec() + 6000
		while clock == "" and Time.get_ticks_msec() < end:
			await process_frame
			for name in CLOCKS:
				if mg.get(name) != null and float(mg.get(name)) != 0.0:
					clock = name
					break
		_ok(clock != "", "no running clock found in minigame " + id)
		if clock != "":
			await _clock_stops(mg, clock, "the %s minigame" % type)
		else:
			await _l_cycle("the %s minigame" % type)


## A zoomed picture holds the tree paused itself: L must still reach the Log, and closing the Log must leave it paused.
func _nested_pause() -> void:
	game.new_game()
	await _goto(STORY)
	paused = true
	main.open_log()
	_ok(_is_open(), "open_log did not open the Log over a paused tree")
	await _key(KEY_ESCAPE)
	_ok(not _is_open() and paused, "closing the Log unpaused something that was already paused")
	paused = false


func _idle_clock() -> void:
	var key := "%d:%s" % [game.chapter, main.current_step()]
	var t0 := float(game.phase_seconds.get(key, 0.0))
	game.set("_last_input_ms", Time.get_ticks_msec() - game.IDLE_MS - 1000)
	await _secs(0.2)
	_ok(is_equal_approx(float(game.phase_seconds.get(key, 0.0)), t0), "play time kept counting for a player who walked away")
	game.set("_last_input_ms", Time.get_ticks_msec())
	await _secs(0.2)
	_ok(float(game.phase_seconds.get(key, 0.0)) > t0, "play time did not restart after the player came back")


func _write_save(data: Dictionary) -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func _saves() -> void:
	# a save from before the Logbook
	game.new_game()
	game.log_add("timeline", "left over")
	game.log_say("nibs", "left over")
	game.log_note = "left over"
	game.phase_seconds = {}
	_write_save({"step": "investigation", "chapter": 1, "flags": {"seen_x": true}, "clues": ["rules"], "skills": [], "hangouts_done": ["nibs"]})
	var step: String = game.load_checkpoint()
	_ok(step == "investigation" and game.has_clue("rules") and game.get_flag("seen_x"), "an old save lost its progress")
	_ok(game.log == [] and game.log_transcript == [] and game.log_note == "" and game.phase_seconds == {}, "an old save did not start the Log empty")
	# damaged fields are ignored, not fatal
	_write_save({"step": "trial", "chapter": 2, "log": 5, "log_transcript": [1, {"who": "x"}], "log_note": 7, "phase_seconds": "no"})
	step = game.load_checkpoint()
	_ok(step == "trial" and game.log == [] and game.log_transcript == [] and game.phase_seconds == {}, "a damaged save was not handled")
	# round trip
	game.chapter = 3
	game.new_game()
	game.phase_seconds = {"1:trial": 12.5}
	game.log_write("trial #a We all agreed.")
	game.log_strike("a")
	game.log_place("Somewhere")
	game.log_say("think", "Hmm.")
	game.log_note = "my note"
	game.set_alibi_mark("nibs", "doubt")
	game.save_checkpoint("trial")
	game.new_game()
	game.phase_seconds = {}
	_ok(game.load_checkpoint() == "trial", "round trip lost the step")
	_ok(game.log.size() == 2 and bool(game.log_entries("trial")[0]["struck"]), "round trip lost Log entries")
	_ok(game.log_transcript.size() == 1 and game.log_note == "my note" and game.alibi_mark("nibs") == "doubt", "round trip lost the Transcript, note or marks")
	_ok(is_equal_approx(float(game.phase_seconds.get("1:trial", 0.0)), 12.5), "round trip lost the play time")
	# leaving the game keeps play time since the last checkpoint and touches nothing else in the save
	game.phase_seconds = {"1:trial": 40.0, "1:execution": 3.0}
	game.flush_play_time()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	_ok(float(saved["phase_seconds"]["1:trial"]) == 40.0 and float(saved["phase_seconds"]["1:execution"]) == 3.0, "play time was not written on the way out")
	_ok(saved["log_note"] == "my note" and str(saved["step"]) == "trial", "writing play time disturbed the save")
	# time since the checkpoint survives Continue in the same session
	game.phase_seconds["1:trial"] = 50.0
	_write_save(saved)
	game.load_checkpoint()
	_ok(float(game.phase_seconds["1:trial"]) == 50.0, "Continue threw away play time since the checkpoint")
	# starting a chapter again restarts only that chapter's numbers
	game.phase_seconds = {"1:trial": 9.0, "2:trial": 8.0}
	game.chapter = 1
	game.new_game()
	_ok(not game.phase_seconds.has("1:trial") and game.phase_seconds.has("2:trial"), "New Game cleared the wrong chapter's play time")
	game.chapter = 3


func _pictures() -> void:
	DirAccess.make_dir_recursive_absolute(shots)
	game.chapter = 3
	game.new_game()
	await _goto(STORY)
	game.log_write("timeline 8:00 PM | Snapjaw called everyone to the lobby for an announcement.")
	game.log_write("timeline 9:15 PM | Heard someone say they'd check the boiler before bed.")
	game.log_write("people nibs Told me he stayed in the library until ten.")
	game.log_write("people zuzu 10 PM | Told me she was fixing a lamp.")
	game.log_write("trial #a We all agreed the side door was shut all night.")
	game.log_write("trial Everyone believes the storm knocked the lights out.")
	game.log_strike("a")
	game.log_place("Lobby")
	game.log_thing("Stone lantern")
	game.log_thing("Foam cushions")
	game.log_place("Changing Room")
	for i in 30:
		game.log_say(["nibs", "zuzu", "narr", "think", "voice", "all"][i % 6], "Sample line number %d of something somebody said out loud." % i)
	game.log_note = "Ask about the lamp.\nTry the stairs again."
	game.set_alibi_mark("nibs", "trust")
	game.set_alibi_mark("zuzu", "doubt")
	game.set_alibi_mark("bruno", "unsure")
	await _shot("story_tag")
	for s in LogRules.SECTIONS:
		main.open_notebook("log", str(s[0]))
		await _secs(0.5)
		await _shot("log_" + str(s[0]))
		_pause().close()
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))

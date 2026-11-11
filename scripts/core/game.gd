extends Node
## Global game state. Autoload name: Game
##
## Minigames: call Game.begin_minigame() when they start, then Game.reward(Game.REWARD_X)
## for correct actions and Game.mistake(Game.PENALTY_X) for wrong ones. Skills are applied here.

const Skills := preload("res://scripts/data/skills.gd")
const Clues := preload("res://scripts/data/clues.gd")
const Cast := preload("res://scripts/data/cast.gd")
const Chapters := preload("res://scripts/data/chapters.gd")
const LogRules := preload("res://scripts/data/log_rules.gd")

signal convince_changed(value: float, delta: float)
signal clue_added(clue_id: String)
signal skill_added(skill_id: String)

const SAVE_PATH := "user://splash_trial_save.json"
const SETTINGS_PATH := "user://splash_trial_settings.json"

const CONVINCE_THRESHOLD := 60.0
const BASE_CONVINCE := 15.0

# --- Convince economy (all minigames use these) ---
const REWARD_DEBATE := 9.0      # correct shot in a Splash Debate
const PENALTY_DEBATE := 8.0     # wrong shot (wrong drop or wrong weak spot)
# (running out of time never costs convince: only wrong answers do)
const REWARD_CHOICE := 7.0      # Pick-the-Answer correct (choice / present / character)
const PENALTY_CHOICE := 9.0     # Pick-the-Answer wrong
const REWARD_BUBBLES := 7.0     # Bubble Letters solved
const PENALTY_BUBBLES := 3.0    # wrong bubble popped
const REWARD_COUNTER := 2.0     # each successful timed counter in Rebuttal Showdown
const PENALTY_COUNTER := 4.0    # each missed counter
const REWARD_REBUTTAL := 8.0    # final rebuttal evidence correct
const PENALTY_REBUTTAL := 9.0   # final rebuttal evidence wrong
const REWARD_REWIND_PANEL := 2.0
const PENALTY_REWIND := 6.0
const REWARD_REWIND := 6.0      # completing the Case Rewind
const REWARD_PAIR := 9.0        # two-part present, or naming several guests
const REWARD_ROLL := 2.0        # each guest answered in a Roll Call
const PENALTY_ROLL := 5.0
const REWARD_TIME := 7.0        # Time Pick
const PENALTY_TIME := 8.0
const EARLY_BONUS := 3.0        # paid once when a Truth Drop shown too soon comes up for real
const HINT_COST := 5.0          # asking for a debate hint, where the chapter makes you ask
const MISSING_COST := 6.0       # a Truth Drop handed over in the trial (see pay_missing)

## Main flow controller (scripts/core/main.gd). Screens may call Game.main.goto(step) / Game.main.open_notebook().
var main: Node = null

# --- Debug / test options (from command line, after `--`) ---
var autotest := false     # --autotest : auto-advance text, choices pick option 1, minigames self-solve
var debug_start := ""     # --start=<step>   (see main.gd STEPS)
var debug_minigame := ""  # --minigame=<trial_data id>  run one minigame in isolation
var debug_script := ""    # --script=<story script id>  play one story script
var shot_path := ""       # --shot=<abs path .png>  save a screenshot then quit
var shot_delay := 3.0     # --shot-delay=<seconds>
var skills_all := false   # --all-skills
var autotest_slow := false  # --slow : with --autotest, advance text at a readable pace (for screenshots)
var no_rewards := false   # --no-rewards : correct answers give no convince (tests the losing vote path)
var debug_case := 0       # --pick-case=<n> : with --autotest, the title screen picks that case from Choose Case
var debug_case_menu := false  # --case-menu : open the title screen's case list (for screenshots)
var debug_trial := ""     # --trial-fixture=<id> : play one script from scripts/data/trial_data_test.gd as the trial
var autotest_wrong := false  # --wrong-path : with --autotest, take the offered early vote instead of refusing it
var debug_anim := ""      # --anim=<anim_scenes id> : play one animated scene through the real @anim command
var debug_anim_t := -1.0  # --anim-t=<seconds> : with --anim, start there (and with --shot, save exactly that frame)

# --- Settings ---
var text_speed := 1.0     # characters-per-second multiplier
var music_volume := 0.7
var sfx_volume := 0.8
var fullscreen := false

# --- Progress state ---
## Current chapter (1 to Chapters.LAST). Mirrors Chapters.current, which the data scripts read.
var chapter := 1:
	set(v):
		chapter = clampi(v, 1, Chapters.LAST)
		Chapters.current = chapter
## Highest chapter the player may start from the title screen (saved with the settings).
var chapter_unlocked := 1
var flags := {}
var clues: Array[String] = []
var skills: Array[String] = []
var hangouts_done: Array[String] = []
var convince := BASE_CONVINCE
var trial_start_convince := BASE_CONVINCE
var _free_mistake := false
var _first_aid_used := false
## Alibi Board: guest -> Array of revealed fields ("motive", "<when>", "<when> proof").
var alibi_seen := {}
## Alibi Board: the player's own mark per guest ("trust", "doubt" or "unsure"). Nothing else ever writes these.
var alibi_marks := {}
## Alibi Board: rows the story added on top of the chapter's plain hours.
var alibi_rows: Array[String] = []
## Mid-trial checkpoint ({"label", "convince", "missing_paid"}); empty = start the trial from the top.
var trial_resume := {}
var _missing_paid := 0.0
## Logbook entries, in the order Mochi wrote them (scripts/data/log_rules.gd):
## {"sec": section, "text": String, "when": heading, "who": guest or "", "clock": time or "", "id": String, "struck": bool}
@warning_ignore("shadowed_global_identifier")
var log: Array = []
## Logbook: the last lines of dialogue, {"who": speaker, "text": plain text}. Oldest first.
var log_transcript: Array = []
## Logbook: the player's own note. Nothing else ever writes this.
var log_note := ""
## Active play time in seconds per flow step, keyed "<chapter>:<step>" (e.g. "2:investigation"). Doesn't count the
## pause overlay, the title screen or a player gone quiet for IDLE_MS. Kept across chapters; a chapter's own numbers restart with it.
var phase_seconds := {}
const IDLE_MS := 300000
var _last_input_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	load_settings()
	_inherit_unlock()
	_load_play_time()
	if skills_all:
		for s in Skills.SKILLS.keys():
			skills.append(s)


func _parse_args() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for a in args:
		if a == "--autotest":
			autotest = true
		elif a == "--all-skills":
			skills_all = true
		elif a == "--slow":
			autotest_slow = true
		elif a == "--no-rewards":
			no_rewards = true
		elif a == "--wrong-path":
			autotest_wrong = true
		elif a.begins_with("--trial-fixture="):
			debug_trial = a.get_slice("=", 1)
		elif a.begins_with("--chapter="):
			chapter = int(a.get_slice("=", 1))
		elif a.begins_with("--pick-case="):
			debug_case = int(a.get_slice("=", 1))
		elif a == "--case-menu":
			debug_case_menu = true
		elif a.begins_with("--start="):
			debug_start = a.get_slice("=", 1)
		elif a.begins_with("--minigame="):
			debug_minigame = a.get_slice("=", 1)
		elif a.begins_with("--script="):
			debug_script = a.get_slice("=", 1)
		elif a.begins_with("--anim="):
			debug_anim = a.get_slice("=", 1)
		elif a.begins_with("--anim-t="):
			debug_anim_t = float(a.get_slice("=", 1))
		elif a.begins_with("--shot="):
			shot_path = a.get_slice("=", 1)
		elif a.begins_with("--shot-delay="):
			shot_delay = float(a.get_slice("=", 1))


# ------------------------------------------------------------------ state
func new_game() -> void:
	flags.clear()
	clues.clear()
	hangouts_done.clear()
	skills.clear()
	if skills_all:
		for s in Skills.SKILLS.keys():
			skills.append(s)
	convince = BASE_CONVINCE
	_first_aid_used = false
	alibi_seen = {}
	alibi_marks = {}
	alibi_rows.clear()
	trial_resume = {}
	_missing_paid = 0.0
	self.log = []
	log_transcript = []
	log_note = ""
	for k in phase_seconds.keys():
		if str(k).begins_with("%d:" % chapter):
			phase_seconds.erase(k)


func set_flag(flag_name: String, value: Variant = true) -> void:
	flags[flag_name] = value


func get_flag(flag_name: String, default: Variant = false) -> Variant:
	return flags.get(flag_name, default)


func add_clue(id: String) -> bool:
	if clues.has(id):
		return false
	clues.append(id)
	clue_added.emit(id)
	return true


func has_clue(id: String) -> bool:
	return clues.has(id)


func has_all_required_clues() -> bool:
	for c in Clues.required():
		if not clues.has(c):
			return false
	return true


func add_skill(id: String) -> bool:
	if skills.has(id):
		return false
	skills.append(id)
	skill_added.emit(id)
	return true


func has_skill(id: String) -> bool:
	return skills.has(id)


# ------------------------------------------------------------------ convince
func start_trial() -> void:
	var c := BASE_CONVINCE
	if has_skill("captains_courage"):
		c += 10.0
	if has_skill("poise"):
		c += 8.0
	if has_skill("comfort_food"):
		c += 5.0
	trial_start_convince = c
	_first_aid_used = false
	set_flag("vote_correct", false)
	set_flag("voted_early", false)
	if not trial_resume.is_empty():
		_missing_paid = float(trial_resume.get("missing_paid", 0.0))
		set_convince(float(trial_resume.get("convince", c)))
		return
	_missing_paid = 0.0
	for k in flags.keys():
		if str(k).begins_with("early_"):
			flags.erase(k)
	set_convince(c)


func set_convince(v: float) -> void:
	var old := convince
	convince = clampf(v, 0.0, 100.0)
	convince_changed.emit(convince, convince - old)


## Call when a minigame starts (resets the Deep Roots free mistake).
func begin_minigame() -> void:
	_free_mistake = has_skill("deep_roots")


## Correct action. Returns the actual amount added.
func reward(amount: float) -> float:
	if no_rewards:
		convince_changed.emit(convince, 0.0)
		return 0.0
	if has_skill("encore"):
		amount *= 1.25
	var old := convince
	set_convince(convince + amount)
	return convince - old


## Wrong action. Returns the actual amount removed (positive number, 0 if forgiven).
func mistake(amount: float) -> float:
	if _free_mistake:
		_free_mistake = false
		convince_changed.emit(convince, 0.0)
		return 0.0
	amount *= float(Chapters.get_value("penalty_scale", 1.0))
	if has_skill("iron_hide"):
		amount *= 0.75
	var old := convince
	var v := convince - amount
	if has_skill("first_aid") and not _first_aid_used and v < 20.0:
		_first_aid_used = true
		v += 15.0
	set_convince(v)
	return old - convince


## Multiply every minigame countdown / statement duration by this.
func timer_scale() -> float:
	return 1.25 if has_skill("power_nap") else 1.0


## Convince needed at the current chapter's vote.
func convince_threshold() -> float:
	return float(Chapters.get_value("threshold", CONVINCE_THRESHOLD))


func is_convinced() -> bool:
	return convince >= convince_threshold()


## Costs the convince for a Truth Drop the player reached the trial without, up to the chapter's cap.
func pay_missing() -> float:
	var cap := float(Chapters.get_value("missing_cap", 18.0))
	var cost := minf(MISSING_COST, maxf(cap - _missing_paid, 0.0))
	_missing_paid += cost
	if cost > 0.0:
		set_convince(convince - cost)
	return cost


## A Truth Drop that is right but too soon: no cost now, and a small bonus when it comes up for real.
## Only Truth Drop ids count. The flag belongs to no segment, so an option number or a guest here would pay out on
## some unrelated later answer with the same key (tools/check_depth.py rejects such "early" lists too).
func note_early(clue_id: String) -> void:
	if Clues.CLUES.has(clue_id):
		set_flag("early_" + clue_id, true)


## Call when a Truth Drop is used correctly. Pays the bonus once if it was shown too soon earlier.
func pay_early(clue_id: String) -> void:
	if not Clues.CLUES.has(clue_id):
		return
	if get_flag("early_" + clue_id, false) and not get_flag("early_paid_" + clue_id, false):
		set_flag("early_paid_" + clue_id, true)
		reward(EARLY_BONUS)


## Mid-trial checkpoint: a retry (or Continue) comes back to this label with the convince it has now, but never less
## than `floor`, the least that tools/check_depth.py proves a careful run from the label can still win with. A player
## who reached it low on convince must not be stuck retrying a trial they can no longer win.
func set_trial_checkpoint(label: String, floor_convince: float = 0.0) -> void:
	trial_resume = {"label": label, "convince": maxf(convince, floor_convince), "missing_paid": _missing_paid}
	if not autotest:
		save_checkpoint("trial")


# ------------------------------------------------------------------ alibi board
func reveal_alibi(guest: String, field: String) -> void:
	var list: Array = alibi_seen.get(guest, [])
	if not list.has(field):
		list.append(field)
		alibi_seen[guest] = list


func add_alibi_row(when: String) -> void:
	if not alibi_rows.has(when):
		alibi_rows.append(when)


## The player's own mark on a guest: "", "trust", "doubt" or "unsure".
func alibi_mark(guest: String) -> String:
	return str(alibi_marks.get(guest, ""))


func set_alibi_mark(guest: String, mark: String) -> void:
	if mark == "":
		alibi_marks.erase(guest)
	else:
		alibi_marks[guest] = mark


# ------------------------------------------------------------------ logbook
## Adds a Logbook entry under the current day. A script that replays can't write the same thing twice;
## walking into the same place again only counts once a day. A chapter without a Logbook records nothing.
func log_add(sec: String, text: String, who: String = "", clock: String = "", id: String = "") -> void:
	if not Chapters.logbook():
		return
	var when := LogRules.when(main.current_step() if main else "")
	for e in self.log:
		if e["sec"] == sec and e["text"] == text and e["who"] == who and e["clock"] == clock and (sec != "places" or e["when"] == when):
			return
	self.log.append({"sec": sec, "text": text, "when": when, "who": who, "clock": clock, "id": id, "struck": false})


## Runs one `@log` line (see LogRules.parse).
func log_write(rest: String) -> void:
	var p := LogRules.parse(rest)
	if p.is_empty():
		push_warning("Game: bad @log line: " + rest)
	elif p["sec"] == "strike":
		log_strike(str(p["text"]))
	else:
		log_add(str(p["sec"]), str(p["text"]), str(p["who"]), str(p["clock"]), str(p["id"]))


## The trial disproved something the group believed: its entry is crossed out from now on.
func log_strike(id: String) -> void:
	if not Chapters.logbook():
		return
	for e in self.log:
		if e["id"] == id:
			e["struck"] = true


func log_place(place: String) -> void:
	log_add("places", LogRules.place_line(place))


func log_thing(thing: String) -> void:
	log_add("places", LogRules.thing_line(thing))


func log_entries(sec: String) -> Array:
	return self.log.filter(func(e: Variant) -> bool: return e["sec"] == sec)


## A line of dialogue for the Transcript, as plain text (no emphasis: it must not stand out here).
## once: a line that comes round again (a debate loops its statements) is kept only the first time.
func log_say(who: String, text: String, once: bool = false) -> void:
	if not Chapters.logbook():
		return
	var plain := text.replace("*", "").replace("{", "").replace("}", "").strip_edges()
	if plain == "":
		return
	if once:
		for e in log_transcript:
			if e["who"] == who and e["text"] == plain:
				return
	log_transcript.append({"who": who, "text": plain})
	if log_transcript.size() > LogRules.TRANSCRIPT_MAX:
		log_transcript.pop_front()


# ------------------------------------------------------------------ play time
func _process(delta: float) -> void:
	if main == null or not main.play_clock_running():
		return
	if not autotest and Time.get_ticks_msec() - _last_input_ms > IDLE_MS:
		return
	var key := "%d:%s" % [chapter, main.current_step()]
	phase_seconds[key] = float(phase_seconds.get(key, 0.0)) + delta


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		_last_input_ms = Time.get_ticks_msec()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush_play_time()


## Writes the play time into the save without touching anything else in it, so that time since the last
## checkpoint isn't lost when the player leaves (a finished case has no checkpoint after its trial).
func flush_play_time() -> void:
	if autotest or phase_seconds.is_empty() or not has_save():
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	data["phase_seconds"] = _merged_seconds(data.get("phase_seconds", {}))
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


## Start-up: the play times already in the save, so that a New Game or Choose Case (which restart only their own
## chapter's numbers) doesn't write over every earlier case's numbers at its first checkpoint.
func _load_play_time() -> void:
	if not has_save():
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) == TYPE_DICTIONARY:
		phase_seconds = _merged_seconds(data.get("phase_seconds", {}))


## phase_seconds with `saved` folded in, keeping the larger number for each step. Play time never runs backwards.
func _merged_seconds(saved: Variant) -> Dictionary:
	var out := phase_seconds.duplicate()
	if typeof(saved) == TYPE_DICTIONARY:
		for k in saved.keys():
			out[k] = maxf(float(out.get(k, 0.0)), float(saved[k]))
	return out


# ------------------------------------------------------------------ save / settings
func save_checkpoint(step: String) -> void:
	var data := {
		"step": step, "chapter": chapter, "flags": flags, "clues": clues, "skills": skills,
		"hangouts_done": hangouts_done,
		"alibi_seen": alibi_seen, "alibi_marks": alibi_marks, "alibi_rows": alibi_rows, "trial_resume": trial_resume,
		"log": self.log, "log_transcript": log_transcript, "log_note": log_note, "phase_seconds": phase_seconds,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Restores state and returns the saved step id ("" if none).
func load_checkpoint() -> String:
	if not has_save():
		return ""
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	var clock := phase_seconds.duplicate()
	new_game()
	chapter = int(data.get("chapter", 1))
	flags = data.get("flags", {})
	for c in data.get("clues", []):
		clues.append(str(c))
	for s in data.get("skills", []):
		if not skills.has(str(s)):
			skills.append(str(s))
	for h in data.get("hangouts_done", []):
		hangouts_done.append(str(h))
	# saves from before the Alibi Board and mid-trial checkpoints simply have none of these
	var seen: Variant = data.get("alibi_seen", {})
	alibi_seen = seen if typeof(seen) == TYPE_DICTIONARY else {}
	var marks: Variant = data.get("alibi_marks", {})
	alibi_marks = marks if typeof(marks) == TYPE_DICTIONARY else {}
	for r in data.get("alibi_rows", []):
		alibi_rows.append(str(r))
	var res: Variant = data.get("trial_resume", {})
	trial_resume = res if typeof(res) == TYPE_DICTIONARY else {}
	# ...and saves from before the Logbook simply start it empty
	self.log = _entries_from(data.get("log", []), ["sec", "text", "when", "who", "clock", "id", "struck"])
	log_transcript = _entries_from(data.get("log_transcript", []), ["who", "text"])
	log_note = str(data.get("log_note", ""))
	phase_seconds = clock
	phase_seconds = _merged_seconds(data.get("phase_seconds", {}))
	return str(data.get("step", ""))


## The dictionaries in a saved list that have every expected key. Anything else in a save is ignored.
func _entries_from(saved: Variant, keys: Array) -> Array:
	var out: Array = []
	if typeof(saved) == TYPE_ARRAY:
		for e in saved:
			if typeof(e) == TYPE_DICTIONARY and (e as Dictionary).has_all(keys):
				out.append(e)
	return out


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"text_speed": text_speed, "music_volume": music_volume,
			"sfx_volume": sfx_volume, "fullscreen": fullscreen,
			"chapter_unlocked": chapter_unlocked,
		}))


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	text_speed = float(data.get("text_speed", 1.0))
	music_volume = float(data.get("music_volume", 0.7))
	sfx_volume = float(data.get("sfx_volume", 0.8))
	fullscreen = bool(data.get("fullscreen", false))
	chapter_unlocked = clampi(int(data.get("chapter_unlocked", 1)), 1, Chapters.LAST)
	apply_fullscreen()


## The 3D walk-around version keeps its own saves (its own user folder), but if the classic version already
## unlocked Chapter 2 on this computer, the title screen offers it here too. Read-only.
func _inherit_unlock() -> void:
	var p := OS.get_user_data_dir().get_base_dir().path_join("Splash Trial").path_join("splash_trial_settings.json")
	if not FileAccess.file_exists(p):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(data) == TYPE_DICTIONARY:
		chapter_unlocked = maxi(chapter_unlocked, clampi(int(data.get("chapter_unlocked", 1)), 1, Chapters.LAST))


## Called when a chapter's credits finish: unlocks the next chapter on the title screen.
func unlock_chapter(ch: int) -> void:
	if ch > chapter_unlocked and ch <= Chapters.LAST:
		chapter_unlocked = ch
		save_settings()


func apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply_fullscreen()
	save_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


## True while the player holds the fast-forward key (Ctrl) or autotest is on.
func is_fast_forward() -> bool:
	return (autotest and not autotest_slow) or Input.is_key_pressed(KEY_CTRL)

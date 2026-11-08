extends Node
## Global game state. Autoload name: Game
##
## Minigames: call Game.begin_minigame() when they start, then Game.reward(Game.REWARD_X)
## for correct actions and Game.mistake(Game.PENALTY_X) for wrong ones. Skills are applied here.

const Skills := preload("res://scripts/data/skills.gd")
const Clues := preload("res://scripts/data/clues.gd")
const Cast := preload("res://scripts/data/cast.gd")
const Chapters := preload("res://scripts/data/chapters.gd")

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

# --- Settings ---
var text_speed := 1.0     # characters-per-second multiplier
var music_volume := 0.7
var sfx_volume := 0.8
var fullscreen := false

# --- Progress state ---
## Current chapter (1 or 2). Mirrors Chapters.current, which the data scripts read.
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	load_settings()
	_inherit_unlock()
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
		elif a.begins_with("--chapter="):
			chapter = int(a.get_slice("=", 1))
		elif a.begins_with("--start="):
			debug_start = a.get_slice("=", 1)
		elif a.begins_with("--minigame="):
			debug_minigame = a.get_slice("=", 1)
		elif a.begins_with("--script="):
			debug_script = a.get_slice("=", 1)
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


func is_convinced() -> bool:
	return convince >= CONVINCE_THRESHOLD


# ------------------------------------------------------------------ save / settings
func save_checkpoint(step: String) -> void:
	var data := {
		"step": step, "chapter": chapter, "flags": flags, "clues": clues, "skills": skills,
		"hangouts_done": hangouts_done,
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
	return str(data.get("step", ""))


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

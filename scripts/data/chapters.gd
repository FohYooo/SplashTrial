extends RefCounted
## Per-chapter data. The active chapter lives in the static var `current` (Game.chapter writes it).
## Data scripts (cast, clues, story, trial data, investigation data) read Chapters.current so they
## never need the Game autoload. Spoilers: see docs/DESIGN.md (chapter 1) and docs/DESIGN2.md (chapter 2).
## Optional "day_starts" (Case 3 on) maps each day's first flow step to its day number; see day_at().
## Difficulty keys (all optional, see docs/ARCHITECTURE.md section 1e):
##   "threshold"        convince needed at the vote
##   "penalty_scale"    multiplies every mistake (Game.mistake)
##   "hint_loops"       debate loops before the hint shows by itself (0 = never by itself)
##   "hint_on_request"  the hint is a button that costs convince instead
##   "ending"           "auto" (the investigation ends on the last required Drop) or "choice" (the player ends it)
##   "missing_cap"      most convince a trial can take for Truth Drops the player arrives without
##   "ammo_min"         a debate with fewer Truth Drops loaded is topped up from the notebook to this many
##   "freetime_slots"   visits per Free Time: an int, or {free time step: visits} for a chapter with Free Time on several
##                      days (then everyone can be visited again each day); default 3
##   "alibi_board"      the notebook shows the Alibi Board tab (Case 3 on; Cases 1 and 2 play as released)
##   "logbook"          the Logbook exists: L, the "Log [L]" tag, the Log tab, and everything it records (Case 3 on;
##                      Cases 1 and 2 have none of it, as released)
## Ending keys (all optional, Case 3 on):
##   "after_vote"       flow step after a correct final vote (default "execution"). "confession" plays story id
##                      "confession" on the courtroom stage, then "next" carries on; with no such script it is skipped
##   "gameover"         the chapter's own wrong-vote screen (default scripts/screens/gameover_screen.gd)
##   "credits_cast"     the line under STARRING in the credits
##   "credits_mourned"  extra memorial cards after the victim's: [[id, name, line], ...]
##   "credits_quiet"    no fireworks at the end of the credits

static var current := 1

const LAST := 3

const CH := {
	1: {
		"title": "Murder at Yuzu Springs",
		"case": "Case 1",
		"victim": "coco",
		"victim_name": "Captain Coco",
		"memorial_line": "Ace Sailor. Protector of her crew. Ahoy, forever.",
		"culprit": "wisp",
		"gone": [],                      # dead before this chapter starts
		"first_step": "prologue",
		"auto_picks": ["coco", "pepper", "nibs"],
		"execution": "res://scripts/screens/execution_screen.gd",
		"investigation": "res://scripts/data/investigation_data.gd",
		"rooms3d": "res://scripts/world3d/rooms1.gd",
		"inv_start_clues": ["rules", "snapjaw_file"],
		# Cases 1 and 2 play exactly as released (the user chose to leave them as they are): 60%, normal penalties,
		# the hint after 2 loops, no extra ammo, and the investigation ends on the last required Truth Drop.
		"threshold": 60.0, "penalty_scale": 1.0, "hint_loops": 2, "hint_on_request": false, "ending": "auto",
		"next": {
			"prologue": "freetime", "freetime": "motive", "motive": "evening", "evening": "night",
			"night": "discovery", "discovery": "investigation", "investigation": "investigation_end",
			"investigation_end": "trial", "execution": "epilogue", "epilogue": "credits",
		},
	},
	2: {
		"title": "Murder on the Mudlark",
		"case": "Case 2",
		"victim": "marigold",
		"victim_name": "Marigold Fern",
		"memorial_line": "Ace Nurse. She looked after every one of us.",
		"culprit": "tumble",
		"gone": ["coco", "wisp"],
		"first_step": "aftermath",
		"auto_picks": ["zuzu", "marigold", "pepper"],
		"execution": "res://scripts/screens/execution2_screen.gd",
		"investigation": "res://scripts/data/investigation_data2.gd",
		"rooms3d": "res://scripts/world3d/rooms2.gd",
		"inv_start_clues": ["rules2", "snapjaw_file2"],
		# As released, like Case 1 (see the note there).
		"threshold": 60.0, "penalty_scale": 1.0, "hint_loops": 2, "hint_on_request": false, "ending": "auto",
		"next": {
			"aftermath": "drain", "drain": "prologue",
			"prologue": "freetime", "freetime": "motive", "motive": "evening", "evening": "night",
			"night": "discovery", "discovery": "investigation", "investigation": "investigation_end",
			"investigation_end": "trial", "execution": "epilogue", "epilogue": "credits",
		},
	},
	3: {
		"title": "Murder at Warden's Rest",
		"alibi_board": true,
		# the depth rules (tools/check_depth.py) are errors from here on: rows, motives and evidence balance are in
		"depth_checked": true,
		"logbook": true,
		"case": "Case 3",
		# Spoilers: docs/DESIGN3.md and the plan's spoiler file. Nothing shown before the final vote reads these.
		"victim": "nibs",
		"victim_name": "Professor Nibs",
		"memorial_line": "Ace Chemist. He wanted the truth for all of us. Hypothetically, he got it.",
		"culprit": "pepper",
		"gone": ["coco", "wisp", "marigold", "tumble"],
		"first_step": "aftermath",
		"auto_picks": ["bramble", "bruno", "duchess"],
		"execution": "res://scripts/screens/execution3_screen.gd",
		"gameover": "res://scripts/screens/gameover3_screen.gd",
		"after_vote": "confession",
		"credits_cast": "the guests (and host) of the Warden's Rest",
		"credits_mourned": [["grub", "Grub Pemberton", "Ace Chef. He fed every one of us, right up to the end."]],
		"credits_quiet": true,
		"investigation": "res://scripts/data/investigation_data3.gd",
		"rooms3d": "res://scripts/world3d/rooms3.gd",
		"map_title": "MANSION MAP",
		# the investigation opens with these (story_case3.gd "investigation_start"), so no stage counts them
		"inv_start_clues": ["rules3", "snapjaw_file3", "ledger_read", "bat_bite", "grub_soup"],
		"threshold": 70.0, "penalty_scale": 1.5, "hint_loops": 0, "hint_on_request": true, "ending": "choice",
		"missing_cap": 18.0, "ammo_min": 5,
		"day_starts": {"day1": 1, "day2": 2, "day3": 3, "day4": 4, "day5": 5, "discovery": 6},
		# Free Time on Days 1, 2, 3 and 5 (main.gd FREETIME_STEPS); the day scripts set c3_day2 / c3_day3 / c3_day5 for the
		# shared freetime_intro / freetime_outro / hangout_<id> scripts
		"freetime_slots": {"freetime": 2, "freetime2": 3, "freetime3": 2, "freetime5": 2},
		"next": {
			"aftermath": "quake", "quake": "day1",
			"day1": "freetime", "freetime": "night1", "night1": "day2", "day2": "freetime2", "freetime2": "evening2",
			"evening2": "day3", "day3": "freetime3", "freetime3": "night3", "night3": "day4", "day4": "night4",
			"night4": "day5", "day5": "freetime5", "freetime5": "evening", "evening": "night", "night": "discovery",
			"discovery": "investigation", "investigation": "investigation_end",
			"investigation_end": "trial", "confession": "execution", "execution": "epilogue",
			"epilogue": "caiman_kill", "caiman_kill": "epilogue_after", "epilogue_after": "credits",
		},
	},
}


static func data(ch: int = -1) -> Dictionary:
	var c := current if ch < 0 else ch
	return CH.get(c, CH[1])


static func get_value(key: String, default: Variant = null) -> Variant:
	return data().get(key, default)


## Everyone dead by the trial of the current chapter (memorial portraits).
static func dead() -> Array:
	var out: Array = data()["gone"].duplicate()
	out.append(data()["victim"])
	return out


## Dead before the current chapter began (not available for free time).
static func gone() -> Array:
	return data()["gone"]


static func next_step(step: String) -> String:
	var nx: Dictionary = data()["next"]
	return str(nx.get(step, ""))


## The current chapter's 3D room script (static build(), SPACES, FREE_SPACES, FREE_START).
static func rooms3d() -> Script:
	return load(str(data()["rooms3d"]))


## Is this flow step the first step of a new day? Such steps are save checkpoints.
static func is_day_start(step: String) -> bool:
	return (data().get("day_starts", {}) as Dictionary).has(step)


## The story day a flow step falls on, found by walking the step order from the chapter's first step.
## 0 = before Day 1, or a chapter without days. Steps after the walk runs out count as the last day.
static func day_at(step: String) -> int:
	var starts: Dictionary = data().get("day_starts", {})
	if starts.is_empty():
		return 0
	var nx: Dictionary = data()["next"]
	var s := str(data()["first_step"])
	var day := 0
	for i in nx.size() + 1:
		day = int(starts.get(s, day))
		if s == step or not nx.has(s):
			break
		s = str(nx[s])
	return day


## Has a room or space opened on this day? `entry` is its ROOMS or SPACES entry ("opens_day": int, optional).
## Day 0 means nothing is gated.
static func room_open(entry: Dictionary, day: int) -> bool:
	return day <= 0 or int(entry.get("opens_day", 1)) <= day


## How many visits a Free Time step allows ("freetime_slots": an int, or {step: visits}; default 3).
static func freetime_slots(step: String) -> int:
	var v: Variant = data().get("freetime_slots", 3)
	if typeof(v) == TYPE_DICTIONARY:
		return int((v as Dictionary).get(step, 3))
	return int(v)


## Has the chapter got Free Time on several days? Then each one starts with nobody visited yet.
static func daily_free_time() -> bool:
	return typeof(data().get("freetime_slots")) == TYPE_DICTIONARY


## Has this chapter got a Logbook? (Cases 1 and 2 don't: no L key, no tag, no tab, nothing recorded.)
static func logbook() -> bool:
	return bool(data().get("logbook", false))


## Does the investigation wait for the player to end it? (Chapters without the key end on the last required Drop.)
static func ends_by_choice() -> bool:
	return str(data().get("ending", "auto")) == "choice"


## Has the story got as far as `marker` by flow step `step`? Walks the step order from the chapter's first step.
## A step outside the order (the trial and after, debug runs) counts as past every marker.
static func step_reached(step: String, marker: String) -> bool:
	var nx: Dictionary = data()["next"]
	var s := str(data()["first_step"])
	for i in nx.size() + 2:
		if s == marker:
			return true
		if s == step or not nx.has(s):
			return s != step
		s = str(nx[s])
	return true

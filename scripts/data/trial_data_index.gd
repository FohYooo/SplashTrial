extends RefCounted
## Looks up Splash Trial minigame data for the current chapter:
## chapter 1 = trial_data.gd, chapter 2 = trial_data2.gd (ids prefixed c2_), chapter 3 = trial_data3.gd (c3_).

const Chapters := preload("res://scripts/data/chapters.gd")
const TrialData1 := preload("res://scripts/data/trial_data.gd")
## Chapters after the first load on demand (chapter -> trial data file).
const LATER_PATHS := {2: "res://scripts/data/trial_data2.gd", 3: "res://scripts/data/trial_data3.gd"}
## Minigames the daily story plays outside the trial (chapter -> data file, same formats), such as Case 3's Tea-Time
## Tribunal. Kept apart so the trial's own file stays the trial's.
const STORY_PATHS := {3: "res://scripts/data/story_minigames3.gd"}

static var _loaded := {}
static var _story_loaded := {}


static func table() -> Dictionary:
	var ch := Chapters.current
	if not LATER_PATHS.has(ch):
		return TrialData1.DATA
	if not _loaded.has(ch):
		var path := str(LATER_PATHS[ch])
		var t: Dictionary = {}
		if ResourceLoader.exists(path):
			var scr: Script = load(path)
			t = scr.get_script_constant_map().get("DATA", {})
		_loaded[ch] = t
	return _loaded[ch]


static func get_data(id: String) -> Dictionary:
	var t := table()
	if t.has(id):
		return t[id]
	var st := story_table()
	if st.has(id):
		return st[id]
	# allow any id from either chapter (debug --minigame)
	if TrialData1.DATA.has(id):
		return TrialData1.DATA[id]
	# test fixtures for the trial types (--minigame=t_...)
	if id.begins_with("t_"):
		return (load("res://scripts/data/trial_data_test.gd").get_script_constant_map()["DATA"] as Dictionary).get(id, {})
	return {}


## The current chapter's story minigames (STORY_PATHS), or an empty table.
static func story_table() -> Dictionary:
	var ch := Chapters.current
	if not STORY_PATHS.has(ch):
		return {}
	if not _story_loaded.has(ch):
		var path := str(STORY_PATHS[ch])
		var t: Dictionary = {}
		if ResourceLoader.exists(path):
			var scr: Script = load(path)
			t = scr.get_script_constant_map().get("DATA", {})
		_story_loaded[ch] = t
	return _story_loaded[ch]

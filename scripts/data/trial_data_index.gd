extends RefCounted
## Looks up Splash Trial minigame data for the current chapter:
## chapter 1 = trial_data.gd, chapter 2 = trial_data2.gd (ids prefixed c2_).

const Chapters := preload("res://scripts/data/chapters.gd")
const TrialData1 := preload("res://scripts/data/trial_data.gd")
const CH2_PATH := "res://scripts/data/trial_data2.gd"

static var _ch2: Dictionary = {}
static var _ch2_loaded := false


static func table() -> Dictionary:
	if Chapters.current == 2:
		if not _ch2_loaded:
			_ch2_loaded = true
			if ResourceLoader.exists(CH2_PATH):
				var scr: Script = load(CH2_PATH)
				_ch2 = scr.get_script_constant_map().get("DATA", {})
		return _ch2
	return TrialData1.DATA


static func get_data(id: String) -> Dictionary:
	var t := table()
	if t.has(id):
		return t[id]
	# allow any id from either chapter (debug --minigame)
	if TrialData1.DATA.has(id):
		return TrialData1.DATA[id]
	return {}

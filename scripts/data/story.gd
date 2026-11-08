extends RefCounted
## Story script registry. Script texts live in:
##   chapter 1: story/story_daily.gd  (prologue, free time hangouts, motive, evening, night, discovery, epilogue)
##              story/story_case.gd   (investigation snippets, investigation_end, trial)
##   chapter 2: story/story_daily2.gd (aftermath, prologue, hangouts, motive, evening, night, discovery, epilogue)
##              story/story_case2.gd  (investigation snippets, investigation_end, trial)
## Each of those files defines `const SCRIPTS := { "id": """...DSL...""" }`. Ids are looked up in the
## current chapter's files only (Chapters.current), so both chapters can use the same step ids.

const Chapters := preload("res://scripts/data/chapters.gd")
const StoryDaily := preload("res://scripts/data/story/story_daily.gd")
const StoryCase := preload("res://scripts/data/story/story_case.gd")
const CH2_FILES := ["res://scripts/data/story/story_daily2.gd", "res://scripts/data/story/story_case2.gd"]

static var _ch2: Array = []


static func _tables() -> Array:
	if Chapters.current == 2:
		if _ch2.is_empty():
			for p in CH2_FILES:
				if ResourceLoader.exists(p):
					var scr: Script = load(p)
					var consts: Dictionary = scr.get_script_constant_map()
					var t: Dictionary = consts.get("SCRIPTS", {})
					_ch2.append(t)
		return _ch2
	return [StoryDaily.SCRIPTS, StoryCase.SCRIPTS]


static func has(id: String) -> bool:
	for t in _tables():
		var d: Dictionary = t
		if d.has(id):
			return true
	return false


static func get_text(id: String) -> String:
	for t in _tables():
		var d: Dictionary = t
		if d.has(id):
			return d[id]
	push_warning("Story: missing script '%s' (chapter %d)" % [id, Chapters.current])
	return "think: (Script '%s' is missing.)\n@end" % id

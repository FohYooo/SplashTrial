extends RefCounted
## Story script registry. Script texts live in:
##   chapter 1: story/story_daily.gd  (prologue, free time hangouts, motive, evening, night, discovery, epilogue)
##              story/story_case.gd   (investigation snippets, investigation_end, trial)
##   chapter 2: story/story_daily2.gd (aftermath, prologue, hangouts, motive, evening, night, discovery, epilogue)
##              story/story_case2.gd  (investigation snippets, investigation_end, trial)
##   chapter 3: story/story_daily3.gd, story/story_case3.gd (same split), story/story_end3.gd (epilogue, epilogue_after)
## Each of those files defines `const SCRIPTS := { "id": """...DSL...""" }`. Ids are looked up in the
## current chapter's files only (Chapters.current), so every chapter can use the same step ids.

const Chapters := preload("res://scripts/data/chapters.gd")
const StoryDaily := preload("res://scripts/data/story/story_daily.gd")
const StoryCase := preload("res://scripts/data/story/story_case.gd")
## Chapters after the first load on demand (chapter -> story files).
const LATER_FILES := {
	2: ["res://scripts/data/story/story_daily2.gd", "res://scripts/data/story/story_case2.gd"],
	3: ["res://scripts/data/story/story_daily3.gd", "res://scripts/data/story/story_case3.gd", "res://scripts/data/story/story_end3.gd"],
}

static var _loaded := {}


static func _tables() -> Array:
	var ch := Chapters.current
	if not LATER_FILES.has(ch):
		return [StoryDaily.SCRIPTS, StoryCase.SCRIPTS]
	if not _loaded.has(ch):
		var tables: Array = []
		for p in LATER_FILES[ch]:
			if ResourceLoader.exists(p):
				var scr: Script = load(p)
				tables.append(scr.get_script_constant_map().get("SCRIPTS", {}))
		_loaded[ch] = tables
	return _loaded[ch]


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

extends RefCounted
## Story script registry. Script texts live in:
##   story/story_daily.gd  (prologue, free time hangouts, motive, evening, night, discovery, epilogue)
##   story/story_case.gd   (investigation snippets, investigation_end, trial)
## Each of those files defines `const SCRIPTS := { "id": """...DSL...""" }`.

const StoryDaily := preload("res://scripts/data/story/story_daily.gd")
const StoryCase := preload("res://scripts/data/story/story_case.gd")


static func has(id: String) -> bool:
	return StoryDaily.SCRIPTS.has(id) or StoryCase.SCRIPTS.has(id)


static func get_text(id: String) -> String:
	if StoryDaily.SCRIPTS.has(id):
		return StoryDaily.SCRIPTS[id]
	if StoryCase.SCRIPTS.has(id):
		return StoryCase.SCRIPTS[id]
	push_warning("Story: missing script '%s'" % id)
	return "think: (Script '%s' is missing.)\n@end" % id

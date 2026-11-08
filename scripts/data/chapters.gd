extends RefCounted
## Per-chapter data. The active chapter lives in the static var `current` (Game.chapter writes it).
## Data scripts (cast, clues, story, trial data, investigation data) read Chapters.current so they
## never need the Game autoload. Spoilers: see docs/DESIGN.md (chapter 1) and docs/DESIGN2.md (chapter 2).

static var current := 1

const LAST := 2

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
		"inv_start_clues": ["rules", "snapjaw_file"],
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
		"inv_start_clues": ["rules2", "snapjaw_file2"],
		"next": {
			"aftermath": "drain", "drain": "prologue",
			"prologue": "freetime", "freetime": "motive", "motive": "evening", "evening": "night",
			"night": "discovery", "discovery": "investigation", "investigation": "investigation_end",
			"investigation_end": "trial", "execution": "epilogue", "epilogue": "credits",
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

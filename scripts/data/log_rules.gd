extends RefCounted
## The Logbook's rules: its sections, how an entry is stamped, and the words Mochi uses for the entries the game
## writes by itself. Shown on the notebook's Log tab (scripts/ui/pause_menu.gd). State lives in Game (log,
## log_transcript, log_note). The story writes entries with `@log` (docs/ARCHITECTURE.md section 3).
##
## Writing rules (tools/check_content.py checks every `@log` line, and the lines below, against them):
##   - only what Mochi saw or heard, in her own first-person words, so she never names herself
##   - never connect two facts and never flag anything as mattering: see BANNED
##   - no count of what is left, and nothing the player hasn't seen yet
##   - a wrong theory is written as what everyone believed, and only `@log strike` crosses it out
##   - in a chapter that writes People entries, no guest's entries may stand out in number or kind

const Chapters := preload("res://scripts/data/chapters.gd")

## Section id, title, in the order the Log tab lists them.
const SECTIONS := [
	["timeline", "Timeline"],
	["places", "Places and things"],
	["people", "People"],
	["transcript", "Transcript"],
	["trial", "Trial record"],
	["notes", "Your notes"],
]
## What `@log` may write to. The Transcript fills itself, and "Your notes" belongs to the player alone.
const WRITTEN := ["timeline", "places", "people", "trial"]
const TRANSCRIPT_MAX := 200
const NOTE_MAX := 1200

## How a flow step reads as a heading. A chapter with days puts the day in front ("Day 2, Free Time").
const PHASES := {
	"aftermath": "Aftermath", "drain": "Aftermath", "quake": "Aftermath", "prologue": "Arrival", "freetime": "Free Time",
	"motive": "The motive", "evening": "Evening", "night": "Night", "discovery": "Morning", "investigation": "Investigation",
	"investigation_end": "Investigation", "trial": "Class trial", "execution": "After the trial", "epilogue": "After the trial",
	"credits": "After the trial",
	# Case 3's extra steps: Free Time on several days, and the nights and evenings between them
	"freetime2": "Free Time", "freetime3": "Free Time", "freetime4": "Free Time", "freetime5": "Free Time",
	"night1": "Night", "evening2": "Evening", "night3": "Night", "night4": "Night",
	# the trial's recess (Case 3) is still the trial
	"recess": "Class trial",
}

## The entries the game writes by itself. Which wording a name gets depends only on the name, so an entry can
## never look different because of what the thing turned out to be.
const PLACE_LINES := ["%s. Went in.", "%s. Walked through.", "%s. Had a wander."]
const THING_LINES := ["%s. Had a look.", "%s. Took a closer look.", "%s. Stopped to look."]

## `@evening`: a small question at the end of a day. It asks and never suggests.
const EVENING_PROMPT := "Another day done. Do I feel any differently about anyone?"
const EVENING_OPEN := "Go over my marks"
const EVENING_SKIP := "Not tonight"

## Regular expressions (case-insensitive) no entry may match, grouped by what they would give away.
const BANNED := [
	# flagging something as mattering
	"\\bimportant", "\\bcrucial", "\\bvital\\b", "\\bsignificant", "\\bnotable", "\\bnoteworthy", "\\bsuspicious", "\\bstrange",
	"\\bodd\\b", "\\bweird", "\\bclues?\\b", "\\bevidence\\b", "\\bkey (detail|point|fact|piece|clue)", "worth (remembering|noting|checking)",
	"remember this", "keep in mind", "pay attention",
	# connecting facts
	"(which|that|this) means", "\\btherefore\\b", "\\bmust (have|be)\\b", "\\bcould ?n.t have\\b", "\\bcould not have\\b", "\\bdisprov", "\\bproves?\\b",
	"\\bproof\\b", "\\bcontradict", "\\bdoes ?n.t (match|fit|add up)\\b", "\\bdoes not (match|fit|add up)\\b", "\\bmatches\\b", "\\bexplains\\b", "that.s why",
	# counting what's left
	"\\b\\d+ (of|out of) \\d+\\b", "(left|still) to (find|examine|check)", "\\bremaining\\b", "\\bhave ?n.t (found|examined|checked)\\b", "\\bstill need",
	# not her own words
	"\\bMochi\\b",
]


## One line for walking into a place.
static func place_line(place: String) -> String:
	return str(PLACE_LINES[absi(place.hash()) % PLACE_LINES.size()]) % place


## One line for looking at a thing.
static func thing_line(thing: String) -> String:
	return str(THING_LINES[absi(thing.hash()) % THING_LINES.size()]) % thing


## The heading an entry written during a flow step goes under.
static func when(step: String) -> String:
	var day := Chapters.day_at(step)
	var phase := str(PHASES.get(step, ""))
	if day <= 0:
		return phase
	return "Day %d" % day if phase == "" else "Day %d, %s" % [day, phase]


## `@log` arguments -> {"sec", "text", "who", "clock", "id"}, or {} if the line isn't valid.
##   @log timeline 9:30 PM | Snapjaw called everyone to the lobby.     (the time before " | " is optional)
##   @log places The lift goes down to a floor I hadn't seen.
##   @log people <guest> Told me she was in the kitchen.
##   @log trial #door_shut We all agreed the door was shut.            (the #id is optional, for crossing it out later)
##   @log strike door_shut                                             (sec "strike", text = the id)
static func parse(rest: String) -> Dictionary:
	var sp := rest.find(" ")
	if sp == -1:
		return {}
	var sec := rest.substr(0, sp)
	var text := rest.substr(sp + 1).strip_edges()
	var out := {"sec": sec, "text": text, "who": "", "clock": "", "id": ""}
	if sec == "strike":
		return out
	if not WRITTEN.has(sec) or text == "":
		return {}
	if sec == "people":
		var who_end := text.find(" ")
		if who_end == -1:
			return {}
		out["who"] = text.substr(0, who_end)
		text = text.substr(who_end + 1).strip_edges()
	elif sec == "trial" and text.begins_with("#"):
		var id_end := text.find(" ")
		if id_end == -1:
			return {}
		out["id"] = text.substr(1, id_end - 1)
		text = text.substr(id_end + 1).strip_edges()
	var bar := text.find(" | ")
	if bar != -1:
		out["clock"] = text.substr(0, bar).strip_edges()
		text = text.substr(bar + 3).strip_edges()
	out["text"] = text
	return out

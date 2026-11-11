extends RefCounted
## The Alibi Board's data: what each guest says they were doing, hour by hour, and their reason to kill.
## Shown in the notebook (scripts/ui/pause_menu.gd). The story reveals entries with `@alibi` (docs/ARCHITECTURE.md section 3).
##
## DATA[chapter][guest] = {"motive": String, "slots": [{"when": String, "where": String, "proof": String}]}
##   when   one of the chapter's HOURS, or a row the story adds later with `@alibi row <when>`
##   where  what the guest says, short enough for a small square on the board
##   proof  who or what backs it up, if anything ("" = nothing does)
##
## Writing rules (tools/check_depth.py checks them): the board states what was said and leaves the weighing to the
## player, so no entry may call anything confirmed, suspect, cleared or the like. Every living guest has a motive
## and a row for each hour they account for, and at least three innocent guests have no proof at the time that matters.
## A chapter with no entry here shows blank rows; its guests can still be marked.
## Plain data only: the revealed state lives in Game (alibi_seen, alibi_marks, alibi_rows).

const Chapters := preload("res://scripts/data/chapters.gd")
const Cast := preload("res://scripts/data/cast.gd")

## The plain hourly rows every chapter starts with. Meals and mornings get no row of their own.
const HOURS := {
	1: ["6 PM", "7 PM", "8 PM", "9 PM", "10 PM", "11 PM"],
	2: ["6 PM", "7 PM", "8 PM", "9 PM", "10 PM", "11 PM", "12 AM"],
	3: ["6 PM", "7 PM", "8 PM", "9 PM", "10 PM", "11 PM", "12 AM"],
}

## Filled in by the packages that write each case's depth pass.
## Case 3: the motives are revealed at the Visitor's Passes on Day 2 (story_daily3.gd "evening2"), so they hold only what
## is known then: the loved one in the Gaol. Later grudges go to the Logbook. The hourly rows are the night of Day 5, as
## each guest tells it (lies included), in Mochi's words. The daily story reveals what Mochi sees for herself: every 8 PM
## row at dinner, then the 9:40, 9:55, 11:20 and 11:35 scenes. The rest is for the investigation to reveal. Proofs name
## only someone or something other than the guest's own word; the dinner rows have none, so the table is no proof.
## The 5 PM row (4:30 to 5:40, when the bookcase was loosened) is added by the trial, at its first overturn
## (story_case3.gd "trial", `@alibi row 5 PM`), and only then revealed.
const DATA := {
	3: {
		"bramble": {"motive": "Her father is in the Gaol. He grew roses; she was told he'd gone into a home. Checking out would free him.", "slots": [
			{"when": "5 PM", "where": "The Conservatory, potting seedlings with Fennel.", "proof": "Fennel says so."},
			{"when": "6 PM", "where": "The Conservatory, potting seedlings with Fennel.", "proof": "Fennel says so."},
			{"when": "7 PM", "where": "Her room, changing for dinner.", "proof": ""},
			{"when": "8 PM", "where": "Dinner. Never left the table.", "proof": ""},
			{"when": "9 PM", "where": "Dinner, then the Conservatory with Fennel from 9:20, to watch the moonflowers open.", "proof": "Fennel says so."},
			{"when": "10 PM", "where": "The Conservatory with Fennel until 10:45. Then her room.", "proof": "Fennel, until 10:45."},
			{"when": "11 PM", "where": "Her room, alone, in the dark.", "proof": ""},
			{"when": "12 AM", "where": "Her room, asleep.", "proof": ""},
		]},
		"bruno": {"motive": "His student Sesame is in the Gaol. She's nine, his youngest at the dojo. Checking out would free her.", "slots": [
			{"when": "5 PM", "where": "The cliff path, carrying a crate up from the wreck.", "proof": ""},
			{"when": "6 PM", "where": "The cliff path, carrying the last crates up from the wreck.", "proof": ""},
			{"when": "7 PM", "where": "The Generator Room, oiling it before dinner.", "proof": ""},
			{"when": "8 PM", "where": "Dinner. Never left the table.", "proof": ""},
			{"when": "9 PM", "where": "Dinner, then the Generator Room. Says Grub went down with him at 9:30.", "proof": ""},
			{"when": "10 PM", "where": "The Generator Room, keeping it running.", "proof": ""},
			{"when": "11 PM", "where": "The Generator Room. Says Reginald came in when the lights went out.", "proof": ""},
			{"when": "12 AM", "where": "The Generator Room until it ran again. Then his room.", "proof": ""},
		]},
		"duchess": {"motive": "Her niece Plum is in the Gaol. She's nineteen and sews buttonholes. Checking out would free her.", "slots": [
			{"when": "5 PM", "where": "Her room, sewing Lulu's costume.", "proof": ""},
			{"when": "6 PM", "where": "Her room, cutting out Lulu's costume.", "proof": ""},
			{"when": "7 PM", "where": "Her room, dressing for dinner.", "proof": ""},
			{"when": "8 PM", "where": "Dinner. Never left the table.", "proof": ""},
			{"when": "9 PM", "where": "Dinner, then her room, alone, hunting for her pins.", "proof": ""},
			{"when": "10 PM", "where": "Her room, then the Music Room at 10:30 for Lulu's fitting.", "proof": "Lulu, from 10:30."},
			{"when": "11 PM", "where": "The fitting with Lulu until 11:30, in the dark after 11:05. Then bed.", "proof": "Lulu, until 11:30."},
			{"when": "12 AM", "where": "Her room, asleep.", "proof": ""},
		]},
		"fennel": {"motive": "His sister Saffron is in the Gaol. She paints miniatures. Checking out would free her.", "slots": [
			{"when": "5 PM", "where": "The Conservatory, drawing Bramble at her seedlings.", "proof": "Bramble says so."},
			{"when": "6 PM", "where": "The Conservatory, drawing Bramble at her seedlings.", "proof": "Bramble says so."},
			{"when": "7 PM", "where": "The Conservatory, finishing the drawing.", "proof": ""},
			{"when": "8 PM", "where": "Dinner, sketching, next to me. Never left the table.", "proof": ""},
			{"when": "9 PM", "where": "Dinner, then the Conservatory with Bramble from 9:20.", "proof": "Bramble says so."},
			{"when": "10 PM", "where": "The Conservatory with Bramble until 10:45, drawing moonflowers. Then his room.", "proof": "Bramble, until 10:45."},
			{"when": "11 PM", "where": "His room, alone, in the dark.", "proof": ""},
			{"when": "12 AM", "where": "His room, asleep.", "proof": ""},
		]},
		"grub": {"motive": "His mum is in the Gaol. She taught him to cook. Checking out would free her.", "slots": [
			{"when": "5 PM", "where": "The kitchen, making the soup. I was there, chopping the onions.", "proof": ""},
			{"when": "6 PM", "where": "The kitchen, cooking.", "proof": ""},
			{"when": "7 PM", "where": "The kitchen, cooking.", "proof": ""},
			{"when": "8 PM", "where": "Serving. In and out of the kitchen all through dinner.", "proof": ""},
			{"when": "9 PM", "where": "Can't remember.", "proof": ""},
			{"when": "10 PM", "where": "Can't remember.", "proof": ""},
			{"when": "11 PM", "where": "Can't remember. I found him in the Wine Cellar at 11:20, sitting in the dark.", "proof": ""},
			{"when": "12 AM", "where": "His room, he thinks. He locked himself in.", "proof": ""},
		]},
		"lulu": {"motive": "Her old teacher Miss Pip is in the Gaol. She taught Lulu to sing. Checking out would free her.", "slots": [
			{"when": "5 PM", "where": "The Music Room, practising.", "proof": ""},
			{"when": "6 PM", "where": "The Music Room, practising standing still.", "proof": ""},
			{"when": "7 PM", "where": "The Music Room, practising scales.", "proof": ""},
			{"when": "8 PM", "where": "Dinner. Out at 8:40 for her lip balm, back at 8:45.", "proof": ""},
			{"when": "9 PM", "where": "Dinner, then the Music Room, practising.", "proof": ""},
			{"when": "10 PM", "where": "The Music Room. The Duchess came for the fitting at 10:30.", "proof": "The Duchess, from 10:30."},
			{"when": "11 PM", "where": "The fitting until 11:30, in the dark after 11:05. Then my room, in tears, from 11:35.", "proof": "I was with her from 11:35."},
			{"when": "12 AM", "where": "My room, with me, until 12:10. Then her own room.", "proof": "I was with her until 12:10."},
		]},
		"nibs": {"motive": "His assistant Fizz is in the Gaol. She's twenty-two. Checking out would free her.", "slots": [
			{"when": "5 PM", "where": "Out at 4:30 to watch the tide on the beach. Back at 5:40; I passed him on the stairs.", "proof": ""},
			{"when": "6 PM", "where": "The Library, working.", "proof": ""},
			{"when": "7 PM", "where": "The Library, working.", "proof": ""},
			{"when": "8 PM", "where": "Dinner. Signed the roster on the way in.", "proof": ""},
			{"when": "9 PM", "where": "First up at 9:15, for the Library. Argued with Zuzu there at 9:40.", "proof": ""},
			{"when": "10 PM", "where": "The Library, working.", "proof": ""},
			{"when": "11 PM", "where": "The Library, working.", "proof": ""},
			{"when": "12 AM", "where": "The Library, working.", "proof": ""},
		]},
		"pepper": {"motive": "Her old editor Mr. Pica is in the Gaol. He's ninety. Checking out would free him.", "slots": [
			{"when": "5 PM", "where": "The Gallery darkroom, developing.", "proof": ""},
			{"when": "6 PM", "where": "The Gallery darkroom, developing.", "proof": ""},
			{"when": "7 PM", "where": "Her room, dressing for dinner.", "proof": ""},
			{"when": "8 PM", "where": "Dinner. Out at 8:50 to change her film, back at 9:02.", "proof": "Her own photos of the Gallery, stamped 8:52 and 9:00."},
			{"when": "9 PM", "where": "Dinner, then the Gallery darkroom.", "proof": ""},
			{"when": "10 PM", "where": "The Gallery darkroom, developing.", "proof": ""},
			{"when": "11 PM", "where": "The Gallery. Took flash photos in the dark.", "proof": "Her own photos, stamped 11:06 to 11:18."},
			{"when": "12 AM", "where": "Her room, lettering tomorrow's Puddle.", "proof": ""},
		]},
		"reginald": {"motive": "His mother, the Dowager, is in the Gaol. She's eighty-one. Checking out would free her.", "slots": [
			{"when": "5 PM", "where": "The terrace, on watch.", "proof": ""},
			{"when": "6 PM", "where": "The terrace, on watch.", "proof": ""},
			{"when": "7 PM", "where": "His room, waxing his moustache for dinner.", "proof": ""},
			{"when": "8 PM", "where": "Dinner. Out at 8:30 for his moustache wax, back at 8:40.", "proof": ""},
			{"when": "9 PM", "where": "Dinner, then the Grand Hall at 9:55 to start his watch, with me.", "proof": "I was with him from 9:55 until the ten o'clock bell."},
			{"when": "10 PM", "where": "On patrol through the house.", "proof": ""},
			{"when": "11 PM", "where": "On patrol. Didn't see anyone in the dark.", "proof": ""},
			{"when": "12 AM", "where": "On patrol, until dawn.", "proof": ""},
		]},
		"zuzu": {"motive": "Their mum is in the Gaol. She ran a radio station from her kitchen. Checking out would free her.", "slots": [
			{"when": "5 PM", "where": "The Attic, mapping cameras.", "proof": ""},
			{"when": "6 PM", "where": "The Attic, mapping cameras.", "proof": ""},
			{"when": "7 PM", "where": "The Attic, mapping cameras.", "proof": ""},
			{"when": "8 PM", "where": "Dinner.", "proof": ""},
			{"when": "9 PM", "where": "Out at 9:05, back at 9:10. At 9:40, arguing with Nibs in the Library. Then up to the Attic.", "proof": ""},
			{"when": "10 PM", "where": "The Attic, working on the cameras.", "proof": ""},
			{"when": "11 PM", "where": "The Attic, in the dark.", "proof": ""},
			{"when": "12 AM", "where": "The Attic, then bed.", "proof": ""},
		]},
	},
}


## One entry per living guest of the current chapter, blank if the chapter hasn't written one.
static func entries() -> Dictionary:
	var table: Dictionary = DATA.get(Chapters.current, {})
	var out := {}
	for id in Cast.roster_alive():
		if id == "mochi":
			continue
		var e: Dictionary = table.get(id, {})
		out[id] = {"motive": str(e.get("motive", "")), "slots": e.get("slots", [])}
	return out


## Who the board lists, in the spoiler-safe order. The victim stays on it until the body is found, so that a board
## opened days before the murder gives nothing away.
static func guests(body_found: bool) -> Array:
	var out: Array = []
	for id in Cast.roster_alive():
		if id == "mochi" or (body_found and id == str(Chapters.get_value("victim", ""))):
			continue
		out.append(id)
	return out


## The chapter's rows, then any the story added, in clock order.
static func rows(added: Array) -> Array:
	var out: Array = (HOURS.get(Chapters.current, HOURS[1]) as Array).duplicate()
	for r in added:
		if not out.has(r):
			out.append(r)
	out.sort_custom(func(a: Variant, b: Variant) -> bool: return minutes(str(a)) < minutes(str(b)))
	return out


## Minutes since noon, so an evening sorts in order across midnight: "9:30 PM" -> 570, "12 AM" -> 720.
static func minutes(when: String) -> int:
	var parts := when.strip_edges().to_upper().split(" ", false)
	if parts.is_empty():
		return 0
	var clock := parts[0].split(":")
	var h := int(clock[0]) % 12
	var m := int(clock[1]) if clock.size() > 1 else 0
	var am := parts.size() > 1 and parts[1].begins_with("A")
	return (h + 12 if am else h) * 60 + m


## The stored keys one `@alibi <guest> <field>` reveals. field: "motive", "all", "<when>" or "<when> proof".
static func expand(guest: String, field: String) -> Array:
	var e: Dictionary = entries().get(guest, {})
	if field == "all":
		var out: Array = ["motive"]
		for s in e.get("slots", []):
			var when := str((s as Dictionary).get("when", ""))
			out.append(when)
			out.append(when + " proof")
		return out
	return [field]


## Is this field something the guest's entry actually has? (Story typos are caught by tools/check_depth.py.)
static func has_field(guest: String, field: String) -> bool:
	var e: Dictionary = entries().get(guest, {})
	if field == "motive" or field == "all":
		return true
	for s in e.get("slots", []):
		var when := str((s as Dictionary).get("when", ""))
		if field == when or field == when + " proof":
			return true
	return false


## What the player knows of one guest at one row: {"where": String, "proof": String}, blank if unheard.
static func known(guest: String, when: String, seen: Array) -> Dictionary:
	var e: Dictionary = entries().get(guest, {})
	for s in e.get("slots", []):
		var sd: Dictionary = s
		if str(sd.get("when", "")) == when:
			return {
				"where": str(sd.get("where", "")) if seen.has(when) else "",
				"proof": str(sd.get("proof", "")) if seen.has(when + " proof") else "",
			}
	return {"where": "", "proof": ""}


static func known_motive(guest: String, seen: Array) -> String:
	if not seen.has("motive"):
		return ""
	return str((entries().get(guest, {}) as Dictionary).get("motive", ""))

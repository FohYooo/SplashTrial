extends RefCounted

const Chapters := preload("res://scripts/data/chapters.gd")
## Static character data. Portrait art lives at res://art/chars/<id>_<expr>.svg
## Expressions available for every character: normal, happy, shock, angry, sad

const EXPRESSIONS := ["normal", "happy", "shock", "angry", "sad"]

## Order used for menus (free time, vote, etc.). "mochi" is the player.
const ORDER := [
	"mochi", "coco", "wisp", "bruno", "lulu", "pepper", "duchess", "bramble",
	"nibs", "zuzu", "reginald", "grub", "tumble", "marigold", "fennel",
]

## Spoiler-safe display order (Mochi first, then alphabetical by full name). Use this for anything the
## player sees as a list outside the trial (credits roll, free-time picker) so the order gives nothing away.
const ROSTER := [
	"mochi", "bramble", "bruno", "coco", "duchess", "fennel", "grub", "lulu",
	"marigold", "tumble", "pepper", "nibs", "reginald", "wisp", "zuzu",
]

## color = name-tag color, pitch = text-blip pitch multiplier
const CHARS := {
	"mochi":    {"name": "Mochi", "full": "Mochi", "talent": "Ace Bath Connoisseur", "color": Color("ffb347"), "pitch": 1.00},
	"coco":     {"name": "Coco", "full": "Captain Coco", "talent": "Ace Sailor", "color": Color("4a90d9"), "pitch": 0.90},
	"wisp":     {"name": "Wisp", "full": "Wisp Vanderloo", "talent": "Ace Magician", "color": Color("9b6bd6"), "pitch": 0.85},
	"bruno":    {"name": "Bruno", "full": "Bruno Brawnsworth", "talent": "Ace Wrestler", "color": Color("d64545"), "pitch": 0.65},
	"lulu":     {"name": "Lulu", "full": "Lulu Starling", "talent": "Ace Pop Idol", "color": Color("ff7eb9"), "pitch": 1.35},
	"pepper":   {"name": "Pepper", "full": "Pepper Quill", "talent": "Ace Journalist", "color": Color("e0a050"), "pitch": 1.15},
	"duchess":  {"name": "Duchess", "full": "Duchess Velveteen", "talent": "Ace Fashion Designer", "color": Color("c9a0dc"), "pitch": 1.10},
	"bramble":  {"name": "Bramble", "full": "Bramble Thistlewood", "talent": "Ace Gardener", "color": Color("7cb342"), "pitch": 1.05},
	"nibs":     {"name": "Nibs", "full": "Professor Nibs", "talent": "Ace Chemist", "color": Color("90a4ae"), "pitch": 0.95},
	"zuzu":     {"name": "Zuzu", "full": "Zuzu Byte", "talent": "Ace Hacker", "color": Color("26c6da"), "pitch": 1.20},
	"reginald": {"name": "Reginald", "full": "Sir Reginald Puddlesworth III", "talent": "Ace Fencer", "color": Color("e8c547"), "pitch": 0.80},
	"grub":     {"name": "Grub", "full": "Grub Pemberton", "talent": "Ace Chef", "color": Color("ff8a50"), "pitch": 0.85},
	"tumble":   {"name": "Tumble", "full": "Old Man Tumble", "talent": "Ace Napper", "color": Color("b0bec5"), "pitch": 0.70},
	"marigold": {"name": "Marigold", "full": "Marigold Fern", "talent": "Ace Nurse", "color": Color("81d4a8"), "pitch": 1.15},
	"fennel":   {"name": "Fennel", "full": "Fennel Dauber", "talent": "Ace Painter", "color": Color("ef5350"), "pitch": 1.00},
	"snapjaw":  {"name": "Snapjaw", "full": "Warden Snapjaw", "talent": "Mastermind", "color": Color("43a047"), "pitch": 0.75},
}

static func exists(id: String) -> bool:
	return CHARS.has(id)

static func display_name(id: String) -> String:
	return CHARS[id]["name"] if CHARS.has(id) else id.capitalize()

static func full_name(id: String) -> String:
	return CHARS[id]["full"] if CHARS.has(id) else id.capitalize()

static func talent(id: String) -> String:
	return CHARS[id]["talent"] if CHARS.has(id) else ""

static func color(id: String) -> Color:
	return CHARS[id]["color"] if CHARS.has(id) else Color.WHITE

static func pitch(id: String) -> float:
	return CHARS[id]["pitch"] if CHARS.has(id) else 1.0

## Living guests at trial time in the current chapter (everyone except the dead).
static func survivors() -> Array:
	var dead := Chapters.dead()
	var out := []
	for id in ORDER:
		if not dead.has(id):
			out.append(id)
	return out


## Guests alive when the current chapter starts (free time, title peeks...). Includes the victim.
static func alive_at_start() -> Array:
	var gone := Chapters.gone()
	var out := []
	for id in ORDER:
		if not gone.has(id):
			out.append(id)
	return out


## Spoiler-safe display order (see ROSTER), limited to guests alive when the chapter starts.
static func roster_alive() -> Array:
	var gone := Chapters.gone()
	var out := []
	for id in ROSTER:
		if not gone.has(id):
			out.append(id)
	return out

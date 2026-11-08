extends RefCounted
## Truth Drops (evidence). Icon art (optional) at res://art/props/clue_<id>.svg
## ORDER / REQUIRED are chapter 1; ORDER2 is chapter 2. Use order() / required() for the current chapter.

const Chapters := preload("res://scripts/data/chapters.gd")

const ORDER := [
	"rules", "snapjaw_file", "coco_watch", "cushion_edge", "bruno_headband",
	"marigold_account", "cracked_bucket", "garden_door", "sauna_log", "cape_thread",
	"living_statue", "lulu_glitter", "mannequin", "pepper_photo",
]

const REQUIRED := ORDER

const ORDER2 := [
	"rules2", "snapjaw_file2", "rounds_log", "lilac_thread", "grub_ghost", "anchor_doorstop",
	"boot_prints", "wax_lump", "bruno_boots", "duchess_shawl", "snore_alibi", "pepper_log",
	"tumble_bunk", "dictaphone",
]


static func order() -> Array:
	return ORDER2 if Chapters.current == 2 else ORDER


## Every Truth Drop of the current chapter is required.
static func required() -> Array:
	return order()

const CLUES := {
	"rules": {
		"name": "Resort Rules",
		"desc": "1. Guests may not leave the resort.\n2. Nighttime is 10:00 PM - 7:00 AM.\n3. The Bathhouse is locked during Nighttime. Snapjaw's sensors confirm nobody enters or exits it then.\n4. A killer who isn't caught at the Splash Trial gets to CHECK OUT.\n5. After a body is found: investigation, then a Splash Trial.\n6. No violence against Warden Snapjaw (he bites).",
	},
	"snapjaw_file": {
		"name": "Snapjaw File #1",
		"desc": "Victim: Captain Coco. Found in the Yuzu Bath at 7:00 AM. Cause of death: a single heavy blow to the back of the head; she fell into the water unconscious. Time of death: between 9:30 PM and 10:00 PM. No other injuries.",
	},
	"coco_watch": {
		"name": "Coco's Pocket Watch",
		"desc": "Coco's waterproof captain's watch. The glass is cracked from a hard impact, and the hands stopped at 9:47.",
	},
	"cushion_edge": {
		"name": "Cushioned Bath Edge",
		"desc": "Every rock around the Yuzu Bath is covered in thick foam safety cushions (\"SAFETY FIRST! - Snapjaw\"). There's nothing hard to hit your head on.",
	},
	"bruno_headband": {
		"name": "Bruno's Headband",
		"desc": "Bruno's red headband, found on the bath's edge right beside where Coco was floating. Bruno says he left it on his hook in the changing room before going into the sauna.",
	},
	"marigold_account": {
		"name": "Marigold's Account",
		"desc": "Walking back from the infirmary at about 9:56 PM, Marigold saw Bruno leave the bathhouse front door, red-faced and steaming. She saw no one else.",
	},
	"cracked_bucket": {
		"name": "Cracked Wooden Bucket",
		"desc": "A wooden bath bucket stuffed behind the changing-room lockers. Its rim is cracked and dented. The handle is speckled with sparkly SILVER-VIOLET glitter.",
	},
	"garden_door": {
		"name": "Garden Side Door",
		"desc": "A little-used side door in the changing room that opens onto the garden stone path. It can't be seen from the bathhouse's front entrance. Unlocked until Nighttime.",
	},
	"sauna_log": {
		"name": "Sauna Door Log",
		"desc": "The sauna's safety panel records every time its door opens. Last night: 9:28 PM and 9:56 PM. No other openings.",
	},
	"cape_thread": {
		"name": "Torn Violet Thread",
		"desc": "A strand of shiny violet silk embroidered with tiny silver stars, snagged on a rose bush along the garden path between the Lounge's back door and the bathhouse side door. Bramble pruned that bush at 9:00 PM - it wasn't there then.",
	},
	"living_statue": {
		"name": "The Living Statue",
		"desc": "Lulu, Bramble, Tumble and Fennel watched Wisp perform \"The Living Statue\" in the Lounge from 9:35 to 9:55 PM. The \"statue\" stood perfectly still behind a half-drawn curtain the whole time.",
	},
	"lulu_glitter": {
		"name": "Lulu's Glitter",
		"desc": "Pink glitter sprinkled on the front-row seat where Lulu sat. Lulu only ever uses her signature \"Bubblegum Pink\" glitter.",
	},
	"mannequin": {
		"name": "Gift-Shop Mannequin",
		"desc": "A capybara-sized display mannequin from Duchess's gift shop, found in the storage closet behind the Lounge stage. Silver-violet glitter on its shoulders. Duchess says it vanished from her display yesterday afternoon.",
	},
	"pepper_photo": {
		"name": "Pepper's Photo (9:46 PM)",
		"desc": "Pepper's flash photo of the Living Statue, taken from the Lounge doorway at 9:46 PM. A small white tag dangles from the statue's collar: \"GIFT SHOP - 4,800 yen\".",
	},
	# ------------------------------------------------------------------ chapter 2
	"rules2": {
		"name": "Mudlark Rules",
		"desc": "1. No leaving the resort. The Mudlark is your new home!\n2. Nighttime is 10:00 PM - 7:00 AM. The gangway is raised: nobody gets on or off.\n3. Cabin doors have no locks. Fire safety!\n4. A killer who isn't caught at the Splash Trial gets to CHECK OUT.\n5. After a body is found: investigation, then a Splash Trial.\n6. No violence against Warden Snapjaw (he still bites).",
	},
	"snapjaw_file2": {
		"name": "Snapjaw File #2",
		"desc": "Victim: Marigold Fern. Found on the infirmary floor at 7:00 AM by Grub. Cause of death: a single heavy blow to the back of the head. Time of death: between 10:00 PM and midnight. No other injuries.",
	},
	"rounds_log": {
		"name": "Marigold's Rounds Log",
		"desc": "Marigold's clipboard. \"10:30 Grub - tummy tonic.\" \"10:40 kettle on - Mr. Tumble's chamomile at 11:00 sharp!\" The last line trails off into a long ink smear.",
	},
	"lilac_thread": {
		"name": "Lilac Silk Scrap",
		"desc": "A small scrap of lilac silk lying on Marigold's cot. It's the same shade as the Duchess's shawl.",
	},
	"grub_ghost": {
		"name": "Grub's Ghost Story",
		"desc": "At 6:00 AM, on his way to the galley to bake, Grub saw a small hunched figure carrying \"a big trumpet thing\" slip into the purser's office in the dark. He's sure it was the ship's ghost.",
	},
	"anchor_doorstop": {
		"name": "Anchor Doorstop",
		"desc": "The infirmary's heavy brass anchor doorstop, found buried in the boiler room's coal pile. Coal dust in the fluke, wiped clean of anything else. Marigold said she could barely lift it.",
	},
	"boot_prints": {
		"name": "Giant Boot Prints",
		"desc": "Huge boot prints in the coal dust of the boiler room, from the door to the coal pile and back. They are oddly shallow, and the steps are very close together.",
	},
	"wax_lump": {
		"name": "Melted Wax Lump",
		"desc": "A blackened lump of melted wax in the furnace ash, with a small brass end-cap stuck in it. Bruno says it wasn't there when he banked the fire last night.",
	},
	"bruno_boots": {
		"name": "Bruno's Spare Boots",
		"desc": "Bruno's enormous spare boots on the laundry boot rack. Coal dust in the treads, and crumpled ship-issue socks stuffed deep into both toes. Bruno left them there clean to dry yesterday.",
	},
	"duchess_shawl": {
		"name": "Duchess's Shawl",
		"desc": "The Duchess's lilac shawl, hanging on the laundry line after the soup accident at dinner. One corner is missing, cut off in a perfectly straight line.",
	},
	"snore_alibi": {
		"name": "Tumble's Snoring",
		"desc": "From Cabin 1, Mochi heard Old Man Tumble snoring through the wall nonstop from 10:00 PM until about midnight. Then it suddenly stopped.",
	},
	"pepper_log": {
		"name": "Pepper's Snore Log",
		"desc": "Pepper timed Tumble's snoring from Cabin 3 with her stopwatch: the same squeaky little cough at 10:04, 10:08, 10:12, 10:16... exactly every 4 minutes, until the snoring stopped at midnight.",
	},
	"tumble_bunk": {
		"name": "Tumble's Bunk",
		"desc": "Tumble's bunk is neatly made and the pillow is perfectly smooth. In the rug beside it, close to the wall shared with Cabin 1, are four small round dents.",
	},
	"dictaphone": {
		"name": "Echo-Matic Dictaphone",
		"desc": "Snapjaw-brand wax-cylinder dictaphone in the purser's office. Plays 4-minute cylinders; one winding runs 2 hours. Its REPEAT lever is still ON, the spring is run down, and there's no cylinder inside. It stands on four little round feet.",
	},
}

static func clue_name(id: String) -> String:
	return CLUES[id]["name"] if CLUES.has(id) else id

static func desc(id: String) -> String:
	return CLUES[id]["desc"] if CLUES.has(id) else ""

extends RefCounted
## Truth Drops (evidence). Icon art (optional) at res://art/props/clue_<id>.svg

const ORDER := [
	"rules", "snapjaw_file", "coco_watch", "cushion_edge", "bruno_headband",
	"marigold_account", "cracked_bucket", "garden_door", "sauna_log", "cape_thread",
	"living_statue", "lulu_glitter", "mannequin", "pepper_photo",
]

const REQUIRED := ORDER

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
}

static func clue_name(id: String) -> String:
	return CLUES[id]["name"] if CLUES.has(id) else id

static func desc(id: String) -> String:
	return CLUES[id]["desc"] if CLUES.has(id) else ""

extends RefCounted
## Truth Drops (evidence). Icon art (optional) at res://art/props/clue_<id>.svg
## ORDER / REQUIRED are chapter 1; ORDER2 is chapter 2; ORDER3 (required) and OPTIONAL3 (can be missed) are chapter 3,
## with TRIAL3 (handed over in the trial) and STORY3 (the Day 4 Tribunal's). Use order() / required() for the current chapter.
## Case 3 entries list "about": the guests a Drop concerns, for tools/check_depth.py's evidence balance only (never shown).
## Descriptions say what's there, never what it means.
## A Truth Drop may list pictures: "images": [{"art": <prop or bg name, or res:// path>, "stamp": <caption>}],
## opened in the evidence viewer (scripts/ui/evidence_viewer.gd).

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

## Chapter 3. Five come from the story before the body (rules3 on Day 1; the rest are written up at the start of the
## investigation, story_case3.gd "investigation_start", and listed in chapters.gd "inv_start_clues" so no stage counts
## them); the other 29 are found by hand, in three stages (investigation_data3.gd STAGES).
const ORDER3 := [
	"rules3", "snapjaw_file3", "ledger_read", "bat_bite", "grub_soup",
	"fallen_bookcase", "wall_anchor", "cup_ring", "desk_contents", "nibs_blotter", "arm_no_bruise", "nibs_mouth",
	"door_scratches",
	"tray_grains", "bell_tape", "pantry_glitter", "old_puddle", "manual_injuries", "manual_illness", "powder_record",
	"lulu_tin", "bait_tin", "generator_log", "fitting_ticket",
	"passage_door", "passage_tracks", "shawl_hem", "hat_feather", "pen_case", "shaft_pen", "gallery_clock",
	"dinner_sketch", "photo_roll", "gallery_grate",
]

## Chapter 3's Drops that are found but not needed: a few that back up an alibi, the hidden Ledger pages, and five
## curios that look like they matter.
const OPTIONAL3 := [
	"packet_log", "conservatory_sketch", "watch_roster", "terrace_mud",
	"ledger_terrace", "ledger_hall", "ledger_dining", "ledger_kitchen", "ledger_music", "ledger_library", "ledger_wing",
	"burned_glove", "painted_page", "dead_camera", "moustache_wax", "music_box",
]

## Chapter 3's Drops that nobody can find in the investigation: guests hand them over in the trial (story_case3.gd
## "trial"). Not required, so the investigation never asks for them, never grants them and never counts them.
const TRIAL3 := ["nibs_cup", "nibs_sheet", "scene_photos"]

## Chapter 3's daily story hands these out for the Tea-Time Tribunal on Day 4 (story_daily3.gd "day4",
## story_minigames3.gd). They stay in the notebook, but they're not part of the murder case: neither required nor
## optional, so the investigation's counts, stages and checks never see them.
const STORY3 := ["night3_ash", "night3_rug", "night3_desk"]
const REQUIRED_BY_CHAPTER := {1: ORDER, 2: ORDER2, 3: ORDER3}
const OPTIONAL_BY_CHAPTER := {3: OPTIONAL3}
const TRIAL_BY_CHAPTER := {3: TRIAL3}
const STORY_BY_CHAPTER := {3: STORY3}


## Every Truth Drop of the current chapter: the required ones, then the optional ones.
static func order() -> Array:
	return required() + (OPTIONAL_BY_CHAPTER.get(Chapters.current, []) as Array)


## The Truth Drops the current chapter's investigation cannot end without.
static func required() -> Array:
	return REQUIRED_BY_CHAPTER.get(Chapters.current, ORDER)


## Every Truth Drop the current chapter has anywhere: order(), the ones the trial hands over and the daily story's.
## For debug runs that start late (main.gd _give_all_clues).
static func everything() -> Array:
	return order() + (TRIAL_BY_CHAPTER.get(Chapters.current, []) as Array) + (STORY_BY_CHAPTER.get(Chapters.current, []) as Array)

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
	# ------------------------------------------------------------------ chapter 3 (Warden's Rest)
	"rules3": {
		"name": "Warden's Rest Rules",
		"desc": "1. No leaving the island.\n2. Nighttime: 10 PM - 7 AM. Nobody outdoors (the terrace counts as in).\n3. Bedroom doors lock from the inside.\n4. A killer who isn't caught at the Splash Trial gets to CHECK OUT.\n5. A body means an investigation, then a Splash Trial.\n6. No violence against Warden Snapjaw (he bites).\n7. Aftershocks are posted on the board a day ahead. I am punctual.\n8. A body means pockets out at the door, and every camera to my darkroom.",
	},
	"snapjaw_file3": {
		"name": "Snapjaw File #3",
		"desc": "Victim: Professor Nibs. Found in the Library at 7:00 AM, at his desk, under the tall bookcase. The door had to be broken in. Time of death: between 9:30 PM and midnight. Cause of death: \"Check your rule book!\" The rest of the page is a drawing of a bookcase.",
		"about": [],
	},
	# automatic: things Mochi saw in the days before, written up at the start of the investigation
	"ledger_read": {
		"name": "The Ledger, Read Aloud",
		"desc": "Day 3, breakfast. Snapjaw read four lines of the Ledger aloud: Plum Velveteen, on information from Prof. N. The Dowager Puddlesworth, from Prof. N. Ada Byte, from Pepper Q. Miss Pip, from B. Thistlewood. The entries are typed small and neat; the names in blacker, squarer type. He says some lines are forged.",
		"about": ["duchess", "reginald", "pepper", "zuzu", "bramble", "lulu"],
	},
	"grub_soup": {
		"name": "The Evening Soup",
		"desc": "Day 5, 4:30 PM, the kitchen. The ladle rattled against the pot; Grub couldn't keep it still. He lifted it to taste and couldn't put it in his mouth, so I tasted it for him. He salted the pot three times. He watched the water jug the whole time I held it.",
		"about": ["grub"],
	},
	"bat_bite": {
		"name": "Bat Bites",
		"desc": "Day 1, the Wine Cellar. Snapjaw's \"improved\" bats bit three of us on the paw: Grub, Zuzu and Reginald. Bruno bandaged Grub and Zuzu. Reginald bandaged himself. Nibs said bat bites are mostly harmless.",
		"about": ["grub", "zuzu", "reginald"],
	},
	# stage 1: the Library and the Grand Hall
	"fallen_bookcase": {
		"name": "The Tall Bookcase",
		"desc": "The tall bookcase that stood behind the desk lies face down across it. Its base is a foot out from the wall. Behind the base, two pale scrape marks run across the floorboards from the skirting.",
		"about": [],
	},
	"wall_anchor": {
		"name": "The Wall Brace",
		"desc": "High on the wall where the bookcase stood: the outline of an iron brace plate, and two clean screw holes with no splinters round them. Up on the cornice ledge, under the white dust, six screws lie side by side in a row.",
		"about": [],
	},
	"cup_ring": {
		"name": "Side Table by the Hatch",
		"desc": "The side table by the dumbwaiter hatch is filmed with white dust. In the dust there's one clean ring, the size of a teacup's foot. There is no cup on the table.",
		"about": [],
	},
	"desk_contents": {
		"name": "Things on the Desk",
		"desc": "On the desk: the blotter, an inkstand with two wells, the lamp (still on), his spectacles, a ruler, three books on typefaces, a magnifying glass, loose notes, a saucer of paper clips. Under it: his slippers. On the floor across the room, by the hatch: one plain black pen, smooth end to end.",
		"about": [],
	},
	"nibs_blotter": {
		"name": "Desk Blotter",
		"desc": "Read backwards, what soaked through into the blotter: \"4:30 out. Tide.\" \"5:40 back. Shelf rocks. Tell Bruno.\" Then lines of working notes in a steady hand, with times down the margin, the last one 10:05. No line with a result.",
		"about": ["bruno"],
	},
	"arm_no_bruise": {
		"name": "The Broken Arm",
		"desc": "His right arm is pinned under the edge of the bookcase, broken, bent where an arm doesn't bend. Round the break the fur lies flat and the skin underneath is pale. No swelling. No bruise.",
		"about": [],
	},
	"nibs_mouth": {
		"name": "Tongue and Teeth",
		"desc": "His tongue and his front teeth are stained dark, nearly black. His lips are dry. He chewed his pens; his teeth were always a bit inky.",
		"about": [],
	},
	"door_scratches": {
		"name": "Scratches on the Door",
		"desc": "The outside of the Library door, low down: fresh scratches through the varnish, in rows of four, from the floor to about knee height. Little curls of varnish on the carpet under them.",
		"about": ["grub"],
	},
	# stage 2: the kitchens, the cellar, the wreck, the generator, the rest of the house
	"tray_grains": {
		"name": "Tray in the Dumbwaiter",
		"desc": "In the dumbwaiter car at the Library end, behind the hatch: a tray with a teapot and a milk jug, and a space for a cup. The tea in the pot is cold. Pale grains have settled in the bottom of the pot, and a few lie spilled on the tray.",
		"about": ["lulu", "grub"],
	},
	"bell_tape": {
		"name": "Dumbwaiter Bell Tape",
		"desc": "The dumbwaiter's bell in the pantry punches a hole in a paper tape every time the car goes up. Snapjaw's label: \"NEW TAPE EVERY EVENING AT SIX.\" Since six last night, one hole.",
		"about": ["lulu", "grub"],
	},
	"pantry_glitter": {
		"name": "Hatch Rope",
		"desc": "The dumbwaiter rope at the pantry hatch, at paw height: a few specks of bright pink glitter caught in the fibres.",
		"about": ["lulu"],
	},
	"old_puddle": {
		"name": "Pantry Shelf Paper",
		"desc": "The pantry shelves are lined with old newspaper. Under the flour tins: a Daily Puddle, Island Edition, from Day 2, back when it was typed. Every small e in it has the same tiny nick out of the top of its curve.",
		"about": ["pepper"],
	},
	"manual_injuries": {
		"name": "Nurse's Manual: Injuries",
		"desc": "Marigold's nursing manual from the Mudlark, the chapter on broken bones: \"In the living, a broken limb swells and bruises within the hour. A bone broken after death will neither swell nor bruise.\"",
		"about": [],
	},
	"manual_illness": {
		"name": "Nurse's Manual: Bites",
		"desc": "The same manual, a page with its corner turned down: \"Bites from bats. Rare, slow and serious. Days or weeks later: fever, itching at the bite, restlessness, lost hours, trembling paws, drooling, and a horror of water, so that the patient cannot bear to drink.\"",
		"about": ["grub"],
	},
	"powder_record": {
		"name": "Dose Card",
		"desc": "Taped inside the infirmary cabinet door, in Marigold's round hand: \"Sleeping powder (Duchess V., her own tin). 1 pinch: a good night. 2 pinches: sleeps through anything, 8 to 10 hours. Never more than 3. A whole tin would stop a heart.\"",
		"about": ["duchess"],
	},
	"lulu_tin": {
		"name": "Silver Powder Tin",
		"desc": "In Marigold's locker in the wreck: her cap, her scissors, her book, and a little silver tin of sleeping powder with a V on the lid. Nearly full. In the smooth top of the powder, two small dents side by side. A fleck of pink glitter on the lid.",
		"about": ["lulu", "duchess"],
	},
	"bait_tin": {
		"name": "Rat-Bait Paste",
		"desc": "Snapjaw-brand rat-bait tins, set out in the Wine Cellar, the Conservatory and the Attic since Day 2. Label: a grinning rat with crosses for eyes. \"SURE-SHOT PASTE. Smells of aniseed! Rats can't resist! Acts in one to two hours. Not for capybaras (mostly).\"",
		"about": ["bramble"],
	},
	"generator_log": {
		"name": "Generator Log",
		"desc": "The Generator Room log, last night, in big square capitals: \"B. 9:30. ON.\" A tick every quarter of an hour after that. The last line: \"STOPPED 11:05.\" Under it, in careful copperplate: \"Witnessed, R. Puddlesworth.\" No other names.",
		"about": ["bruno", "reginald"],
	},
	"fitting_ticket": {
		"name": "Fitting Ticket",
		"desc": "Pinned to the dress form in the Music Room, in the Duchess's hand: \"Fitting. L. Starling. 10:30 PM, one hour.\" On the gown, the pins go along half the hem in a neat line, then the rest are stuck in crooked and close together.",
		"about": ["duchess", "lulu"],
	},
	# stage 3: the Gallery, the Attic, the Plover Room, the servants' passage
	"passage_door": {
		"name": "Door Behind the Tapestry",
		"desc": "Behind the Library tapestry, a narrow door into a passage inside the wall, 80 cm across. Bruno tried it and stuck at the shoulders. No bolt on either side. On the floor inside, white limewash from the ceiling lies over everything.",
		"about": ["duchess"],
	},
	"passage_tracks": {
		"name": "Prints in the Passage",
		"desc": "In the passage, white limewash lies over an older film of grey dust. One set of prints goes along it, there and back, each print pressed through the white to the grey. Between the prints, the grey under the white is smooth.",
		"about": ["duchess"],
	},
	"shawl_hem": {
		"name": "Line in the Dust",
		"desc": "Beside the prints in the passage, a wide, smooth line drawn through the white dust, as if something soft trailed along the floor. Three lilac silk threads caught on a splinter of the skirting.",
		"about": ["duchess"],
	},
	"hat_feather": {
		"name": "Snapped Feather",
		"desc": "On the iron bracket above the passage door at the Library end, high up: a long lilac ostrich feather, snapped in half.",
		"about": ["duchess"],
	},
	"pen_case": {
		"name": "Case of Old Pens",
		"desc": "On the mantel in his bedroom, locked until Snapjaw opened it with the key from his pocket: an open case lined with red felt, his old pens laid in a row. Every one is chewed at the end, some to splinters. A label inside the lid: \"RETIRED.\"",
		"about": [],
	},
	"shaft_pen": {
		"name": "Bottom of the Shaft",
		"desc": "At the bottom of the dumbwaiter shaft, under the pantry hatch, in a black muck of old crumbs and grease: one pen, chewed to splinters at the end. It stinks of the shaft.",
		"about": [],
	},
	"gallery_clock": {
		"name": "Gallery Mantel Clock",
		"desc": "The Gallery's mantel clock lies on the hearth where the aftershock threw it, glass cracked. The hands stopped at 11:05. A brass plate on the back: \"Wound and set by the Warden, daily, to the second.\"",
		"about": ["pepper"],
	},
	"dinner_sketch": {
		"name": "Dinner Sketches",
		"desc": "Fennel's strip of little charcoal sketches of dinner, Day 5, with the Dining Room clock in every one. 8:05: Nibs at the roster, pen in his teeth. Then a square each time a chair was empty: 8:30, 8:40, 8:50, 9:05, and Grub's four times. 9:15: Nibs at the door in his coat, pen in his mouth.",
		"about": ["fennel", "bramble", "reginald", "lulu", "pepper", "zuzu", "grub"],
	},
	"photo_roll": {
		"name": "Roll in the Darkroom",
		"desc": "Pepper's own earlier roll, developed in the Gallery darkroom and pegged up to dry. Two frames of the Gallery, stamped 8:52 and 9:00. Then four flash frames of the Gallery in the dark, stamped 11:06 to 11:18.",
		"about": ["pepper"],
		"images": [
			{"art": "res://art/evidence/c3_roll_1.jpg", "stamp": "Stamped 8:52 PM"},
			{"art": "res://art/evidence/c3_roll_2.jpg", "stamp": "Stamped 9:00 PM"},
			{"art": "res://art/evidence/c3_roll_3.jpg", "stamp": "Stamped 11:06 PM"},
			{"art": "res://art/evidence/c3_roll_4.jpg", "stamp": "Stamped 11:09 PM"},
			{"art": "res://art/evidence/c3_roll_5.jpg", "stamp": "Stamped 11:13 PM"},
			{"art": "res://art/evidence/c3_roll_6.jpg", "stamp": "Stamped 11:18 PM"},
		],
	},
	"gallery_grate": {
		"name": "Gallery Grate",
		"desc": "The Gallery grate holds a thick cake of ash, many sheets' worth, far more than on Night 3. The fire was never lit. One corner didn't burn: a scrap of a typed line, \"...over the lazy cai\".",
		"about": ["pepper", "zuzu"],
	},
	# delivered in the trial
	"nibs_cup": {
		"name": "The Teacup",
		"desc": "The cup from the Library side table, wrapped in a lilac handkerchief. A little cold tea in the bottom. It smells sweet, like violets, the way the Duchess's sleeping powder does. Nothing else.",
		"about": ["duchess", "lulu"],
	},
	"nibs_sheet": {
		"name": "Top Sheet of His Notes",
		"desc": "The top sheet from his desk, times down the margin. \"Entries: one face, nicked e. Names: another face, the prison office machine. Two machines. Ask G. for his shelf paper.\" \"9:58 Tea tastes of powder. Bless them. Not drinking that.\" Last line: \"10:14 Tongue numb. Pen tastes of liquorice.\"",
		"about": ["duchess", "grub"],
	},
	"scene_photos": {
		"name": "The 7 AM Roll",
		"desc": "Pepper's roll from the Library at seven this morning, printed in Snapjaw's darkroom: sixteen frames, numbered, each with her camera's time stamp.",
		"about": ["zuzu", "bruno", "reginald", "lulu", "fennel", "grub", "pepper"],
		"images": [
			{"art": "res://art/evidence/c3_frame_01.jpg", "stamp": "No. 1   7:02 AM"},
			{"art": "res://art/evidence/c3_frame_02.jpg", "stamp": "No. 2   7:02 AM"},
			{"art": "res://art/evidence/c3_frame_03.jpg", "stamp": "No. 3   7:02 AM"},
			{"art": "res://art/evidence/c3_frame_04.jpg", "stamp": "No. 4   7:03 AM"},
			{"art": "res://art/evidence/c3_frame_05.jpg", "stamp": "No. 5   7:03 AM"},
			{"art": "res://art/evidence/c3_frame_06.jpg", "stamp": "No. 6   7:03 AM"},
			{"art": "res://art/evidence/c3_frame_07.jpg", "stamp": "No. 7   7:03 AM"},
			{"art": "res://art/evidence/c3_frame_08.jpg", "stamp": "No. 8   7:04 AM"},
			{"art": "res://art/evidence/c3_frame_09.jpg", "stamp": "No. 9   7:04 AM"},
			{"art": "res://art/evidence/c3_frame_10.jpg", "stamp": "No. 10   7:04 AM"},
			{"art": "res://art/evidence/c3_frame_11.jpg", "stamp": "No. 11   7:04 AM"},
			{"art": "res://art/evidence/c3_frame_12.jpg", "stamp": "No. 12   7:05 AM"},
			{"art": "res://art/evidence/c3_frame_13.jpg", "stamp": "No. 13   7:05 AM"},
			{"art": "res://art/evidence/c3_frame_14.jpg", "stamp": "No. 14   7:05 AM"},
			{"art": "res://art/evidence/c3_frame_15.jpg", "stamp": "No. 15   7:06 AM"},
			{"art": "res://art/evidence/c3_frame_16.jpg", "stamp": "No. 16   7:06 AM"},
		],
	},
	# optional: found but not needed
	"packet_log": {
		"name": "Screen in the Attic",
		"desc": "Zuzu's corner of the Attic: a screen spliced into the camera wiring. Its log starts at 9:48 PM and runs all night, a line every few seconds, typed commands, until 6:51 AM. It's in the dark during the blackout and picks up again at 11:20.",
		"about": ["zuzu"],
	},
	"conservatory_sketch": {
		"name": "Moonflower Drawing",
		"desc": "On the easel in the Conservatory: a charcoal drawing of moonflowers half open, and Bramble asleep in the wicker chair beside them. In the corner: \"Night 5. 10:40. She snores.\"",
		"about": ["fennel", "bramble"],
	},
	"watch_roster": {
		"name": "Watch Roster",
		"desc": "The watch roster on its clipboard by the Dining Room door. Five nights of R. PUDDLESWORTH down the watch column. On every dinner line, in round, cheerful handwriting: Prof. N. Last night's: \"Prof. N. 8:05.\"",
		"about": ["reginald"],
	},
	"terrace_mud": {
		"name": "Planter by the Telescope",
		"desc": "Boot prints in the damp earth of the planter next to the telescope, pointing at the parapet, and a ring of lantern soot on the stone. The telescope is aimed at the west wing of the Gaol.",
		"about": ["reginald"],
	},
	"ledger_terrace": {
		"name": "Ledger Page No. 207",
		"desc": "A page torn out of the Ledger, under a planter on the terrace. \"No. 207. Hawthorn Thistlewood, nurseryman. Held for: growing a rose of an unregistered colour.\" Underneath, in blacker, squarer type: \"On information from: F. Dauber.\"",
		"about": ["bramble", "fennel"],
	},
	"ledger_hall": {
		"name": "Ledger Page No. 88",
		"desc": "A page torn out of the Ledger, behind a portrait frame in the Grand Hall. \"No. 88. Augustus Pica, newspaper editor. Held for: printing a correction.\" Underneath, in blacker, squarer type: \"On information from: Z. Byte.\"",
		"about": ["pepper", "zuzu"],
	},
	"ledger_dining": {
		"name": "Ledger Page No. 151",
		"desc": "A page torn out of the Ledger, behind the still life in the Dining Room. \"No. 151. Mrs. Hetty Pemberton, cook. Held for: seasoning without a licence.\" Underneath, in blacker, squarer type: \"On information from: R. Puddlesworth.\"",
		"about": ["grub", "reginald"],
	},
	"ledger_kitchen": {
		"name": "Ledger Page No. 236",
		"desc": "A page torn out of the Ledger, behind the framed menu in the kitchen. \"No. 236. Sesame, nine years old, student of the dojo. Held for: throwing a grown-up in a public park.\" Underneath, in blacker, squarer type: \"On information from: G. Pemberton.\"",
		"about": ["bruno", "grub"],
	},
	"ledger_music": {
		"name": "Ledger Page No. 174",
		"desc": "A page torn out of the Ledger, behind the still life by the Music Room door. \"No. 174. Saffron Dauber, painter of miniatures. Held for: an unflattering likeness of a public figure.\" Underneath, in blacker, squarer type: \"On information from: L. Starling.\"",
		"about": ["fennel", "lulu"],
	},
	"ledger_library": {
		"name": "Ledger Page No. 192",
		"desc": "A page torn out of the Ledger, between two books in the Library. \"No. 192. Fizz Bracken, laboratory assistant. Held for: a small explosion, Tuesday.\" Underneath, in blacker, squarer type: \"On information from: D. Velveteen.\" Folded once and unfolded again.",
		"about": ["duchess"],
	},
	"ledger_wing": {
		"name": "Ledger Page No. 9",
		"desc": "A page torn out of the Ledger, pushed under the runner in the Bedroom Wing. \"No. 9. Mrs. Mochi, the elder. Held for: running a bathhouse without a sign.\" The bottom of the page, where the informer's name would be, is torn off.",
		"about": [],
	},
	"burned_glove": {
		"name": "Burned Glove",
		"desc": "In the little stove under the Conservatory's potting bench: a gardening glove, half burned. The fingers that didn't burn are stiff with something greyish, and smell of aniseed.",
		"about": ["bramble"],
	},
	"painted_page": {
		"name": "Little Seascape",
		"desc": "Propped on the Gallery window seat to dry: a little seascape in oils, painted on the back of a typed sheet. Held up to the window, typing shows through backwards: \"No. 313 ... On information from: B. Thist...\" The rest is under the paint.",
		"about": ["fennel", "bramble"],
	},
	"dead_camera": {
		"name": "Camera in the Rafters",
		"desc": "One of Snapjaw's cameras up in the Attic rafters, its red eye dark. Its wires have been cut neatly and twisted back, and a strip of black tape wound over the lens.",
		"about": ["zuzu"],
	},
	"moustache_wax": {
		"name": "Tin of Wax",
		"desc": "On the cloakroom shelf above the coat hooks: a small tin of moustache wax, lid off, a claw-scoop dug out of it. It smells of bergamot.",
		"about": ["reginald"],
	},
	"music_box": {
		"name": "Music Box",
		"desc": "A music box on the Music Room shelf. Wound, it plays three notes and stops. Under the little dancer, folded small: a child's drawing of a capybara in an enormous hat, signed \"Plum, age 6\".",
		"about": ["duchess"],
	},
	# a test fixture (scripts/data/trial_data_test.gd): in no chapter's lists
	"t_pictures": {
		"name": "Test Pictures",
		"desc": "Test fixture: a Truth Drop with pictures.",
		"images": [
			{"art": "lobby", "stamp": "Test picture 1"},
			{"art": "dining", "stamp": "Test picture 2"},
			{"art": "kitchen", "stamp": "Test picture 3"},
		],
	},
	# ------------------------------------------------------------------ chapter 3, the Tea-Time Tribunal (STORY3)
	"night3_ash": {
		"name": "Gallery Grate, Night 3",
		"desc": "Night 3, the Gallery fireplace: one sheet burned to ash. One corner didn't catch: half a name in black, square type, ...ISTLEWOOD. The fire was never lit. Only the page burned.",
	},
	"night3_rug": {
		"name": "Gallery Hearth Rug",
		"desc": "The rug in front of the Gallery grate, the morning after Night 3. Ash puffed out over it in a grey fan. Bright pink glitter lies on top of the ash, and nowhere else on the rug.",
	},
	"night3_desk": {
		"name": "Library Desk, Night 3",
		"desc": "Where the folder of samples sat: a clean square on the blotter, the lamp still on, a cold cup of cocoa. The Library door bolts from the inside. Nothing is broken.",
	},
}

static func clue_name(id: String) -> String:
	return CLUES[id]["name"] if CLUES.has(id) else id

static func desc(id: String) -> String:
	return CLUES[id]["desc"] if CLUES.has(id) else ""

## The pictures a Truth Drop opens in the evidence viewer ([] if none).
static func images(id: String) -> Array:
	return CLUES[id].get("images", []) if CLUES.has(id) else []

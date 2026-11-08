extends RefCounted
## Chapter 2 investigation rooms (the Mudlark). Same format as investigation_data.gd (see its header).
## Hotspot / talk scripts are story ids in story/story_case2.gd. Spoilers: docs/DESIGN2.md §7.

const START_ROOM := "infirmary"
const ROOM_ORDER := ["infirmary", "boiler", "laundry", "hall", "tumble_cabin", "purser"]
const SLOT_X := {"left": 170.0, "right": 1110.0}
const PERSON_SCALE := 0.62

const ROOMS := {
	"infirmary": {
		"name": "Infirmary", "bg": "ship_infirmary_body", "enter_script": "inv2_enter_infirmary",
		"hotspots": [
			{"id": "body", "label": "Marigold", "rect": [440, 440, 380, 140], "script": "inv2_infirmary_body"},
			{"id": "cot", "label": "Cot", "rect": [560, 260, 330, 130], "script": "inv2_infirmary_cot"},
			{"id": "log", "label": "Rounds log", "rect": [370, 140, 110, 140], "script": "inv2_infirmary_log"},
			{"id": "kettle", "label": "Kettle", "rect": [370, 320, 130, 110], "script": "inv2_infirmary_kettle"},
			{"id": "door", "label": "Door", "rect": [880, 140, 90, 320], "script": "inv2_infirmary_door"},
		],
		"people": [
			{"char": "grub", "slot": "left", "expr": "sad", "script": "inv2_talk_grub"},
			{"char": "nibs", "slot": "right", "expr": "normal", "script": "inv2_talk_nibs"},
		],
	},
	"boiler": {
		"name": "Boiler Room", "bg": "ship_boiler", "enter_script": "inv2_enter_boiler",
		"hotspots": [
			{"id": "coal", "label": "Coal pile", "rect": [360, 360, 260, 200], "script": "inv2_boiler_coal"},
			{"id": "prints", "label": "Boot prints", "rect": [560, 590, 340, 100], "script": "inv2_boiler_prints"},
			{"id": "furnace", "label": "Furnace", "rect": [680, 140, 240, 260], "script": "inv2_boiler_furnace"},
			{"id": "gauges", "label": "Pressure gauges", "rect": [420, 130, 160, 120], "script": "inv2_boiler_gauges"},
		],
		"people": [
			{"char": "bruno", "slot": "left", "expr": "sad", "script": "inv2_talk_bruno"},
			{"char": "reginald", "slot": "right", "expr": "angry", "script": "inv2_talk_reginald"},
		],
	},
	"laundry": {
		"name": "Laundry", "bg": "ship_laundry", "enter_script": "inv2_enter_laundry",
		"hotspots": [
			{"id": "rack", "label": "Boot rack", "rect": [380, 430, 220, 160], "script": "inv2_laundry_rack"},
			{"id": "line", "label": "Drying line", "rect": [420, 110, 460, 200], "script": "inv2_laundry_line"},
			{"id": "basket", "label": "Sewing basket", "rect": [660, 470, 160, 110], "script": "inv2_laundry_basket"},
			{"id": "tubs", "label": "Wash tubs", "rect": [800, 330, 140, 120], "script": "inv2_laundry_tubs"},
		],
		"people": [
			{"char": "bramble", "slot": "left", "expr": "sad", "script": "inv2_talk_bramble"},
			{"char": "duchess", "slot": "right", "expr": "angry", "script": "inv2_talk_duchess"},
		],
	},
	"hall": {
		"name": "Cabin Corridor", "bg": "ship_hall", "enter_script": "inv2_enter_hall",
		"hotspots": [
			{"id": "door1", "label": "Cabin 1 (yours)", "rect": [370, 180, 150, 310], "script": "inv2_hall_door1"},
			{"id": "door2", "label": "Cabin 2 (Tumble)", "rect": [560, 160, 160, 330], "script": "inv2_hall_door2"},
			{"id": "door3", "label": "Cabin 3 (Pepper)", "rect": [760, 180, 150, 310], "script": "inv2_hall_door3"},
			{"id": "tube", "label": "Speaking tube", "rect": [490, 70, 70, 80], "script": "inv2_hall_tube"},
		],
		"people": [
			{"char": "lulu", "slot": "left", "expr": "sad", "script": "inv2_talk_lulu"},
			{"char": "pepper", "slot": "right", "expr": "normal", "script": "inv2_talk_pepper"},
		],
	},
	"tumble_cabin": {
		"name": "Tumble's Cabin", "bg": "ship_tumble_cabin", "enter_script": "inv2_enter_tumble_cabin",
		"hotspots": [
			{"id": "bunk", "label": "Bunk & rug", "rect": [400, 330, 440, 330], "script": "inv2_tumble_cabin_bunk"},
			{"id": "nightstand", "label": "Nightstand", "rect": [850, 360, 100, 150], "script": "inv2_tumble_cabin_nightstand"},
			{"id": "porthole", "label": "Porthole", "rect": [560, 120, 140, 140], "script": "inv2_tumble_cabin_porthole"},
			{"id": "nightcap", "label": "Nightcap", "rect": [380, 120, 110, 140], "script": "inv2_tumble_cabin_nightcap"},
		],
		"people": [
			{"char": "tumble", "slot": "left", "expr": "normal", "script": "inv2_talk_tumble"},
		],
	},
	"purser": {
		"name": "Purser's Office", "bg": "ship_purser", "enter_script": "inv2_enter_purser",
		"hotspots": [
			{"id": "dictaphone", "label": "Dictaphone", "rect": [560, 300, 200, 200], "script": "inv2_purser_dictaphone"},
			{"id": "rack", "label": "Cylinder rack", "rect": [370, 130, 170, 210], "script": "inv2_purser_rack"},
			{"id": "safe", "label": "Safe", "rect": [800, 330, 140, 180], "script": "inv2_purser_safe"},
			{"id": "armchair", "label": "Armchair", "rect": [380, 420, 160, 170], "script": "inv2_purser_armchair"},
		],
		"people": [
			{"char": "zuzu", "slot": "left", "expr": "normal", "script": "inv2_talk_zuzu"},
			{"char": "fennel", "slot": "right", "expr": "normal", "script": "inv2_talk_fennel"},
		],
	},
}

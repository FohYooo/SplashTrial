extends RefCounted
## Investigation rooms. Coordinates are in the 1280x720 game space.
## rect = [x, y, w, h]. The background art draws the matching object INSIDE each rect.
## People stand in slots: "left" (center x=170) or "right" (center x=1110), drawn as their
## portrait at 0.62 scale, bottom-anchored at y=720 (occupying roughly y 348..720).
## Hotspot scripts / talk scripts are story ids in story/story_case.gd.
## The investigation screen sets flag "seen_<script id>" after a script finishes once, so
## scripts can branch with `@if seen_<id> -> again`.

const START_ROOM := "bath"
const ROOM_ORDER := ["bath", "changing", "sauna", "garden", "lounge", "storage", "giftshop", "dining"]
const SLOT_X := {"left": 170.0, "right": 1110.0}
const PERSON_SCALE := 0.62

const ROOMS := {
	"bath": {
		"name": "Yuzu Bath", "bg": "bath_body", "enter_script": "inv_enter_bath",
		"hotspots": [
			{"id": "body", "label": "Captain Coco", "rect": [470, 380, 340, 140], "script": "inv_bath_body"},
			{"id": "cushion", "label": "Foam cushions", "rect": [340, 540, 240, 100], "script": "inv_bath_cushion"},
			{"id": "headband", "label": "Red headband", "rect": [700, 560, 140, 70], "script": "inv_bath_headband"},
			{"id": "yuzu", "label": "Floating yuzu", "rect": [380, 300, 110, 60], "script": "inv_bath_yuzu"},
			{"id": "lantern", "label": "Stone lantern", "rect": [880, 120, 90, 180], "script": "inv_bath_lantern"},
		],
		"people": [
			{"char": "marigold", "slot": "right", "expr": "sad", "script": "inv_talk_marigold"},
			{"char": "bruno", "slot": "left", "expr": "sad", "script": "inv_talk_bruno"},
		],
	},
	"changing": {
		"name": "Changing Room", "bg": "changing", "enter_script": "inv_enter_changing",
		"hotspots": [
			{"id": "lockers", "label": "Lockers", "rect": [60, 110, 400, 430], "script": "inv_changing_lockers"},
			{"id": "buckets", "label": "Bucket stack", "rect": [520, 430, 200, 150], "script": "inv_changing_buckets"},
			{"id": "hooks", "label": "Coat hooks", "rect": [520, 140, 240, 110], "script": "inv_changing_hooks"},
			{"id": "side_door", "label": "Side door", "rect": [790, 110, 160, 400], "script": "inv_changing_side_door"},
		],
		"people": [
			{"char": "reginald", "slot": "right", "expr": "angry", "script": "inv_talk_reginald"},
		],
	},
	"sauna": {
		"name": "Sauna", "bg": "sauna", "enter_script": "inv_enter_sauna",
		"hotspots": [
			{"id": "panel", "label": "Door panel", "rect": [820, 160, 120, 160], "script": "inv_sauna_panel"},
			{"id": "benches", "label": "Benches", "rect": [340, 420, 520, 200], "script": "inv_sauna_benches"},
			{"id": "stove", "label": "Sauna stove", "rect": [500, 140, 200, 220], "script": "inv_sauna_stove"},
		],
		"people": [
			{"char": "zuzu", "slot": "left", "expr": "normal", "script": "inv_talk_zuzu"},
			{"char": "nibs", "slot": "right", "expr": "normal", "script": "inv_talk_nibs"},
		],
	},
	"garden": {
		"name": "Garden Path", "bg": "garden", "enter_script": "inv_enter_garden",
		"hotspots": [
			{"id": "rosebush", "label": "Rose bush", "rect": [520, 300, 240, 200], "script": "inv_garden_rosebush"},
			{"id": "path", "label": "Stone path", "rect": [380, 520, 520, 180], "script": "inv_garden_path"},
			{"id": "lounge_door", "label": "Lounge back door", "rect": [340, 160, 140, 250], "script": "inv_garden_lounge_door"},
			{"id": "bath_door", "label": "Bathhouse side door", "rect": [800, 160, 140, 250], "script": "inv_garden_bath_door"},
		],
		"people": [
			{"char": "bramble", "slot": "left", "expr": "sad", "script": "inv_talk_bramble"},
		],
	},
	"lounge": {
		"name": "Lounge", "bg": "lounge", "enter_script": "inv_enter_lounge",
		"hotspots": [
			{"id": "stage", "label": "Stage & curtain", "rect": [430, 120, 420, 320], "script": "inv_lounge_stage"},
			{"id": "chairs", "label": "Front-row seats", "rect": [400, 480, 480, 170], "script": "inv_lounge_chairs"},
			{"id": "back_door", "label": "Back door", "rect": [860, 150, 100, 280], "script": "inv_lounge_back_door"},
		],
		"people": [
			{"char": "lulu", "slot": "left", "expr": "sad", "script": "inv_talk_lulu"},
			{"char": "wisp", "slot": "right", "expr": "normal", "script": "inv_talk_wisp"},
		],
	},
	"storage": {
		"name": "Storage Closet", "bg": "storage", "enter_script": "inv_enter_storage",
		"hotspots": [
			{"id": "mannequin", "label": "Mannequin", "rect": [480, 200, 220, 380], "script": "inv_storage_mannequin"},
			{"id": "trunk", "label": "Magic trunk", "rect": [740, 300, 200, 260], "script": "inv_storage_trunk"},
			{"id": "boxes", "label": "Prop boxes", "rect": [340, 120, 130, 200], "script": "inv_storage_boxes"},
		],
		"people": [
			{"char": "tumble", "slot": "left", "expr": "normal", "script": "inv_talk_tumble"},
		],
	},
	"giftshop": {
		"name": "Gift Shop", "bg": "giftshop", "enter_script": "inv_enter_giftshop",
		"hotspots": [
			{"id": "pedestal", "label": "Empty pedestal", "rect": [520, 300, 220, 260], "script": "inv_giftshop_pedestal"},
			{"id": "price_gun", "label": "Price-tag gun", "rect": [760, 420, 140, 100], "script": "inv_giftshop_price_gun"},
			{"id": "shelves", "label": "Shelves", "rect": [380, 120, 520, 160], "script": "inv_giftshop_shelves"},
		],
		"people": [
			{"char": "fennel", "slot": "left", "expr": "normal", "script": "inv_talk_fennel"},
			{"char": "duchess", "slot": "right", "expr": "angry", "script": "inv_talk_duchess"},
		],
	},
	"dining": {
		"name": "Dining Hall", "bg": "dining", "enter_script": "inv_enter_dining",
		"hotspots": [
			{"id": "table", "label": "Dinner table", "rect": [380, 420, 520, 200], "script": "inv_dining_table"},
			{"id": "kitchen_door", "label": "Kitchen door", "rect": [560, 140, 180, 260], "script": "inv_dining_kitchen_door"},
			{"id": "menu", "label": "Menu board", "rect": [800, 120, 140, 180], "script": "inv_dining_menu"},
		],
		"people": [
			{"char": "grub", "slot": "left", "expr": "sad", "script": "inv_talk_grub"},
			{"char": "pepper", "slot": "right", "expr": "normal", "script": "inv_talk_pepper"},
		],
	},
}

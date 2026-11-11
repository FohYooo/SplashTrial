extends RefCounted
## Chapter 3 investigation rooms (Warden's Rest, the morning of Day 6). Same format as investigation_data.gd (see its
## header), plus "opens_day" (Chapters.room_open) and "opens_stage" on a room or on one hotspot (investigation_screen.gd).
## The hotspot scripts are story ids in story/story_case3.gd; the 3D objects are the anchors of the same id in
## world3d/rooms3.gd (a space listed here is a room; its anchors become examinable). Rects are for the 2D screen (--2d)
## over each room's bg. Spoilers: docs/DESIGN3.md, "The investigation".
##
## Three stages: the Library and the Grand Hall; then the rest of the house, the kitchens, the cellar, the wreck and the
## Generator Room; then the Gallery, the Attic, his bedroom and the servants' passage. STAGES lists the story breaks
## between them, plus one broadcast halfway through the second (it opens nothing), so "opens_stage" 1 is the second
## stage and 3 the third. A break plays when the player has found that many required Truth Drops by hand (the ones from
## investigation_start never count), and from the last one on, Finish is always there.

const START_ROOM := "library"
const ROOM_ORDER := ["library", "grand_hall", "kitchen", "dining_room", "wine_cellar", "generator_room", "music_room",
	"conservatory", "wreck", "terrace", "bedroom_wing", "gallery", "attic", "bedroom_nibs", "servants_passage"]
const SLOT_X := {"left": 170.0, "right": 1110.0}
const PERSON_SCALE := 0.62

const STAGES := [
	{"after": 8, "script": "inv3_stage2"},
	{"after": 14, "script": "inv3_snn"},
	{"after": 19, "script": "inv3_stage3"},
]

const ROOMS := {
	# ------------------------------------------------------------------ stage 1
	"library": {
		"name": "Library", "bg": "manor_library_after", "opens_day": 2, "enter_script": "inv3_enter_library",
		"hotspots": [
			{"id": "bookcase", "label": "Tall bookcase", "rect": [470, 215, 200, 125], "script": "inv3_lib_bookcase"},
			{"id": "body", "label": "Professor Nibs", "rect": [520, 340, 150, 70], "script": "inv3_lib_body"},
			{"id": "wall_brace", "label": "Wall above the shelves", "rect": [520, 120, 160, 90], "script": "inv3_lib_brace"},
			{"id": "desk", "label": "Desk", "rect": [690, 330, 70, 70], "script": "inv3_lib_desk"},
			{"id": "blotter", "label": "Blotter", "rect": [440, 340, 70, 45], "script": "inv3_lib_blotter"},
			{"id": "side_table", "label": "Side table", "rect": [1075, 365, 100, 85], "script": "inv3_lib_side_table"},
			{"id": "hatch", "label": "Dumbwaiter hatch", "rect": [1055, 265, 60, 75], "script": "inv3_lib_hatch", "opens_stage": 1},
			{"id": "floor_pen", "label": "Floor by the hatch", "rect": [960, 440, 110, 50], "script": "inv3_lib_floor"},
			{"id": "tapestry", "label": "Tapestry", "rect": [1215, 110, 65, 330], "script": "inv3_lib_tapestry"},
			{"id": "books_floor", "label": "Books on the floor", "rect": [280, 420, 420, 110], "script": "inv3_lib_books"},
			{"id": "typewriter", "label": "Library typewriter", "rect": [900, 390, 80, 50], "script": "inv3_lib_typewriter"},
			{"id": "door", "label": "Broken door", "rect": [360, 600, 200, 110], "script": "inv3_lib_door"},
			{"id": "ledger_page", "label": "Loose page", "rect": [320, 160, 110, 230], "script": "inv3_lib_page"},
		],
		"people": [
			{"char": "zuzu", "slot": "left", "expr": "sad", "script": "inv3_talk_zuzu"},
			{"char": "pepper", "slot": "right", "expr": "sad", "script": "inv3_talk_pepper"},
		],
	},
	"grand_hall": {
		"name": "Grand Hall", "bg": "manor_hall", "opens_day": 1, "enter_script": "inv3_enter_grand_hall",
		"hotspots": [
			{"id": "library_door", "label": "Library door", "rect": [215, 25, 165, 80], "script": "inv3_hall_library_door"},
			{"id": "notice_board", "label": "Notice board", "rect": [125, 280, 70, 150], "script": "inv3_hall_notice"},
			{"id": "clock", "label": "Hall clock", "rect": [412, 188, 60, 55], "script": "inv3_hall_clock"},
			{"id": "warden_portrait", "label": "Warden's portrait", "rect": [545, 115, 190, 175], "script": "inv3_hall_portrait"},
			{"id": "ledger_page", "label": "Portrait frame", "rect": [1090, 280, 65, 150], "script": "inv3_hall_page"},
		],
		"people": [
			{"char": "reginald", "slot": "left", "expr": "angry", "script": "inv3_talk_reginald"},
			{"char": "duchess", "slot": "right", "expr": "sad", "script": "inv3_talk_duchess"},
		],
	},
	# ------------------------------------------------------------------ stage 2
	"kitchen": {
		"name": "Kitchen", "bg": "manor_pantry", "opens_day": 1, "opens_stage": 1, "enter_script": "inv3_enter_kitchen",
		"hotspots": [
			{"id": "soup_pot", "label": "Soup pot", "rect": [795, 560, 90, 60], "script": "inv3_kit_soup"},
			{"id": "knife_block", "label": "Knife block", "rect": [1000, 450, 110, 80], "script": "inv3_kit_knives"},
			{"id": "sink", "label": "Sink", "rect": [200, 420, 160, 90], "script": "inv3_kit_sink"},
			{"id": "pantry_shelf", "label": "Pantry shelves", "rect": [160, 270, 290, 120], "script": "inv3_kit_shelf"},
			{"id": "hatch", "label": "Dumbwaiter hatch", "rect": [570, 265, 110, 140], "script": "inv3_kit_hatch"},
			{"id": "hatch_rope", "label": "Hatch rope", "rect": [676, 280, 26, 110], "script": "inv3_kit_rope"},
			{"id": "bell_tape", "label": "Service bell", "rect": [712, 212, 46, 230], "script": "inv3_kit_bell"},
			{"id": "shaft_bottom", "label": "Bottom of the shaft", "rect": [595, 432, 92, 78], "script": "inv3_kit_shaft", "opens_stage": 3},
			{"id": "ledger_page", "label": "Framed menu", "rect": [610, 236, 60, 24], "script": "inv3_kit_page"},
		],
		"people": [
			{"char": "grub", "slot": "right", "expr": "sad", "script": "inv3_talk_grub"},
		],
	},
	"dining_room": {
		"name": "Dining Room", "bg": "manor_cloakroom", "opens_day": 1, "opens_stage": 1, "enter_script": "inv3_enter_dining",
		"hotspots": [
			{"id": "coat_hooks", "label": "Coat hooks", "rect": [240, 200, 300, 200], "script": "inv3_din_hooks"},
			{"id": "watch_roster", "label": "Watch roster", "rect": [560, 220, 70, 90], "script": "inv3_din_roster"},
			{"id": "dining_clock", "label": "Dining Room clock", "rect": [990, 160, 80, 140], "script": "inv3_din_clock"},
			{"id": "ledger_page", "label": "Still life", "rect": [700, 150, 140, 100], "script": "inv3_din_page"},
		],
		"people": [],
	},
	"wine_cellar": {
		"name": "Wine Cellar", "bg": "manor_cellar", "opens_day": 2, "opens_stage": 1, "enter_script": "inv3_enter_cellar",
		"hotspots": [
			{"id": "bait_tin", "label": "Rat-bait tin", "rect": [380, 470, 90, 60], "script": "inv3_cel_bait"},
			{"id": "cellar_stool", "label": "Stool", "rect": [600, 450, 90, 110], "script": "inv3_cel_stool"},
			{"id": "bats", "label": "Ceiling", "rect": [480, 40, 320, 110], "script": "inv3_cel_bats"},
		],
		"people": [],
	},
	"generator_room": {
		"name": "Generator Room", "bg": "manor_generator", "opens_day": 5, "opens_stage": 1, "enter_script": "inv3_enter_generator",
		"hotspots": [
			{"id": "generator_log", "label": "Log book", "rect": [880, 300, 90, 120], "script": "inv3_gen_log"},
			{"id": "generator", "label": "Generator", "rect": [420, 240, 400, 260], "script": "inv3_gen_generator"},
		],
		"people": [
			{"char": "bruno", "slot": "left", "expr": "sad", "script": "inv3_talk_bruno"},
		],
	},
	"music_room": {
		"name": "Music Room", "bg": "manor_music", "opens_day": 2, "opens_stage": 1, "enter_script": "inv3_enter_music",
		"hotspots": [
			{"id": "fitting_table", "label": "Fitting table", "rect": [800, 380, 160, 100], "script": "inv3_mus_ticket"},
			{"id": "dress_form", "label": "Dress form", "rect": [880, 200, 120, 260], "script": "inv3_mus_dress"},
			{"id": "music_box", "label": "Music box", "rect": [330, 300, 80, 60], "script": "inv3_mus_box"},
			{"id": "piano", "label": "Piano", "rect": [440, 280, 300, 200], "script": "inv3_mus_piano"},
			{"id": "ledger_page", "label": "Still life", "rect": [220, 150, 120, 100], "script": "inv3_mus_page"},
		],
		"people": [
			{"char": "lulu", "slot": "left", "expr": "sad", "script": "inv3_talk_lulu"},
		],
	},
	"conservatory": {
		"name": "Conservatory", "bg": "manor_conservatory", "opens_day": 3, "opens_stage": 1, "enter_script": "inv3_enter_conservatory",
		"hotspots": [
			{"id": "bait_tin", "label": "Rat-bait tin", "rect": [300, 420, 80, 60], "script": "inv3_con_bait"},
			{"id": "potting_bench", "label": "Potting bench", "rect": [200, 380, 260, 140], "script": "inv3_con_bench"},
			{"id": "easel", "label": "Easel", "rect": [860, 220, 140, 260], "script": "inv3_con_easel"},
			{"id": "fountain", "label": "Fountain", "rect": [540, 380, 220, 140], "script": "inv3_con_fountain"},
		],
		"people": [
			{"char": "bramble", "slot": "right", "expr": "sad", "script": "inv3_talk_bramble"},
		],
	},
	"wreck": {
		"name": "Mudlark Wreck", "bg": "manor_wreck", "opens_day": 5, "opens_stage": 1, "enter_script": "inv3_enter_wreck",
		"hotspots": [
			{"id": "manual_shelf", "label": "Shelf of manuals", "rect": [380, 150, 180, 110], "script": "inv3_wre_manuals"},
			{"id": "medicine_cabinet", "label": "Medicine cabinet", "rect": [580, 140, 160, 140], "script": "inv3_wre_cabinet"},
			{"id": "locker", "label": "Locker", "rect": [900, 160, 120, 300], "script": "inv3_wre_locker"},
			{"id": "cot", "label": "Cot", "rect": [560, 380, 300, 120], "script": "inv3_wre_cot"},
		],
		"people": [],
	},
	"terrace": {
		"name": "Terrace", "bg": "manor_terrace", "opens_day": 1, "opens_stage": 1, "enter_script": "inv3_enter_terrace",
		"hotspots": [
			{"id": "terrace_mud", "label": "Planter", "rect": [880, 420, 160, 90], "script": "inv3_ter_planter"},
			{"id": "telescope", "label": "Telescope", "rect": [760, 250, 110, 220], "script": "inv3_ter_telescope"},
			{"id": "ledger_page", "label": "Under a planter", "rect": [300, 470, 120, 60], "script": "inv3_ter_page"},
		],
		"people": [],
	},
	"bedroom_wing": {
		"name": "Bedroom Wing", "bg": "manor_corridor", "opens_day": 1, "opens_stage": 1, "enter_script": "inv3_enter_wing",
		"hotspots": [
			{"id": "ledger_page", "label": "Runner", "rect": [500, 560, 280, 100], "script": "inv3_wing_page"},
		],
		"people": [],
	},
	# ------------------------------------------------------------------ stage 3
	"gallery": {
		"name": "Gallery", "bg": "manor_gallery", "opens_day": 2, "opens_stage": 3, "enter_script": "inv3_enter_gallery",
		"hotspots": [
			{"id": "clock", "label": "Mantel clock", "rect": [930, 420, 90, 60], "script": "inv3_gal_clock"},
			{"id": "darkroom", "label": "Darkroom", "rect": [760, 160, 140, 280], "script": "inv3_gal_darkroom"},
			{"id": "grate", "label": "Grate", "rect": [1020, 360, 100, 90], "script": "inv3_gal_grate"},
			{"id": "window_seat", "label": "Window seat", "rect": [300, 400, 200, 90], "script": "inv3_gal_seat"},
			{"id": "portraits", "label": "Portraits", "rect": [360, 120, 360, 180], "script": "inv3_gal_portraits"},
		],
		"people": [
			{"char": "fennel", "slot": "left", "expr": "sad", "script": "inv3_talk_fennel"},
		],
	},
	"attic": {
		"name": "Attic", "bg": "manor_attic", "opens_day": 3, "opens_stage": 3, "enter_script": "inv3_enter_attic",
		"hotspots": [
			{"id": "zuzu_desk", "label": "Corner desk", "rect": [820, 330, 200, 140], "script": "inv3_att_desk"},
			{"id": "dead_camera", "label": "Camera in the rafters", "rect": [880, 80, 100, 80], "script": "inv3_att_camera"},
			{"id": "bait_tin", "label": "Rat-bait tin", "rect": [520, 470, 80, 60], "script": "inv3_att_bait"},
			{"id": "trunks", "label": "Trunks", "rect": [200, 380, 240, 140], "script": "inv3_att_trunks"},
		],
		"people": [],
	},
	"bedroom_nibs": {
		"name": "Plover Room", "bg": "manor_bedroom", "opens_day": 1, "opens_stage": 3, "enter_script": "inv3_enter_plover",
		"hotspots": [
			{"id": "pen_case", "label": "Case on the mantel", "rect": [520, 250, 110, 60], "script": "inv3_plo_case"},
			{"id": "desk", "label": "Writing desk", "rect": [900, 330, 160, 140], "script": "inv3_plo_desk"},
			{"id": "bed", "label": "Bed", "rect": [380, 360, 320, 160], "script": "inv3_plo_bed"},
		],
		"people": [],
	},
	"servants_passage": {
		"name": "Servants' Passage", "bg": "manor_passage", "opens_day": 6, "opens_stage": 3, "enter_script": "inv3_enter_passage",
		"hotspots": [
			{"id": "passage_door", "label": "Narrow door", "rect": [560, 220, 160, 280], "script": "inv3_pas_door"},
			{"id": "tracks", "label": "Floor", "rect": [460, 520, 360, 160], "script": "inv3_pas_tracks"},
			{"id": "hem_line", "label": "Skirting", "rect": [300, 470, 160, 120], "script": "inv3_pas_hem"},
			{"id": "feather", "label": "Door bracket", "rect": [620, 170, 70, 60], "script": "inv3_pas_feather"},
			{"id": "bells", "label": "Old service bells", "rect": [820, 140, 200, 120], "script": "inv3_pas_bells"},
		],
		"people": [],
	},
}

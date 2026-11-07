extends RefCounted
## Free Time skills. Effects are applied centrally by Game (see game.gd helpers)
## or checked by minigames with Game.has_skill(id).

const BY_CHAR := {
	"coco": "captains_courage", "wisp": "sleight_of_paw", "bruno": "iron_hide",
	"lulu": "encore", "pepper": "scoop_sense", "duchess": "poise",
	"bramble": "deep_roots", "nibs": "hypothesis", "zuzu": "autocomplete",
	"reginald": "en_garde", "grub": "comfort_food", "tumble": "power_nap",
	"marigold": "first_aid", "fennel": "artists_eye",
}

const SKILLS := {
	"captains_courage": {"name": "Captain's Courage", "desc": "Start the trial with +10% convince."},
	"sleight_of_paw": {"name": "Sleight of Paw", "desc": "Rebuttal Showdown timing window is 40% wider."},
	"iron_hide": {"name": "Iron Hide", "desc": "Mistakes cost 25% less convince."},
	"encore": {"name": "Encore!", "desc": "Correct answers give 25% more convince."},
	"scoop_sense": {"name": "Scoop Sense", "desc": "In Splash Debates, the correct weak spot sparkles after the first loop."},
	"poise": {"name": "Poise", "desc": "Start the trial with +8% convince."},
	"deep_roots": {"name": "Deep Roots", "desc": "Your first mistake in each minigame is forgiven."},
	"hypothesis": {"name": "Hypothesis", "desc": "In Pick-the-Answer questions, one wrong option is crossed out."},
	"autocomplete": {"name": "Autocomplete", "desc": "In Bubble Letters, the next correct letter shimmers."},
	"en_garde": {"name": "En Garde", "desc": "Rebuttal counters give double convince."},
	"comfort_food": {"name": "Comfort Food", "desc": "Start the trial with +5% convince."},
	"power_nap": {"name": "Power Nap", "desc": "All minigame timers run 25% slower."},
	"first_aid": {"name": "First Aid", "desc": "Once per trial, if convince falls below 20%, recover 15%."},
	"artists_eye": {"name": "Artist's Eye", "desc": "In Case Rewind, one wrong option per panel is crossed out."},
}

static func skill_name(id: String) -> String:
	return SKILLS[id]["name"] if SKILLS.has(id) else id

static func desc(id: String) -> String:
	return SKILLS[id]["desc"] if SKILLS.has(id) else ""

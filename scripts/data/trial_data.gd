extends RefCounted
## Splash Trial minigame data, keyed by id. Used by `@minigame <id>` in the trial script.
## Formats are documented in docs/ARCHITECTURE.md section 5.
## In statement text, {curly braces} mark a WEAK SPOT (shootable phrase).

const DATA := {
	# ------------------------------------------------------------------ 1. accident theory
	"debate_accident": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["cushion_edge", "coco_watch", "snapjaw_file"],
		"statements": [
			{"speaker": "tumble", "expr": "normal", "text": "Zzz... Coco probably just dozed off in that nice warm water..."},
			{"speaker": "nibs", "expr": "normal", "text": "Hypothetically, an unconscious capybara could {drown} in a few minutes."},
			{"speaker": "duchess", "expr": "angry", "text": "Obviously she slipped on the wet floor and {hit her head on the rocks}!"},
			{"speaker": "grub", "expr": "sad", "text": "Accidents happen! Like when my soufflés collapse..."},
		],
		"answer": {"statement": 2, "weak": 0, "drop": "cushion_edge"},
		"wrong": [{"speaker": "pepper", "expr": "angry", "text": "Huh? What does THAT have to do with anything?"}],
		"hint": "Duchess says Coco hit her head on the rocks... but what were the rocks around the bath covered with?",
	},
	# ------------------------------------------------------------------ 2. weapon
	"q_weapon": {
		"type": "present",
		"speaker": "nibs",
		"prompt": "If she didn't hit her head on the rocks... then what did the culprit hit Coco with?",
		"answer": "cracked_bucket",
		"wrong": {"speaker": "zuzu", "expr": "normal", "text": "ngl that's not a weapon. try again."},
	},
	# ------------------------------------------------------------------ 3. time of attack
	"q_time": {
		"type": "choice",
		"speaker": "marigold",
		"prompt": "The file only says between 9:30 and 10:00... When exactly was Coco attacked?",
		"options": ["9:30 PM", "9:47 PM", "9:56 PM", "10:00 PM"],
		"answer": 1,
		"wrong": {"speaker": "marigold", "expr": "sad", "text": "Hmm... are you sure? Think about what stopped when she fell."},
	},
	# ------------------------------------------------------------------ 4. Bruno accused
	"debate_bruno": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["sauna_log", "bruno_headband", "marigold_account"],
		"statements": [
			{"speaker": "pepper", "expr": "angry", "text": "Bruno was the last one seen leaving the bathhouse, at {9:56}! Scoop!"},
			{"speaker": "duchess", "expr": "normal", "text": "And darling, his {headband} was lying right beside poor Coco!"},
			{"speaker": "reginald", "expr": "angry", "text": "I say, Bruno simply {slipped out of the sauna}, struck her at 9:47, and went back in!"},
			{"speaker": "bruno", "expr": "sad", "text": "Bruno... Bruno was in the sauna the whole time..."},
		],
		"answer": {"statement": 2, "weak": 0, "drop": "sauna_log"},
		"wrong": [{"speaker": "reginald", "expr": "angry", "text": "Hah! I say, that proves nothing whatsoever!"}],
		"hint": "If Bruno slipped out of the sauna, the door would have opened... What records the sauna door?",
	},
	# ------------------------------------------------------------------ 5. Lulu accused (glitter)
	"debate_glitter": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["lulu_glitter", "cracked_bucket", "living_statue"],
		"statements": [
			{"speaker": "duchess", "expr": "angry", "text": "Glitter on the bucket handle! Who here sparkles more than our little {idol}?"},
			{"speaker": "lulu", "expr": "shock", "text": "M-my glitter? I always carry some, but..."},
			{"speaker": "pepper", "expr": "angry", "text": "That glitter is {exactly the same as Lulu's}! Case closed!"},
			{"speaker": "lulu", "expr": "sad", "text": "Lulu-lu... nobody believes me..."},
		],
		"answer": {"statement": 2, "weak": 0, "drop": "lulu_glitter"},
		"wrong": [{"speaker": "duchess", "expr": "happy", "text": "Darling, that's simply irrelevant."}],
		"hint": "What color is the glitter on the bucket... and what color is Lulu's?",
	},
	# ------------------------------------------------------------------ 6. whose glitter
	"q_glitter_owner": {
		"type": "character",
		"speaker": "nibs",
		"prompt": "Silver-violet glitter... Who uses glitter like that?",
		"answer": "wisp",
		"exclude": ["mochi", "coco"],
		"wrong": {"speaker": "fennel", "expr": "normal", "text": "Non, non! Think of who makes things sparkle... with a POOF!"},
	},
	# ------------------------------------------------------------------ 7. Wisp's alibi
	"debate_alibi": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["pepper_photo", "living_statue", "mannequin", "cape_thread"],
		"statements": [
			{"speaker": "lulu", "expr": "normal", "text": "Wisp was on stage from {9:35 to 9:55}! We all saw him!"},
			{"speaker": "bramble", "expr": "happy", "text": "He stood so still... like a beautiful {garden statue}..."},
			{"speaker": "fennel", "expr": "happy", "text": "I sketched him for twenty minutes. He {never blinked}. Magnifique!"},
			{"speaker": "wisp", "expr": "happy", "text": "The statue on that stage {was me}, the one and only Wisp!"},
		],
		"answer": {"statement": 3, "weak": 0, "drop": "pepper_photo"},
		"wrong": [{"speaker": "wisp", "expr": "happy", "text": "Hoho! A swing and a miss, my dear audience!"}],
		"hint": "Was the 'statue' really Wisp? Did anyone take a picture of it?",
	},
	# ------------------------------------------------------------------ 8. where is the double
	"q_mannequin": {
		"type": "present",
		"speaker": "pepper",
		"prompt": "A gift-shop price tag on the statue?! Then what was really standing on that stage?",
		"answer": "mannequin",
		"wrong": {"speaker": "pepper", "expr": "angry", "text": "That's not it! Think about the price tag!"},
	},
	# ------------------------------------------------------------------ 9. the route
	"bubbles_garden": {
		"type": "bubbles",
		"prompt": "How did the culprit get from the Lounge to the bathhouse without being seen? Along the ___ path!",
		"answer": "GARDEN",
		"decoys": "SPTOHLKW",
		"time": 60.0,
	},
	# ------------------------------------------------------------------ 10. Wisp fights back
	"rebuttal_wisp": {
		"type": "rebuttal",
		"opponent": "wisp",
		"intro": "A magician never reveals his secrets... but I'll gladly cut yours to ribbons!",
		"lines": [
			"A price tag? Anyone could have hung that on a cape!",
			"Mannequins don't walk, my dear audience! Who carried it?",
			"Four witnesses saw me take my bow at 9:55!",
			"You have no proof I ever left the Lounge!",
		],
		"final": {
			"text": "Prove I ever set paw on that {garden path}!",
			"drops": ["cape_thread", "pepper_photo", "mannequin", "garden_door"],
			"answer": "cape_thread",
		},
		"time_per_line": 2.6,
	},
	# ------------------------------------------------------------------ 11. closing argument
	"rewind_final": {
		"type": "rewind",
		"title": "CASE REWIND",
		"panels": [
			{"caption": "On the afternoon before the murder, the culprit secretly took a ___ from the gift shop and hid it in the storage closet behind the stage.",
				"options": ["display mannequin", "price-tag gun", "wooden bucket"], "answer": 0, "bg": "giftshop"},
			{"caption": "At 9:35 PM the culprit began \"The Living Statue\" in the Lounge. Behind the half-drawn curtain, he swapped places with ___.",
				"options": ["Lulu", "the mannequin", "Old Man Tumble"], "answer": 1, "bg": "lounge"},
			{"caption": "He slipped out the Lounge's back door and ran along the garden path, where his violet cape snagged on ___.",
				"options": ["a stone lantern", "the sauna door", "a rose bush"], "answer": 2, "bg": "garden"},
			{"caption": "He entered the bathhouse through the ___, grabbed a wooden bucket from the stack, and took Bruno's headband from its hook.",
				"options": ["garden side door", "front entrance", "kitchen window"], "answer": 0, "bg": "changing"},
			{"caption": "At ___ he struck Captain Coco on the back of the head with the bucket. She fell into the water, and her watch cracked and stopped.",
				"options": ["9:30 PM", "9:56 PM", "9:47 PM"], "answer": 2, "bg": "bath"},
			{"caption": "He left the headband beside the bath to frame ___, hid the bucket behind the lockers, and ran back to the Lounge to take his bow at 9:55.",
				"options": ["Bruno", "Lulu", "Reginald"], "answer": 0, "bg": "lounge"},
		],
		"culprit": "wisp",
		"finale": "And the only capybara who could have done all of that... is YOU, Wisp Vanderloo, the Ace Magician!",
	},
	# ------------------------------------------------------------------ 12. the vote
	"vote_final": {
		"type": "vote",
		"culprit": "wisp",
		"fallback": "bruno",
		"threshold": 60.0,
	},
}

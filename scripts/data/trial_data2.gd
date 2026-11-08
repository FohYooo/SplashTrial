extends RefCounted
## Chapter 2 ("Murder on the Mudlark") Splash Trial minigame data, keyed by id (prefix c2_).
## Used by `@minigame <id>` in story/story_case2.gd. Formats: docs/ARCHITECTURE.md section 5.
## Segment order and answers: docs/DESIGN2.md section 6.
## In statement text, {curly braces} mark a WEAK SPOT (shootable phrase).

const DATA := {
	# ------------------------------------------------------------------ 2. weapon
	"c2_q_weapon": {
		"type": "present",
		"speaker": "nibs",
		"prompt": "One heavy blow, and the bruise is curved with a little hook at one end... What did the culprit hit Marigold with?",
		"answer": "anchor_doorstop",
		"wrong": {"speaker": "nibs", "expr": "normal", "text": "Hypothetically... no. That couldn't leave a curved, hooked bruise. Think heavier. Much heavier."},
	},
	# ------------------------------------------------------------------ 3. time of attack
	"c2_q_time": {
		"type": "choice",
		"speaker": "grub",
		"expr": "sad",
		"prompt": "She gave me my tummy tonic at 10:30, and she was fine... humming, even. So when was Marigold attacked?",
		"options": ["10:00 PM", "10:30 PM", "10:40 PM", "11:00 PM", "Midnight"],
		"answer": 2,
		"wrong": {"speaker": "grub", "expr": "sad", "text": "Hmm... Marigold wrote everything down, Mochi. What was the very last line in her log?"},
	},
	# ------------------------------------------------------------------ 4. Bruno accused (boot prints)
	"c2_debate_boots": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["boot_prints", "bruno_boots", "anchor_doorstop"],
		"statements": [
			{"speaker": "pepper", "expr": "angry", "text": "Giant prints in the coal! {Nobody has feet as big as Bruno}!"},
			{"speaker": "reginald", "expr": "angry", "text": "The brute {walked to that coal pile in his own boots} and buried the anchor!"},
			{"speaker": "bruno", "expr": "sad", "text": "Bruno was asleep... Bruno only goes to the coal pile at 6:30..."},
			{"speaker": "duchess", "expr": "angry", "text": "Disgusting. Coal everywhere. {Only a stoker} would set foot near that filthy pile!"},
		],
		"answer": {"statement": 1, "weak": 0, "drop": "bruno_boots"},
		"wrong": [
			{"speaker": "reginald", "expr": "angry", "text": "Hah! That only proves the brute has enormous feet!"},
			{"speaker": "pepper", "expr": "angry", "text": "Nice try, Mochi! Bruno's still on my front page!"},
		],
		"hint": "Reginald says Bruno wore his own boots. But which boots made those prints... and what was stuffed deep inside them?",
	},
	# ------------------------------------------------------------------ 5. Duchess accused (lilac scrap)
	"c2_debate_shawl": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["lilac_thread", "duchess_shawl", "rounds_log"],
		"statements": [
			{"speaker": "reginald", "expr": "angry", "text": "At dinner she said {you'll regret meddling with me}! I heard it myself!"},
			{"speaker": "lulu", "expr": "sad", "text": "That scrap on the cot is {the Duchess's lilac}... the very same color..."},
			{"speaker": "pepper", "expr": "angry", "text": "Her shawl was {torn off in the struggle}! Scoop!"},
			{"speaker": "duchess", "expr": "angry", "text": "I was in my cabin, darlings! Alone! Furious, but ALONE!"},
		],
		"answer": {"statement": 2, "weak": 0, "drop": "duchess_shawl"},
		"wrong": [
			{"speaker": "duchess", "expr": "angry", "text": "Darling, that is hardly helping!"},
			{"speaker": "reginald", "expr": "angry", "text": "I say, that proves nothing whatsoever!"},
		],
		"hint": "Pepper says the shawl was torn in a struggle. But what did the edge of the missing corner look like?",
	},
	# ------------------------------------------------------------------ 6. where the culprit went first
	"c2_q_laundry": {
		"type": "choice",
		"speaker": "nibs",
		"prompt": "Bruno's boots and the Duchess's shawl... both were taken from the same place. Where did the culprit go first?",
		"options": ["Boiler room", "Laundry", "Galley", "Purser's office"],
		"answer": 1,
		"wrong": {"speaker": "nibs", "expr": "normal", "text": "Hmm. Where were Bruno's spare boots drying? And where did the Duchess hang her shawl?"},
	},
	# ------------------------------------------------------------------ 8. the snoring alibi
	"c2_debate_snore": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["snore_alibi", "pepper_log", "rules2"],
		"statements": [
			{"speaker": "pepper", "expr": "happy", "text": "I heard him {nonstop from ten until midnight}! Every single snore!"},
			{"speaker": "lulu", "expr": "normal", "text": "Old capybaras just {snore all night long}! It's natural! Lulu-lu~!"},
			{"speaker": "pepper", "expr": "normal", "text": "Every snore was {perfectly natural}, cough and all! I'd know!"},
			{"speaker": "tumble", "expr": "normal", "text": "Zzz... eh? Snoring? Me? I {sleep like a log}, young'un..."},
		],
		"answer": {"statement": 2, "weak": 0, "drop": "pepper_log"},
		"wrong": [
			{"speaker": "pepper", "expr": "angry", "text": "Hey! That doesn't disprove a single snore!"},
			{"speaker": "lulu", "expr": "sad", "text": "Lulu-lu? I don't get it..."},
		],
		"hint": "Pepper timed that little cough with her stopwatch. Does a natural snore cough at the exact same moment, every four minutes?",
	},
	# ------------------------------------------------------------------ 9. it was a recording
	"c2_bubbles_recording": {
		"type": "bubbles",
		"prompt": "A cough that repeats exactly every four minutes, all night long... That wasn't snoring. It was a ___!",
		"answer": "RECORDING",
		"decoys": "SPALMTWU",
		"time": 70.0,
	},
	# ------------------------------------------------------------------ 10. the device
	"c2_q_device": {
		"type": "present",
		"speaker": "zuzu",
		"prompt": "ok but what on this boat can record a sound and loop it?",
		"answer": "dictaphone",
		"wrong": {"speaker": "zuzu", "expr": "normal", "text": "nah. that can't record anything. think hardware. old hardware."},
	},
	# ------------------------------------------------------------------ 11. whose snoring
	"c2_q_who": {
		"type": "character",
		"speaker": "nibs",
		"prompt": "Then whose snoring was recorded on that cylinder?",
		"answer": "tumble",
		"exclude": ["mochi"],
		"wrong": {"speaker": "nibs", "expr": "normal", "text": "Hypothetically... whose snoring were Mochi and Pepper hearing through their walls all night?"},
	},
	# ------------------------------------------------------------------ 13. Tumble fights back
	"c2_rebuttal_tumble": {
		"type": "rebuttal",
		"opponent": "tumble",
		"intro": "Sonny... I'm ninety-one. Let an old capybara sleep.",
		"lines": [
			"I can barely climb a staircase, let alone fight a nurse!",
			"Anybody can record anybody, sonny!",
			"I nap in that office every day! Of course I've seen the contraption!",
			"Marigold was my friend. She brought me tea every night!",
		],
		"final": {
			"text": "Prove that {contraption was ever beside my bunk}!",
			"drops": ["tumble_bunk", "grub_ghost", "wax_lump", "dictaphone"],
			"answer": "tumble_bunk",
		},
		"wrong": [
			{"speaker": "tumble", "expr": "happy", "text": "Heh. That's not proof, young'un. That's a bedtime story."},
			{"speaker": "tumble", "expr": "normal", "text": "Try again. Take your time. Old folks are patient."},
		],
		"time_per_line": 2.6,
	},
	# ------------------------------------------------------------------ 14. where's the cylinder
	"c2_q_cylinder": {
		"type": "present",
		"speaker": "tumble",
		"prompt": "Then where's the cylinder, eh? If I recorded myself snoring, play it for everyone!",
		"answer": "wax_lump",
		"wrong": {"speaker": "tumble", "expr": "happy", "text": "Heh. Can't play a tune on that, young'un. Where's my cylinder?"},
	},
	# ------------------------------------------------------------------ 15. closing argument
	"c2_rewind_final": {
		"type": "rewind",
		"title": "CASE REWIND",
		"panels": [
			{"caption": "In the afternoon, the culprit borrowed the purser's ___ and recorded four minutes of his own snoring on a blank cylinder.",
				"options": ["ship's bell", "Echo-Matic dictaphone", "speaking tube"], "answer": 1, "bg": "ship_purser"},
			{"caption": "At 10:00 PM he set it on the rug beside his bunk, horn against Mochi's wall, wound it, flipped the ___ lever, and slipped out.",
				"options": ["brake", "whistle", "REPEAT"], "answer": 2, "bg": "ship_tumble_cabin"},
			{"caption": "In the laundry he pulled on ___, stuffing socks into the toes, and snipped a corner off the Duchess's shawl.",
				"options": ["Bruno's spare boots", "Reginald's fencing shoes", "Grub's kitchen clogs"], "answer": 0, "bg": "ship_laundry"},
			{"caption": "At 10:40, while Marigold put the kettle on for his chamomile, he struck her from behind with the ___.",
				"options": ["kettle", "anchor doorstop", "wax cylinder"], "answer": 1, "bg": "ship_infirmary"},
			{"caption": "He left the lilac scrap on her cot, buried the doorstop in the ___, and returned the boots to the laundry.",
				"options": ["furnace", "laundry basket", "coal pile"], "answer": 2, "bg": "ship_boiler"},
			{"caption": "At 6:00 AM he carried the dictaphone back, where Grub mistook him for a ___, and burned the cylinder in the furnace.",
				"options": ["ghost", "burglar", "Snapjaw"], "answer": 0, "bg": "ship_hall"},
		],
		"culprit": "tumble",
		"finale": "And the capybara who 'slept' through the whole night... is YOU, Old Man Tumble, the Ace Napper!",
	},
	# ------------------------------------------------------------------ 16. the vote
	"c2_vote_final": {
		"type": "vote",
		"culprit": "tumble",
		"fallback": "duchess",
		"threshold": 60.0,
	},
}

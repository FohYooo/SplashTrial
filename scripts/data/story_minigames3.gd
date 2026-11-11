extends RefCounted
## Chapter 3 ("Murder at Warden's Rest") minigames the daily story plays outside the trial, keyed by id.
## Looked up by trial_data_index.gd (STORY_PATHS) after the trial's own table, so `@minigame <id>` works in any
## story script. Formats: docs/ARCHITECTURE.md section 5. Nothing here is part of the Splash Trial or its numbers.
##
## c3_tribunal: Day 4's Tea-Time Tribunal (story_daily3.gd "day4"), a short no-stakes Splash Debate about Night 3.
## SPOILERS for the Tribunal only: the page in the Gallery grate was burned by Lulu, and the glitter on the hearth rug
## gives her away. The samples theft is left open on purpose. Its Truth Drops are clues.gd STORY3.

const DATA := {
	"c3_tribunal": {
		"type": "debate",
		"title": "TEA-TIME TRIBUNAL",
		"drops": ["night3_ash", "night3_rug", "night3_desk", "rules3"],
		"statements": [
			{"speaker": "reginald", "expr": "angry", "text": "The page named Miss Thistlewood and lived in her drawer. She burned it {before it could be tested}!"},
			{"speaker": "duchess", "expr": "normal", "text": "Burn the page, take the samples, and {nobody can ever match your hand}, darling. Tidy."},
			{"speaker": "lulu", "expr": "angry", "text": "Lulu was {asleep in her room with the door locked} all night! Lulu didn't see a thing!"},
			{"speaker": "zuzu", "expr": "normal", "text": "attic, all night. {nobody came up my stairs}. that's all i've got."},
			{"speaker": "bramble", "expr": "sad", "text": "...I asked for it to be tested... in front of everyone... {why would I burn my own proof}..."},
		],
		"answer": {"statement": 2, "weak": 0, "drop": "night3_rug"},
		"wrong": [
			{"speaker": "snapjaw", "expr": "happy", "text": "Wrong! Splendid! Nothing rides on it, so do it again!"},
			{"speaker": "reginald", "expr": "angry", "text": "That changes nothing! The page was in HER drawer!"},
			{"speaker": "fennel", "expr": "normal", "text": "Mochi, darling, that's a very nice shot at absolutely nothing."},
		],
		"hint": "Somebody says they never left their room. Did anything of theirs turn up somewhere it shouldn't, after the page burned?",
	},
}

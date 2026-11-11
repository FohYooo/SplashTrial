extends RefCounted
## Test fixtures for the trial segment types: `--minigame=t_<name> --autotest` tries a wrong answer first and then
## solves it, and `--trial-fixture=<id> --autotest` runs one script below through the real trial flow.
## Not part of any case; written against Case 1's first two Truth Drops, which every chapter 1 run has.

const DATA := {
	"t_present2": {
		"type": "present",
		"speaker": "nibs",
		"prompt": "Test: which two Truth Drops go together here?",
		"answer": ["rules", "snapjaw_file"],
		"wrong": {"speaker": "nibs", "expr": "normal", "text": "Test: those two don't belong together."},
	},
	"t_present2_early": {
		"type": "present",
		"speaker": "nibs",
		"prompt": "Test: two Truth Drops, one of them too soon.",
		"answer": ["rules", "snapjaw_file"],
		"early": {"coco_watch": "Test: that's right, but I can't prove it yet."},
	},
	"t_present_early": {
		"type": "present",
		"speaker": "nibs",
		"prompt": "Test: one Truth Drop, with an early one on the list.",
		"answer": "rules",
		"early": {"snapjaw_file": {"speaker": "mochi", "expr": "normal", "text": "Test: not yet."}},
		"wrong": {"speaker": "nibs", "expr": "normal", "text": "Test: wrong one."},
	},
	"t_present_view": {
		"type": "present",
		"speaker": "nibs",
		"prompt": "Test: a Truth Drop with pictures to look at first.",
		"answer": "t_pictures",
	},
	"t_character_multi": {
		"type": "character",
		"speaker": "snapjaw",
		"prompt": "Test: who left the table? Pick everyone.",
		"answers": ["bruno", "lulu", "fennel"],
		"wrong": {"speaker": "snapjaw", "expr": "happy", "text": "Test: not that lot."},
	},
	"t_roll_call": {
		"type": "roll_call",
		"title": "ROLL CALL",
		"speaker": "snapjaw",
		"prompt": "Test: who can back them up?",
		"entries": [
			{"guest": "bruno", "expr": "normal", "claim": "Test: Bruno was in the sauna.", "answer": "nobody",
				"wrong": {"speaker": "bruno", "expr": "sad", "text": "Test: Nobody saw Bruno."}},
			{"guest": "lulu", "expr": "happy", "claim": "Test: I was in the front row!", "answer": ["bramble", "tumble"]},
			{"guest": "duchess", "expr": "angry", "claim": "Test: I was in my shop, darling.", "answer": "fennel"},
		],
	},
	"t_time_one": {
		"type": "time_pick",
		"title": "WHAT TIME?",
		"speaker": "nibs",
		"prompt": "Test: when did the watch stop?",
		"from": "9:00 PM",
		"to": "10:30 PM",
		"step": 1,
		"answer": "9:47 PM",
		"wrong": {"speaker": "nibs", "expr": "normal", "text": "Test: not then."},
	},
	"t_time_window": {
		"type": "time_pick",
		"title": "WHEN WAS IT POSSIBLE?",
		"speaker": "snapjaw",
		"expr": "happy",
		"prompt": "Test: set the window, from the first moment it could happen to the last.",
		"from": "7:00 PM",
		"to": "12:30 AM",
		"step": 5,
		"answer": ["8:05 PM", "9:15 PM"],
		"wrong": {"speaker": "snapjaw", "expr": "happy", "text": "Test: wrong window."},
	},
	"t_rewind_jam": {
		"type": "rewind",
		"title": "CASE REWIND",
		"culprit": "bruno",
		"finale": "Test: this finale never plays.",
		"panels": [
			{"caption": "Test: the first panel is ___.", "options": ["fine", "bad", "worse"], "answer": 0, "bg": "lobby"},
			{"caption": "Test: the second panel is ___.", "options": ["bad", "fine", "worse"], "answer": 1, "bg": "dining"},
			{"caption": "Test: nothing fits in ___.", "options": ["this", "that", "the other"], "jam": true, "bg": "kitchen"},
			{"caption": "Test: never reached ___.", "options": ["a", "b"], "answer": 0, "bg": "lounge"},
		],
	},
	"t_offer_vote": {
		"type": "choice",
		"speaker": "snapjaw",
		"expr": "happy",
		"prompt": "Test: the vote is open. Well? Shall we?",
		"options": ["Vote now", "Run it through once more"],
		"answer": 1,
		"vote_option": 0,
		"wrong": {"speaker": "snapjaw", "expr": "happy", "text": "Test: unreachable."},
	},
	"t_free": {
		"type": "choice",
		"free": true,
		"speaker": "nibs",
		"prompt": "Test: any answer is fine.",
		"options": ["First", "Second", "Third"],
		"option_flags": ["", "t_said_second", ""],
		"answer": 1,
	},
	"t_vote": {
		"type": "vote",
		"culprit": "bruno",
		"fallback": "lulu",
	},
	"t_vote_false": {
		"type": "vote",
		"culprit": "bruno",
		"fallback": "lulu",
		"false_vote": true,
	},
	"t_evidence": {
		"type": "evidence",
		"speaker": "pepper",
		"prompt": "Test: find the two pictures that don't belong.",
		"images": [
			{"art": "lobby", "stamp": "Picture 1"},
			{"art": "dining", "stamp": "Picture 2"},
			{"art": "kitchen", "stamp": "Picture 3"},
			{"art": "lounge", "stamp": "Picture 4"},
		],
		"answers": [1, 3],
		"wrong": {"speaker": "pepper", "expr": "normal", "text": "Test: no, not those."},
	},
	"t_debate_six": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["rules", "snapjaw_file", "coco_watch", "cushion_edge", "bruno_headband", "t_pictures"],
		"statements": [
			{"speaker": "pepper", "expr": "angry", "text": "Test: {nothing here} is wrong!"},
			{"speaker": "lulu", "expr": "sad", "text": "Test: {the rest of this} is a lie."},
		],
		"answer": {"statement": 1, "weak": 0, "drop": "cushion_edge"},
		"early": {"coco_watch": "Test: right, but too soon."},
		"hint": "Test: a hint.",
		"wrong": [{"speaker": "pepper", "expr": "angry", "text": "Test: wrong."}],
	},
}

const SCRIPTS := {
	"false_finish": """
@bg trial
@music trial
snapjaw[happy]: Test: the false finish.
@checkpoint before_showdown 20
@label before_showdown
@minigame t_rewind_jam
@minigame t_offer_vote
@if voted_early -> early
@minigame t_present2
@convince +100
@minigame t_vote
@ifnot vote_correct -> wrong
snapjaw[happy]: Test: right verdict.
@end
@label early
@minigame t_vote_false
@label wrong
@sfx wrong
snapjaw[happy]: Test: wrong verdict.
@end
""",
}

extends RefCounted
## Chapter 3 ("Murder at Warden's Rest") Splash Trial minigame data, keyed by id (prefix c3_).
## Used by `@minigame <id>` in story/story_case3.gd "trial". Formats: docs/ARCHITECTURE.md section 5.
## Segment order, answers and the reasoning behind them: the plan's spoiler file, S3 "Trial outline", and docs/DESIGN3.md
## "The trial". In statement text, {curly braces} mark a WEAK SPOT (shootable phrase).
##
## Writing rules for this file: every debate loads 5 to 6 Truth Drops, the wrong ones plausible; hints exist but only show
## when asked for (chapters.gd "hint_on_request"); "early" lists Drops that are right but too soon (no cost, a small
## bonus later), and a few that are right but not the one this question is after, so a sharp player is never charged
## for being right; "missing" names who brings up a required Drop the player arrives without.
## Two-part questions only name a speaker in "missing", so each missing Drop gets the stock line from the right guest.

const DATA := {
	# ------------------------------------------------------------------ 2. "It simply fell"
	"c3_debate_fell": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["fallen_bookcase", "wall_anchor", "cup_ring", "desk_contents", "nibs_blotter", "door_scratches"],
		"statements": [
			{"speaker": "reginald", "expr": "angry", "text": "Rule seven! It was posted! At 11:05 the house shook and that bookcase {simply fell over}!"},
			{"speaker": "duchess", "expr": "normal", "text": "Old house, old shelves, darlings. Things {fall down in earthquakes}. It's practically their job."},
			{"speaker": "grub", "expr": "sad", "text": "Maybe it was nobody, love. Maybe the house did it. Houses can be cruel."},
			{"speaker": "bruno", "expr": "sad", "text": "Bruno lifted it. It was {very heavy}. Heavy things fall hard."},
		],
		"answer": {"statement": 0, "weak": 0, "drop": "fallen_bookcase"},
		"early": {
			"wall_anchor": "Those screws up on the cornice... I can't say yet when they came out. Let's start with what the bookcase itself shows.",
		},
		"missing": {"speaker": "bruno", "expr": "normal", "text": "Mochi. When Bruno lifted it, Bruno saw the bottom. It was a foot out from the wall, with scrapes behind. Here."},
		"wrong": [
			{"speaker": "reginald", "expr": "angry", "text": "Pah! That proves nothing about how a bookcase falls, citizen!"},
			{"speaker": "duchess", "expr": "angry", "text": "Darling, I asked how it fell, not what it fell on."},
		],
		"hint": "A bookcase that only tips over pivots on its base. Where was the base of this one this morning?",
	},
	# ------------------------------------------------------------------ 3. when did he die (free: the group settles either way)
	"c3_q_when": {
		"type": "choice",
		"free": true,
		"speaker": "reginald",
		"expr": "normal",
		"prompt": "Then let us establish the hour, citizen. When did Professor Nibs die?",
		"options": ["During the blackout, at 11:05", "Before the lights went out", "After the lights came back"],
		"option_flags": ["", "c3_said_before", "c3_said_after"],
		"answer": 0,
	},
	# ------------------------------------------------------------------ 4. roll call, 11:05 to 11:20
	"c3_roll_blackout": {
		"type": "roll_call",
		"title": "ROLL CALL",
		"speaker": "snapjaw",
		"prompt": "Lights out, 11:05 to 11:20! Who can vouch for whom? Pick the one who backs them up, or Nobody.",
		"entries": [
			{"guest": "duchess", "expr": "normal", "claim": "The Music Room, darlings. Pinning Lulu's hem in the pitch dark.", "answer": "lulu",
				"wrong": {"speaker": "duchess", "expr": "angry", "text": "Darling, I was pinning a gown. Who do you suppose was inside it?"}},
			{"guest": "lulu", "expr": "sad", "claim": "The fitting! Lulu stood SO still in the dark. The whole time!", "answer": "duchess",
				"wrong": {"speaker": "lulu", "expr": "sad", "text": "Lulu wasn't standing still for nobody! Somebody was sticking pins in Lulu!"}},
			{"guest": "zuzu", "expr": "sad", "claim": "attic. alone. in the dark. like a mushroom.", "answer": "nobody",
				"wrong": {"speaker": "zuzu", "expr": "normal", "text": "nobody was up there. i'd have noticed. it's my attic."}},
			{"guest": "bramble", "expr": "sad", "claim": "...my room... on my bed... I didn't move...", "answer": "nobody",
				"wrong": {"speaker": "bramble", "expr": "sad", "text": "...no... nobody was with me... Fennel had gone to his room by then..."}},
			{"guest": "fennel", "expr": "normal", "claim": "My room, mon ami, discussing my knee with my knee.", "answer": "nobody",
				"wrong": {"speaker": "fennel", "expr": "normal", "text": "Alas, I was alone with the knee. It is poor company and a worse witness."}},
			{"guest": "grub", "expr": "sad", "claim": "I don't know, love. The cellar? It went dark and white and loud.", "answer": "nobody",
				"wrong": {"speaker": "grub", "expr": "sad", "text": "You found me when the lights came back, Mochi. Not before. Nobody saw me before."}},
			{"guest": "pepper", "expr": "normal", "claim": "The Gallery, partner. Flash, flash, flash, all through the dark.", "answer": "nobody",
				"wrong": {"speaker": "pepper", "expr": "normal", "text": "Nobody else was in the Gallery. Just me and my flash."}},
		],
	},
	# ------------------------------------------------------------------ 5. the Duchess, publicly named
	"c3_debate_duchess": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["fitting_ticket", "ledger_read", "arm_no_bruise", "powder_record", "manual_injuries", "door_scratches"],
		"statements": [
			{"speaker": "reginald", "expr": "angry", "text": "Plum's line, read aloud, and HIS name on it! She {sat alone in her room all night} with that grudge!"},
			{"speaker": "lulu", "expr": "sad", "text": "The Duchess said such horrible things to him. At breakfast. At dinner. Every day."},
			{"speaker": "duchess", "expr": "angry", "text": "I said dreadful things, darlings. {Saying is not shoving}."},
			{"speaker": "zuzu", "expr": "normal", "text": "she's strong enough. have you seen her hats. those are structural."},
		],
		"answer": {"statement": 0, "weak": 0, "drop": "fitting_ticket"},
		"early": {
			"arm_no_bruise": "His arm... I keep thinking about his arm. But I can't make that say anything yet. Not on its own.",
			"manual_injuries": "Marigold's manual. I know what it says. I can't put it next to anything yet. Let me come back to it.",
		},
		"missing": {"speaker": "lulu", "expr": "sad", "text": "Mochi... the Duchess wrote a ticket for Lulu's fitting. It's pinned to the gown. Lulu has it here."},
		"wrong": [
			{"speaker": "reginald", "expr": "angry", "text": "Irrelevant! A lady alone with a grudge is a lady alone with a grudge!"},
			{"speaker": "duchess", "expr": "sad", "text": "Darling, if that's your defence of me I'd rather hang."},
		],
		"hint": "Reginald says she was alone all night. Was she? Where was she supposed to be at half past ten?",
	},
	# ------------------------------------------------------------------ 6. Reginald's "patrol", and his accusation
	"c3_debate_reginald": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["generator_log", "watch_roster", "bat_bite", "arm_no_bruise", "manual_injuries", "nibs_blotter"],
		"statements": [
			{"speaker": "reginald", "expr": "angry", "text": "When the lights went, I was {on patrol upstairs}, alone, as a night watchman should be!"},
			{"speaker": "reginald", "expr": "angry", "text": "Whereas Brawnsworth sat down there in the dark with nobody to see him!"},
			{"speaker": "bruno", "expr": "sad", "text": "Bruno was with the generator. Bruno said so."},
			{"speaker": "zuzu", "expr": "normal", "text": "nobody's believed the patrol since day three. you're {asleep by half ten}."},
			{"speaker": "reginald", "expr": "angry", "text": "RESTING. MY. EYES."},
		],
		"answer": {"statement": 0, "weak": 0, "drop": "generator_log"},
		"early": {
			"arm_no_bruise": "His arm. No. Not yet. First I want to know where everybody really was.",
			"manual_injuries": "Marigold's manual... not yet. Where Reginald really was comes first.",
			"watch_roster": "His roster says he was on watch, every night. It says that because he writes it. I need something he didn't write.",
		},
		"missing": {"speaker": "bruno", "expr": "normal", "text": "Mochi. The generator book. Bruno brought it. Bruno writes in it every night."},
		"wrong": [
			{"speaker": "reginald", "expr": "angry", "text": "That says nothing whatever about my patrol!"},
			{"speaker": "reginald", "expr": "angry", "text": "A Puddlesworth's word is his bond, citizen. That is no bond-breaker."},
		],
		"hint": "Reginald says he was upstairs at 11:05. Somebody wrote down exactly who was where at 11:05. Somewhere hot and loud.",
	},
	# ------------------------------------------------------------------ 7. Zuzu's row (with the Attic screen's log)
	"c3_debate_zuzu": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["packet_log", "dead_camera", "door_scratches", "ledger_read", "bat_bite", "arm_no_bruise"],
		"statements": [
			{"speaker": "lulu", "expr": "sad", "text": "Zuzu shouted at him. Lulu heard about it. Everybody heard about it."},
			{"speaker": "duchess", "expr": "angry", "text": "They {went straight back into that Library} after the row, darlings, and finished it."},
			{"speaker": "zuzu", "expr": "angry", "text": "i went UP. to the attic. i never went back. not till the coffee."},
			{"speaker": "grub", "expr": "sad", "text": "Don't fight, loves. Please don't fight. He hated it when we fought."},
		],
		"answer": {"statement": 1, "weak": 0, "drop": "packet_log"},
		"early": {
			"arm_no_bruise": "His arm... no. Not yet. Where Zuzu went after the row first.",
		},
		"wrong": [
			{"speaker": "duchess", "expr": "angry", "text": "Darling, that's a gadget, not an answer."},
			{"speaker": "zuzu", "expr": "sad", "text": "...that doesn't help me, mochi."},
		],
		"hint": "Zuzu says they went up to the Attic and stayed there. Is there anything up there that keeps time by itself?",
	},
	# without the Attic screen's log, Mochi answers from what she saw on the stairs
	"c3_q_zuzu_stairs": {
		"type": "choice",
		"speaker": "duchess",
		"expr": "angry",
		"prompt": "Mochi, you were sitting right there on the stairs, darling. Where did Zuzu go after that row?",
		"options": ["Back into the Library", "Up the back stairs, towards the Attic", "Down to the kitchen"],
		"answer": 1,
		"wrong": {"speaker": "zuzu", "expr": "angry", "text": "no. you SAW me. i walked right past you."},
	},
	# ------------------------------------------------------------------ 8. Zuzu goes for Pepper
	"c3_debate_pepper": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["photo_roll", "gallery_grate", "ledger_read", "gallery_clock", "arm_no_bruise", "manual_injuries"],
		"statements": [
			{"speaker": "zuzu", "expr": "angry", "text": "your name's on my mum's line. you {came over in the dark} and pushed it on him before he could prove it."},
			{"speaker": "zuzu", "expr": "angry", "text": "and the gallery grate's full of ash. a typed corner. the samples. that's your fireplace."},
			{"speaker": "pepper", "expr": "shock", "text": "I was shooting the dark in the Gallery, partner! My pictures {say exactly where I was}!"},
			{"speaker": "reginald", "expr": "normal", "text": "Then the lady's photographs must speak for her. Do they?"},
		],
		"answer": {"statement": 0, "weak": 0, "drop": "photo_roll"},
		"early": {
			"gallery_clock": "The clock on the Gallery hearth... I don't know what it tells me yet. Not about this.",
			"arm_no_bruise": "His arm. Not yet. Where Pepper was in the dark comes first.",
			"manual_injuries": "Marigold's manual... not yet. First, the dark.",
		},
		"missing": {"speaker": "fennel", "expr": "normal", "text": "Mochi, the prints on the line in Pepper's darkroom. I took them down, before they curled. Look."},
		"wrong": [
			{"speaker": "zuzu", "expr": "angry", "text": "that's not where she was. show me where she was."},
			{"speaker": "pepper", "expr": "sad", "text": "Partner, that's not helping me. Or anybody."},
		],
		"hint": "Pepper says her pictures show where she was. Does she have any pictures from the dark?",
	},
	# ------------------------------------------------------------------ 9. first overturn: already dead
	"c3_q_dead_before": {
		"type": "present",
		"speaker": "fennel",
		"expr": "normal",
		"prompt": "Mochi, you have the face of a sum that won't come out. Two things, then. What is wrong with 'he died under the bookcase'?",
		"answer": ["arm_no_bruise", "manual_injuries"],
		"missing": {"speaker": "fennel", "expr": "normal"},
		"wrong": {"speaker": "fennel", "expr": "normal", "text": "Those two don't talk to each other, mon ami. What did his body show, and what does a body ever show?"},
	},
	# ------------------------------------------------------------------ 10. the tea
	"c3_q_tea": {
		"type": "present",
		"speaker": "duchess",
		"expr": "normal",
		"prompt": "Then what DID he have last night, darling? And how did it get to a man behind a bolted door?",
		"answer": ["tray_grains", "bell_tape"],
		"missing": {"speaker": "grub", "expr": "sad"},
		"wrong": {"speaker": "duchess", "expr": "normal", "text": "No, darling. Something he drank. And something that says how it got up there."},
	},
	# ------------------------------------------------------------------ 11. Reginald accuses Grub
	"c3_debate_grub": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["manual_illness", "grub_soup", "door_scratches", "tray_grains", "powder_record", "generator_log"],
		"statements": [
			{"speaker": "reginald", "expr": "angry", "text": "His kitchen! His tray! His tea! And he {pretends he can't remember} a single minute of it!"},
			{"speaker": "reginald", "expr": "angry", "text": "Scratches on the Library door in rows of four, and splinters under his claws!"},
			{"speaker": "grub", "expr": "sad", "text": "I don't know. I don't KNOW, love. Maybe I did. Maybe I did it."},
			{"speaker": "bruno", "expr": "angry", "text": "Grub was with Bruno at half past nine! Bruno said!"},
			{"speaker": "lulu", "expr": "sad", "text": "Grub wouldn't. Grub... Grub wouldn't..."},
		],
		"answer": {"statement": 0, "weak": 0, "drop": "manual_illness"},
		"missing": {"speaker": "bruno", "expr": "sad", "text": "Mochi. Bruno read Marigold's book too. The page with the corner down. Bruno brought it."},
		"wrong": [
			{"speaker": "reginald", "expr": "angry", "text": "That only shows he's a poor cook, citizen! It hardly excuses him!"},
			{"speaker": "grub", "expr": "sad", "text": "That doesn't help, love. Nothing helps."},
		],
		"hint": "Reginald says Grub is pretending. Is there a reason a capybara might lose whole hours without pretending at all?",
	},
	"c3_bubbles_sick": {
		"type": "bubbles",
		"prompt": "Shaking paws, lost hours, a horror of water... Grub isn't scheming. Grub is ___.",
		"answer": "SICK",
		"decoys": "LYAMNET",
		"time": 60.0,
	},
	# ------------------------------------------------------------------ 12. who sent the tray
	"c3_q_tray_who": {
		"type": "present",
		"speaker": "reginald",
		"expr": "angry",
		"prompt": "Very well! If not the cook, then who sent up that tray? Two things, citizen, or sit down!",
		"answer": ["pantry_glitter", "lulu_tin"],
		"missing": {"speaker": "bramble", "expr": "sad"},
		"wrong": {"speaker": "reginald", "expr": "angry", "text": "Who touched the rope, and where did the powder come from? Those are the questions!"},
	},
	# ------------------------------------------------------------------ 13. "her tea killed him"
	"c3_debate_tea": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["powder_record", "nibs_blotter", "lulu_tin", "tray_grains", "bait_tin", "manual_illness"],
		"statements": [
			{"speaker": "lulu", "expr": "sad", "text": "Two pinches. Lulu put two pinches in the pot. Lulu killed him."},
			{"speaker": "reginald", "expr": "angry", "text": "The powder {stopped his heart}, and the bookcase fell on a dead man!"},
			{"speaker": "duchess", "expr": "shock", "text": "My powder. My own powder, out of my own tin. Oh, Lulu."},
			{"speaker": "pepper", "expr": "sad", "text": "Lulu, why? Why would you even...?"},
			{"speaker": "lulu", "expr": "sad", "text": "So he'd sleep! Just sleep! Past midnight! So he wouldn't find out!"},
		],
		"answer": {"statement": 1, "weak": 0, "drop": "powder_record"},
		"early": {
			"nibs_blotter": "His blotter, yes. He was still writing at five past ten. But first: could two pinches ever do it?",
		},
		"missing": {"speaker": "duchess", "expr": "sad", "text": "Mochi. Marigold's card. Taped in her cabinet. I've read it a hundred times. Here."},
		"wrong": [
			{"speaker": "reginald", "expr": "angry", "text": "Poppycock! Powder is powder!"},
			{"speaker": "lulu", "expr": "sad", "text": "Mochi, please. Lulu did it. Lulu DID it."},
		],
		"hint": "Lulu put in two pinches. Marigold wrote down exactly what two pinches do.",
	},
	# ------------------------------------------------------------------ 14. someone came back
	"c3_q_came_back": {
		"type": "present",
		"speaker": "zuzu",
		"expr": "normal",
		"prompt": "where's the cup. and how did anyone get it, with the door bolted? two things.",
		"answer": ["cup_ring", "passage_door"],
		"early": {
			"passage_tracks": "The prints in the passage... I can't say what they mean yet. First: did anybody come back at all, and how?",
		},
		"missing": {"speaker": "bruno", "expr": "normal"},
		"wrong": {"speaker": "zuzu", "expr": "normal", "text": "no. where the cup was, and a way in that isn't the door."},
	},
	# ------------------------------------------------------------------ 15. whose trail
	"c3_q_trail": {
		"type": "present",
		"speaker": "reginald",
		"expr": "normal",
		"prompt": "A passage in the wall! Then somebody walked it after the aftershock. What did they leave behind them?",
		"answer": "shawl_hem",
		"early": {
			"passage_tracks": "The prints... yes. But they don't say whose. Something else in there does.",
		},
		"missing": {"speaker": "fennel", "expr": "normal", "text": "Mochi, I went in after you with the lamp. On a splinter by the skirting, look: threads. I kept one."},
		"wrong": {"speaker": "reginald", "expr": "normal", "text": "No, no. Something they left in the passage itself, citizen!"},
	},
	"c3_q_trail_who": {
		"type": "character",
		"speaker": "reginald",
		"expr": "normal",
		"prompt": "A trailing hem, and lilac silk. Whose trail is it?",
		"answer": "duchess",
		"exclude": ["mochi"],
		"wrong": {"speaker": "reginald", "expr": "normal", "text": "Lilac, citizen. Who in this house dresses in lilac from her ears to her hem?"},
	},
	# ------------------------------------------------------------------ 16. the Duchess denies everything
	"c3_rebuttal_duchess": {
		"type": "rebuttal",
		"opponent": "duchess",
		"intro": "Passages? Threads? Darlings, I have never been so insulted, and I have been to the opera.",
		"lines": [
			"I was in my room hunting pins, and then in the Music Room, and then in BED!",
			"Half this house wears lilac. Lulu's gown is lilac. The curtains are lilac!",
			"A Velveteen does not crawl about inside walls like a mouse!",
			"I hated that man. I'd have done it to his face, in daylight, with a hatpin!",
		],
		"final": {
			"text": "Prove {it was MY hat in that passage}, or apologise!",
			"drops": ["hat_feather", "shawl_hem", "passage_door", "music_box", "fitting_ticket", "passage_tracks"],
			"answer": "hat_feather",
		},
		"early": {
			"passage_tracks": "The prints... no. They say somebody went there and back. They don't say whose hat it was.",
		},
		"missing": {"speaker": "lulu", "expr": "sad", "text": "Mochi... the feather. On the bracket over the little door. Lulu saw it up there this morning. Lulu brought it. Here."},
		"wrong": [
			{"speaker": "duchess", "expr": "happy", "text": "Ha! That's a thread, darling, not a hat."},
			{"speaker": "duchess", "expr": "angry", "text": "That says nothing about MY hat! Try again, or apologise!"},
		],
		"time_per_line": 2.6,
	},
	# ------------------------------------------------------------------ 17. the offer: the only early vote in the case
	"c3_q_vote_offer": {
		"type": "choice",
		"speaker": "snapjaw",
		"expr": "happy",
		"prompt": "A grudge, a door in the wall, a lilac trail and a snapped feather! Shall I open the vote? Right now? Go on!",
		"options": ["Vote now", "Run it through once more, from the top"],
		"answer": 1,
		"vote_option": 0,
		"wrong": {"speaker": "snapjaw", "expr": "happy", "text": "Ooh, so careful! Fine, fine."},
	},
	# ------------------------------------------------------------------ 18. the Rewind that jams on panel 4
	"c3_rewind_false": {
		"type": "rewind",
		"title": "CASE REWIND",
		"panels": [
			{"caption": "In the afternoon, someone climbed the Library ladder and took the six ___ out of the bookcase's wall brace.",
				"options": ["screws", "books", "candles"], "answer": 0, "bg": "manor_library"},
			{"caption": "At 9:55 Lulu sent a pot of tea up the dumbwaiter, with two pinches of the Duchess's ___ in it.",
				"options": ["sugar", "sleeping powder", "rat-bait"], "answer": 1, "bg": "manor_pantry"},
			{"caption": "At 10:30 the Duchess went to the Music Room for Lulu's ___, and stayed there until 11:30.",
				"options": ["singing lesson", "concert", "fitting"], "answer": 2, "bg": "manor_music"},
			{"caption": "Before the fitting, she slipped through the ___ behind the tapestry and killed him at his desk.",
				"options": ["servants' passage", "Library door", "dumbwaiter"], "jam": true, "jam_text": "IT DOESN'T FIT!", "bg": "manor_passage"},
			{"caption": "At 11:45 she came back the same way for the ___ that smelled of her powder.",
				"options": ["teacup", "teapot", "tin"], "answer": 0, "bg": "manor_library_after"},
			{"caption": "And at seven she stood at the back of the crowd, in her ___, as if nothing had happened.",
				"options": ["hat", "dressing gown", "gloves"], "answer": 0, "bg": "manor_library_after"},
		],
		"culprit": "duchess",
		"finale": "And the capybara who walked inside the walls... is YOU, the Duchess Velveteen!",
	},
	"c3_q_tracks": {
		"type": "present",
		"speaker": "snapjaw",
		"expr": "angry",
		"prompt": "STOP! Why does my lovely reel stick? What's wrong with panel four? Two things, Mochi. Quickly!",
		"answer": ["passage_tracks", "rules3"],
		"missing": {"speaker": "fennel", "expr": "normal"},
		"wrong": {"speaker": "snapjaw", "expr": "angry", "text": "Wrong, wrong! What's on that passage floor, and when did it get there?"},
	},
	# ------------------------------------------------------------------ 20. it wasn't the tea
	"c3_q_not_tea": {
		"type": "present",
		"speaker": "reginald",
		"expr": "angry",
		"prompt": "Then it was the tea after all! The cup! What else is there? Two things, citizen!",
		"answer": ["nibs_cup", "nibs_sheet"],
		"wrong": {"speaker": "reginald", "expr": "angry", "text": "The cup itself, and what HE wrote about it! He was a man of notes!"},
	},
	# ------------------------------------------------------------------ 21. "nobody could have reached him"
	"c3_debate_reach": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["nibs_mouth", "scene_photos", "bell_tape", "passage_tracks", "tray_grains", "nibs_sheet"],
		"statements": [
			{"speaker": "reginald", "expr": "angry", "text": "The door was bolted from inside. Mochi's own photograph says so!"},
			{"speaker": "zuzu", "expr": "normal", "text": "one trip up the dumbwaiter all night. that was the tea. that's it."},
			{"speaker": "lulu", "expr": "sad", "text": "And nobody came through the wall until after... after he already..."},
			{"speaker": "grub", "expr": "sad", "text": "And everybody ate out of my one pot. One loaf. One ladle."},
			{"speaker": "duchess", "expr": "angry", "text": "So {nothing could ever have got into him}, and he died anyway! Of spite, I expect!"},
		],
		"answer": {"statement": 4, "weak": 0, "drop": "nibs_mouth"},
		"early": {
			"nibs_sheet": "His last line says it, yes. But look at him first. What did his own mouth show this morning?",
		},
		"missing": {"speaker": "zuzu", "expr": "sad", "text": "his mouth. his teeth. i was right there. black, like ink. i can't stop seeing it."},
		"wrong": [
			{"speaker": "duchess", "expr": "angry", "text": "Darling, that's a way IN. I'm telling you there wasn't one."},
			{"speaker": "reginald", "expr": "angry", "text": "That's the room, citizen! I'm talking about the man!"},
		],
		"hint": "Nothing came in from outside. What had he got with him, all evening, that went into his mouth?",
	},
	# ------------------------------------------------------------------ 22. the pen on the floor
	"c3_q_floor_pen": {
		"type": "present",
		"speaker": "fennel",
		"expr": "normal",
		"prompt": "The pen on the floor, then. Something about it bothers you, Mochi. What? Two things.",
		"answer": ["desk_contents", "pen_case"],
		"missing": {"speaker": "zuzu", "expr": "sad"},
		"wrong": {"speaker": "fennel", "expr": "normal", "text": "No, no. The pen itself, mon ami. And every other pen he ever had."},
	},
	# ------------------------------------------------------------------ 23. what killed him
	"c3_q_what_killed": {
		"type": "present",
		"speaker": "bruno",
		"expr": "normal",
		"prompt": "So where is his real pen? And what was on it? Two things, Mochi.",
		"answer": ["shaft_pen", "bait_tin"],
		"missing": {"speaker": "grub", "expr": "sad"},
		"wrong": {"speaker": "bruno", "expr": "sad", "text": "Bruno does not think so. Where is the chewed one? And what tastes of liquorice?"},
	},
	# ------------------------------------------------------------------ 24. Bramble's gloves
	"c3_debate_bramble": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["dinner_sketch", "bait_tin", "burned_glove", "conservatory_sketch", "shaft_pen", "watch_roster"],
		"statements": [
			{"speaker": "lulu", "expr": "angry", "text": "Bramble lays the bait! For the rats! In her gardening gloves!"},
			{"speaker": "reginald", "expr": "angry", "text": "The Conservatory tin has been scooped at, and the Conservatory is hers!"},
			{"speaker": "bramble", "expr": "sad", "text": "...for Grub's kitchen... I wore my gloves... I washed my paws three times..."},
			{"speaker": "lulu", "expr": "angry", "text": "And at dinner she {slipped out to the hooks} and dabbed it on his pen!"},
		],
		"answer": {"statement": 3, "weak": 0, "drop": "dinner_sketch"},
		"missing": {"speaker": "fennel", "expr": "sad", "text": "Mochi. My strip from dinner. You'll want it now. Every square, with the clock in it."},
		"wrong": [
			{"speaker": "lulu", "expr": "angry", "text": "That doesn't change anything! It was HER bait!"},
			{"speaker": "reginald", "expr": "angry", "text": "Pah! Gardening is no alibi!"},
		],
		"hint": "Lulu says Bramble slipped out to the hooks at dinner. Who kept a record of every chair that was ever empty?",
	},
	# ------------------------------------------------------------------ 25. when, and who left the table
	"c3_time_hooks": {
		"type": "time_pick",
		"title": "WHEN COULD IT BE DONE?",
		"speaker": "snapjaw",
		"expr": "happy",
		"prompt": "Set the window, Mochi! From the first moment anybody could get at that pen, to the last!",
		"from": "4:30 PM",
		"to": "12:30 AM",
		"step": 5,
		"answer": ["8:05 PM", "9:15 PM"],
		"wrong": {"speaker": "snapjaw", "expr": "happy", "text": "Ooh, no. When did he hang it up, and when did he take it back down?"},
	},
	"c3_who_left": {
		"type": "character",
		"speaker": "snapjaw",
		"expr": "happy",
		"prompt": "And who left the table in that window? Name every one, darling. Every single one!",
		"answers": ["reginald", "lulu", "pepper", "zuzu", "grub"],
		"exclude": ["mochi"],
		"wrong": {"speaker": "snapjaw", "expr": "happy", "text": "Not quite! Count the empty chairs again. Fennel drew every one."},
	},
	# ------------------------------------------------------------------ 26. the two frames, and who could reach the far wall
	"c3_frames_pick": {
		"type": "evidence",
		"clue": "scene_photos",
		"speaker": "pepper",
		"expr": "normal",
		"prompt": "Find the last frame where the hatch is still shut, partner, and the first one where it's open.",
		"answers": [8, 11],
		"wrong": {"speaker": "pepper", "expr": "normal", "text": "Not that one. The LAST frame with the hatch shut, partner, and the FIRST with it open. The little door with SERVICE over it."},
	},
	"c3_who_reach": {
		"type": "character",
		"speaker": "snapjaw",
		"expr": "happy",
		"prompt": "Between frame 9 and frame 12, who could have crossed to that far wall? Pick them all!",
		"answers": ["duchess", "bramble", "pepper"],
		"exclude": ["mochi"],
		"wrong": {"speaker": "snapjaw", "expr": "happy", "text": "Tsk! Anyone in both frames, in the same spot, stayed put. And who wasn't even in the room yet?"},
	},
	# ------------------------------------------------------------------ 27. why bring a spare
	"c3_q_spare": {
		"type": "present",
		"speaker": "duchess",
		"expr": "normal",
		"prompt": "Darling, anyone might grab a clean pen off his box and swap it in a panic. Why does it have to be planned?",
		"answer": "scene_photos",
		"missing": {"speaker": "zuzu", "expr": "normal", "text": "the photos. frame 3. look at his pen box."},
		"wrong": {"speaker": "duchess", "expr": "normal", "text": "No, darling. When did that clean pen leave his box? Is there a picture of the box?"},
	},
	# ------------------------------------------------------------------ 28. "Zuzu was closest to him"
	"c3_debate_zuzu2": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["scene_photos", "packet_log", "dead_camera", "desk_contents", "photo_roll", "nibs_sheet"],
		"statements": [
			{"speaker": "pepper", "expr": "normal", "text": "Wait, wait. Zuzu {was closest to him the whole time}. Right there, by the desk, by everything!"},
			{"speaker": "zuzu", "expr": "angry", "text": "i was holding his paw."},
			{"speaker": "pepper", "expr": "normal", "text": "And Zuzu left the table at 9:05. That's on both lists, partner!"},
			{"speaker": "reginald", "expr": "normal", "text": "I confess the lady has a point."},
		],
		"answer": {"statement": 0, "weak": 0, "drop": "scene_photos"},
		"missing": {"speaker": "bruno", "expr": "sad", "text": "Mochi. The photographs. Bruno is in them, holding up the shelf. Zuzu is too."},
		"wrong": [
			{"speaker": "pepper", "expr": "normal", "text": "That doesn't move Zuzu an inch from that desk, partner."},
			{"speaker": "zuzu", "expr": "angry", "text": "mochi. come on."},
		],
		"hint": "Pepper says Zuzu was closest. Closest to the body, yes. Was Zuzu ever anywhere near the far wall?",
	},
	# ------------------------------------------------------------------ 29. "the artist isn't in his own sketch"
	"c3_debate_fennel": {
		"type": "debate",
		"title": "SPLASH DEBATE",
		"drops": ["dinner_sketch", "scene_photos", "conservatory_sketch", "watch_roster", "photo_roll", "bait_tin"],
		"statements": [
			{"speaker": "pepper", "expr": "normal", "text": "Then what about the artist? He's not in his own sketches either, is he?"},
			{"speaker": "pepper", "expr": "normal", "text": "He could have {hopped out to the hooks} between squares and never drawn it!"},
			{"speaker": "fennel", "expr": "angry", "text": "Hopped? HOPPED? Madame, I have one working leg and a stick."},
			{"speaker": "bramble", "expr": "sad", "text": "...he wouldn't... he was sitting next to Mochi..."},
		],
		"answer": {"statement": 1, "weak": 0, "drop": "dinner_sketch"},
		"early": {
			"scene_photos": "He's in both frames, yes, by the door. But Pepper's asking about dinner. What shows he never left the table?",
		},
		"wrong": [
			{"speaker": "pepper", "expr": "normal", "text": "Doesn't keep him in his chair, partner."},
			{"speaker": "fennel", "expr": "angry", "text": "Mochi! I am being slandered by a camera!"},
		],
		"hint": "Pepper says Fennel could have slipped out between squares. Whose chair was his crutch leaning on all through dinner?",
	},
	# ------------------------------------------------------------------ 30. third overturn: the truth's in the timestamps
	"c3_q_timestamp": {
		"type": "present",
		"speaker": "pepper",
		"expr": "normal",
		"prompt": "I was in the Gallery, partner. Check the stamp. The truth's in the timestamps. ...Isn't it?",
		"answer": ["photo_roll", "gallery_clock"],
		"missing": {"speaker": "fennel", "expr": "normal"},
		"wrong": {"speaker": "pepper", "expr": "normal", "text": "That's not a timestamp, partner. Check the stamp. Check it against something."},
	},
	# ------------------------------------------------------------------ 31. who moved the pen
	"c3_q_who_moved": {
		"type": "character",
		"speaker": "snapjaw",
		"expr": "happy",
		"prompt": "Then say it, Mochi! Who poisoned his pen, and moved it at seven o'clock?",
		"answer": "pepper",
		"exclude": ["mochi"],
		"wrong": {"speaker": "snapjaw", "expr": "happy", "text": "Oh, no no no. Left the table, out of both frames, and a clock that lies. Who?"},
	},
	# ------------------------------------------------------------------ 32. "prove I touched that pen"
	"c3_rebuttal_pepper": {
		"type": "rebuttal",
		"opponent": "pepper",
		"intro": "Partner. You know me. Facts first. So let's have some facts.",
		"lines": [
			"I was taking pictures! That's all I ever do at a body!",
			"My camera was in both paws the whole time. Click, wind, click, wind!",
			"Anybody could have walked behind me in that crowd!",
			"A clock on a wall isn't a fact. It's furniture!",
		],
		"final": {
			"text": "Prove {I ever touched that pen}, partner. One fact. Just one.",
			"drops": ["scene_photos", "shaft_pen", "desk_contents", "dinner_sketch", "photo_roll", "gallery_clock"],
			"answer": "scene_photos",
		},
		"missing": {"speaker": "zuzu", "expr": "angry", "text": "her own roll. frames 9 to 12. look where she was standing."},
		"wrong": [
			{"speaker": "pepper", "expr": "normal", "text": "That's about the pen, partner. Not about me."},
			{"speaker": "pepper", "expr": "sad", "text": "One fact, Mochi. You've got everything except that one."},
		],
		"time_per_line": 2.5,
	},
	# ------------------------------------------------------------------ 33. why
	"c3_q_why": {
		"type": "present",
		"speaker": "bruno",
		"expr": "sad",
		"prompt": "Why, Mochi? Why Pepper? Bruno does not understand. Bruno needs to understand. Two things.",
		"answer": ["nibs_sheet", "old_puddle"],
		"missing": {"speaker": "grub", "expr": "sad"},
		"wrong": {"speaker": "bruno", "expr": "sad", "text": "No. What did the Professor find out? And what was he looking for, on Day 4?"},
	},
	# ------------------------------------------------------------------ 34. closing argument
	"c3_rewind_final": {
		"type": "rewind",
		"title": "CASE REWIND",
		"panels": [
			{"caption": "Between 4:30 and 5:40, while he watched the tide, the culprit took the six ___ out of the bookcase's brace, and one new pen from his box.",
				"options": ["screws", "books", "hinges"], "answer": 0, "bg": "manor_library"},
			{"caption": "At about twenty past five, in the Gallery, she set her camera's ___ to 8:52 and shot two frames with the mantel clock behind her.",
				"options": ["flash", "date-back", "lens cap"], "answer": 1, "bg": "manor_gallery"},
			{"caption": "At 8:05 he chewed his pen, pocketed it and hung his coat on the ___, as he did every night.",
				"options": ["hooks", "back of his chair", "Library door"], "answer": 0, "bg": "manor_cloakroom"},
			{"caption": "At 8:50 she left the table 'to change her film', and smeared Snapjaw's aniseed ___ on the chewed end of his pen.",
				"options": ["sleeping powder", "moustache wax", "rat-bait paste"], "answer": 2, "bg": "manor_cloakroom"},
			{"caption": "At 9:15 he walked out chewing. Behind his bolted door his tongue went numb at 10:14, and he died long before the ___.",
				"options": ["tea arrived", "11:05 aftershock", "fitting began"], "answer": 1, "bg": "manor_library"},
			{"caption": "At seven, while Bruno lifted the bookcase and every eye was on it, she crossed the room and swapped his chewed pen for the ___ one.",
				"options": ["broken", "red", "new"], "answer": 2, "bg": "manor_library_after"},
			{"caption": "She slid the chewed pen down the dumbwaiter ___, and kept shooting, so the roll showed every face in the room but hers.",
				"options": ["shaft", "chimney", "drain"], "answer": 0, "bg": "manor_pantry"},
		],
		"culprit": "pepper",
		"finale": "And the one face that never appears in her own pictures... is YOURS, Pepper Quill, the Ace Journalist!",
	},
	# ------------------------------------------------------------------ 35. the vote
	"c3_vote_final": {
		"type": "vote",
		"culprit": "pepper",
		"fallback": "duchess",
		"threshold": 70.0,
	},
	# the vote Snapjaw offers at 17: taken before the case is finished, it is always the wrong answer
	"c3_vote_early": {
		"type": "vote",
		"culprit": "pepper",
		"fallback": "duchess",
		"threshold": 70.0,
		"false_vote": true,
	},
}

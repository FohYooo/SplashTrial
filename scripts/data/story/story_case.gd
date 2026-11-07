extends RefCounted
## Case scripts: investigation snippets, investigation_end and the Splash Trial.
## DSL reference: docs/ARCHITECTURE.md section 3. Story bible: docs/DESIGN.md.
##
## Investigation snippets play as a transparent auto_portrait overlay on top of the room
## (no @bg / @show). The investigation screen sets flag "seen_<script id>" after a snippet
## finishes, so every snippet starts with "@ifnot seen_<id> -> first": the short revisit
## reminder comes first, then "@label first" + the first-time path. Every path shows at
## least one line before @end (so hosts that await `finished` never miss the signal).
## Clues are re-given on revisits (silently skipped if already owned).
##
## Branches use @ifnot on purpose: it behaves correctly even if the flag value is truthy
## and the player's truthiness check errors out (the command then just falls through,
## which is exactly the "don't jump" case for @ifnot). Same for the vote verdict below.

const SCRIPTS := {
	# =====================================================================================
	# INVESTIGATION - start / complete
	# =====================================================================================
	"investigation_start": """
@card INVESTIGATION | Find the truth for Captain Coco
think: Coco... Just last night she was laughing so loud at dinner that the plates rattled.
think: And now she's gone. Crying won't help her. Finding the truth will.
think: Somebody in this resort did this to her. I'm going to find out who.
@clue rules
@clue snapjaw_file
think: Snapjaw's File and the Resort Rules are in my notebook. Now I need more *Truth Drops*.
narr: TIP: Click the *glowing* objects and people in each room to investigate them.
narr: TIP: Use the *Map* to move between rooms. Press *Esc* at any time to open your notebook of Truth Drops.
think: Every Truth Drop I find is ammo for the trial. I can't afford to miss a single one.
@end
""",
	"investigation_complete": """
@sfx chime
think: Wait. Let me go over everything one more time...
think: The watch. The cushions. The bucket. The headband. The sauna log. The glitter. The thread. The photo...
think: I don't have every answer yet. But I think I have every piece.
think: Hang on, Coco. Whoever did this is going to have to face the truth.
@end
""",
	# =====================================================================================
	# YUZU BATH (bg bath_body) - people: marigold (right), bruno (left)
	# =====================================================================================
	"inv_enter_bath": """
@ifnot seen_inv_enter_bath -> first
think: The Yuzu Bath. The steam still hasn't cleared.
@end
@label first
@sfx splash
narr: Steam curls over the Yuzu Bath. In the pale morning light, everything looks wrong.
think: A perfect outdoor hot spring. The kind of place I've loved my whole life...
think: And Captain Coco is floating in it. Marigold and Bruno haven't left the edge.
think: Focus, Mochi. Look at everything, carefully. Coco deserves that much.
@end
""",
	"inv_bath_body": """
@ifnot seen_inv_bath_body -> first
think: Coco's waterproof watch cracked and stopped at 9:47. That must be when she fell.
@clue coco_watch
@end
@label first
narr: Captain Coco floats face-down among the yuzu. Her white captain's hat drifts beside her.
think: Coco... I'm so sorry. Please forgive me for looking.
marigold[sad]: I already checked her, Mochi. One heavy bump on the back of her head. No other injuries at all.
think: Her gold watch chain is trailing in the water. Her pocket watch is still clipped to it.
narr: The watch's glass is cracked like a spiderweb. Its hands are frozen in place.
think: It stopped at *9:47*...
bruno[sad]: Captain showed Bruno that watch. Waterproof. She said it survived three shipwrecks.
think: Then the water didn't stop it. Something hit it hard enough to crack the glass. Like the bath floor, when she fell.
@clue coco_watch
marigold[sad]: She always said that watch was tougher than any sailor. Oh, Captain...
@end
""",
	"inv_bath_cushion": """
@ifnot seen_inv_bath_cushion -> first
think: Foam on every single rock. Nobody could crack their head on these.
@clue cushion_edge
@end
@label first
narr: Every rock around the bath is wrapped in thick, squishy foam cushions.
think: Even the tiny pebbles have cushions. There's a label stitched on one: SAFETY FIRST! - Snapjaw.
@sfx poof
snapjaw[happy]: Do you like them? I'd hate for anyone to perish by some silly ACCIDENT. Where's the fun in that? Snap-snap-snap!
@sfx whoosh
think: And he's gone again. I hate when he does that.
narr: Mochi presses a paw into the foam. It squishes like a marshmallow.
think: There's nothing hard to hit your head on anywhere around this bath.
@clue cushion_edge
bruno[sad]: Bruno napped on those cushions once. Very soft. Like a cloud.
@end
""",
	"inv_bath_headband": """
@ifnot seen_inv_bath_headband -> first
think: Bruno's headband, set right beside Coco. He swears he left it on his hook.
@clue bruno_headband
@end
@label first
narr: A red headband lies on the cushioned edge, right beside where Coco is floating.
think: Red, with a big knot... Everybody in the resort knows this headband.
bruno[shock]: That is Bruno's headband! Why is it here?!
bruno[sad]: Bruno hung it on his hook in the changing room. Before sauna. Like always. Bruno did not bring it here!
think: It's dry. It never touched the water. Somebody set it down right here, neatly, where everyone would see it.
@clue bruno_headband
marigold[sad]: Bruno... I'm not accusing you. But you know how this looks.
bruno[sad]: Bruno knows. Bruno knows...
@end
""",
	"inv_bath_yuzu": """
@ifnot seen_inv_bath_yuzu -> first
think: Coco bathed at 9:45 every night. Anyone at dinner knew exactly where she'd be. And that she'd be alone.
@end
@label first
narr: Fresh yuzu bob gently on the water, bumping into each other with soft little knocks.
think: As an Ace Bath Connoisseur I can tell: perfect temperature, one yuzu per capybara. A flawless bath.
think: Coco called this bath her harbor. She soaked here every night at *9:45* sharp.
think: And everyone knew it. She announced it to the whole table at dinner...
@end
""",
	"inv_bath_lantern": """
@ifnot seen_inv_bath_lantern -> first
think: With this much steam, someone could pass the bath at night and never notice Coco.
@end
@label first
narr: A tall stone lantern stands at the far edge of the bath. Its candle has burned down to a stub.
think: From here, I can barely make out the changing room through all this steam.
think: At night, with only this lantern lit, you could walk right past the bath and never see anyone in the water.
marigold[normal]: The steam is always thickest at night. It's lovely for the skin. Terrible for seeing anything.
@end
""",
	"inv_talk_marigold": """
@ifnot seen_inv_talk_marigold -> first
marigold[sad]: Bruno left by the front door at about 9:56, steaming hot. Nobody else. I'd swear to it.
@clue marigold_account
@end
@label first
marigold[sad]: Mochi... are you holding up? Sit down if you feel dizzy. Shock does strange things to blood pressure.
mochi: I'm okay. Marigold, did you see anything last night?
marigold[normal]: I was restocking the infirmary alone. I walked back to the guest wing at about *9:56*.
marigold[normal]: On the way I passed the bathhouse. Bruno came out of the front door, red-faced and steaming like a teapot.
marigold[sad]: He waved and walked off. I didn't see anybody else. Not a soul.
@clue marigold_account
marigold[sad]: As for Coco... a single blow to the back of the head. She was unconscious before she ever hit the water.
marigold[sad]: She didn't suffer. I keep telling myself that.
@end
""",
	"inv_talk_bruno": """
@ifnot seen_inv_talk_bruno -> first
bruno[sad]: Bruno was in the sauna the whole time. Headband was on the hook. Bruno does not understand...
@end
@label first
bruno[sad]: Mochi... Bruno did not hurt Captain. Bruno would never. Never ever.
mochi: I want to hear your side, Bruno. What happened last night?
bruno[normal]: Bruno went to sauna a little before 9:30. Hung lucky headband on hook first. Headband gets sweaty otherwise.
bruno[normal]: Bruno sat. Bruno sweated. Very relaxing. Bruno did not come out until the sand timer ran out.
bruno[sad]: When Bruno came out, headband was gone from hook. Bruno thought someone borrowed it. Bruno shrugged and went to bed.
mochi: You didn't see Coco on your way out?
bruno[sad]: Too much steam. Bruno went straight out the front door. Bruno did not even look at the bath...
bruno[sad]: If Bruno looked... maybe Bruno could have helped her.
@end
""",
	# =====================================================================================
	# CHANGING ROOM - people: reginald (right)
	# =====================================================================================
	"inv_enter_changing": """
@ifnot seen_inv_enter_changing -> first
think: The Changing Room. Reginald is still standing guard like a statue with a sword.
@end
@label first
@sfx door
narr: Rows of wooden lockers, a stack of bath buckets and a line of coat hooks. Warm air drifts in from the bath.
think: Anyone heading to the Yuzu Bath has to pass through here. Including whoever attacked Coco.
reginald[angry]: Halt! Who goes there?! Ah... it's only you, Mochi. I am guarding the scene. Somebody must.
@end
""",
	"inv_changing_lockers": """
@ifnot seen_inv_changing_lockers -> first
think: The cracked bucket was hidden behind these lockers. Silver-violet glitter on the handle.
@clue cracked_bucket
@end
@label first
narr: The lockers stand in neat rows along the wall. One of them sits slightly crooked, pulled away from the wall.
think: There's a gap behind it... Something is stuffed back there.
@sfx whoosh
narr: Mochi pulls out a wooden bath bucket. Its rim is cracked and badly dented.
think: This dent... it hit something hard. Or someone.
think: And the handle is speckled with glitter. Sparkly *silver-violet* glitter.
think: Silver and violet... I feel like I've seen sparkles exactly like this somewhere before.
@clue cracked_bucket
reginald[shock]: Great heavens! Is that... the instrument of the foul deed?!
reginald[angry]: Hidden behind a locker like a coward's dagger. Whoever did this has no honor whatsoever!
@end
""",
	"inv_changing_buckets": """
@ifnot seen_inv_changing_buckets -> first
think: Solid wooden buckets. One of them was taken from this stack.
@end
@label first
narr: A neat stack of wooden bath buckets, each one stamped with the Yuzu Springs crest.
think: They're heavy. Solid wood with metal bands. You could really hurt someone with one of these.
think: There's a damp ring on the floor beside the stack. As if one bucket was set down here, then taken away.
@ifnot seen_inv_changing_lockers -> notfound
think: That's where the cracked bucket behind the lockers came from. The culprit grabbed it right here.
@end
@label notfound
think: One bucket is missing from the stack... I wonder where it went.
@end
""",
	"inv_changing_hooks": """
@ifnot seen_inv_changing_hooks -> first
think: Bruno's hook is empty. Anybody passing through here could have grabbed that headband.
@end
@label first
narr: A row of coat hooks along the wall. One has a little red mark painted above it.
reginald[normal]: That is the brute's hook. Bruno hangs that ridiculous red rag of his there every evening before his sauna.
think: Bruno's hook... and it's empty now. Anyone walking through the changing room could have just taken the headband.
reginald[angry]: Bah! Or the brute carried it to the bath himself and dropped it in his haste. Simple!
think: Hmm. If Bruno attacked someone, would he really leave his own famous headband right next to her?
@end
""",
	"inv_changing_side_door": """
@ifnot seen_inv_changing_side_door -> first
think: The garden side door. Unlocked until Nighttime, and invisible from the front entrance.
@clue garden_door
@end
@label first
narr: In the corner, half hidden behind a folding screen, is a small wooden door.
@sfx door
think: It opens straight onto the garden stone path! I didn't even know this door was here.
think: You can't see it from the bathhouse's front entrance at all. Someone could come and go without being noticed.
narr: A single crushed rose petal is stuck to the doormat.
reginald[normal]: That old thing? Nobody uses it. Snapjaw locks it with everything else at Nighttime, I'm told.
think: Which means until ten o'clock last night... it was unlocked.
@clue garden_door
@end
""",
	"inv_talk_reginald": """
@ifnot seen_inv_talk_reginald -> first
reginald[angry]: I practiced alone in the gym. That is the plain truth, and I shall not dress it up in ribbons!
@end
@label first
reginald[angry]: Before you ask, Mochi: yes, I look suspicious. No, I did not do it. A Puddlesworth does not skulk!
mochi: Where were you last night, Reginald?
reginald[normal]: Until 9:30 I was fencing with Captain Coco in the gym. She had a fine wrist for a sailor. Fine indeed.
reginald[sad]: Then she left for her bath... and I stayed behind to practice alone. Lunge, parry, lunge...
mochi: Alone? So nobody can confirm where you were?
reginald[angry]: I say! Is a gentleman's word not enough?! ...No. I suppose it is not. Not in this wretched place.
reginald[angry]: But mark my words. That brute Bruno slipped out of his sauna. I would wager my finest plume on it!
think: Reginald has no alibi at all... and he's awfully eager to point at Bruno.
@end
""",
	# =====================================================================================
	# SAUNA - people: zuzu (left), nibs (right)
	# =====================================================================================
	"inv_enter_sauna": """
@ifnot seen_inv_enter_sauna -> first
think: The Sauna. Still roasting. Zuzu and Nibs are poking around by the door.
@end
@label first
narr: A wave of dry heat slaps Mochi in the face. Cedar benches, glowing stones and a little panel blinking by the door.
think: Phew! Bruno sat in here for almost half an hour? He really is the Ace Wrestler.
zuzu[normal]: sup. careful, it's like a thousand degrees in here.
nibs[normal]: Ninety degrees Celsius, to be precise. Hypothetically survivable. Practically miserable.
@end
""",
	"inv_sauna_panel": """
@ifnot seen_inv_sauna_panel -> first
zuzu[normal]: log says 9:28 and 9:56. nothing in between. that panel can't lie. it's too dumb to lie.
@clue sauna_log
@end
@label first
narr: A small safety panel by the sauna door, with a blinking screen and a tiny Snapjaw logo.
zuzu[normal]: oh that? door log. safety thing. it records every single time the door opens. found it yesterday.
zuzu[normal]: tried to hack it. read-only. can't edit, can't delete. skill issue on my part tbh.
mochi: So it shows when the door opened last night?
zuzu[happy]: yep. look.
narr: The screen reads: DOOR OPENED 9:28 PM. DOOR OPENED 9:56 PM. Nothing else.
think: *9:28*... that's when Bruno went in. And *9:56* is when he came out. The door never opened in between.
@clue sauna_log
nibs[normal]: Hypothetically, had anyone left the sauna between those times, the panel would have recorded it. Elegant.
@end
""",
	"inv_sauna_benches": """
@ifnot seen_inv_sauna_benches -> first
think: Bruno's sweaty outline is still on the top bench. He barely moved.
@end
@label first
narr: Cedar benches, worn smooth. There's a big, damp, capybara-shaped patch on the top bench.
think: That is... definitely Bruno-sized. He must have sat in one spot the whole time.
nibs[normal]: Fascinating. A capybara of Bruno's mass could sweat out two liters in half an hour.
think: Gross. But it fits. He really did sit in here for a long time.
@end
""",
	"inv_sauna_stove": """
@ifnot seen_inv_sauna_stove -> first
think: The sauna stove. Very hot, and not very helpful.
@end
@label first
narr: Hot stones hiss on top of an iron stove. A ladle rests in a little metal pail of water.
@sfx sizzle
think: Hot, hot, hot! This pail is metal. Not like the wooden buckets in the changing room.
zuzu[normal]: don't touch the rocks. i touched the rocks. do not recommend. 0 out of 10.
@end
""",
	"inv_talk_zuzu": """
@ifnot seen_inv_talk_zuzu -> first
zuzu[normal]: library with nibs. sauna log is legit. no cams on the garden path. that's all i got. gl.
@end
@label first
zuzu[sad]: hey mochi. rip coco. she was loud but like... the good kind of loud.
mochi: Where were you last night, Zuzu?
zuzu[normal]: library w/ nibs from dinner till nighttime. he explained capybara lung capacity for 40 minutes. i have trauma now.
zuzu[normal]: also poked at snapjaw's camera network. no cameras on the garden path. convenient ngl.
think: No cameras on the garden path... I'll remember that.
@end
""",
	"inv_talk_nibs": """
@ifnot seen_inv_talk_nibs -> first
nibs[normal]: Remember: five minutes of breath. Coco was unconscious before she went under. The only logical conclusion.
@end
@label first
nibs[normal]: Ah, Mochi. Hypothetically speaking, I should be in a lab. But a death demands data.
mochi: Where were you last night, Professor?
nibs[happy]: In the library with Zuzu, from dinner until Nighttime. I delivered a lecture on capybara respiration. Zuzu listened. Mostly.
nibs[normal]: Did you know a capybara can hold its breath for five whole minutes? Coco certainly could.
nibs[sad]: Which means she must have been unconscious when she went under. Otherwise she'd simply have climbed out.
think: So Coco didn't just slip into the water. Someone knocked her out first.
@end
""",
	# =====================================================================================
	# GARDEN PATH - people: bramble (left)
	# =====================================================================================
	"inv_enter_garden": """
@ifnot seen_inv_enter_garden -> first
think: The Garden Path. Bramble is still tending her roses.
@end
@label first
@sfx door
narr: A quiet garden of mossy stones and lanterns. A stone path winds between two little doors, with a rose bush in the middle.
think: So this is the garden path. The Lounge's back door on one side... and the bathhouse on the other.
bramble[sad]: Good morning, Mochi... The roses are drooping today. I think they know.
@end
""",
	"inv_garden_rosebush": """
@ifnot seen_inv_garden_rosebush -> first
bramble[sad]: I pruned at nine. The thread came after. Somebody hurried past my roses in the dark...
@clue cape_thread
@end
@label first
narr: A rose bush grows right beside the stone path, its thorny branches leaning over the stones.
think: Something is caught on one of the thorns. A thin, shiny thread...
narr: It's a strand of violet silk, embroidered with tiny silver stars.
think: Violet silk with silver stars. This was torn off someone's clothes. Someone who brushed past in a hurry.
bramble[shock]: Oh! That wasn't there last night... I pruned this bush at nine o'clock. Every single branch.
bramble[normal]: There was nothing on it but leaves and buds. Someone came down this path after nine. In a hurry. Roses notice rushing.
@clue cape_thread
@end
""",
	"inv_garden_path": """
@ifnot seen_inv_garden_path -> first
think: The stone path runs straight from the Lounge to the bathhouse. Someone ran along it recently.
@end
@label first
narr: Flat stepping stones run through the moss in a line, from one door to the other.
think: It connects the Lounge's back door to the bathhouse side door. A shortcut nobody seems to use.
think: Some of the moss between the stones has been kicked loose. Somebody ran along here, and recently.
bramble[sad]: My poor moss... trampled. Moss takes years to grow, and only one careless paw to ruin.
@end
""",
	"inv_garden_lounge_door": """
@ifnot seen_inv_garden_lounge_door -> first
think: The Lounge's back door. The stage is just on the other side.
@end
@label first
narr: A plain wooden door at one end of the path. A little sign reads: LOUNGE - STAFF ONLY.
think: The Lounge's back door. It must open right beside the little stage.
think: Someone on that stage could step out through here... and be in the garden in seconds.
@end
""",
	"inv_garden_bath_door": """
@ifnot seen_inv_garden_bath_door -> first
think: The bathhouse side door, hidden in ivy. It leads straight into the changing room.
@end
@label first
narr: A small, weathered door in the bathhouse wall, almost hidden behind ivy.
think: This must lead into the changing room. From out here, you'd hardly guess it was a door at all.
bramble[normal]: Hardly anyone uses that door. Only me, to fetch water for the roses... and only in daylight.
@end
""",
	"inv_talk_bramble": """
@ifnot seen_inv_talk_bramble -> first
bramble[normal]: I pruned at nine and watched the show from 9:35 to 9:55. The roses and I have nothing else to tell.
@end
@label first
bramble[sad]: Mochi... I'm sorry about Coco. She once said my roses were the prettiest port she'd ever docked in.
mochi: Bramble, where were you last night?
bramble[normal]: I pruned the roses along this path at nine, like every evening. Then I went to the Lounge to watch Wisp's show.
bramble[happy]: The Living Statue... He stood so still, Mochi. Like a garden statue that had forgotten how to move.
bramble[normal]: Lulu, Tumble, Fennel and I watched from 9:35 until he took his bow at 9:55.
bramble[sad]: It felt so peaceful. And all that time, Coco was...
@end
""",
	# =====================================================================================
	# LOUNGE - people: lulu (left), wisp (right)
	# =====================================================================================
	"inv_enter_lounge": """
@ifnot seen_inv_enter_lounge -> first
think: The Lounge. Wisp is still lounging by the stage as if he owns it.
@end
@label first
narr: A cozy lounge with a little stage. The red curtain is still half drawn from last night's show.
think: This is where Wisp performed The Living Statue. Lulu looks like she's been crying.
wisp[happy]: Ah! The detective arrives! Welcome, welcome, to the scene of my greatest performance.
@end
""",
	"inv_lounge_stage": """
@ifnot seen_inv_lounge_stage -> first
think: The half-drawn curtain hides the back of the stage. Whatever happened back there, the audience couldn't see it.
@end
@label first
narr: A small wooden stage. The red curtain hangs half drawn across it, leaving the back corner in deep shadow.
think: Half the stage is hidden behind that curtain. From the seats, you'd only see whatever stood in the light.
narr: Faint scuff marks on the floorboards lead from the shadows toward the back of the stage.
wisp[happy]: Behold, the hallowed boards! Here I stood, motionless as marble, for twenty glorious minutes.
wisp[normal]: The curtain? Pure atmosphere, my dear audience. A little mystery makes the magic sparkle.
@end
""",
	"inv_lounge_chairs": """
@ifnot seen_inv_lounge_chairs -> first
think: Lulu's seat is covered in Bubblegum Pink glitter. Only pink, she says. Never any other color.
@clue lulu_glitter
@end
@label first
narr: A row of plush seats faces the stage. One front-row seat glitters in the light.
think: Glitter, all over the seat cushion. Bright *pink* glitter.
lulu[sad]: That's my seat... I threw my glitter when Wisp took his bow. It's Bubblegum Pink. Lulu-lu...
lulu[normal]: I only ever use Bubblegum Pink! It's my signature color! Never silver, never gold, never anything else!
think: Pink. Only ever pink. I'd better remember that.
@clue lulu_glitter
@end
""",
	"inv_lounge_back_door": """
@ifnot seen_inv_lounge_back_door -> first
think: The back door leads straight to the garden path. Wisp seemed oddly jumpy about it.
@end
@label first
narr: A narrow door just beside the stage, half hidden by the edge of the curtain.
@sfx door
think: It opens onto the garden path! Someone could slip out here without the audience ever noticing.
wisp[shock]: Oh! That old door? It's... drafty. Terribly drafty. I'd keep it shut if I were you.
wisp[happy]: Anyway! Nothing to see there but a door, my dear. A dull, ordinary door. Hoho!
@end
""",
	"inv_talk_lulu": """
@ifnot seen_inv_talk_lulu -> first
lulu[sad]: The show was from 9:35 to 9:55, and Wisp never moved. Four of us watched him. Lulu-lu...
@clue living_statue
@end
@label first
lulu[sad]: Mochi... Lulu-lu... I can't stop thinking about Coco. She said I sang louder than a lighthouse horn.
mochi: Lulu, can you tell me about last night's show?
lulu[normal]: Wisp's Living Statue! It started at 9:35. There was a big POOF of smoke, and then he just... froze!
lulu[normal]: Bramble, Tumble, Fennel and me watched the whole time. He didn't move once until his bow at 9:55!
lulu[happy]: When he bowed, I threw my glitter! It was the best show ever... At least, I thought so.
@clue living_statue
lulu[sad]: Mochi, everyone keeps looking at me funny. I didn't do anything bad. I promise...
@end
""",
	"inv_talk_wisp": """
@ifnot seen_inv_talk_wisp -> first
wisp[happy]: Still here? Try the bath, my dear. Or perhaps ask a certain wrestler about his headband. Hoho!
@end
@label first
wisp[happy]: Ah, Mochi! Our little bath expert, turned detective. How thrilling! How may I assist?
mochi: Where were you when Coco was attacked?
wisp[happy]: Why, on that very stage! The Living Statue, from 9:35 to 9:55. Four witnesses, my dear audience. Four!
wisp[normal]: Poor Captain Coco. Such a bright, loud soul. I could hardly believe it when I heard.
wisp[normal]: If I may offer a humble observation... that red headband beside the bath. Rather damning, wouldn't you say?
wisp[happy]: Not that I would ever accuse dear Bruno, of course. I merely point at things. A magician's habit.
think: He keeps the left side of his cape tucked tightly behind his back. Is he cold?
wisp[normal]: Hmm? Oh, the stage lights are off, that's all. I'm not fond of the dark. Now, off you go! Detect!
@end
""",
	# =====================================================================================
	# STORAGE CLOSET - people: tumble (left)
	# =====================================================================================
	"inv_enter_storage": """
@ifnot seen_inv_enter_storage -> first
think: The Storage Closet. Tumble is still napping on the curtains.
@end
@label first
narr: A cramped, dusty closet behind the Lounge stage. Prop boxes, a star-covered trunk... and a tall shape in the corner.
think: Eek! Oh... it's just a mannequin. And Old Man Tumble, snoring on a pile of spare curtains.
tumble[normal]: Zzz... eh? What? Is it breakfast? Is it lunch? Is it... Tuesday?
@end
""",
	"inv_storage_mannequin": """
@ifnot seen_inv_storage_mannequin -> first
think: A gift-shop mannequin, hidden right behind the stage. Glitter on its shoulders.
@clue mannequin
@end
@label first
narr: A capybara-sized display mannequin stands in the corner, smooth and blank-faced.
think: It's about the same height as... well, as most of us. Its shoulders are sprinkled with sparkly *silver-violet* glitter.
@ifnot seen_inv_giftshop_pedestal -> noshop
think: This has to be the mannequin missing from Duchess's display! What's it doing all the way back here?
@jump clue
@label noshop
think: What's a mannequin doing back here? It looks just like the ones on display in the gift shop.
@label clue
@clue mannequin
tumble[normal]: Zzz... Nice fella. Very quiet. Doesn't snore. Doesn't breathe either... Zzz.
@end
""",
	"inv_storage_trunk": """
@ifnot seen_inv_storage_trunk -> first
think: Wisp's star-covered trunk, dusted with silver-violet Stardust Powder.
@end
@label first
narr: A big magician's trunk painted with silver stars, locked with a star-shaped padlock.
think: Painted on the lid: THE VANDERLOO FLOATING CIRCUS. This must be Wisp's.
narr: A fine dusting of sparkly powder clings to the latches, glittering silver and violet.
think: Wisp's Stardust Powder... He threw a cloud of it when we first met him, didn't he? With that big POOF.
@end
""",
	"inv_storage_boxes": """
@ifnot seen_inv_storage_boxes -> first
think: Wisp's family photo, taped inside a prop box. Their floating circus on Lily Pond.
@end
@label first
narr: Stacks of prop boxes. Fake flowers, rubber doves, an endless rope of knotted scarves.
think: There's an old photo taped inside one box. A circus tent floating on a lily pond, and a big family of capybaras waving.
think: Written on the back: Come home soon, star of the show! Love, Mama.
think: Wisp's family... During the Home Movies last night, his hands were trembling.
@end
""",
	"inv_talk_tumble": """
@ifnot seen_inv_talk_tumble -> first
tumble[normal]: Zzz... statues don't breathe... Zzz... and neither do... zzz...
@end
@label first
tumble[normal]: Zzz... eh? What? Oh, it's you, young'un. Pull up a curtain. Best napping spot in the whole resort.
mochi: Tumble, you watched Wisp's show last night, right?
tumble[happy]: Sure did. Second row. Well... I closed my eyes a bit. Resting 'em. A fella can listen with his eyes closed.
tumble[normal]: Funny thing, though. Whenever I opened 'em, that statue was mighty still. Not a wiggle. Not a twitch.
tumble[normal]: When you get to be my age, you learn a thing or two. Like this one: statues don't breathe.
mochi: ...But Wisp isn't a statue.
tumble[happy]: Exactly my point, young'un. Exactly my point. Zzz...
think: What did he mean by that? The statue on stage wasn't breathing...?
@end
""",
	# =====================================================================================
	# GIFT SHOP - people: fennel (left), duchess (right)
	# =====================================================================================
	"inv_enter_giftshop": """
@ifnot seen_inv_enter_giftshop -> first
think: The Gift Shop. Duchess is still glaring at that empty pedestal.
@end
@label first
narr: Shelves of capybara plushies, yuzu soaps and souvenir towels. Mannequins pose on pedestals in fancy outfits.
duchess[angry]: Mochi! Finally, someone with eyes! Do you SEE this? Do you see this... this CRIME?!
think: I think she means the empty pedestal. Not... the actual crime.
@end
""",
	"inv_giftshop_pedestal": """
@ifnot seen_inv_giftshop_pedestal -> first
duchess[angry]: My mannequin, darling! Capybara-sized and stolen yesterday afternoon! Find it!
@end
@label first
narr: In the middle of the display, one pedestal stands completely empty.
duchess[angry]: My best mannequin! Capybara-sized, perfectly proportioned, dressed in my finest! GONE!
duchess[angry]: It vanished yesterday afternoon, darling. I turned my back for one cup of tea and poof! Stolen!
mochi: Did you tell anyone?
duchess[sad]: Who would care? A guest is murdered and suddenly everyone forgets about fashion. Typical.
think: A capybara-sized mannequin, stolen the very afternoon before Coco died... Could that matter?
@ifnot seen_inv_storage_mannequin -> notfound
think: Wait. The mannequin hidden in the storage closet behind the stage... That has to be this one!
@label notfound
@end
""",
	"inv_giftshop_price_gun": """
@ifnot seen_inv_giftshop_price_gun -> first
think: GIFT SHOP - 4,800 yen. Every item in here gets the same little white tag.
@end
@label first
narr: A clunky price-tag gun sits on the counter beside a roll of little white tags.
@sfx pop
narr: Mochi squeezes the trigger. A tag pops out: GIFT SHOP - 4,800 yen.
duchess[angry]: Don't touch that dreadful thing! It stamps everything with the same price. Plushies, soaps, mannequins!
fennel[happy]: Ah, but a true artist notices every detail. Even price tags! Little white ghosts, hanging off everything.
think: Every item in this shop gets one of these little white tags. Even the mannequins.
@end
""",
	"inv_giftshop_shelves": """
@ifnot seen_inv_giftshop_shelves -> first
think: Plushies, soaps and towels, all tagged GIFT SHOP - 4,800 yen. Pricey.
@end
@label first
narr: Shelves crammed with capybara plushies, yuzu soaps and fluffy towels. Every item wears a little white tag.
think: There's even a Snapjaw plushie. It's... unsettlingly cute.
fennel[happy]: The composition is chaos, but the colors! Magnifique! I could paint these shelves for a week.
@end
""",
	"inv_talk_duchess": """
@ifnot seen_inv_talk_duchess -> first
duchess[angry]: My room. Alone. Beauty sleep. And someone stole my mannequin. Those are the facts, darling.
@end
@label first
duchess[angry]: If you're here to ask where I was, darling: my room. Alone. Beauty sleep doesn't happen by itself.
duchess[sad]: Captain Coco was dreadfully loud, and her stripes clashed with everything. But she didn't deserve this.
duchess[angry]: And now my mannequin is missing too! Snatched right off its pedestal yesterday afternoon!
duchess[normal]: It still had its price tag tucked in the collar. If anyone dares to parade around in my design, I'll know. I'll KNOW.
think: Its price tag was still on it... I should keep that in mind.
@end
""",
	"inv_talk_fennel": """
@ifnot seen_inv_talk_fennel -> first
fennel[normal]: Twenty minutes, and he never blinked. The cape never stirred. Remarkable... or strange?
@end
@label first
fennel[sad]: Mochi! Mon ami! I am painting my grief. Look. It is very blue.
mochi: Fennel, you watched Wisp's show last night?
fennel[happy]: But of course! I sketched him for twenty minutes straight. A perfect model. He never blinked! Not once! Magnifique!
fennel[normal]: Even his cape. Not one fold moved. The shadows stayed exactly where I drew them. I have never seen such stillness.
fennel[normal]: Hmm. Now that I say it out loud... it is almost too perfect, non?
@end
""",
	# =====================================================================================
	# DINING HALL - people: grub (left), pepper (right)
	# =====================================================================================
	"inv_enter_dining": """
@ifnot seen_inv_enter_dining -> first
think: The Dining Hall. Grub and Pepper are still here.
@end
@label first
narr: The Dining Hall. Last night's yuzu feast has been cleared away, but the smell of citrus lingers.
think: Last night we were all here, eating together. Coco laughed so hard she knocked over the soy sauce.
grub[sad]: Mochi... I made breakfast. Nobody's eating. A chef without diners is just a guy holding a spoon.
@end
""",
	"inv_dining_table": """
@ifnot seen_inv_dining_table -> first
think: Everyone shared their plans at this table last night. Including Coco's bath at 9:45.
@end
@label first
narr: The long dinner table. Every seat still has a little name card, folded by Grub.
think: Coco's card is at the head of the table. It says CAPTAIN in big bold letters. She wrote that herself.
think: At dinner, she announced her bath at 9:45, same as always. Wisp announced his show. Bruno, the sauna.
think: Everyone told everyone exactly where they'd be. Anyone could have planned around that.
@end
""",
	"inv_dining_kitchen_door": """
@ifnot seen_inv_dining_kitchen_door -> first
think: Grub and I washed dishes in the kitchen from 9:30 to 10:00. We're each other's alibi.
@end
@label first
narr: The swinging door to the kitchen. Inside, the dish rack is still full of clean plates.
think: I spent last night in there with Grub, washing dishes from 9:30 until Nighttime at 10:00.
think: At some point we heard faint applause from the Lounge. That must have been Wisp's bow.
grub[normal]: You're a natural with a sponge, Mochi. Those plates came out cleaner than a fresh-squeezed alibi!
@end
""",
	"inv_dining_menu": """
@ifnot seen_inv_dining_menu -> first
think: Coco's little anchor doodle is still on the menu board. Grub won't erase it.
@end
@label first
narr: A chalkboard menu in Grub's curly handwriting. LAST NIGHT: Yuzu Feast! TODAY: Comfort Porridge.
think: Someone doodled a little anchor next to the yuzu feast. That has to be Coco.
grub[sad]: She drew that during dinner. Said my yuzu glaze was worth sailing across an ocean for. I can't bring myself to erase it.
@end
""",
	"inv_talk_grub": """
@ifnot seen_inv_talk_grub -> first
grub[normal]: You and me, kitchen, 9:30 to 10:00. Your alibi is solid as my day-old bread. That's a compliment!
@end
@label first
grub[sad]: Mochi. Here, take a rice ball. Grief is hard to swallow, so swallow this first.
mochi: Grub, if anyone asks... can you tell them where I was last night?
grub[normal]: Easy! You were with me in the kitchen from 9:30 till 10:00, scrubbing pots. You never left. Not even for a snack.
grub[happy]: And I never left either. So we're each other's alibi. Two peas in a pot!
grub[sad]: I just wish Coco had come by for a late snack instead of that bath. I'd have made her anything...
@end
""",
	"inv_talk_pepper": """
@ifnot seen_inv_talk_pepper -> first
pepper[normal]: 9:46, statue act, from the doorway. Sharpest shot I've taken all week. Now go find me a motive for Bruno!
@clue pepper_photo
@end
@label first
pepper[normal]: Mochi! Investigating too, huh? Cute. But I'm three scoops ahead of you. Probably four.
mochi: Where were you last night, Pepper?
pepper[happy]: Everywhere! Hallways, lobby, lounge. I photograph everything. Rule number one of the scoop: always have film!
pepper[normal]: Here, look. 9:46 PM, a flash photo of Wisp's statue act, taken from the Lounge doorway. Then I went to bed.
narr: The photo shows the statue on stage in Wisp's hat and cape, lit up by the flash. A little white tag dangles from its collar.
think: Wait. What's that tiny white thing hanging from the collar? Some kind of... tag?
pepper[normal]: That? Costume tag, probably. Who cares! The real scoop is Bruno. His headband was right next to the body!
@clue pepper_photo
pepper[angry]: Mark my words, Mochi. At the trial, I'm going to nail him. SCOOP!
@end
""",
	# =====================================================================================
	# INVESTIGATION END (story screen, full-screen; explicit @show)
	# =====================================================================================
	"investigation_end": """
@bg lobby
@music stop
@sfx chime
narr: Ding-dong. Every speaker in the resort crackled to life at once.
@sfx static
@show snapjaw happy center
snapjaw[happy]: Attention, attention, my darling guests! Time's UP! Put down those magnifying glasses!
snapjaw[happy]: Please make your way to the Lobby, where the Bubble Lift awaits. Next stop: the Splash Trial! Snap-snap-snap!
@hide snapjaw
narr: One by one, the others drifted into the Lobby. Nobody said much.
@sfx whoosh
@shake 6
narr: In the middle of the floor, the tiles slid apart. A giant glass bubble rose from below, glowing turquoise.
@show pepper angry left
@show bruno sad right
pepper[angry]: Finally. I've got my headline ready. Bruno, you might want to start practicing your apology.
bruno[sad]: Bruno... did not do anything...
@hide all
@show marigold sad left
@show lulu sad right
marigold[sad]: Let's all just... stay calm. And stay together. That's what Coco would have wanted.
lulu[sad]: Lulu-lu... I don't want to go down there...
@hide all
@show wisp happy center
wisp[happy]: Courage, my dear audience! Every great performance begins with a descent into darkness.
wisp[normal]: ...Shall we?
think: His voice wobbled on the word darkness. Just for a second.
@hide all
@bg none
@sfx door
narr: The bubble sealed shut with a soft pop. Then, slowly, it began to sink.
narr: Down past the bathhouse pipes. Down past the roots of Bramble's roses. Down, and down, and down.
think: If we get the vote wrong, everyone but the killer will be punished.
think: And if we get it right... one of us won't be coming back up.
@bg trial
@music tension
@sfx splash
narr: The bubble burst open onto a vast, round chamber far beneath the resort.
narr: Fifteen wooden podiums stood in a ring around a glowing turquoise pool. On a rock island in the middle sat an empty throne.
narr: One podium held a framed portrait of Captain Coco, crossed out with two strips of red tape.
think: Coco... One of the capybaras standing at these podiums took you away from us.
think: And I'm going to prove which one.
@end
""",
	# =====================================================================================
	# THE SPLASH TRIAL (trial screen, auto_portrait)
	# =====================================================================================
	"trial": """
@bg trial
@music trial
@card THE SPLASH TRIAL | Case 1: Murder at Yuzu Springs
@sfx splash
@shake 8
narr: With a geyser of turquoise spray, Warden Snapjaw burst out of the pool and flopped onto his throne.
snapjaw[happy]: Welcome, welcome, to the very first SPLASH TRIAL! Snap-snap-snap!
snapjaw[happy]: Just look at all your gloomy little faces! Fifteen podiums, fourteen guests, and one portrait. How dramatic!
think: Everyone is standing at a podium in the ring. Coco's portrait is right next to mine.
reginald[angry]: Release us at once, you overgrown handbag! This is barbaric!
snapjaw[angry]: Ah-ah-ah! Rule six, Sir Puddle-whatever. Violence against the Warden is strictly prohibited. I BITE.
@sfx gavel
reginald[shock]: ...Duly noted.
grub[sad]: Coco's podium has a picture on it. With red tape across it. That's... that's just mean.
snapjaw[happy]: It's called a memorial, Chef! I'm very sentimental. Snap-snap-snap!
snapjaw[normal]: Now, the rules! Listen closely, because I only explain them once. Well, twice, if you die and retry.
snapjaw[normal]: First, you'll debate who killed Captain Coco. Then, everyone votes for the culprit.
snapjaw[happy]: If the majority picks the real culprit, only the culprit gets punished. Simple! Fair! Delicious!
snapjaw[angry]: But if you pick WRONG... then everyone EXCEPT the culprit gets punished. And the culprit checks out, free as a bird!
snapjaw[happy]: Oh, and one more thing, Mochi. See that meter at the top? That's your very own *Convince Meter*!
snapjaw[normal]: Make sharp arguments and it fills. Make silly mistakes and it drains. Glug, glug, glug.
snapjaw[happy]: If it's under *60%* when we vote, nobody will listen to you. They'll just vote with their gut! Snap-snap-snap!
think: My Convince Meter... If I want everyone to follow me, I have to make every argument count.
@choice What should I say?
> Why are you doing this to us? -> ask_why
> Let's get this over with. -> ask_start
@label ask_why
mochi: Why are you doing this to us, Snapjaw?
snapjaw[happy]: Why? WHY? Because it's the most fun a caiman can have with his scales on! Next question!
@jump rules_done
@label ask_start
mochi: Let's get this over with.
snapjaw[happy]: Ooh, eager! I like that in a defendant. I mean, a guest! Snap-snap-snap!
@label rules_done
pepper[angry]: Fine by me! Because my gut already knows who did it. It was Bruno!
bruno[shock]: B-Bruno?!
reginald[angry]: I say, I'm inclined to agree with the journalist. The brute was at the bathhouse!
marigold[sad]: Wait! Shouldn't we start from the beginning? We don't even know how Coco died. Not really.
nibs[normal]: Quite right. Hypothetically speaking, a conclusion without evidence is merely a guess wearing a lab coat.
duchess[normal]: Oh, please. I'm not even convinced there IS a culprit, darling. Accidents happen in bathtubs all the time.
tumble[normal]: Zzz... eh? Are we voting? I vote for... lunch.
think: Here it comes. They're going to argue it was an accident.
think: Listen for the contradiction... If anything they say doesn't hold water, I'll fire the right Truth Drop straight at it.
@minigame debate_accident
mochi: Duchess, you said Coco slipped and hit her head on the rocks. But that's impossible.
mochi: Every rock around the Yuzu Bath is wrapped in thick foam cushions. There's nothing hard to hit your head on.
snapjaw[happy]: SAFETY FIRST! I'm a very responsible host, you know. Snap-snap-snap!
duchess[shock]: Cushions? On ROCKS? How perfectly tacky...
marigold[normal]: Mochi's right. And the file says a single heavy blow to the back of the head. You don't get that from falling onto foam.
nibs[normal]: Furthermore, a capybara can hold its breath for five minutes. Coco didn't drown by accident. She was unconscious.
grub[sad]: So she didn't just... slip. Someone did that to her.
nibs[normal]: Which leaves only one hypothesis. Someone struck her. With something hard.
think: Something hard... and something the culprit didn't want anyone to find.
@minigame q_weapon
mochi: This. A wooden bath bucket I found stuffed behind the lockers in the changing room.
mochi: Its rim is cracked and dented, like it slammed into something hard. Or someone.
@sfx gasp
grub[shock]: A bath bucket? That's... I don't even have a pun for that. That's just awful.
reginald[angry]: Hidden behind the lockers? Then this was no accident. Someone did this on purpose and tried to hide it!
@shout mochi IT WAS MURDER!
lulu[shock]: Murder... Then one of us really... Lulu-lu...
marigold[sad]: A blow like that, from behind... She never even saw it coming.
snapjaw[happy]: Murder most splashy! Now we're cooking with bathwater! Snap-snap-snap!
zuzu[normal]: ok so it's murder. next question. when.
marigold[sad]: That's what I keep thinking about. If only we knew exactly...
think: The exact time. Coco's watch was waterproof... so why did it stop?
@minigame q_time
mochi: At 9:47. Coco's pocket watch was waterproof. She used to brag that it survived three shipwrecks.
mochi: Water couldn't stop it. But the glass is cracked from a hard impact, and the hands froze at *9:47*.
mochi: When Coco was struck, she fell and her watch hit the bath floor. That's the moment of the attack.
marigold[sad]: 9:47... Oh, Captain.
zuzu[normal]: k. so who was where at 9:47. alibi speedrun. go.
grub[normal]: Mochi and I were washing dishes in the kitchen from 9:30 to 10:00. Neither of us left. Clean as a whistle, and so were the plates!
nibs[normal]: Zuzu and I were in the library. I lectured. Zuzu suffered.
zuzu[normal]: can confirm. suffered.
lulu[normal]: Bramble, Tumble, Fennel and me were in the Lounge, watching Wisp's Living Statue show!
wisp[happy]: And I, of course, was the star. Frozen in place from 9:35 to 9:55. Behold, my alibi!
duchess[normal]: I was in my room. Alone. Beauty sleep is not a group activity, darling.
reginald[sad]: I... was practicing alone in the gym. But a gentleman's word is his bond!
pepper[normal]: Me? I was everywhere, getting shots for my scoop file. Then I went to bed. Next!
bruno[sad]: Bruno was in the sauna. Very hot. Very long.
marigold[normal]: I was restocking the infirmary by myself. But when I walked back at about 9:56...
pepper[angry]: ...you saw BRUNO leaving the bathhouse! Exactly! Go on, say it, Marigold!
marigold[sad]: Well... yes. He came out of the front door, red-faced and steaming.
pepper[happy]: SCOOP! The last capybara seen leaving the scene of the crime! It's Bruno, I'm telling you!
bruno[sad]: Bruno was in the sauna... Bruno did not even see Captain...
reginald[angry]: A likely story! The sauna is right next to the bath!
think: Pepper and Reginald are ganging up on him. But that sauna remembers every single time its door opened...
think: Listen carefully. Somewhere in their argument, there's a hole.
@minigame debate_bruno
mochi: Reginald, Bruno couldn't have slipped out of the sauna. Its door has a safety panel that logs every opening.
mochi: Last night it opened at 9:28, when Bruno went in, and at 9:56, when he came out. Nothing in between.
zuzu[normal]: can confirm. i tried to hack it. it's read-only. the log is legit.
nibs[normal]: If Bruno had stepped out at 9:47, the panel would show it. Hypothesis... rejected!
reginald[shock]: I... I say. Then I accused an innocent capybara. Before witnesses! Before a crocodile!
snapjaw[angry]: CAIMAN! I am a CAIMAN! Honestly, the nerve of some guests...
reginald[sad]: Bruno. I withdraw my accusation. A Puddlesworth always admits his errors. Eventually.
pepper[angry]: Hold on! What about the headband?! It was RIGHT next to the body! Explain that, muscles!
bruno[sad]: Bruno always hangs headband on hook in changing room before sauna. Always. Every time.
bruno[sad]: When Bruno came out, the hook was empty. Bruno thought someone borrowed it. Bruno did not think... this.
mochi: Bruno's hook is right there in the changing room. Anyone walking through could have grabbed that headband.
mochi: The culprit took it while Bruno was in the sauna, and left it beside Coco on purpose. To frame him.
nibs[normal]: Then the culprit passed through the changing room sometime between 9:28 and 9:56. Fascinating.
think: And they didn't have to come through the front door to do it...
marigold[normal]: That fits. When I saw Bruno at 9:56 he wasn't panicking. He waved at me. He just looked... boiled.
bruno[happy]: Mochi... Bruno is grateful. Bruno will give Mochi a big hug later. A gentle one.
pepper[sad]: Ugh. Fine. Bruno's off my front page. For now.
snapjaw[angry]: Booooring! Somebody accuse somebody juicier! I didn't build a whole trial pool for group hugs!
duchess[angry]: Very well! I have a juicier suspect right here. Did nobody else notice the glitter on that bucket handle?
@sfx gasp
lulu[shock]: G-glitter...?
think: The glitter on the bucket... I'd better remember exactly what color it was.
@minigame debate_glitter
mochi: Pepper, that glitter isn't the same as Lulu's at all.
mochi: Lulu's seat in the Lounge was covered in her glitter, and it's Bubblegum Pink. She only ever uses pink.
mochi: But the glitter on the bucket handle is *silver-violet*. Completely different.
lulu[shock]: Lulu-lu?! Somebody... actually believes me?
lulu[happy]: Mochi! I could sing! I won't. But I could!
pepper[shock]: Pink versus silver-violet... Okay, okay. I got carried away. My editor would kill me. Figuratively!
pepper[sad]: Sorry, Lulu. Retraction printed. Front page. Big letters.
lulu[happy]: Lulu-lu~! Apology accepted!
duchess[normal]: Hmph. Then whose glitter is it, darling? It certainly isn't mine. I only wear pearls.
nibs[happy]: An excellent question. Answer it, and our list of suspects shrinks considerably.
think: Silver and violet sparkles... I remember. The very first time we met him, there was a big POOF...
@minigame q_glitter_owner
mochi: Wisp. Your Stardust Powder is silver-violet. You threw a cloud of it the moment you first appeared.
@ifnot seen_inv_storage_trunk -> no_trunk
mochi: There's a dusting of it on your magic trunk in the storage closet, too.
@label no_trunk
@sfx gasp
@shake 8
all: WISP?!
grub[shock]: Wisp? But he's so... polite! He complimented my soup!
duchess[shock]: The magician? Well. He does have a flair for the dramatic, darling. I'll give him that.
wisp[shock]: M-me? Hoho... Oh, Mochi. My dear, dear Mochi.
wisp[happy]: A little glitter proves nothing! Stardust gets everywhere. That's half the magic!
wisp[angry]: And you're all forgetting something rather important. At 9:47, I was on stage in front of FOUR witnesses!
lulu[normal]: That's true... We watched him the whole time!
fennel[happy]: Oui! I sketched every second of it!
snapjaw[happy]: Ooh, an alibi! Four witnesses! This is better than reality TV! Let's hear it, magic man!
@music trial_climax
think: Wisp's alibi looks airtight. Four witnesses, twenty minutes, one statue that never moved.
think: Unless the statue on that stage wasn't really him... I need proof of what was actually standing up there.
@minigame debate_alibi
mochi: Wisp, the statue on that stage wasn't you. And Pepper's photo proves it.
mochi: She took it from the Lounge doorway at 9:46. Everyone, look closely at the statue's collar.
pepper[shock]: My photo? Let me see... There's a little white tag hanging from the collar. It says... GIFT SHOP - 4,800 yen?!
duchess[shock]: That's MY price tag! From MY gift shop! That ghastly price gun tags everything in there!
fennel[shock]: Mon dieu! I sketched that tag! I thought it was a button! Catastrophique!
tumble[normal]: Zzz... told ya... statues don't breathe...
wisp[shock]: That... that is a smudge! A speck of dust on the lens! Pepper, your camera is filthy!
pepper[angry]: Excuse me?! My lens is SPOTLESS! I polish it every morning!
pepper[normal]: Wait, wait, wait. Hold the presses.
think: Something that could stand perfectly still for twenty minutes, without blinking, without breathing...
@minigame q_mannequin
@shout mochi IT'S A MANNEQUIN!
mochi: A capybara-sized display mannequin, stolen from Duchess's gift shop yesterday afternoon.
mochi: I found it in the storage closet right behind the Lounge stage. Its shoulders were covered in silver-violet glitter.
duchess[angry]: My mannequin! Dressed up in a cheap magician's cape! I could scream! I AM screaming!
lulu[shock]: Then for twenty minutes... we were cheering for a doll?!
bramble[sad]: I said he was like a garden statue... He really was. He was never there at all.
fennel[sad]: I painted a mannequin. Twenty minutes of my life. For a mannequin.
mochi: Fennel, you said he never blinked once. And Tumble said it best: statues don't breathe.
mochi: Of course it never blinked. Of course it never breathed. It was never alive.
tumble[happy]: Heh. Took you young'uns long enough. Zzz...
mochi: After the big POOF of smoke, behind the half-drawn curtain, Wisp swapped places with the mannequin.
mochi: Nobody watching from the seats could tell the difference. And the real Wisp was free to go wherever he wanted.
wisp[angry]: Preposterous! Even IF I had left the stage, how could I cross the whole resort to the bathhouse unseen?
wisp[happy]: The hallways were crawling with guests! Our dear Pepper was snapping pictures everywhere!
pepper[normal]: He's... not wrong. I was all over those hallways, and I never saw him.
think: He didn't need the hallways. There's another way from the Lounge to the bathhouse. A quiet one...
@minigame bubbles_garden
mochi: The garden path! The Lounge has a back door right beside the stage, and it opens onto the garden.
mochi: The path leads to a little side door into the changing room. Nobody uses it, and it can't be seen from the front.
mochi: And there was a crushed rose petal stuck to the mat inside that side door. Someone came in straight from the garden.
bramble[shock]: My garden path... It's such a quiet path. Only the roses would have seen.
zuzu[normal]: and there are no cameras on the garden path. big brain route ngl.
reginald[normal]: Out the back, along the garden, in by the side... I say. Swift, silent and unseen. Diabolical footwork!
snapjaw[happy]: I'm not saying anything! But I AM smiling. Snap-snap-snap!
wisp[angry]: Enough! Enough of this little fairy tale!
wisp[angry]: You have no proof, Mochi! None! If you want a show, then let me show you how a real showman fights back!
think: He's coming straight at me. I have to counter every line he throws... then find the weak spot in his last one.
@minigame rebuttal_wisp
mochi: You did set paw on that garden path, Wisp. And you left something behind.
mochi: A strand of violet silk embroidered with tiny silver stars, snagged on a rose bush right beside the path.
bramble[normal]: I pruned that bush at nine o'clock. There was nothing on it then. That thread came after nine.
fennel[shock]: Violet silk with silver stars... I know that pattern! I have sketched it a hundred times! It is Wisp's cape!
mochi: Wisp. You've been holding the left side of your cape closed this whole trial. Show us the hem.
@sfx heartbeat
narr: Wisp's gloved paw tightened on his cape. For a long moment, nobody breathed.
narr: Then, slowly, the cape fell open. A ragged tear ran along its hem, right where a few silver stars should have been.
@sfx gasp
@shake 10
lulu[sad]: Wisp... no...
reginald[shock]: Great heavens...
wisp[angry]: Thorns! Roses have thorns everywhere! I could have torn it... anywhere! Anytime!
bramble[normal]: Not on that bush, Wisp. I pruned it at nine. And the thread was still hanging there this morning, waiting.
snapjaw[happy]: Ooooh! The plot thickens like a good gravy! Mochi, why don't you walk us through the whole thing? From the top!
think: Alright. From the very beginning. Every piece, in order. Let's show everyone what really happened.
@minigame rewind_final
@shout mochi IT WAS YOU, WISP!
narr: The chamber fell silent. Even the pool stopped rippling.
wisp[sad]: ...
wisp[sad]: Bravo, Mochi. A flawless performance. I'd applaud, but... my paws won't stop shaking.
bruno[sad]: Wisp... Wisp let everyone think it was Bruno.
marigold[sad]: Wisp. Please. Just tell us the truth.
wisp[sad]: ...
@music snapjaw
snapjaw[happy]: Snap-snap-snap! Looks like we've reached my FAVORITE part! It's VOTING TIME!
snapjaw[happy]: Everyone, cast your vote! Who killed Captain Coco? Choose wisely... or don't! I'm entertained either way!
snapjaw[normal]: And remember, majority rules. If Mochi hasn't convinced you, just follow that gut of yours. Snap-snap-snap!
think: This is it. Before we vote... should I say something to everyone?
@choice One last word before the vote...
> Trust the evidence. -> last_evidence
> Do it for Coco. -> last_coco
@label last_evidence
mochi: Everyone, don't vote with your gut. Vote with the evidence. Every Truth Drop points the same way.
@jump last_done
@label last_coco
mochi: Everyone... Coco protected all of us. Now it's our turn to stand up for her. Please.
@label last_done
grub[sad]: Whatever happens, Mochi... thanks for fighting this hard.
think: I hope I've convinced them. For Coco.
@minigame vote_final
@ifnot vote_correct -> wrong
@label correct
@sfx correct
@shout snapjaw CORRECT!
snapjaw[happy]: Ding-ding-ding! The one who killed Captain Coco was Wisp Vanderloo, the Ace Magician!
snapjaw[happy]: Bravo, bravo! A splendid splash of a verdict! Snap-snap-snap!
@music sad
narr: Wisp stood very still. Not like a statue. Like someone who had finally run out of tricks.
lulu[sad]: Why, Wisp? Why Coco?
wisp[sad]: ...Because of the Home Movie.
wisp[sad]: My family's floating circus, on Lily Pond. My mother. My little brothers. Every acrobat I grew up with.
wisp[sad]: I watched the bulldozers drain the pond, and the big top sink into the mud. Three days, the timer said. Three days.
wisp[sad]: The Living Statue was always a trick, you know. Nobody can stand still for twenty minutes. Not even me.
wisp[sad]: I borrowed the mannequin that afternoon for my finale. I was going to pop up behind the audience. Ta-da.
wisp[sad]: Then the Home Movie played... and I realized my little trick was the perfect alibi. I planned the rest before the screen went dark.
wisp[sad]: And Coco had told the whole table she'd be in the bath at 9:45. Alone. Same as always.
wisp[sad]: The headband was just... there, on its hook. A magician uses whatever is in reach. Bruno, I'm so sorry.
bruno[sad]: Bruno... forgives Wisp. Bruno does not know how. But Bruno does.
wisp[sad]: Coco was the first one here to call me crewmate. She said nobody on her crew would ever check out.
wisp[sad]: She meant it. She would have protected me, too. And I...
narr: Wisp's voice cracked. He took off his tall top hat and held it against his chest.
wisp[sad]: Captain... I'm sorry. I hope the sea is calm and warm, wherever you've sailed off to.
wisp[sad]: Everyone... please don't let him do this to you again. Don't watch his movies. Don't trust his timers.
wisp[sad]: And keep the lights on for each other at night, would you? I was always so afraid of the dark.
wisp[sad]: Mochi. You saw through every one of my tricks. You'd have made a marvelous magician's assistant.
lulu[sad]: Wisp... your show really was the best one I ever saw. Even the parts that were fake.
reginald[sad]: You were a scoundrel, Vanderloo. But I shall remember the scoundrel's courage at the end.
wisp[sad]: Thank you, all of you. Truly. My dear audience... this is my final bow.
narr: Wisp bowed deeply, sweeping his torn cape behind him. Nobody applauded. Nobody could.
think: I don't know what to say. We found the truth. We survived. So why does it hurt this much?
@music snapjaw
snapjaw[happy]: Sniff, sniff! How touching! I'm practically leaking motor oil! Now, then...
snapjaw[happy]: I've prepared a VERY special punishment for our Ace Magician! After all, the show must go on!
@card THE GRAND FINALE | Wisp's Last Vanishing Act
snapjaw[happy]: It's PUNISHMENT TIME! Snap-snap-snap!
@end
# ---------------------------------------------------------------- WRONG VERDICT
@label wrong
@sfx wrong
@shout snapjaw WRONG!
snapjaw[happy]: Ding-ding-ding! The votes are in, and the majority is... WRONG! Wrong, wrong, WRONG!
snapjaw[happy]: The one who killed Captain Coco was Wisp Vanderloo, the Ace Magician! Snap-snap-snap!
wisp[sad]: I... I'm sorry. I'm so sorry, everyone.
snapjaw[happy]: Congratulations, Wisp! You get to CHECK OUT! As for the rest of you...
snapjaw[happy]: It's PUNISHMENT TIME for everybody else! Hope you all like it hot! Snap-snap-snap!
think: No... I couldn't convince them. Coco... everyone... I'm so sorry.
@end
""",
}

extends RefCounted
## Chapter 2 ("Murder on the Mudlark") case scripts: investigation snippets, investigation_end and the
## Splash Trial. DSL reference: docs/ARCHITECTURE.md section 3. Story bible: docs/DESIGN2.md.
## Trial minigame data: scripts/data/trial_data2.gd (ids prefixed c2_).
##
## Investigation snippets play as a transparent auto_portrait overlay on top of the room
## (no @bg / @show). The investigation screen sets flag "seen_<script id>" after a snippet
## finishes, so every snippet starts with "@ifnot seen_<id> -> first": the short revisit
## reminder comes first, then "@label first" + the first-time path. Every path shows at
## least one line before @end. Clues are re-given on revisits (silently skipped if owned).
## Same @ifnot convention as Chapter 1 (story_case.gd), also for the vote verdict.
##
## Spoiler discipline (DESIGN2 intro): during the investigation Tumble is sleepy comic relief and
## the bunk dents / dictaphone are only "odd details". Nothing before the trial's turn winks at him.

const SCRIPTS := {
	# =====================================================================================
	# INVESTIGATION - start / complete
	# =====================================================================================
	"investigation_start": """
@card INVESTIGATION | Find the truth for Marigold
think: Marigold... She was always the first to ask if I'd eaten. If I'd slept. If I'd had enough water.
think: She took care of every single one of us. And somebody on this boat...
think: No. Crying can wait. She'd want me to look after everyone. The best way to do that now is to find the truth.
@clue rules2
@clue snapjaw_file2
think: The Mudlark Rules and Snapjaw File #2 are in my notebook. Time to find more *Truth Drops*.
think: The gangway was raised all night. Nobody got on or off. Whoever did this is still on board. With us.
narr: TIP: Click the *glowing* objects and people in each room. Use the *Map* to move around the ship. *Esc* opens your notebook.
@end
""",
	"investigation_complete": """
@sfx chime
think: Wait. Let me go over everything one more time...
think: The rounds log. The anchor in the coal. The giant boots. The cut shawl. Grub's ghost. A lump of melted wax...
think: Half of these pieces don't fit together yet. But I think I have all of them.
think: Marigold never wanted to be too late for anyone. I'm not going to be too late for her.
@end
""",
	# =====================================================================================
	# INFIRMARY (bg ship_infirmary_body) - people: grub (left), nibs (right)
	# =====================================================================================
	"inv2_enter_infirmary": """
@ifnot seen_inv2_enter_infirmary -> first
think: The infirmary. Grub still hasn't left the doorway. Nibs is still taking notes.
@end
@label first
@sfx door
narr: The ship's infirmary. A cot, a medicine cabinet, a little desk... and a burnt smell hanging in the air.
think: Marigold was so proud of this room. She said every ship needs one place where somebody takes care of you.
think: And now she's lying on the floor, and the door just creaks back and forth whenever anyone walks past.
nibs[sad]: Mochi. I've been trying to be useful. Hypothetically, it's what she would have done.
@end
""",
	"inv2_infirmary_body": """
@ifnot seen_inv2_infirmary_body -> first
think: One blow to the back of the head, from behind. Nibs says the bruise is curved, with a little hook at one end.
@end
@label first
narr: Marigold lies on the floor beside her cot. Her nurse cap, with its little green cross, has fallen off beside her.
think: Marigold... I'm sorry. I'll be quick. And careful. The way you'd want.
nibs[sad]: One blow to the back of the head, exactly as the file says. From behind. She never saw it coming.
nibs[normal]: The bruise has an odd shape, though. Curved, like a crescent moon. With a little hook at one end.
think: A curved shape with a hook... Whatever hit her was heavy, and it wasn't just a plain club.
nibs[sad]: She'd have scolded me for kneeling on a cold floor. Bad for the knees, Professor. I can hear her saying it.
@end
""",
	"inv2_infirmary_cot": """
@ifnot seen_inv2_infirmary_cot -> first
think: A scrap of lilac silk on Marigold's cot. The exact shade of the Duchess's shawl.
@clue lilac_thread
@end
@label first
narr: Marigold's cot is neatly made, a folded blanket at its foot. Something small and pale purple lies on the pillow.
think: A little scrap of silk. Soft, shiny... *lilac*.
think: I know that color. There's only one capybara on this ship who wears lilac silk.
grub[sad]: That's the Duchess's color. She was so angry at Marigold at dinner. You'll regret meddling with me, she said...
think: Everybody at the table heard her say it.
@clue lilac_thread
@end
""",
	"inv2_infirmary_log": """
@ifnot seen_inv2_infirmary_log -> first
think: 10:30, Grub's tonic. 10:40, kettle on, chamomile for Mr. Tumble at 11:00. Then the pen trails off into a smear.
@clue rounds_log
@end
@label first
narr: A clipboard hangs above the desk. Marigold's rounds log, written in neat, round handwriting.
think: She wrote down every single visit. Even the ones that were only to say goodnight.
narr: The last two lines read: 10:30 Grub - tummy tonic. 10:40 kettle on - Mr. Tumble's chamomile at 11:00 sharp!
think: And then the last line doesn't end. The ink slides right off the edge of the words into a long smear.
think: As if her pen slipped while she was still writing.
@clue rounds_log
grub[sad]: She gave me my tonic at 10:30. She was humming. She told me off about the cheese. That's the last thing she ever said to me...
@end
""",
	"inv2_infirmary_kettle": """
@ifnot seen_inv2_infirmary_kettle -> first
think: The kettle boiled itself dry on the burner. Marigold put it on and never came back for it.
@end
@label first
narr: A little copper kettle sits on a burner beside the desk. The burner is off now, but the kettle is scorched black.
@sfx sizzle
think: Ow! Still warm. And bone dry inside. Not a single drop left.
nibs[normal]: I switched the burner off this morning. Far too late. Hypothetically, it boiled for hours until every drop was gone.
think: Beside it, a little teapot and a tin of chamomile, waiting on a tray. The teapot is empty. Never filled.
think: She put the kettle on... and never came back to take it off.
@end
""",
	"inv2_infirmary_door": """
@ifnot seen_inv2_infirmary_door -> first
think: The heavy brass anchor that held this door open is gone. Somebody took it.
@end
@label first
narr: The infirmary door hangs loose on its hinges, creaking whenever someone walks past.
think: There's a round, clean patch on the floorboards right beside it. As if something heavy sat there for a long time.
grub[sad]: Her doorstop's gone. A big brass anchor. She kept the door wide open with it, so she'd hear if anybody needed her.
grub[normal]: She said it weighed a ton. I tried to move it for her once. Couldn't budge it! And I lift soup pots for a living!
@ifnot seen_inv2_infirmary_body -> nobody
think: A brass anchor... Anchors have curved arms with little hooks on the ends. Just like the shape of that bruise.
@end
@label nobody
think: A heavy brass anchor. Where would something like that even go?
@end
""",
	"inv2_talk_grub": """
@ifnot seen_inv2_talk_grub -> first
grub[sad]: Six o'clock, pitch dark, a little hunched ghost with a big trumpet thing, sneaking into the purser's office. I know what I saw!
@clue grub_ghost
@end
@label first
grub[sad]: Mochi... I brought her toast. Cinnamon, crusts off. She liked the crusts off.
grub[sad]: I knocked, and the door just swung open, and... I dropped the whole tray. I've never dropped a tray in my life.
mochi: Grub, I'm so sorry. Can you tell me about last night?
grub[normal]: She gave me my tummy tonic at 10:30, right here. Then I went straight to bed. I'm up at six every day to bake.
grub[sad]: So I'm the last one who saw her, AND the first one who found her. That's the worst sandwich of facts I've ever made.
grub[shock]: Oh! And Mochi... this morning I saw a GHOST!
mochi: A ghost?
grub[normal]: At six, on my way to the galley. Pitch dark. A small, hunched figure carrying a big trumpet thing. It slipped into the purser's office.
grub[shock]: Every old boat has a ghost! Everybody knows that! I ran to the galley and kneaded dough until my paws hurt.
@clue grub_ghost
think: A ghost with a trumpet... More likely just someone. But who wanders into the purser's office at six in the morning?
@end
""",
	"inv2_talk_nibs": """
@ifnot seen_inv2_talk_nibs -> first
nibs[normal]: Chess with Zuzu until 1 AM. One blow, from behind, by something heavy and curved. Those are my data.
@end
@label first
nibs[normal]: Ah, Mochi. I'm a chemist, not a doctor. But Marigold isn't here to... well. Someone has to read the evidence.
mochi: Where were you last night, Professor?
nibs[normal]: In the saloon, playing chess with Zuzu from dinner until 1 AM. Neither of us left the board. I was winning.
nibs[sad]: Hypothetically winning. Zuzu disputes it.
nibs[normal]: As for Marigold: one blow, from behind, by something heavy with a curved edge. Very heavy.
nibs[normal]: Whoever swung it was either very strong... or very determined. I find the second possibility far more frightening.
think: Very strong... When the others hear that, they're all going to think of the same capybara.
@end
""",
	# =====================================================================================
	# BOILER ROOM (bg ship_boiler) - people: bruno (left), reginald (right)
	# =====================================================================================
	"inv2_enter_boiler": """
@ifnot seen_inv2_enter_boiler -> first
think: The boiler room. Hot, loud, and black with coal dust. Reginald is still glaring at Bruno.
@end
@label first
@sfx door
narr: A blast of heat. A huge iron furnace glows at the back, pipes rattle overhead, and coal dust coats every surface.
think: So this is where the deck tub's hot water comes from. It's like standing inside a dragon.
reginald[angry]: Mochi! Stand back. I have the suspect under close guard.
bruno[sad]: Bruno is not going anywhere. Bruno works here. Every morning.
@end
""",
	"inv2_boiler_coal": """
@ifnot seen_inv2_boiler_coal -> first
think: The infirmary's anchor doorstop, buried in the coal. Wiped clean of everything but coal dust.
@clue anchor_doorstop
@end
@label first
narr: A great black hill of coal is heaped against the wall, a shovel stuck in its side.
think: Something is glinting near the bottom. Something gold... no. Brass.
@sfx whoosh
narr: Mochi digs into the coal and pulls out something heavy. Very heavy. A brass anchor, nearly as long as their arm.
@ifnot seen_inv2_infirmary_door -> nodoor
think: This is the doorstop from the infirmary! The one that used to hold Marigold's door open!
@jump found
@label nodoor
think: A brass anchor, buried in coal? It looks like the kind of thing you'd use to prop a heavy door open.
@label found
think: Coal dust is packed into one curved arm, the fluke. But apart from that it's been wiped clean. Completely clean.
@clue anchor_doorstop
reginald[angry]: Hah! Buried in the brute's own coal pile! Is there anyone else aboard who digs in that coal?!
bruno[shock]: Bruno did not bury that! Bruno shovels coal OUT. Not things IN!
@end
""",
	"inv2_boiler_prints": """
@ifnot seen_inv2_boiler_prints -> first
think: Giant boot prints from the door to the coal pile and back. Huge, but shallow, and very close together.
@clue boot_prints
@end
@label first
narr: A trail of boot prints runs through the coal dust on the floor, from the door to the coal pile and back again.
think: These are HUGE. Each one is longer than my whole forearm.
reginald[angry]: Only one capybara on this ship has feet like barges. I rest my case!
bruno[sad]: Bruno walks on the planks by the wall. Always. Coal dust is very bad for boots.
think: Hmm. The prints are enormous... but they're barely pressed into the dust. And so close together. Tiny little steps.
think: Like someone big, tiptoeing. Or... I don't know. Weird.
@clue boot_prints
@end
""",
	"inv2_boiler_furnace": """
@ifnot seen_inv2_boiler_furnace -> first
think: A blackened lump of melted wax in the furnace ash, with a little brass cap stuck in it. Bruno says it wasn't there last night.
@clue wax_lump
@end
@label first
narr: The furnace door glows orange around its edges. Below the grate sits a tray of grey ash.
think: There's something in the ash. A blackened, lumpy blob, like a candle that melted into a puddle and hardened again.
narr: A tiny brass end-cap is stuck in the middle of it, half sunk in the wax.
bruno[normal]: That was not there when Bruno banked the fire last night. Bruno empties the ash tray every evening. Bruno is tidy.
bruno[sad]: This morning Bruno only shoveled. Bruno did not look down. Bruno was sleepy.
think: Somebody burned something in this furnace. Last night... or early this morning.
@clue wax_lump
@end
""",
	"inv2_boiler_gauges": """
@ifnot seen_inv2_boiler_gauges -> first
think: The gauges say COZY. The only cozy thing in this whole room.
@end
@label first
narr: A row of brass pressure gauges, needles twitching. Instead of numbers, the dials read CHILLY, COZY, TOASTY and CHECK OUT.
think: ...CHECK OUT. Of course that's on there.
bruno[normal]: Bruno keeps the needle on COZY. Warm water for the deck tub. Everyone deserves a warm bath. Even here.
reginald[normal]: ...That is, I admit, a rather decent sentiment. For a suspect.
@end
""",
	"inv2_talk_bruno": """
@ifnot seen_inv2_talk_bruno -> first
bruno[sad]: Bruno went to bed early. Alone. Bruno shoveled coal at 6:30. Bruno's spare boots dry in the laundry. That is all.
@end
@label first
bruno[sad]: Mochi... Bruno knows how this looks. Again.
mochi: Tell me about last night, Bruno.
bruno[normal]: Bruno banked the fire. Then Bruno went to his cabin early. Alone. Bruno slept like a big rock.
bruno[normal]: At 6:30 Bruno got up and shoveled coal, like every morning. Then Bruno heard Grub scream.
bruno[sad]: Bruno has no alibi. Nobody watches Bruno sleep. That would be weird.
mochi: Is that why you're covered in coal?
bruno[normal]: Bruno is always covered in coal now. That is why Bruno keeps spare boots drying in the laundry. Clean ones.
bruno[sad]: Pepper said sorry to Bruno only yesterday. Now Pepper looks at Bruno like that again...
@end
""",
	"inv2_talk_reginald": """
@ifnot seen_inv2_talk_reginald -> first
reginald[sad]: I kept the night watch at the stern. And I rested my eyes. Briefly. For several hours.
@end
@label first
reginald[angry]: Mochi! I have taken it upon myself to guard the evidence. And the suspect. Simultaneously!
mochi: Reginald, where were you last night?
reginald[normal]: Keeping the night watch, as I swore to, in the Captain's honour. I took my post on a crate at the stern, by the paddle wheel.
reginald[sad]: And then I rested my eyes. For one moment. When I opened them it was two in the morning, and my moustache was damp.
mochi: So you were asleep. Alone.
reginald[angry]: A Puddlesworth does not SLEEP on watch! He... tactically recharges! ...Alone. Yes.
reginald[sad]: The Captain would have stayed awake. She'd have caught the villain by the tail. I have failed her twice now.
think: Reginald has no alibi again. And again, he's awfully eager to point at Bruno.
@end
""",
	# =====================================================================================
	# LAUNDRY (bg ship_laundry) - people: bramble (left), duchess (right)
	# =====================================================================================
	"inv2_enter_laundry": """
@ifnot seen_inv2_enter_laundry -> first
think: The laundry. It smells of soap and steam... and, oddly, a little bit of coal.
@end
@label first
@sfx door
narr: Wash tubs, a clanky old mangle, and lines of white sheets strung under the ceiling like sails. Warm and damp.
duchess[angry]: Mochi! Finally, somebody with EYES! Come and see what some barbarian has done to my shawl!
bramble[sad]: Hello, Mochi... I came down to wash my gloves. And to be somewhere quiet for a little while.
@end
""",
	"inv2_laundry_rack": """
@ifnot seen_inv2_laundry_rack -> first
think: Bruno's spare boots. He left them clean. Now there's coal in the treads and socks stuffed deep into both toes.
@clue bruno_boots
@end
@label first
narr: A wooden boot rack by the wall. On it sits one enormous pair of boots, like two leather rowboats.
think: Bruno's spare pair. He keeps them down here to dry, because coal dust is bad for boots.
think: But there's black coal dust packed into the treads. Fresh coal dust.
narr: Mochi reaches inside one boot. Something soft is crammed deep into the toe.
think: Socks? Crumpled-up grey ship-issue socks, stuffed all the way into the toes. In both boots.
duchess[normal]: Hideous things. Like two coal barges. I've been trying not to look at them all morning.
think: Why would anybody stuff socks into Bruno's boots? Huh.
@clue bruno_boots
@end
""",
	"inv2_laundry_line": """
@ifnot seen_inv2_laundry_line -> first
think: The Duchess's lilac shawl. One corner is missing, cut off in a perfectly straight line.
@clue duchess_shawl
@end
@label first
narr: Among the white sheets on the drying line hangs one splash of color: a long *lilac* silk shawl.
duchess[angry]: My shawl! Hand-dyed! Irreplaceable! First that chef drowns it in tomato soup, and now THIS!
think: One corner is missing. But it isn't torn. The edge is perfectly straight, as if it was cut with scissors.
duchess[sad]: I hung it here to dry after dinner. And this morning... mutilated. Who would do such a thing to silk?
@clue duchess_shawl
@ifnot seen_inv2_infirmary_cot -> nocot
think: The lilac scrap on Marigold's cot... it's exactly the same color. That must be the missing corner.
@label nocot
@end
""",
	"inv2_laundry_basket": """
@ifnot seen_inv2_laundry_basket -> first
think: The sewing basket. Scissors sharp enough to cut silk in a single snip. And no lock on the door.
@end
@label first
narr: A wicker sewing basket sits on a stool: spools of thread, a pincushion, and a pair of long silver scissors.
duchess[normal]: For emergencies of fashion, darling. A loose hem waits for no one.
think: These scissors are sharp. Really sharp. You could cut silk with one snip.
duchess[angry]: Don't look at me like that! The basket sits right here, in a room with no lock! ANYONE could have used it!
think: She's right about that. No locks anywhere on this ship. Rule three.
@end
""",
	"inv2_laundry_tubs": """
@ifnot seen_inv2_laundry_tubs -> first
think: Wash tubs and a mountain of grey ship-issue socks. Anybody could grab a pair.
@end
@label first
narr: Three big wooden wash tubs, still full of grey, soapy water. Beside them, a basket overflowing with grey socks.
think: SHIP-ISSUE, stamped on every pair, next to a tiny Snapjaw face. There must be a hundred of them.
bramble[normal]: Mine had a hole in the heel. I planted a little moss in it. It's very happy now.
think: A hundred identical socks in an open basket. Anybody could take a pair, and nobody would ever notice.
@end
""",
	"inv2_talk_bramble": """
@ifnot seen_inv2_talk_bramble -> first
bramble[normal]: Lulu, Fennel and I watched the fungus glow on deck from 10:15 until about 11:30. It glowed brightest at eleven.
@end
@label first
bramble[sad]: Mochi... Marigold put ointment on my thorn scratches yesterday. She said gardeners never wear their gloves enough.
mochi: Bramble, where were you last night?
bramble[normal]: Up on the promenade deck with Lulu and Fennel, from about 10:15 until 11:30. We watched the cave fungus glow.
bramble[happy]: At eleven it was brightest. As if the whole cave breathed out light. Fennel painted it. Lulu named the mushrooms.
bramble[sad]: And somewhere below us, all that time... I wish the fungus could have shown us where to look.
bramble[normal]: The laundry smells of coal today, Mochi. Laundry should smell of soap. Something is out of place here.
@end
""",
	"inv2_talk_duchess": """
@ifnot seen_inv2_talk_duchess -> first
duchess[angry]: My cabin. Alone. Awake all night without my powder. And yes, I said she'd regret it. I say that to everyone, darling!
@end
@label first
duchess[angry]: If you've come to ask where I was, darling: in my cabin. Alone. Staring at the ceiling. ALL night.
duchess[angry]: That nurse confiscated my sleeping powder at dinner. Doctor's orders, she said. She isn't even a doctor!
mochi: You told her she'd regret meddling with you.
duchess[shock]: I... Darling, I say that to everyone! I once said it to a hat! The hat was fine!
duchess[sad]: ...I didn't mean it. Not like that. I was tired, and frightened, and rude. That's all it was.
duchess[angry]: And if anyone thinks I would ruin my OWN silk to do something so vulgar, they know nothing about fashion!
@end
""",
	# =====================================================================================
	# CABIN CORRIDOR (bg ship_hall) - people: lulu (left), pepper (right)
	# =====================================================================================
	"inv2_enter_hall": """
@ifnot seen_inv2_enter_hall -> first
think: The cabin corridor. Cabin 1 is mine, Cabin 2 is Tumble's, Cabin 3 is Pepper's.
@end
@label first
narr: The narrow cabin corridor, lit by a single brass lamp. Three wooden doors in a row: 1, 2 and 3.
think: My cabin, Tumble's cabin, Pepper's cabin. The walls between them are about as thick as a cracker.
pepper[normal]: Mochi! Good timing. I need a witness for my witness statement.
lulu[sad]: Lulu-lu... I didn't want to be alone. Is it okay if I stay here with you two?
@end
""",
	"inv2_hall_door1": """
@ifnot seen_inv2_hall_door1 -> first
think: My cabin. I lay awake in there for hours last night, listening to the snoring through the wall.
@end
@label first
narr: Cabin 1. Mochi's cabin. The key turns in the door, but the lock doesn't do anything at all.
think: Rule three. No locks. Fire safety first. Snapjaw's idea of a joke.
think: Last night I lay in there staring at the ceiling, thinking about my postcard. Our little hot spring, filled with concrete...
think: The only thing that helped was the snoring through the wall. Steady, like waves on a shore.
@end
""",
	"inv2_hall_door2": """
@ifnot seen_inv2_hall_door2 -> first
think: Tumble snored nonstop from ten until midnight. I heard every bit of it through the wall. Then it just stopped.
@clue snore_alibi
@end
@label first
narr: Cabin 2. A little sign hangs from the knob in shaky handwriting: NAPPING. ALSO SLEEPING. DO NOT DISTURB.
think: Old Man Tumble's cabin. Right next door to mine.
think: I heard him all night long through the wall. Snoring, loud and steady, with the same funny little squeaky cough now and then.
think: From the nighttime chime at ten... until around midnight. Then it just stopped, and the whole ship went quiet.
lulu[normal]: Mr. Tumble snores that loud? Lulu-lu... that's kind of cute. Like a little tugboat.
@clue snore_alibi
@end
""",
	"inv2_hall_door3": """
@ifnot seen_inv2_hall_door3 -> first
think: Pepper's newsroom. Ink, notes, and one very well-used stopwatch.
@end
@label first
narr: Cabin 3. A card is pinned to the door: PEPPER QUILL - NEWSROOM - KNOCK FIRST. SCOOPS ONLY.
think: Inside, the walls are covered in pinned-up notes and photos. A little silver stopwatch sits on the desk.
pepper[happy]: Welcome to the Mudlark Gazette! Circulation: twelve. Well, eleven. Bruno only looks at the pictures.
pepper[normal]: Thin walls, though. I could hear Tumble through mine all night long. Worst neighbor ever. Great material.
@end
""",
	"inv2_hall_tube": """
@ifnot seen_inv2_hall_tube -> first
think: The speaking tube goes straight to Snapjaw. I am never talking into it again.
@end
@label first
narr: A brass speaking tube pokes out of the wall, its mouth flared like a little trumpet with a lid.
think: Old ships used these to talk between decks. I wonder where this one goes...
mochi: Hello? Is anybody there?
@sfx static
snapjaw[happy]: Snapjaw's Room Service! How may I ignore you today? Snap-snap-snap!
mochi: ...Never mind.
snapjaw[normal]: Every speaking tube on the Mudlark leads to ME, little detective. Every single one. Do enjoy your investigation!
think: Great. A trumpet in the wall that only talks to the warden. Very helpful.
@end
""",
	"inv2_talk_lulu": """
@ifnot seen_inv2_talk_lulu -> first
lulu[sad]: Promenade deck, 10:15 to 11:30, with Bramble and Fennel. Glowing mushrooms. Then bed. Lulu-lu...
@end
@label first
lulu[sad]: Mochi... Marigold gave me honey for my throat yesterday when my voice cracked. She said an idol has to look after her pipes.
mochi: Lulu, where were you last night?
lulu[normal]: Up on the promenade deck with Bramble and Fennel! From 10:15 until about 11:30. We watched the glowing fungus.
lulu[sad]: I didn't look down at the mud, though. That old plug hole is so black. Like it goes down forever...
lulu[normal]: Fennel painted. Bramble talked to the mushrooms. And I sang them a sea shanty. A pop one!
lulu[sad]: We were all just up there being happy. And Marigold was down here, all alone...
@end
""",
	"inv2_talk_pepper": """
@ifnot seen_inv2_talk_pepper -> first
pepper[normal]: Cough at 10:04, 10:08, 10:12... every four minutes like clockwork, until midnight. My log doesn't lie!
@clue pepper_log
@end
@label first
pepper[normal]: Mochi! Investigating too, huh? Cute. I've been at it since seven. I'm basically the lead detective.
mochi: Pepper, where were you last night?
pepper[happy]: Cabin 3, writing my scoop. And I can PROVE I was awake the whole time. Because SOMEONE snored.
pepper[normal]: So I did what any real journalist does. I got out my stopwatch and timed it. A journalist times EVERYTHING.
narr: Pepper flips open her notebook. Rows of neat little numbers march down the page.
pepper[normal]: Old Tumble does this squeaky little cough in his sleep. Hrrk! Like that. Cough at 10:04. 10:08. 10:12. 10:16...
pepper[happy]: Every four minutes, right on the dot, until midnight. Then nothing. The fella snores like a metronome!
@clue pepper_log
think: Every four minutes on the dot... Tumble has a very tidy snore. Huh.
pepper[angry]: But forget the snoring. The real scoop is Bruno. Did you SEE him this morning? Coal from his ears to his tail!
@end
""",
	# =====================================================================================
	# TUMBLE'S CABIN (bg ship_tumble_cabin) - people: tumble (left)
	# =====================================================================================
	"inv2_enter_tumble_cabin": """
@ifnot seen_inv2_enter_tumble_cabin -> first
think: Tumble's cabin. He's still sitting on the edge of his bunk, blinking very slowly.
@end
@label first
@sfx door
narr: A small, tidy cabin. A bunk, a nightstand, a porthole glowing faintly aqua, and a nightcap on a hook.
tumble[normal]: Zzz... eh? What? Is it breakfast? Did somebody say there was a... oh. Oh, right. Poor Marigold.
think: Tumble is sitting up on the edge of his bunk, wrapped in his blanket shawl. He looks even sleepier than usual.
@end
""",
	"inv2_tumble_cabin_bunk": """
@ifnot seen_inv2_tumble_cabin_bunk -> first
think: Tumble's bunk is perfectly made, the pillow smooth. And four little round dents in the rug, by the wall next to my cabin.
@clue tumble_bunk
@end
@label first
narr: The bunk is neatly made. The blanket is tucked in tight, and the pillow is smooth and plump.
think: Wow. That's tidier than my bunk, and I'm a lot younger than Tumble.
tumble[happy]: Best bunk on the boat, young'un. Soft as a cloud.
narr: On the rug beside the bunk, close to the wall, there are four small, round dents pressed into the pile.
think: Four little round dents in a neat square. Like something with tiny feet stood here for a while. A stool, maybe?
think: That's the wall between this cabin and mine. Huh. Weird.
@clue tumble_bunk
tumble[normal]: That rug's older than I am. Lumpy as porridge. Zzz...
@end
""",
	"inv2_tumble_cabin_nightstand": """
@ifnot seen_inv2_tumble_cabin_nightstand -> first
think: Tumble's teacup is clean and dry. Marigold never brought him his 11:00 chamomile last night.
@end
@label first
narr: A little nightstand beside the bunk. On it sits a single teacup painted with daisies, perfectly clean and dry.
think: Marigold brought him chamomile every night at eleven. She told everyone at dinner.
tumble[sad]: Every night, that girl brought my tea. Never once woke me. I'd wake up to a cup of cold chamomile and drink it anyway.
tumble[sad]: This morning the cup was dry. Clean as a whistle. I thought she'd just forgotten, for once...
think: She never made it to eleven o'clock. Whatever happened to her, it happened before then.
@end
""",
	"inv2_tumble_cabin_porthole": """
@ifnot seen_inv2_tumble_cabin_porthole -> first
think: Mud flats, glowing fungus, and the gangway. It was raised all night. Nobody got on or off.
@end
@label first
narr: A round brass porthole. Outside, the drained lake stretches away in shining black mud, dotted with patches of aqua fungus.
think: You can see the gangway from here. It was raised all night, just like the rules said. Nobody got on or off the ship.
think: So whoever did this is still on board. Still on this boat. With us.
tumble[normal]: Pretty, isn't it? Reminds me of home. Little stone tub, warm as a hug, steam under the stars... zzz...
@end
""",
	"inv2_tumble_cabin_nightcap": """
@ifnot seen_inv2_tumble_cabin_nightcap -> first
think: Tumble's spare nightcap. One for sleeping, one for napping. Apparently very different activities.
@end
@label first
narr: A droopy, striped nightcap hangs from a hook on the wall. Tumble is wearing one exactly like it.
mochi: You have two nightcaps?
tumble[happy]: One for sleeping. One for napping. Very different activities, young'un. Don't mix 'em up. Terrible things happen.
think: I'm not going to ask what terrible things.
@end
""",
	"inv2_talk_tumble": """
@ifnot seen_inv2_talk_tumble -> first
tumble[normal]: Zzz... slept like a log, young'un. Ten 'til the morning chime. Didn't hear a thing... zzz...
@end
@label first
tumble[normal]: Zzz... eh? Oh. It's you, young'un. Sit, sit. Bunk's warm.
mochi: Mr. Tumble, how are you holding up?
tumble[sad]: Marigold was a sweet girl. Fussed over my old joints like they were made of glass. Nobody's fussed over me in years.
mochi: Where were you last night?
tumble[normal]: Right here. Went to bed at ten. Slept like a log 'til the morning chime. Didn't hear a thing.
tumble[happy]: Heh. Though I hear I'm a bit of a noisy log. Sorry about that, young'un. Thin walls.
mochi: It's okay. Honestly, it helped me fall asleep.
tumble[happy]: That's the spirit. Best lullaby in the world, a good snore. Zzz...
think: He nodded off again in the middle of his own sentence. Some things never change.
@end
""",
	# =====================================================================================
	# PURSER'S OFFICE (bg ship_purser) - people: zuzu (left), fennel (right)
	# =====================================================================================
	"inv2_enter_purser": """
@ifnot seen_inv2_enter_purser -> first
think: The purser's office. Dusty, quiet, and full of old ship junk. Zuzu and Fennel are poking around.
@end
@label first
@sfx door
narr: A cramped office full of old ledgers, a squat safe, a squashy armchair, and a desk with a brass contraption on it.
zuzu[normal]: sup. this room has the best junk on the boat. respect.
fennel[happy]: Mochi! The light in here is magnifique! Old brass, old dust, old secrets...
@end
""",
	"inv2_purser_dictaphone": """
@ifnot seen_inv2_purser_dictaphone -> first
zuzu[normal]: echo-matic. 4 min cylinders, 1 winding = 2 hrs. repeat lever's still on, spring's dead, no cylinder. idk who left it like that.
@clue dictaphone
@end
@label first
narr: On the desk sits a brass contraption with a big flared horn, a little crank, and four stubby round feet.
zuzu[happy]: the echo-matic. snapjaw-brand wax-cylinder dictaphone. still boomer. still goated.
zuzu[normal]: quick recap: pop in a wax cylinder, talk into the horn, it records. 4 minutes per cylinder.
zuzu[normal]: wind the spring and it plays back. one full winding runs for 2 hours. and this lever here is REPEAT. loops forever.
think: There's no cylinder inside right now. And the REPEAT lever is still flipped ON.
zuzu[normal]: spring's totally run down too. somebody played with my favorite toy and didn't put it back right. rude.
@clue dictaphone
fennel[normal]: It stands on four little feet, like a tiny brass pony. Magnifique. I must paint it one day.
@end
""",
	"inv2_purser_rack": """
@ifnot seen_inv2_purser_rack -> first
think: A wall rack of brass-capped wax cylinders. One slot is empty. Its label says BLANK.
@end
@label first
narr: A wooden wall rack holds rows of wax cylinders. Each one wears a little brass end-cap.
fennel[happy]: Like jars of jam on a pantry shelf! Magnifique, non?
think: Every slot is full... except one. There's a single empty gap in the middle row.
fennel[sad]: Ah, but the gap! Like a missing tooth! It ruins the whole composition.
zuzu[normal]: labels say stuff like SNAPJAW'S BIRTHDAY SPEECH and SNAPJAW LAUGHING VOL 9. the label under the gap just says BLANK.
@end
""",
	"inv2_purser_safe": """
@ifnot seen_inv2_purser_safe -> first
think: Snapjaw's safe. Zuzu tried 1234. Snapjaw is not that dumb. Unfortunately.
@end
@label first
narr: A squat iron safe with a Snapjaw logo on the door and a four-digit dial.
zuzu[normal]: tried to crack it. tried 1234. tried 0000. tried his birthday. he doesn't have a birthday.
zuzu[sad]: nothing. turns out he's not that dumb. unfortunately.
@sfx static
snapjaw[happy]: Ah-ah-ah! That's MY petty cash, little hacker! Paws off, or I'll have you for elevenses! Snap-snap-snap!
think: Elevenses... I'm going to pretend he means tea.
@end
""",
	"inv2_purser_armchair": """
@ifnot seen_inv2_purser_armchair -> first
think: The comfiest armchair on the boat. Half the ship seems to have napped in it.
@end
@label first
narr: A squashy old armchair, sagging in the middle like a hammock. A knitted blanket is folded over one arm.
fennel[normal]: Monsieur Tumble naps in this chair every afternoon. He says this is the quietest room on the whole boat.
fennel[happy]: He snores like a cello! Low and long. I sketched him once. An excellent model. He holds a pose forever.
zuzu[normal]: i nap in it too. it's the only chair on this boat that doesn't squeak. top tier chair. 10/10.
@end
""",
	"inv2_talk_zuzu": """
@ifnot seen_inv2_talk_zuzu -> first
zuzu[normal]: chess w/ nibs in the saloon till 1am. he says he was winning. he was not winning.
@end
@label first
zuzu[sad]: hey mochi. rip marigold. she kept telling me to drink water. i said i'm hydrated on vibes. she was right. i wasn't.
mochi: Where were you last night, Zuzu?
zuzu[normal]: saloon. chess w/ nibs. from dinner till like 1am. neither of us left. he says he was winning.
zuzu[happy]: he was not winning.
zuzu[normal]: also poked at snapjaw's cams. there's one in every corridor on this boat, but the feeds are locked. can't see a thing.
think: Cameras everywhere, and no way to see what they saw. Typical Snapjaw.
@end
""",
	"inv2_talk_fennel": """
@ifnot seen_inv2_talk_fennel -> first
fennel[normal]: The promenade deck with Lulu and Bramble, 10:15 to 11:30. I painted the fungus. Before I knew.
@end
@label first
fennel[sad]: Mochi, mon ami. I cannot paint today. Every color I mix comes out the green of her little cross.
mochi: Fennel, where were you last night?
fennel[normal]: On the promenade deck, with Lulu and Bramble. From 10:15 until 11:30. I painted the cave fungus glowing.
fennel[happy]: At eleven it glowed so bright, the whole cave turned aqua. Magnifique! I painted so fast I splashed my own beret.
fennel[sad]: And while I was up there painting the light, below my feet someone was putting one out. I will never paint that cave again.
@end
""",
	# =====================================================================================
	# INVESTIGATION END (story screen, full-screen; explicit @show)
	# =====================================================================================
	"investigation_end": """
@bg ship_deck
@music stop
@sfx chime
narr: Ding-dong. Every speaker on the Mudlark crackled to life at once.
@sfx static
@show snapjaw happy center
snapjaw[happy]: Attention, my soggy little guests! Time's UP! Everybody down to the dock! Your ride to the Splash Trial awaits!
@hide snapjaw
@bg ship_dock
narr: One by one, the survivors filed down the gangway onto the mud flats. Nobody said much.
@sfx whoosh
@shake 8
narr: Out in the middle of the flats, the old plug hole began to gurgle. A giant glass bubble rose out of it, glowing turquoise.
@show duchess angry left
@show reginald angry right
duchess[angry]: If anyone so much as LOOKS at my shawl down there, I shall scream.
reginald[angry]: Look at it, madam? I intend to point at it!
@hide all
@show grub sad left
@show nibs sad right
grub[sad]: She should be here. She'd be making everybody drink a glass of water before the trial...
nibs[sad]: She would. And then she'd check our pulses. Mine is very high, Grub. Hypothetically, she'd be worried.
@hide all
@show tumble normal center
tumble[normal]: Zzz... eh? Are we going somewhere? ...Ah. Down again. My old knees hate that bubble.
@hide all
@bg none
@sfx door
narr: The bubble sealed with a soft pop and sank back into the plug hole. Down through the mud. Down, and down, and down.
think: Twelve of us now. At the last trial, there were fourteen.
think: If we get the vote wrong, everyone but the killer will be punished. And if we get it right... there will be eleven.
@bg trial
@music tension
@sfx splash
narr: The bubble burst open onto the vast round chamber and its glowing turquoise pool.
narr: Fifteen wooden podiums in a ring. Three of them now held framed portraits crossed out with red tape. Coco. Wisp. Marigold.
think: Marigold... one of the capybaras standing at these podiums took you away from us.
think: I'm going to find out who. And this time, I'm going to listen even harder.
@end
""",
	# =====================================================================================
	# THE SPLASH TRIAL (trial screen, stage mode / auto_portrait)
	# =====================================================================================
	"trial": """
@bg trial
@music trial
@card THE SPLASH TRIAL | Case 2: Murder on the Mudlark
@sfx splash
@shake 8
narr: With a geyser of turquoise spray, Warden Snapjaw burst out of the pool and flopped onto his throne, dripping and delighted.
snapjaw[happy]: Welcome BACK, my darlings, to the second SPLASH TRIAL! Two trials in two days! You spoil me! Snap-snap-snap!
snapjaw[happy]: Fifteen podiums, twelve guests and three portraits! The decor really is coming along nicely, don't you think?
think: Coco's portrait. Wisp's. And now Marigold's, smiling, with that little green cross on her cap.
grub[sad]: Her podium's right next to mine. She was always telling me to stand up straight. I'm standing up straight, Marigold...
snapjaw[normal]: You all know the rules by now, so I'll keep it short. I know, I know. I'm very considerate.
snapjaw[normal]: Debate. Vote. Majority rules. Pick the real culprit, and only the culprit gets punished.
snapjaw[angry]: Pick WRONG, and everyone ELSE gets punished while the culprit checks out! Free as a bird!
snapjaw[happy]: And Mochi, mind your *Convince Meter*! Under *60%* at the vote, and nobody listens to you. Snap-snap-snap!
think: Same rules. Same pool. One fewer friend. Okay, Mochi. Listen hard. Every argument counts.
@choice What should I say?
> We'll find the truth. For Marigold. -> open_vow
> You won't get away with this, Snapjaw. -> open_snap
@label open_vow
mochi: We'll find the truth. For Marigold. She looked after every single one of us.
lulu[sad]: For Marigold... Lulu-lu.
@jump open_done
@label open_snap
mochi: You won't get away with this forever, Snapjaw.
snapjaw[happy]: Ooh, a threat! How refreshing! Put it in the suggestion box. The suggestion box is the pool. Snap-snap-snap!
@label open_done
pepper[angry]: Then let's get to it! Because the answer's standing right over there, covered in coal. Bruno!
bruno[shock]: B-Bruno?! Again?!
bruno[sad]: Pepper said sorry to Bruno only yesterday...
pepper[angry]: And I MEANT it! That was a different murder! This is a brand-new scoop!
reginald[angry]: I say, the journalist may be onto something. But I have a far more obvious suspect. The Duchess!
duchess[shock]: ME?!
reginald[angry]: At dinner she told Marigold she'd regret meddling with her! Before witnesses! Before SOUP!
duchess[angry]: Darling, I say that to everyone. I once said it to a hat.
tumble[normal]: Zzz... eh? Did somebody say hat? I like hats. Nice hat, sonny.
duchess[angry]: I am a DUCHESS, not a sonny!
tumble[happy]: Everybody's a sonny at my age. Zzz...
grub[shock]: W-wait, wait! Everybody's going to look at me next, aren't they? I found her! I was the last one to see her!
grub[sad]: I'm the worst sandwich of facts on this whole ship...
zuzu[normal]: chill. nobody accused you. yet.
grub[shock]: YET?!
nibs[normal]: Order! Order, please. Hypothetically, we could shout at each other all day. Let us begin with the facts.
nibs[normal]: Snapjaw File #2. Victim: Marigold Fern, the Ace Nurse. Found in the infirmary at 7:00 AM, by Grub.
nibs[normal]: One heavy blow to the back of the head. Time of death: between 10:00 PM and midnight.
nibs[sad]: And I examined the bruise myself. Curved, with a little hook at one end. Something heavy, with a very particular shape.
think: Something heavy and curved... and something that went missing from the infirmary.
@minigame c2_q_weapon
mochi: This. The infirmary's brass anchor doorstop. I found it buried in the coal pile in the boiler room.
mochi: It used to hold Marigold's door open. This morning the door was swinging loose, and the anchor was gone.
nibs[normal]: The fluke of an anchor is curved, with a hook at the tip. It matches the bruise exactly. Fascinating. And horrible.
@sfx gasp
grub[shock]: Her doorstop?! She could barely even lift that thing! She said it weighed a ton!
lulu[sad]: Someone hit her with her own doorstop... while she was taking care of everybody...
reginald[angry]: And then buried it in coal! In the BOILER ROOM! I need not say whose boiler room that is.
bruno[sad]: ...Bruno's boiler room.
snapjaw[happy]: Ooh, now THAT'S a heavy piece of evidence! Get it? Heavy? Snap-snap-snap!
zuzu[normal]: ok. weapon: anchor. next question. when.
grub[normal]: Oh! I can help with that. I think. Maybe. Let me try...
think: Grub saw her at 10:30. And Marigold wrote down absolutely everything...
@minigame c2_q_time
mochi: At 10:40. Marigold logged every visit in her rounds log. Her last entry says: 10:40, kettle on.
mochi: And that line never ends. The ink trails off into a smear, as if her pen slipped while she was still writing.
mochi: The kettle she put on was found this morning, boiled completely dry. Nobody ever came back to take it off.
grub[sad]: She gave me my tonic at 10:30, and she was humming. And ten minutes later...
@ifnot seen_inv2_tumble_cabin_nightstand -> no_cup
mochi: Tumble's teacup was clean and dry this morning, too. She never brought him his 11:00 chamomile.
tumble[normal]: Zzz... eh? My tea? No, no tea last night. Didn't even notice. Slept right through, as usual.
@label no_cup
nibs[normal]: 10:40, then. It fits the file perfectly. A tidy nurse, to the very last line.
pepper[angry]: Great! Now we know when. And I know WHO! Did everybody see the boot prints in that coal dust?
pepper[angry]: Gigantic! From the door to the coal pile and back! And who on this ship has feet like rowboats?
bruno[sad]: ...Bruno has big feet. Bruno cannot deny it.
reginald[angry]: Ha! The brute admits it!
bruno[shock]: Bruno admits FEET! Not murder!
think: Those prints in the coal dust... they were huge, yes. But something about them was off. And something in the laundry, too...
@minigame c2_debate_boots
mochi: Reginald, those prints weren't made by Bruno's own boots. They were made by his *spare* boots.
mochi: Bruno left them clean, drying in the laundry. This morning they had coal in the treads, and socks crumpled deep into both toes.
bruno[normal]: Bruno did not put socks in his boots. Bruno's boots fit Bruno. Very roomy. Like a cave.
mochi: Exactly. Bruno doesn't need to stuff his toes. Someone with much smaller feet does.
nibs[happy]: And the prints are shallow and close together. Hypothetically: a light capybara, taking small steps in enormous boots.
fennel[happy]: Like a little one wearing papa's shoes! Clomp, clomp! Magnifique! Er... I mean, sinister. Very sinister.
@shout mochi SOMEONE ELSE WORE THOSE BOOTS!
reginald[shock]: Then the boots were a costume! Someone dressed up as the brute! I mean... as Bruno.
bruno[happy]: Mochi... Bruno owes Mochi two big hugs now. Gentle ones.
pepper[sad]: Ugh. Bruno's off my front page. Again. My editor is going to fire me. I'm my own editor.
reginald[angry]: Very well! If someone wished to frame Bruno, I know exactly who would stoop so low. The one who left her calling card!
reginald[angry]: A scrap of lilac silk, on poor Marigold's cot! Only one capybara aboard drapes herself in lilac!
duchess[angry]: Lilac is a COLOR, darling, not a confession!
lulu[sad]: But it really does look just like your shawl...
think: The scrap on the cot. And the shawl on the drying line. I saw them both up close...
@minigame c2_debate_shawl
mochi: Pepper, the Duchess's shawl wasn't torn in any struggle. One corner is missing, cut off in a perfectly straight line.
mochi: When silk tears, it rips and frays. This was snipped, neatly. With scissors.
@shout mochi IT WAS CUT, NOT TORN!
duchess[shock]: Scissors... The sewing basket! It sits right there in the laundry, beside the drying line!
fennel[normal]: A straight edge, cut clean. I have cut a thousand canvases, mon ami. That is a scissor line. Never a struggle.
mochi: Someone cut that corner off on purpose and left it on Marigold's cot. So that we'd all think of the Duchess.
duchess[angry]: Framed! Like a portrait! In a hideous, tacky frame! I want a lawyer! Do we have a lawyer?
snapjaw[happy]: You have ME! I'm extremely legal! Snap-snap-snap!
duchess[sad]: ...Never mind.
pepper[sad]: Okay, okay. Retraction. Two retractions in one trial. That has to be a personal record.
reginald[sad]: And I accused a lady... I say. A Puddlesworth owes the Duchess an apology. With a bow. A deep one.
nibs[normal]: Then let us take stock. Two disguises for a frame-up: Bruno's spare boots, and the Duchess's shawl.
nibs[normal]: And both of them were taken from the very same place. So where did the culprit go first?
@minigame c2_q_laundry
mochi: The laundry. Bruno's spare boots were on the boot rack, the Duchess's shawl was on the drying line, and the scissors were in the sewing basket.
mochi: Everything the culprit needed to frame two capybaras was waiting in one unlocked room.
zuzu[normal]: two frames, one room. efficient. evil, but efficient.
bramble[sad]: The laundry smelled of coal this morning. I noticed it. I just didn't know what it meant...
nibs[normal]: So: the laundry, for the disguise. The infirmary, at 10:40. The boiler room, to bury the anchor. And back again.
zuzu[normal]: k. alibi speedrun. who was where at 10:40. go.
nibs[normal]: Zuzu and I played chess in the saloon from dinner until 1 AM. Neither of us left the board.
zuzu[normal]: can confirm. he says he was winning. he was not.
lulu[normal]: Bramble, Fennel and me were on the promenade deck from 10:15 until 11:30! Watching the glowing mushrooms!
fennel[happy]: Oui! I painted the whole time. Lulu and Bramble posed beautifully. The mushrooms did not.
bramble[normal]: We never left each other. Not even for a moment.
bruno[sad]: Bruno went to bed early. Alone. Nobody can say so but Bruno.
duchess[angry]: My cabin. Alone. Wide awake, because SOMEONE confiscated my powder. Not that I'm bitter. I am extremely bitter.
reginald[sad]: I was keeping the night watch at the stern. And I... rested my eyes. Alone. Until two in the morning.
grub[sad]: I went to bed right after my tonic at 10:30. Alone. Then I got up at six to bake. Alone. And then I found her...
pepper[angry]: Four capybaras with no alibi! Bruno, the Duchess, Reginald and Grub! One of you is lying!
reginald[angry]: How dare you! A Puddlesworth never lies! He merely naps at inopportune moments!
duchess[angry]: Do NOT lump me in with the napping knight and the soup-spiller!
grub[shock]: Soup-spiller?! That was ONE bowl!
bruno[sad]: Bruno is just sad...
pepper[normal]: Well, at least ONE of us has a perfect alibi. Tumble!
pepper[happy]: I was in Cabin 3, right next door to him. Mochi was in Cabin 1, on his other side. We heard him snore the whole night!
tumble[normal]: Zzz... eh? Was I loud? Sorry, young'uns. Thin walls.
mochi: It's true. I heard him through the wall, from the nighttime chime until around midnight. Snoring, nonstop.
lulu[happy]: Aww! Mr. Tumble has the best alibi of anybody! Sleeping!
snapjaw[happy]: The perfect alibi: catching up on your beauty sleep! Snap-snap-snap!
think: Right. I heard him myself. Steady as waves, with that same funny little cough...
think: ...The same little cough. Every time.
think: And every night at eleven, Marigold came in with his chamomile. The only one who ever looked in on him. Except last night.
think: Through the wall, the snoring never changed. Not once. Not when she should have come in. Not ever. It was just so... perfect.
@music trial_climax
@minigame c2_debate_snore
mochi: Pepper, it wasn't natural at all. And your own log proves it.
mochi: The same squeaky little cough at 10:04, 10:08, 10:12... Exactly every four minutes, on the dot, for two whole hours.
pepper[shock]: W-well, yes! I wrote it down because it was funny! He was like a clock! A snoring clock!
mochi: That's just it. Nobody sleeps like a clock. Sleepers roll over. They mumble. They get quieter, then louder again.
nibs[shock]: Mochi is right. Hypothetically, a sleeping capybara's breathing drifts all night long. But an identical sound, at identical intervals...
nibs[normal]: That isn't biology. That's a pattern. A loop.
think: The same four minutes, over and over and over, for two hours. That wasn't Tumble snoring at all. It was...
@minigame c2_bubbles_recording
@shout mochi IT WAS A RECORDING!
mochi: Someone played a recording of snoring against that wall. The same four minutes, again and again, all night long.
lulu[shock]: A recording?! Of SNORING?! Who records snoring?! Lulu-lu?!
pepper[shock]: I spent two hours logging a... a tape?! I'm a professional! I have a press card!
reginald[normal]: But surely no such contraption exists aboard this rusty old tub?
zuzu[normal]: wait. record. loop. ...oh. oh no. i know this one.
think: Zuzu showed off that old machine like a toy. There's only one thing on the Mudlark that could do this...
@minigame c2_q_device
mochi: The Echo-Matic dictaphone, from the purser's office. A wax-cylinder recorder with a big brass horn.
zuzu[normal]: specs: 4-minute cylinders. a REPEAT lever that loops forever. one winding of the spring = 2 hours of playback.
mochi: Wind it fully at ten o'clock, flip REPEAT, and it plays the same four minutes over and over... until the spring runs down.
pepper[shock]: Two hours from ten o'clock is... midnight. That's exactly when the snoring stopped!
mochi: And this morning, its REPEAT lever was still switched ON. The spring was completely run down. And there was no cylinder inside.
grub[shock]: Somebody played that thing all night long! And then put it back like nothing happened!
duchess[shock]: How utterly devious. And how utterly unfashionable. Wax cylinders, darling? Honestly.
nibs[normal]: Then the next question is very simple. And very uncomfortable.
think: A recording of snoring... with a little squeaky cough in it. Whose snoring?
@minigame c2_q_who
mochi: Yours, Tumble. The snoring Pepper and I heard all night... was a recording of you.
@sfx gasp
@shake 10
all: TUMBLE?!
lulu[shock]: Mr. Tumble?! But he's... he's Mr. TUMBLE! He sleeps through everything!
bruno[shock]: Bruno has to carry Tumble up stairs! Tumble falls asleep on Bruno's back!
reginald[shock]: Preposterous! The fellow must be ninety if he's a day!
tumble[normal]: ...Ninety-one.
narr: The chamber went very quiet.
pepper[shock]: Wait. Wait, wait, wait. If the snoring was a recording... then Tumble wasn't in his bunk at all?
duchess[shock]: Then the only capybara with a perfect alibi has... no alibi whatsoever.
tumble[normal]: Zzz...
snapjaw[happy]: Ooooh! Wakey, wakey, grandpa! I think they're talking about YOU! Snap-snap-snap!
tumble[normal]: Zzz... zz...
tumble[normal]: ...
tumble[normal]: Hm. That's a fine story, young'un. A fine, tall story.
narr: Tumble's voice had changed. Low. Steady. Not the slightest bit sleepy.
think: No Zzz. No eh, what? For the first time since I met him... Tumble sounds wide awake.
tumble[normal]: But you've built it on an awful lot of guesswork. Let an old capybara set you straight.
@minigame c2_rebuttal_tumble
mochi: Your own bunk proves it, Tumble. Four small, round dents in the rug beside it, close to the wall you share with my cabin.
mochi: The Echo-Matic stands on four little round feet. That's where it stood all night long. With its horn pointed at my wall.
zuzu[normal]: four feet, four dents. that's a hardware fingerprint. gg.
mochi: And your bunk was made perfectly, the pillow smooth as new. Nobody had slept in that bed at all.
pepper[sad]: So for two hours, I sat there with my stopwatch... timing a machine. And calling it an alibi.
tumble[normal]: Dents in a rug. Heh. My rug's lumpy as porridge, young'un.
tumble[angry]: You want to talk evidence? Fine. Let's talk evidence.
@minigame c2_q_cylinder
mochi: Nobody can play it, because it's been burned. This melted lump of wax was in the furnace ash, with a little brass end-cap stuck in it.
mochi: The same brass end-caps as the wax cylinders in the purser's office. And one slot on that rack is empty.
@ifnot seen_inv2_purser_rack -> no_rack
fennel[shock]: The missing tooth! The gap in the rack! The label under it said BLANK!
@label no_rack
bruno[normal]: That lump was not in the furnace when Bruno banked the fire last night. Bruno is sure. Bruno is tidy.
mochi: So the cylinder was burned sometime before Bruno came down to shovel at 6:30 this morning.
grub[shock]: Six... in the morning... Oh. Oh no.
grub[shock]: My ghost! At six, I saw a small hunched figure carrying a big trumpet thing into the purser's office!
mochi: That trumpet was the Echo-Matic's brass horn, Grub. It wasn't a ghost. It was someone putting the dictaphone back before anyone woke up.
mochi: Then they burned the cylinder in the furnace before Bruno came down at 6:30. And they forgot to flip the REPEAT lever back.
grub[sad]: I ran away from... and I baked four loaves of bread because I was scared of a ghost...
nibs[normal]: Small and hunched. Light, with short steps, swimming in enormous boots. Hypothetically... it all fits one shape.
narr: Nobody said it. Nobody had to. One by one, every eye in the chamber turned to the smallest, most hunched capybara at the podiums.
tumble[normal]: ...
snapjaw[happy]: Ooh, the tension! I could cut it with a tooth! Mochi, why don't you walk us through the whole night? From the top!
think: Alright. From the very beginning. Every piece, in order. For Marigold.
@minigame c2_rewind_final
@shout mochi IT WAS YOU, TUMBLE!
narr: The chamber fell silent. Even the turquoise pool stopped rippling.
tumble[sad]: ...
bruno[sad]: Old Man Tumble... let everyone think it was Bruno. And the Duchess.
duchess[sad]: My shawl. You cut my shawl, you... you sweet old fool. Why?
pepper[sad]: I logged every cough. I wrote it all down like a clue. I made your alibi for you...
tumble[sad]: ...
@music snapjaw
snapjaw[happy]: Snap-snap-snap! And now, my absolute FAVORITE part! It's VOTING TIME!
snapjaw[happy]: Who killed Marigold Fern? Choose wisely... or don't! I'm entertained either way!
snapjaw[normal]: Remember, majority rules. If Mochi hasn't convinced you, just follow that gut of yours. Snap-snap-snap!
think: This is it. Before we vote... should I say something to everyone?
@choice One last word before the vote...
> Trust the evidence. -> last_evidence
> Do it for Marigold. -> last_marigold
@label last_evidence
mochi: Everyone, please. Don't vote with your gut. Vote with the evidence. Every Truth Drop points the same way.
@jump last_done
@label last_marigold
mochi: Everyone... Marigold looked after all of us. She'd tell us to be brave. So let's be brave. For her.
@label last_done
grub[sad]: Whatever happens, Mochi... she'd have been proud of you. And she'd have told you to drink some water.
think: I hope I've convinced them. For Marigold.
@minigame c2_vote_final
@ifnot vote_correct -> wrong
@label correct
@sfx correct
@shout snapjaw CORRECT!
snapjaw[happy]: Ding-ding-ding! The one who killed Marigold Fern was Old Man Tumble, the Ace Napper!
snapjaw[happy]: Splendid! Two for two! You're all becoming such clever little detectives! Snap-snap-snap!
@music sad
narr: Tumble sat very still at his podium. Then, slowly, for the first time since any of them had met him, his eyes opened all the way.
tumble[normal]: ...Well. That's that, then.
narr: His voice was calm. Clear. There wasn't a trace of sleep left in it.
lulu[sad]: Mr. Tumble... why? Why Marigold?
tumble[sad]: The postcard.
tumble[sad]: Back in my village there's a little stone tub. I built it with my own two paws, sixty years ago. Warm as a hug.
tumble[sad]: Every capybara in that village has soaked in it. Babies. Grandmas. Me, every night for sixty years.
tumble[sad]: On my postcard there was a bulldozer sitting in it. Three days, it said.
tumble[sad]: I knew what I'd do the moment I saw it. I just lay there with the card on my belly, pretending to snore. And I planned.
tumble[sad]: The Echo-Matic was easy. I nap in that office every afternoon. Nobody looks twice at an old fella with his eyes shut.
tumble[sad]: But I knew one thing for certain. Every night at eleven, Marigold came in with my chamomile. She never once missed.
tumble[sad]: She'd have found my bunk empty. And a machine snoring on the rug.
tumble[sad]: So it had to be her. The only one on this boat who ever checked on me... had to be the one.
@sfx heartbeat
grub[sad]: She brought you tea. Every night. She brought you TEA, Tumble...
tumble[sad]: I know, sonny. I know. I'll hear that kettle whistling for however much time I've got left.
tumble[sad]: Bruno. Duchess. I'm sorry. I used your things because they were there. That's all. An old fool's shortcut.
bruno[sad]: Bruno... does not know what to say to Tumble.
duchess[sad]: ...Neither do I, darling. For once in my life.
tumble[normal]: Mochi. Your postcard had a hot spring on it too, didn't it? I saw your face.
mochi: ...Yes. Ours, back home. They were filling it with concrete.
tumble[sad]: Then you know how it pulls at you. Don't let it pull you where it pulled me, young'un. Promise an old fool that.
mochi: I promise.
tumble[sad]: Good. Good.
tumble[normal]: You all thought I was always sleeping. I haven't truly slept in forty years, sonny.
tumble[normal]: Old capybaras just close their eyes and listen.
tumble[sad]: So I heard every kind thing any of you ever said about me. Thank you for those. I didn't deserve a single one.
narr: Tumble tugged his droopy nightcap down over his eyes, as if he could still make it all go dark.
think: We found the truth again. And again, it doesn't feel anything like winning.
@music snapjaw
snapjaw[happy]: Sniff! Such a sleepy little tragedy! Now, then... I've prepared something VERY special for our Ace Napper!
snapjaw[happy]: Everyone deserves a good night's rest. A long one. A VERY, VERY long one!
@card THE ENDLESS LULLABY | Old Man Tumble's Final Bedtime
snapjaw[happy]: It's PUNISHMENT TIME! Snap-snap-snap!
@end
# ---------------------------------------------------------------- WRONG VERDICT
@label wrong
@sfx wrong
@shout snapjaw WRONG!
snapjaw[happy]: Ding-ding-ding! The votes are in, and the majority is... WRONG! Wrong, wrong, WRONG!
snapjaw[happy]: The one who killed Marigold Fern was Old Man Tumble, the Ace Napper! Snap-snap-snap!
narr: Tumble's eyes opened all the way. For the first time, there wasn't a trace of sleep in them.
tumble[sad]: ...Sorry, young'uns. I truly am. Sleep tight.
snapjaw[happy]: Congratulations, grandpa! You get to CHECK OUT! As for the rest of you...
snapjaw[happy]: It's PUNISHMENT TIME for everybody else! Lights out! Snap-snap-snap!
think: No... I couldn't convince them. Marigold... everyone... I'm so sorry.
@end
""",
}

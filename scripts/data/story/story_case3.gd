extends RefCounted
## Chapter 3 ("Murder at Warden's Rest") case scripts: the investigation, investigation_end and the trial.
## DSL reference: docs/ARCHITECTURE.md section 3. Rooms: scripts/data/investigation_data3.gd. Minigames:
## scripts/data/trial_data3.gd. Spoilers: docs/DESIGN3.md ("The investigation") and the plan's spoiler file.
##
## Investigation snippets play as a transparent auto_portrait overlay on top of the room. The investigation screen sets
## flag "seen_<script id>" after a snippet finishes, so each starts with "@ifnot seen_<id> -> first": a short revisit
## line first, then "@label first" and the first look. Truth Drops are given again on a revisit (skipped if held).
## Writing rules for this file: a Truth Drop's line says what's there, never what it means; Mochi may wonder, but never
## settles anything; every talk reveals that guest's own rows on the Alibi Board and one People entry, and no guest
## gets more room than the others. The stage scripts (inv3_stage2, inv3_stage3) are the story breaks between stages.
## The trial, the recess talks and the confession follow the investigation (see the notes above "trial").

const SCRIPTS := {
	# =====================================================================================
	# INVESTIGATION - start / complete / the two stage breaks
	# =====================================================================================
	"investigation_start": """
@card INVESTIGATION | Day 6, Warden's Rest
@music sad
think: Professor Nibs. He was going to have an answer for all of us by midnight. Now he's the question.
snapjaw[happy]: My darlings! Your case file. Hot off my own little press, and very nearly accurate.
@anim c3_inv_file
@clue snapjaw_file3
snapjaw[normal]: The Library and the Grand Hall are yours to rummage. The rest of my house stays locked until I say otherwise.
snapjaw[happy]: I'll say otherwise when it amuses me. Snap-snap-snap!
@clue rules3
think: Before I touch anything, I'm writing down what I already know. All of it. Even the bits that can't possibly matter.
think: The four lines he read out of the Ledger. The bats on the first day. Grub and the soup, yesterday afternoon.
@clue ledger_read
@clue bat_bite
@clue grub_soup
@log timeline Day 6, morning. Snapjaw handed out his file. The Library and the Grand Hall are open; the rest of the house is locked for now.
narr: TIP: Examine things and talk to everyone. The Map (M) takes you back to places you've already walked to. N opens the notebook, L the Log.
@end
""",

	"investigation_complete": """
@anim c3_inv_done
snapjaw[happy]: Finished already? Mochi says so, and I always trust a capybara with dust in its ears.
think: A bookcase. A cold pot of tea. Dust on dust. A house full of people who all did something last night.
think: Nibs would say: don't guess. Measure. Then guess. Then measure again.
think: All right, Professor. I've measured everything I could find. Let's see who it measures up to.
@end
""",

	"inv3_stage2": """
@bg manor_hall
@music tension
narr: I was halfway down the stairs when the shouting started.
reginald[angry]: Out with it! You were the last one to see him alive. Where did you go after you left him?
zuzu[angry]: i told mochi. the attic.
reginald[angry]: Doing WHAT? A screen, you said! Then show us the screen!
narr: Zuzu went up the back stairs three at a time. We all went after them, all the way up under the roof.
@anim c3_inv_delete
@bg manor_attic
zuzu[sad]: there. it's gone. happy?
reginald[shock]: You... you've wiped it. In front of every one of us.
zuzu[angry]: it was mine. whatever it was, it was MINE. it's got nothing to do with him.
narr: Nobody said anything for a long moment. Lulu looked at the floor. Bramble looked at the door.
narr: Pepper had her camera halfway up before she remembered it was empty.
think: That didn't settle anything. It just made everybody a little more sure of whatever they thought already.
snapjaw[happy]: Drama! Lovely. Now out of my Attic, all of you. My cameras are sulking.
snapjaw[happy]: Since you're all in such a sharing mood: the kitchens, the cellar, the music, the flowers, the terrace...
snapjaw[happy]: ...and my poor dear wreck on the shore. Open! Off you go!
@log timeline Zuzu wouldn't say what they did in the Attic after the argument, and cleared something off their screen in front of everyone.
@log timeline Snapjaw opened the rest of the house, the kitchens and the cellar, the Generator Room and the wreck on the shore.
think: Nibs asked Grub for a pot of tea at ten. Grub said somebody else would have to make it. I never found out if anybody did.
@bg none
@end
""",

	"inv3_snn": """
@sfx chime
narr: Every screen in the house came on at once, the way they do. The one in the kitchen, the one in the cellar, even the cracked old set on the wreck.
@anim snn_c3_6
narr: Somebody threw a shoe at the screen in the Grand Hall. I heard it from the other end of the house.
@log timeline Mid-morning, every screen in the house came on: Snapjaw selling hourglasses.
@end
""",

	"inv3_stage3": """
@bg manor_conservatory
@music tension
narr: I heard Lulu scream from the far side of the house.
narr: By the time I got to the Conservatory, half of us were there. Lulu was backed up against the glass with a jug in her paws, water slopping out of it.
lulu[shock]: Lulu only... Lulu was only filling the jug for him! He looked so thirsty! Lulu only held it out!
@anim c3_inv_fountain
narr: Grub was on his knees by the fountain, as far from the water as he could get, both paws over his face.
grub[sad]: I'm sorry. I'm sorry, love. I don't know what that was. It wasn't me. It sounded like me, but it wasn't.
narr: There was drool on his chin. He wiped at it, and his paw was shaking so hard he missed.
bruno[sad]: Grub. Come. Bruno will walk with you. Away from the water. Slowly.
narr: Bruno helped him up and walked him out with one huge arm round his shoulders, the way you'd walk an old dog home. Lulu didn't move until they'd gone.
snapjaw[happy]: Oh dear. Oh dear, dear, dear. Well! To take your minds off it: the Gallery, the Attic and the late Professor's bedroom.
@anim c3_inv_open
bruno[normal]: Mochi. Bruno brought up the big lamp from the Generator Room. For dark places. This house has a lot of dark places.
@log timeline Lulu held out a jug of water to Grub at the Conservatory fountain, and he went for her. Bruno walked him away from the water.
@log timeline Snapjaw opened the Gallery, the Attic and the Plover Room. Bruno brought up a big lamp from the Generator Room.
narr: On my way back through the house I passed the Library. The tapestry on the far wall moved. Just a little, the way a curtain moves at an open window.
think: There's no window behind that tapestry.
@bg none
@end
""",

	# =====================================================================================
	# LIBRARY (stage 1) - people: zuzu, pepper
	# =====================================================================================
	"inv3_enter_library": """
@ifnot seen_inv3_enter_library -> first
think: The Library. White dust, books everywhere, and the bookcase across his desk.
@end
@label first
@music sad
narr: The Library smells of plaster and cold tea. White dust lies over everything like the first snow nobody wanted.
narr: Zuzu hasn't gone far from the desk. Pepper stands by the window with her empty camera, turning it over and over in her paws.
think: Properly, Mochi. He'd want it done properly. Measure first, he'd say. Then guess. Then measure again.
@log places The Library, the morning after: white dust over everything, books across the floor, the tall bookcase down across the desk.
@end
""",

	"inv3_lib_bookcase": """
@ifnot seen_inv3_lib_bookcase -> first
think: The tall bookcase, face down across the desk. Its base a foot out from the wall, two pale scrapes on the boards behind it.
@clue fallen_bookcase
@end
@label first
narr: The tall bookcase lies face down across the desk at a steep slant, its top on the desk, its shelves emptied onto the floor.
narr: Its base isn't against the wall any more. It's a good foot out into the room.
narr: Behind it, from the skirting to the base, two pale scrape marks run across the floorboards where the old varnish has been scoured off.
think: Do bookcases walk before they fall? I've never stood and watched one.
@clue fallen_bookcase
@end
""",

	"inv3_lib_body": """
@ifnot seen_inv3_lib_body -> first
think: His right arm, broken under the shelf, with no swelling and no bruise. His tongue and teeth stained dark.
@clue arm_no_bruise
@clue nibs_mouth
@end
@label first
narr: Nibs sits slumped forward in his chair, his head on the desk, turned to the wall. His white coat is grey with plaster.
think: I'm sorry, Professor. I'll be quick. And careful. You'd want me careful.
narr: His right arm is out across the desk, pinned under the edge of the shelves. It's broken. It bends where an arm doesn't bend.
narr: I parted the fur round the break as gently as I could. Flat. Pale skin underneath. No swelling. No bruise.
@clue arm_no_bruise
narr: His mouth is a little open. His tongue and his front teeth are stained dark, nearly black. His lips are dry and cracked.
think: He chewed his pens. His teeth were always a bit inky. Grandma would have said he needed a toothbrush and a holiday.
@clue nibs_mouth
narr: His spectacles lie on the blotter, a little way from his face, the way you'd put them down to rest your eyes for a minute.
@end
""",

	"inv3_lib_brace": """
@ifnot seen_inv3_lib_brace -> first
think: Two clean screw holes high on the wall, and six screws in a row up on the cornice ledge, under the white dust.
@clue wall_anchor
@end
@label first
narr: High on the wall where the tall bookcase used to stand, under the deep cornice, there's a paler patch of wallpaper: the outline of an iron plate.
narr: In it, two screw holes. Clean ones. No splinters, no torn paper round them.
narr: I dragged the library ladder over and climbed up until my nose was level with the cornice ledge.
narr: Up there, along the top of the ledge, under the white dust: six screws, laid side by side in a neat little row.
think: Somebody tidy did that. Or something very tidy happened all by itself.
@clue wall_anchor
@end
""",

	"inv3_lib_desk": """
@ifnot seen_inv3_lib_desk -> first
think: Everything on and around his desk, and one plain black pen on the floor across the room, by the hatch.
@clue desk_contents
@end
@label first
narr: I went over the desk the way Nibs went over everything: in order, under my breath.
narr: The blotter. An inkstand with two wells, both half full. The lamp, still on. A ruler. Three books on typefaces. A magnifying glass.
narr: Loose notes in his round handwriting, all about letters: the height of a T, the tail of a g. A saucer of paper clips. His slippers under the desk.
narr: And across the room on the floor, by the dumbwaiter hatch, where half the room's loose things fetched up in the shaking: one plain black pen.
think: That's everything. I'll write it all down. Nibs always said the list is the experiment.
@clue desk_contents
@end
""",

	"inv3_lib_floor": """
@ifnot seen_inv3_lib_floor -> first
think: A plain black pen on the floor by the hatch. Smooth, end to end.
@clue desk_contents
@end
@label first
narr: Over by the dumbwaiter hatch, among the books and the dust: a plain black pen, lying on its side.
narr: I didn't pick it up. I crouched over it and looked. Smooth, end to end. A little gold clip. Not a mark on it.
think: It goes on my list of the things round his desk. Everything on this floor came from somewhere.
@clue desk_contents
@end
""",

	"inv3_lib_blotter": """
@ifnot seen_inv3_lib_blotter -> first
think: The blotter, backwards: 4:30 out. 5:40 back, shelf rocks, tell Bruno. Working notes down to 10:05, and no result.
@clue nibs_blotter
@end
@label first
narr: His big green blotter, soaked with a week of his writing. Backwards, the way blotters keep it.
narr: I tilted the brass inkstand until the blotter showed in its shine, and read what I could.
narr: Near the top: "4:30 out. Tide." A little lower: "5:40 back. Shelf rocks. Tell Bruno."
narr: Under that, lines and lines of working notes in a steady, careful hand, with times down the margin.
narr: The last time in the margin is 10:05. After that, nothing that took. And nowhere, in any line, a result.
think: "By midnight I'll have it," he said. Wherever he wrote it, the blotter never saw.
@clue nibs_blotter
@alibi nibs 6 PM
@alibi nibs 7 PM
@alibi nibs 10 PM
@end
""",

	"inv3_lib_side_table": """
@ifnot seen_inv3_lib_side_table -> first
think: The side table by the hatch: white dust over everything, one clean ring in it the size of a cup, and no cup.
@clue cup_ring
@end
@label first
narr: The little side table beside the dumbwaiter hatch. White dust lies over it in a fine, even film.
narr: The box of new pens he counted out loud on Day 3 sits there, lid open.
narr: And in the middle of the dust: a clean ring. A perfect circle of bare, polished wood, about the size of the foot of a teacup.
narr: There's no cup on the table. I looked under it, and round it, and behind the nearest books. No cup.
think: Nibs drank tea the way other people breathe. Where's his cup?
@clue cup_ring
@end
""",

	"inv3_lib_hatch": """
@ifnot seen_inv3_lib_hatch -> first
think: The dumbwaiter car, up at the Library end: a tray, a teapot of cold tea with pale grains in the bottom, a milk jug, no cup.
@clue tray_grains
@end
@label first
narr: The dumbwaiter hatch beside the side table is open a crack. I slid the shutter the rest of the way up.
narr: The car is up here, at the Library end. On it: a tray. A teapot, a little milk jug, and a round empty space where a cup would stand.
narr: The pot's two-thirds full and stone cold. I tipped it to the light. Pale grains have settled in the bottom, like sugar that never melted.
narr: A few more grains lie spilled on the tray, by the spout.
think: He asked for tea at ten. Somebody sent it up.
@clue tray_grains
@end
""",

	"inv3_lib_tapestry": """
@if seen_inv3_stage3 -> draught
@ifnot seen_inv3_lib_tapestry -> first
think: A faded hunting tapestry. Heavy as a carpet.
@end
@label first
narr: A big faded tapestry on the far wall: riders, a great many dogs, and in one corner a very relieved-looking fox.
narr: It's heavy as a carpet, and it hangs flat and still against the wall.
think: Grandma had one like it, with ducks. She said the ducks watched her. I didn't sleep at her house for a year.
@end
@label draught
@if inv3_found_tapestry_door -> known
narr: The tapestry breathed. Just a little. A cold draught came out from under its bottom edge and stirred the white dust on the floor.
narr: I lifted the corner. Behind it, set into the panelling: a narrow door. No handle on this side, only a brass ring. It turned.
think: A door in the wall. Behind his books. All this time.
@flag inv3_found_tapestry_door
@log places Behind the Library tapestry there's a narrow door into the wall.
@end
@label known
think: The narrow door behind the tapestry. It goes into the wall.
@end
""",

	"inv3_lib_books": """
@ifnot seen_inv3_lib_books -> first
think: Hundreds of books, spines up, all over the far side of the floor.
@end
@label first
narr: Books lie in drifts across the far side of the floor, hundreds of them, spines up and pages open, the way they slid off the shelves.
narr: Chemistry. Typefaces. A field guide to seaweed. Three copies of the same book on inks, every one with his notes in the margins.
think: Nobody meant to walk on them. Every one has a footprint on it anyway. Nearly all of us came in at once this morning.
@end
""",

	"inv3_lib_typewriter": """
@ifnot seen_inv3_lib_typewriter -> first
think: The Library's own typewriter, with somebody's sample still wound in.
@end
@label first
narr: The Library's own typewriter, black and heavy, on the reading table by the window. A sheet of paper is still wound in.
narr: Typed on it, once: "The quick brown capybara jumps over the lazy caiman." Somebody's sample from Day 3, never taken out.
think: At the Tribunal Nibs said the Ledger wasn't typed on this machine, not the lines and not the names. He said it like that settled something.
@end
""",

	"inv3_lib_door": """
@ifnot seen_inv3_lib_door -> first
think: The Library door hangs off one hinge. The frame's in splinters.
@end
@label first
narr: The Library door hangs off its top hinge, swung back against the wall. The edge where it shuts is splintered all the way down, and so is the frame.
narr: A small brass plate with two screws still through it lies in the splinters on the floor.
think: Bruno said the frame was warped from the shaking. Old wood, old house. It was always going to split, however he opened it.
@end
""",

	"inv3_lib_page": """
@ifnot seen_inv3_lib_page -> first
think: The Ledger page between the books: Fizz Bracken, laboratory assistant. On information from: D. Velveteen.
@clue ledger_library
@end
@label first
@if read_page_library -> known
narr: Slipped between two books on a shelf: a page torn out of the Ledger, folded once and unfolded again.
narr: "No. 192. Fizz Bracken, laboratory assistant. Held for: a small explosion, Tuesday."
narr: Underneath, in blacker, squarer type: "On information from: D. Velveteen."
think: Nibs's assistant. The page in his own Library, folded and unfolded. He never said a word about it.
@jump done
@label known
narr: The Ledger page between the books, where I left it. Fizz Bracken, Nibs's assistant. D. Velveteen.
think: Folded once and unfolded again. Somebody read it before I did, and put it back.
@label done
@clue ledger_library
@end
""",

	"inv3_talk_zuzu": """
@ifnot seen_inv3_talk_zuzu -> first
zuzu[sad]: attic. all night. that's it. that's all you get.
@end
@label first
zuzu[sad]: don't. i know. i found him. i had coffee. i had a whole speech.
mochi: Zuzu, I'm so sorry. I have to ask. After you and Nibs argued, where did you go?
zuzu[angry]: the attic. all night. and all afternoon before dinner, too, mapping his cameras. you know that.
mochi: Doing what, after the argument?
zuzu[sad]: ...things. on a screen. it doesn't matter.
zuzu[angry]: it doesn't MATTER, mochi. he's dead. whatever i was typing doesn't make him any less dead.
narr: Zuzu knelt down in the dust by the desk again, close to him, as if they were waiting for him to finish a sentence.
@alibi zuzu 6 PM
@alibi zuzu 7 PM
@alibi zuzu 10 PM
@alibi zuzu 11 PM
@alibi zuzu 12 AM
@log people zuzu Says they were in the Attic all night after the argument, and all afternoon before dinner. Won't say what they were doing.
@end
""",

	"inv3_talk_pepper": """
@ifnot seen_inv3_talk_pepper -> first
pepper[sad]: Darkroom all evening, partner. Flash pictures in the blackout. Then the Puddle, by candle, in my room.
@end
@label first
pepper[sad]: He took my film. Right out of the camera. Sixteen frames, and I couldn't tell you what's on them. I wasn't looking.
pepper[sad]: That's the job, Mochi. You point it at the worst thing in the room and you keep pressing. You look later. Except now I can't.
mochi: Pepper, where were you last night?
pepper[normal]: The Gallery. The darkroom cupboard, from dinner on. Four days of rolls, and at last some chemicals to soak them in.
pepper[normal]: Six, I was in there too. Seven, my room, putting on something without fixer stains down the front.
pepper[sad]: When the lights went at five past eleven I just... started shooting. Flash, flash, flash. Dust coming down in the dark. It was something to do with my paws.
pepper[normal]: Then up to my room to letter tomorrow's Puddle by candle. By hand. The ribbon's gone, and nobody on this island sells ribbon.
@alibi pepper 6 PM
@alibi pepper 7 PM
@alibi pepper 9 PM
@alibi pepper 10 PM
@alibi pepper 11 PM
@alibi pepper 12 AM
@log people pepper Says she was in the Gallery darkroom all evening, shot flash pictures there in the blackout, then lettered the Puddle in her room.
@end
""",

	# =====================================================================================
	# GRAND HALL (stage 1) - people: reginald, duchess
	# =====================================================================================
	"inv3_enter_grand_hall": """
@ifnot seen_inv3_enter_grand_hall -> first
think: The Grand Hall. White dust on the chequer, and the Library door at the top of the stairs.
@end
@label first
narr: The white dust has settled on the black and white tiles like flour on a chessboard. Footprints everywhere, all of them ours.
narr: Reginald is pacing at the foot of the stairs. The Duchess sits on the lowest step with her hat in her lap, which I have never once seen her do.
@log places The Grand Hall, the morning after: white dust over the tiles, and everybody's footprints through it.
@end
""",

	"inv3_hall_library_door": """
@ifnot seen_inv3_hall_library_door -> first
think: Low on the outside of the Library door: fresh scratches through the varnish, in rows of four.
@clue door_scratches
@end
@label first
narr: Up on the landing, the outside of the Library door. Low down, near the floor, the varnish is scored through to bare wood.
narr: Scratches. Lots of them, in rows of four, from the floor to about knee height. Little curls of varnish lie on the carpet underneath.
narr: The wood in the scratches is pale and clean. New.
think: Rows of four. Our front paws have four toes. All eleven of us. Ten, now.
@clue door_scratches
@end
""",

	"inv3_hall_notice": """
@ifnot seen_inv3_hall_notice -> first
think: The notice board: the card for the 11:05 aftershock, Grub's menu in pictures, and this morning's Puddle, lettered by hand.
@end
@label first
narr: The notice board by the front door. Pinned dead centre, in Snapjaw's spiky capitals, the card from yesterday morning:
narr: "AFTERSHOCK. TONIGHT. 11:05 PM. I AM PUNCTUAL. Do try to be in something sturdy."
narr: Around it: Grub's menu for the week, all little drawings of pots and fish. Nibs's Fact of the Day, in round handwriting.
narr: "A capybara can hold its breath for five minutes. Professor Nibs can hold his for three. Do not test this."
narr: And this morning's Daily Puddle, hand-lettered in neat capitals. The headline: "QUAKE MAKES DUST OF US ALL."
think: I'm not going to cry at a notice board. I'm not.
@end
""",

	"inv3_hall_clock": """
@ifnot seen_inv3_hall_clock -> first
think: The hall clock, right to the second. Snapjaw winds every clock in the house himself.
@end
@label first
narr: The big clock over the stairs, ticking along as if nothing had happened. It agrees with my room clock to the second.
narr: Snapjaw winds every clock in this house himself, every morning, with a little gold key on his watch chain. He told us on Day 2. Twice.
think: Punctual. The one promise he's ever kept.
@end
""",

	"inv3_hall_portrait": """
@ifnot seen_inv3_hall_portrait -> first
think: The Warden in oils, smiling at everyone.
@end
@label first
narr: The Warden's portrait at the top of the stairs: top hat, half a face of metal, and a smile with far too many teeth in it.
narr: The white dust came down on it too, and settled in the grooves of the paint, so his smile looks whiter than ever.
think: Everybody in this house is watching somebody. He's the only one watching all of us.
@end
""",

	"inv3_hall_page": """
@ifnot seen_inv3_hall_page -> first
think: The page behind the portrait frame: Augustus Pica, newspaper editor. On information from: Z. Byte.
@clue ledger_hall
@end
@label first
@if read_page_grand_hall -> known
narr: Tucked behind the frame of a portrait by the side door: a page torn out of the Ledger.
narr: "No. 88. Augustus Pica, newspaper editor. Held for: printing a correction."
narr: Underneath, in blacker, squarer type: "On information from: Z. Byte."
think: Pepper's old editor. And Zuzu's name. I tucked it back the way I found it.
@jump done
@label known
narr: The page behind the portrait frame is still there. Augustus Pica. Z. Byte.
@label done
@clue ledger_hall
@end
""",

	"inv3_talk_reginald": """
@ifnot seen_inv3_talk_reginald -> first
reginald[angry]: Patrol, citizen! Every corridor, every floor, until dawn. You saw it begin.
@end
@label first
reginald[angry]: I was on watch. ON WATCH. And a man died over my head. Do you know what that is, to a Puddlesworth?
mochi: You were on patrol all night?
reginald[normal]: From the moment you saw me start it, at the ten o'clock bell, until the gong this morning. Every corridor. Every floor.
mochi: Did anybody see you, after ten?
reginald[angry]: Did anybody see me? I am a night watchman! The entire point of a night watchman is that nobody sees him!
reginald[normal]: Before dinner, at six, I kept watch on the terrace. At seven I waxed. A moustache does not maintain itself.
reginald[sad]: When the lights went, I carried on. In the dark. I saw nobody at all. I heard the crash, and I thought: plaster.
@alibi reginald 6 PM
@alibi reginald 7 PM
@alibi reginald 10 PM
@alibi reginald 11 PM
@alibi reginald 12 AM
@log people reginald Says he patrolled every corridor and every floor from the ten o'clock bell until morning, and saw nobody.
@end
""",

	"inv3_talk_duchess": """
@ifnot seen_inv3_talk_duchess -> first
duchess[sad]: My room, darling, hunting pins. The fitting at half past ten. Then bed. That's my evening, all of it.
@end
@label first
duchess[sad]: Don't look at me like that, darling. I know what everyone's thinking. Plum's line, and his name on it. I said dreadful things.
duchess[angry]: I did not like the man. I'm not going to start pretending I did now that he can't hear me.
mochi: Where were you last night, after dinner?
duchess[normal]: In my room, hunting for my pins, which had run off the way pins do. At six I was cutting out Lulu's gown in there. At seven, dressing.
duchess[normal]: At half past ten, the Music Room, for Lulu's fitting. She stood still for nearly an hour. For Lulu that's a minor miracle.
duchess[sad]: Then the lights went at five past eleven and I very nearly swallowed a pin, and we finished by feel. At half past she went off. I went to bed.
duchess[normal]: And I slept, darling. Like a stone. Without my powder, too. Marigold kept it, and now it's on that wretched boat.
@alibi duchess 6 PM
@alibi duchess 7 PM
@alibi duchess 9 PM
@alibi duchess 10 PM
@alibi duchess 11 PM
@alibi duchess 12 AM
@alibi lulu 10 PM proof
@log people duchess Says she was in her room looking for her pins until Lulu's fitting at half past ten, which ran until half past eleven. Then bed.
@end
""",

	# =====================================================================================
	# KITCHEN AND PANTRY (stage 2) - people: grub
	# =====================================================================================
	"inv3_enter_kitchen": """
@ifnot seen_inv3_enter_kitchen -> first
think: Grub's kitchen and the pantry, with the dumbwaiter hatch at the back.
@end
@label first
narr: The kitchen still smells of last night's stew. The pots are washed and stacked, every one of them, and nobody remembers washing them.
narr: Through the arch, the pantry: shelves of tins, the hatch in the wall for the dumbwaiter, and the little brass bell that rings when the car goes up.
narr: Grub is sitting on an upturned crate in the corner with his bandaged paw in his lap, staring at the sink.
@log places The kitchen and the pantry, the morning after. Every pot washed and stacked.
@end
""",

	"inv3_kit_soup": """
@ifnot seen_inv3_kit_soup -> first
think: The big pot, scrubbed and upside down. Yesterday's soup.
@clue grub_soup
@end
@label first
narr: The big soup pot from yesterday, scrubbed and turned upside down on the range to dry.
think: Yesterday afternoon he couldn't taste from it. The ladle chattered on the rim like teeth in the cold, and I tasted it for him.
@clue grub_soup
@end
""",

	"inv3_kit_knives": """
@ifnot seen_inv3_kit_knives -> first
think: Every knife in its slot. The cleaver too.
@end
@label first
narr: The knife block on the table. Every knife in its slot, oiled, edges out of sight, the way Grub's mum taught him.
narr: The biggest slot holds the cleaver, the one with the notch in its spine. He named it once. He wouldn't tell me what.
think: Thirty years of cooking, and he's never cut himself. He told me that on Day 1, and knocked on the table.
@end
""",

	"inv3_kit_sink": """
@ifnot seen_inv3_kit_sink -> first
think: A full jug of water on the drainer. Nobody's touched it.
@end
@label first
narr: On the drainer by the sink, a full jug of water with a skin of white dust on top. It's been standing since yesterday.
narr: When I picked it up, Grub turned his whole body away from it on his crate, slowly, the way a plant turns from the dark.
think: I put it back. Gently. As if it were the thing that might bite.
@end
""",

	"inv3_kit_shelf": """
@ifnot seen_inv3_kit_shelf -> first
think: The pantry shelves are lined with old Puddles. One from Day 2, still typed, with a nick in every small e.
@clue old_puddle
@end
@label first
narr: The pantry shelves are lined with newspaper to catch the drips. I lifted a flour tin. Underneath: the Daily Puddle, Island Edition. Day 2.
narr: Back when it was still typed. "WELCOME TO THE WARDEN'S REST: A REVIEW. One star, for the view."
narr: Every small e on the page has the same tiny nick out of the top of its curve, as if something took a bite out of each one.
think: On Day 4 Nibs said he only needed one early typed Puddle. Line a drawer or wrap a fish, he said. Or a pantry shelf, it turns out.
@clue old_puddle
@end
""",

	"inv3_kit_hatch": """
@ifnot seen_inv3_kit_hatch -> first
think: The pantry end of the dumbwaiter. The car isn't down here; it's up at the Library.
@end
@label first
narr: The dumbwaiter hatch at the pantry end. The shutter's up. The car isn't here: the shaft goes up into the dark, ropes and all.
narr: Beside the space where the car would be, a gap for the rope. A hand's width. Far too narrow for anybody to climb.
think: One pot of tea, up a hole in the wall, all the way to the Library. Everything from Grub's kitchen goes up this way.
@end
""",

	"inv3_kit_rope": """
@ifnot seen_inv3_kit_rope -> first
think: Pink glitter on the dumbwaiter rope, at paw height.
@clue pantry_glitter
@end
@label first
narr: The rope that hauls the car runs down past the hatch. At about paw height, right where you'd grab it, something catches the light.
narr: Glitter. Bright pink glitter, a few specks of it, caught in the fibres of the rope.
think: There's one capybara on this island who sheds glitter the way a cat sheds fur.
@clue pantry_glitter
@end
""",

	"inv3_kit_bell": """
@ifnot seen_inv3_kit_bell -> first
think: The bell punches a hole in its tape every time the car goes up. Since six last night: one hole.
@clue bell_tape
@end
@label first
narr: Above the hatch, a little brass bell on a spring, and under it a strip of paper tape on a reel, like a shop's till roll.
narr: A label in Snapjaw's capitals: "EVERY TRIP UP RINGS THE BELL AND PUNCHES THE TAPE. NEW TAPE EVERY EVENING AT SIX. I like to know who's hungry."
narr: I unrolled last night's tape. Blank, blank, blank, one neat little hole, then blank all the way to this morning.
think: One trip up. One, all night.
@clue bell_tape
@end
""",

	"inv3_kit_shaft": """
@ifnot seen_inv3_kit_shaft -> first
think: A chewed pen in the muck at the bottom of the dumbwaiter shaft.
@clue shaft_pen
@end
@label first
narr: With Bruno's big lamp I could finally see past the pantry hatch, down to the bottom of the shaft, through the little door at floor level.
narr: Down there: years of muck. Crumbs, grease, a teaspoon, something that was once a sausage.
narr: And lying on top of it all, not even sunk in yet: a pen. I fished it out with the tongs.
narr: Black, caked in muck, and chewed to splinters at one end. It stinks of the shaft.
think: A chewed pen, at the bottom of a hole in the wall, in a house where one of us chewed every pen he ever owned.
@clue shaft_pen
@end
""",

	"inv3_kit_page": """
@ifnot seen_inv3_kit_page -> first
think: The page behind the framed menu: Sesame, nine, student of the dojo. On information from: G. Pemberton.
@clue ledger_kitchen
@end
@label first
@if read_page_kitchen -> known
narr: Tucked behind the framed menu on the wall: a page torn out of the Ledger.
narr: "No. 236. Sesame, nine years old, student of the dojo. Held for: throwing a grown-up in a public park."
narr: Underneath, in blacker, squarer type: "On information from: G. Pemberton."
think: Bruno's little student. And Grub's name. In Grub's own kitchen.
@jump done
@label known
narr: The page behind the menu, still there. Sesame, nine. G. Pemberton.
@label done
@clue ledger_kitchen
@end
""",

	"inv3_talk_grub": """
@ifnot seen_inv3_talk_grub -> first
grub[sad]: I don't know where I was, love. I keep saying it. It doesn't get any truer.
@end
@label first
grub[sad]: Mochi. Did I make his tea? You'd tell me, wouldn't you? I've been sitting here trying to remember if I made his tea.
mochi: Grub, where were you last night, after dinner?
grub[sad]: Clearing the plates. Then I wasn't. Then I was on that stool in the cellar, and you were there, and it was dark.
grub[normal]: Before dinner I was here, cooking. Six, seven. That I remember. I remember the onions. You did the onions.
grub[shock]: After that it's like somebody tore the pages out. Bits. A door. A smell of books. My paws hurting.
narr: He held them up. The bandage on the bitten one had gone grey. Under the claws of both paws: splinters, dark ones, the colour of old varnish.
grub[sad]: And my head itches, Mochi. From the inside. Is that a thing? Can a head do that?
@alibi grub 6 PM
@alibi grub 7 PM
@alibi grub 9 PM
@alibi grub 10 PM
@alibi grub 12 AM
@log people grub Says he remembers cooking before dinner and clearing the plates, then nothing until the cellar. Splinters under his claws.
@end
""",

	# =====================================================================================
	# DINING ROOM AND CLOAKROOM (stage 2)
	# =====================================================================================
	"inv3_enter_dining": """
@ifnot seen_inv3_enter_dining -> first
think: The cloakroom hooks, the roster by the door, and the table nobody sat down at this morning.
@end
@label first
narr: The cloakroom outside the Dining Room, and the Dining Room beyond it. The table's laid for a breakfast nobody came to.
narr: Somebody's put the chairs back exactly where they stood at dinner. His is pushed in, tidy, the way he always left it.
@log places The Dining Room and the cloakroom, laid for a breakfast nobody ate.
@end
""",

	"inv3_din_hooks": """
@ifnot seen_inv3_din_hooks -> first
think: The cloakroom hooks, and a tin of moustache wax left on the shelf above them.
@clue moustache_wax
@end
@label first
narr: A row of brass hooks, a name card over each in Snapjaw's capitals. Two for Bruno now. One just for the Duchess's hat.
narr: Nibs's hook is empty. He took his coat when he left, the way he always did.
narr: On the shelf above the hooks, pushed to the back: a little round tin, lid off. Moustache wax, a claw-scoop dug out of it. It smells of bergamot.
think: Somebody comes back for this at half past eight every night. Everybody at that table could tell you who.
@clue moustache_wax
@end
""",

	"inv3_din_roster": """
@ifnot seen_inv3_din_roster -> first
think: The watch roster: R. PUDDLESWORTH every night, and Prof. N. on every dinner line. Last night: Prof. N., 8:05.
@clue watch_roster
@end
@label first
narr: Reginald's watch roster hangs on its nail by the Dining Room door, the pencil on a string beside it.
narr: Down the watch column, five nights running: R. PUDDLESWORTH. R. PUDDLESWORTH. R. PUDDLESWORTH.
narr: And on every dinner line, in round, cheerful handwriting, the only other signature: Prof. N. Last night's says "Prof. N. 8:05".
think: The only one who ever signed it. Reginald said he never knew what to do with that.
@clue watch_roster
@end
""",

	"inv3_din_clock": """
@ifnot seen_inv3_din_clock -> first
think: The Dining Room clock over the sideboard. Right to the second.
@end
@label first
narr: The Dining Room clock over the sideboard, ticking. It agrees with the hall clock to the second, like every clock he winds.
narr: Last night Fennel drew it into every little square of his strip. "The only honest face in any room," he said.
@end
""",

	"inv3_din_page": """
@ifnot seen_inv3_din_page -> first
think: The page behind the still life: Hetty Pemberton, cook. On information from: R. Puddlesworth.
@clue ledger_dining
@end
@label first
@if read_page_dining_room -> known
narr: Tucked behind the still life on the Dining Room wall: a page torn out of the Ledger.
narr: "No. 151. Mrs. Hetty Pemberton, cook. Held for: seasoning without a licence."
narr: Underneath, in blacker, squarer type: "On information from: R. Puddlesworth."
think: Grub's mum. And Reginald's name. I tucked it back behind the frame.
@jump done
@label known
narr: The page behind the still life, still there. Hetty Pemberton. R. Puddlesworth.
@label done
@clue ledger_dining
@end
""",

	# =====================================================================================
	# WINE CELLAR (stage 2)
	# =====================================================================================
	"inv3_enter_cellar": """
@ifnot seen_inv3_enter_cellar -> first
think: The Wine Cellar. The stool where I found Grub last night.
@end
@label first
narr: The cellar's one bulb is still broken. Somebody's hung a storm lantern from the hook instead, and it swings a little, all by itself.
narr: The little stool between the racks, where Grub sat in the dark. The bait tins on the bottom rack, grinning their cartoon grins.
@log places The Wine Cellar, lit by a lantern. The stool where Grub sat last night.
@end
""",

	"inv3_cel_bait": """
@ifnot seen_inv3_cel_bait -> first
think: A tin of Snapjaw's rat-bait paste. Aniseed. Acts in one to two hours.
@clue bait_tin
@end
@label first
narr: On the bottom rack, a squat tin with a cartoon rat on the lid, little crosses for eyes. One of his three. The others are in the Conservatory and the Attic.
narr: "SNAPJAW'S SURE-SHOT PASTE. Smells of aniseed! Rats can't resist! Acts in one to two hours. Not for capybaras (mostly)."
narr: I prised the lid up. Grey paste, a scoop or two gone from the top. The smell came up at me like a liquorice sweet gone bad.
think: Mostly. I hate that he wrote mostly.
@clue bait_tin
@end
""",

	"inv3_cel_stool": """
@ifnot seen_inv3_cel_stool -> first
think: The stool where Grub sat in the dark. His footprints go round it in a little circle.
@end
@label first
narr: The little three-legged stool between the racks. White dust lies all round it, and through the dust, footprints: his.
narr: They don't come from anywhere and they don't go anywhere. They go round the stool in a small tight circle, over and over.
think: He said he didn't remember coming down here. I believe him. I don't think he knew he was here at all.
@end
""",

	"inv3_cel_bats": """
@ifnot seen_inv3_cel_bats -> first
think: The bats. Still up there. Still improved.
@end
@label first
narr: Up in the dark between the beams, the bats. A whole row of them, upside down, wrapped in their wings like little umbrellas.
narr: One opened an eye at me. It was red, like a camera light. It closed it again.
think: Bigger wings, sharper teeth, worse manners. He was so proud of them.
@end
""",

	# =====================================================================================
	# GENERATOR ROOM (stage 2) - people: bruno
	# =====================================================================================
	"inv3_enter_generator": """
@ifnot seen_inv3_enter_generator -> first
think: The Generator Room. Hot, loud, and smelling of oil.
@end
@label first
narr: The Generator Room, under the house. Hot, loud and oily, the big machine thumping away like a heart that's run a long way.
narr: Bruno is sitting on a crate beside it with a rag in his paws, not wiping anything.
@log places The Generator Room, with the generator running.
@end
""",

	"inv3_gen_log": """
@ifnot seen_inv3_gen_log -> first
think: The generator log: B., 9:30, on. Ticks every quarter of an hour. Stopped 11:05, witnessed, R. Puddlesworth.
@clue generator_log
@end
@label first
narr: The generator's log book hangs on a nail by the door with a stub of pencil tied to it.
narr: Last night, in big square capitals: "B. 9:30. ON." Then a tick every quarter of an hour, all the way down the page.
narr: The last line: "STOPPED 11:05." And under it, in careful copperplate: "Witnessed, R. Puddlesworth."
narr: There are no other names on the page.
@clue generator_log
@end
""",

	"inv3_gen_generator": """
@ifnot seen_inv3_gen_generator -> first
think: The generator, thumping away. It trips at 11:05, Snapjaw said. It did.
@end
@label first
narr: The generator thumps and rattles. A brass plate on its side: "WARDEN'S REST ELECTRIC. Trips in any tremor. Restart by hand."
narr: Pinned under the plate, a card in Snapjaw's capitals from yesterday: "IT WILL TRIP AT 11:05. SO WILL YOU, IF YOU'RE ON THE STAIRS."
think: He tells us exactly what's going to happen, every time. It never helps.
@end
""",

	"inv3_talk_bruno": """
@ifnot seen_inv3_talk_bruno -> first
bruno[sad]: Generator Room, all night. Grub came down with Bruno at half past nine. Sir Reginald came when the lights went.
@end
@label first
bruno[sad]: Mochi. Bruno lifted it. Bruno lifted the shelf and Zuzu looked, and he was cold.
bruno[sad]: Bruno has lifted a lot of things. That is the heaviest.
mochi: Where were you last night, Bruno?
bruno[normal]: Here, after dinner. With the generator. It coughs, so Bruno sits with it. Half past nine, Bruno started it and wrote B in the book.
bruno[normal]: Grub came down with Bruno. At half past nine. He sat there, on the crate. He was... quiet.
mochi: All night?
bruno[sad]: ...For a while. Then Bruno was looking at the generator. You know how it is.
bruno[normal]: At five past eleven, the shaking. Dark. It stopped. Sir Reginald came down the stairs with his lantern and held it while Bruno fixed it.
bruno[normal]: Twenty past, lights. Bruno stayed until it ran smooth, then bed. Before dinner: six, the cliff path with the crates. Seven, here, oiling.
@alibi bruno 6 PM
@alibi bruno 7 PM
@alibi bruno 9 PM
@alibi bruno 10 PM
@alibi bruno 11 PM
@alibi bruno 12 AM
@log people bruno Says he kept the generator going all night, that Grub came down with him at half past nine, and that Reginald held a lantern in the blackout.
@end
""",

	# =====================================================================================
	# MUSIC ROOM (stage 2) - people: lulu
	# =====================================================================================
	"inv3_enter_music": """
@ifnot seen_inv3_enter_music -> first
think: The Music Room. The gown on its dress form, still full of pins.
@end
@label first
narr: The Music Room. The piano lid is down, and the gown stands on its dress form by the window like a guest who's arrived too early.
narr: Lulu is sitting on the piano stool with her knees pulled up, very small for somebody who's usually so loud.
@log places The Music Room, the gown still on its dress form.
@end
""",

	"inv3_mus_ticket": """
@ifnot seen_inv3_mus_ticket -> first
think: The fitting ticket, 10:30, one hour. Half the hem pinned neatly, the rest crooked and close together.
@clue fitting_ticket
@end
@label first
narr: On the fitting table, a pincushion shaped like a tomato, the long scissors' empty case, and a cardboard ticket pinned to the gown.
narr: In the Duchess's looping hand: "Fitting. L. Starling. 10:30 PM, one hour. STAND STILL."
narr: Along the hem, the pins march in a neat, even line, halfway round. Then the rest are stuck in crooked and close together, any old how.
@clue fitting_ticket
@end
""",

	"inv3_mus_dress": """
@ifnot seen_inv3_mus_dress -> first
think: Lulu's gown for Saturday's concert. Pink and lilac.
@end
@label first
narr: The gown for Lulu's concert on Saturday. Pink and lilac, with a collar like a sea shell and about four hundred pins in it.
think: She said nobody's allowed to be sad at a concert. I don't know if there's going to be a concert.
@end
""",

	"inv3_mus_box": """
@ifnot seen_inv3_mus_box -> first
think: The music box with a child's drawing folded under the dancer.
@clue music_box
@end
@label first
narr: A music box on the shelf, painted with roses. I wound it. It played three notes and stopped, and the little dancer wobbled.
narr: Under the dancer, folded very small, there's a piece of paper. I unfolded it.
narr: A child's drawing in wax crayon: a capybara in an enormous hat. Signed in big wobbly letters: "Plum, age 6".
@clue music_box
@end
""",

	"inv3_mus_piano": """
@ifnot seen_inv3_mus_piano -> first
think: The piano. Pink glitter in the gaps between the keys.
@end
@label first
narr: The piano, lid down. I lifted it. Pink glitter has worked its way into the gaps between the keys, where it'll live forever now.
narr: Somebody's left a sheet of music on the stand, handwritten, with hearts over every i. The title: "Song For When Everyone's Sad".
@end
""",

	"inv3_mus_page": """
@ifnot seen_inv3_mus_page -> first
think: The page behind the still life: Saffron Dauber, painter of miniatures. On information from: L. Starling.
@clue ledger_music
@end
@label first
@if read_page_music_room -> known
narr: Tucked behind the still life by the door: a page torn out of the Ledger.
narr: "No. 174. Saffron Dauber, painter of miniatures. Held for: an unflattering likeness of a public figure."
narr: Underneath, in blacker, squarer type: "On information from: L. Starling."
think: Fennel's sister. And Lulu's name. In the room where Lulu practises every single day.
@jump done
@label known
narr: The page behind the still life, still there. Saffron Dauber. L. Starling.
@label done
@clue ledger_music
@end
""",

	"inv3_talk_lulu": """
@ifnot seen_inv3_talk_lulu -> first
lulu[sad]: Here, practising, and then the fitting with the Duchess. Lulu stood so still. Lulu stood SO still.
@end
@label first
lulu[sad]: Lulu said goodnight to him. At dinner. He said don't wait up. So Lulu didn't wait up.
mochi: Lulu, I have to ask. Where were you last night, after dinner?
lulu[normal]: Here! In the Music Room. Practising standing still. It's harder than singing. Six and seven too, before dinner. Scales.
lulu[happy]: And at half past ten the Duchess came and it was the fitting! A real one! Lulu didn't move for nearly an hour.
lulu[sad]: Then the lights went, and it was pins in the dark, and the Duchess said words Lulu isn't allowed to say.
lulu[shock]: Lulu was here the whole time. The WHOLE time. Everybody can ask the piano.
narr: She tugged at her sleeve. A little cloud of pink glitter came off it and settled on the piano keys.
@alibi lulu 6 PM
@alibi lulu 7 PM
@alibi lulu 9 PM
@alibi lulu 10 PM
@alibi lulu 11 PM proof
@alibi duchess 10 PM proof
@alibi duchess 11 PM proof
@log people lulu Says she practised in the Music Room until the Duchess came for the fitting at half past ten, which ran until half past eleven.
@end
""",

	# =====================================================================================
	# CONSERVATORY (stage 2) - people: bramble
	# =====================================================================================
	"inv3_enter_conservatory": """
@ifnot seen_inv3_enter_conservatory -> first
think: The Conservatory. Glass, palms, the fountain, and the moonflowers, shut tight again.
@end
@label first
narr: The Conservatory is warm and green, and the glass roof is spidered with new cracks. The moonflowers by the fountain have shut themselves up for the day.
narr: Bramble is kneeling by a tray of seedlings, putting them back into their pots one by one. The quake threw them all out.
@log places The Conservatory, warm and green, new cracks in the glass roof.
@end
""",

	"inv3_con_bait": """
@ifnot seen_inv3_con_bait -> first
think: The Conservatory's rat-bait tin. The lid's been off.
@clue bait_tin
@end
@label first
narr: Under the potting bench, the Conservatory's rat-bait tin, the same grinning rat on the lid.
narr: The lid's been prised off and pushed back on crooked. Inside, the grey paste has been scooped at, more than once, by something that wasn't a rat.
narr: "Acts in one to two hours," the label says. "Smells of aniseed." It does.
@clue bait_tin
@end
""",

	"inv3_con_bench": """
@ifnot seen_inv3_con_bench -> first
think: A gardening glove, half burned, in the little stove under the bench. It smells of aniseed.
@clue burned_glove
@end
@label first
narr: The potting bench: trowels, string, a tray of cuttings, and underneath it a little iron stove for cold nights.
narr: In the stove, on top of yesterday's ash: a gardening glove, half burned. Somebody shut the door on it and it went out.
narr: The fingers that didn't burn are stiff with something greyish. They smell of aniseed.
@clue burned_glove
@end
""",

	"inv3_con_easel": """
@ifnot seen_inv3_con_easel -> first
think: Fennel's moonflower drawing, with Bramble asleep beside it. Night 5, 10:40.
@clue conservatory_sketch
@end
@label first
narr: On the easel by the fountain, a big sheet of charcoal drawing.
narr: Moonflowers, half open, pale as plates. And in the wicker chair beside them, curled up with her mouth open, Bramble, fast asleep.
narr: In the corner, in tiny letters: "Night 5. 10:40. She snores."
@clue conservatory_sketch
@end
""",

	"inv3_con_fountain": """
@ifnot seen_inv3_con_fountain -> first
think: The fountain. A little stone fish spitting water into a bowl.
@end
@label first
narr: A stone fish spits a thin stream of water into a round stone bowl. The moonflowers grow all round it, shut tight for the day.
think: A fountain. The most ordinary thing in the house.
@end
""",

	"inv3_talk_bramble": """
@ifnot seen_inv3_talk_bramble -> first
bramble[sad]: ...the Conservatory... with Fennel... the moonflowers... then my room, in the dark...
@end
@label first
bramble[sad]: ...I keep thinking he'd have found out... about my page... he said he would... he promised...
mochi: Bramble, where were you last night, after dinner?
bramble[normal]: ...here... with Fennel... from twenty past nine... moonflowers open at night, you see... very slowly... we watched...
bramble[sad]: ...I fell asleep in the chair, I think... Fennel woke me at a quarter to eleven when his leg hurt... and I went up to my room...
bramble[sad]: ...and then the lights went... and I sat on my bed in the dark and didn't move... I'm good at not moving...
bramble[normal]: ...before dinner too... six, here with Fennel, potting... seven, my room, changing...
@alibi bramble 6 PM
@alibi bramble 7 PM
@alibi bramble 9 PM
@alibi bramble 10 PM
@alibi bramble 11 PM
@alibi bramble 12 AM
@alibi fennel 6 PM proof
@alibi fennel 9 PM proof
@alibi fennel 10 PM proof
@log people bramble Says she watched the moonflowers in the Conservatory with Fennel from twenty past nine until a quarter to eleven, then sat in her room.
@end
""",

	# =====================================================================================
	# THE MUDLARK WRECK (stage 2)
	# =====================================================================================
	"inv3_enter_wreck": """
@ifnot seen_inv3_enter_wreck -> first
think: The Mudlark, on her side on the shore. Marigold's infirmary, sideways.
@end
@label first
narr: Down the cliff path to the shore. The Duchess and Reginald were coming up it as I went down, and neither one would stand aside.
duchess[angry]: Patrol, he says. All night, he says. Then where were you at eleven, Sir Lantern?
reginald[angry]: Where was I? Where were YOU, madam, with a grudge the size of your hat?
narr: They squeezed past each other on the path like two cats in a drainpipe, and I squeezed past both.
narr: The wreck lies on her side at the tide line. Inside, the infirmary is tilted at a sick angle. Everything that could slide has slid.
think: Marigold kept this room so tidy. She'd be furious. Then she'd make everybody tea.
@log places The Mudlark's infirmary, on its side on the shore.
@end
""",

	"inv3_wre_manuals": """
@ifnot seen_inv3_wre_manuals -> first
think: Marigold's nursing manual: a bone broken after death neither swells nor bruises. And the turned-down page on bat bites.
@clue manual_injuries
@clue manual_illness
@end
@label first
narr: A shelf of Marigold's books, held in by a little brass rail. The fattest is her nursing manual, soft as cloth from use.
narr: Broken bones, a chapter with her pencil ticks all down the margin: "In the living, a broken limb swells and bruises within the hour."
narr: "A bone broken after death will neither swell nor bruise."
@clue manual_injuries
narr: Further on, a page with its corner turned down and a cup ring on it. Bites from bats.
narr: "Rare, slow and serious. Days or weeks later: fever, itching at the bite, restlessness, lost hours, trembling paws, drooling..."
narr: "...and a horror of water, so that the patient cannot bear to drink."
think: Somebody turned this corner down. Not Marigold. She never folded a page in her life. She kept a ribbon for that.
@clue manual_illness
@end
""",

	"inv3_wre_cabinet": """
@ifnot seen_inv3_wre_cabinet -> first
think: Marigold's dose card for the Duchess's sleeping powder. One pinch, two pinches, never more than three.
@clue powder_record
@end
@label first
narr: The medicine cabinet hangs crooked on the bulkhead, but its door still shuts. Bottles, bandages, the green box Bruno used on Day 1.
narr: Taped inside the door, in Marigold's round handwriting, a card:
narr: "Sleeping powder (Duchess V., her own tin). 1 pinch: a good night. 2 pinches: sleeps through anything, 8 to 10 hours."
narr: "Never more than 3. A whole tin would stop a heart."
think: Marigold wrote everything down. Even the dangerous things. Especially those.
@clue powder_record
@end
""",

	"inv3_wre_locker": """
@ifnot seen_inv3_wre_locker -> first
think: Marigold's locker: the Duchess's silver powder tin, nearly full, two little dents in the top, a fleck of pink glitter on the lid.
@clue lulu_tin
@end
@label first
narr: Marigold's locker, the one Grub packed her things into yesterday. Her nurse's cap with the green cross. Her scissors. Her book, with a flower pressed in it.
narr: And a little silver tin with a V on the lid. The Duchess's powder. Grub said he'd put it in here.
narr: I opened it. Nearly full. The top of the powder is smooth, levelled off. In it, side by side, two small dents, the size of a fingertip.
narr: On the lid, caught in the curl of the V: one fleck of pink glitter.
@clue lulu_tin
@end
""",

	"inv3_wre_cot": """
@ifnot seen_inv3_wre_cot -> first
think: Marigold's cot, slid into the corner.
@end
@label first
narr: Marigold's cot has slid all the way into the corner. Her blanket is still folded at the foot of it, square as a letter.
think: Two cases ago she was the one who looked after all of us. Now there's nobody whose job that is. So it's everybody's.
@end
""",

	# =====================================================================================
	# TERRACE (stage 2)
	# =====================================================================================
	"inv3_enter_terrace": """
@ifnot seen_inv3_enter_terrace -> first
think: The terrace, and the Gaol across the water.
@end
@label first
narr: The terrace in the morning light. The wind off the sea has blown most of the white dust away. Across the water, the Gaol sits on its rock like a stone toad.
@log places The terrace, the morning after. Most of the dust blown away.
@end
""",

	"inv3_ter_planter": """
@ifnot seen_inv3_ter_planter -> first
think: Boot prints in the planter by the telescope, a ring of lantern soot on the parapet, the telescope aimed at the Gaol's west wing.
@clue terrace_mud
@end
@label first
narr: In the planter beside the telescope, the earth is damp from the sea air, and somebody has stood in it. Deep boot prints, side by side, pointing at the parapet.
narr: On the stone of the parapet, a black ring of lantern soot, where a lantern stood for a long time.
narr: And the telescope's been swung round and aimed at the Gaol. Not at the lighthouse. At the west wing.
@clue terrace_mud
@end
""",

	"inv3_ter_telescope": """
@ifnot seen_inv3_ter_telescope -> first
think: The telescope, pointed at the Gaol's west wing.
@end
@label first
narr: I put my eye to the telescope. Rows of little barred windows, one of them with a geranium in a pot on the sill.
think: Somebody's been looking for a long time at one particular window. I put it back exactly how it was.
@end
""",

	"inv3_ter_page": """
@ifnot seen_inv3_ter_page -> first
think: The page under the planter: Hawthorn Thistlewood, nurseryman. On information from: F. Dauber.
@clue ledger_terrace
@end
@label first
@if read_page_terrace -> known
narr: Folded and slipped half under one of the planters: a page torn out of the Ledger.
narr: "No. 207. Hawthorn Thistlewood, nurseryman. Held for: growing a rose of an unregistered colour."
narr: Underneath, in blacker, squarer type: "On information from: F. Dauber."
think: Bramble's dad. And Fennel's name under it. I slid it back under the planter.
@jump done
@label known
narr: The page under the planter, still there. Hawthorn Thistlewood. F. Dauber.
@label done
@clue ledger_terrace
@end
""",

	# =====================================================================================
	# BEDROOM WING (stage 2)
	# =====================================================================================
	"inv3_enter_wing": """
@ifnot seen_inv3_enter_wing -> first
think: The Bedroom Wing. Eleven doors, every one with a chair under the handle last night.
@end
@label first
narr: The long corridor of the Bedroom Wing, eleven doors in a row, each named after a bird. Somebody's chalked a line through one of them.
narr: The runner down the middle has rucked up in the shaking, in long folds like a sheet on an unmade bed.
@log places The Bedroom Wing, the runner rucked up by the shaking.
@end
""",

	"inv3_wing_page": """
@ifnot seen_inv3_wing_page -> first
think: The page under the runner. No. 9. Granny Mochi. The name of the informer torn off.
@clue ledger_wing
@end
@label first
narr: Where the runner's rucked up there's a page pushed under it, flat. A page torn out of the Ledger.
narr: "No. 9. Granny Mochi, keeper of a bathhouse. Held for: running hot water without a licence."
narr: The bottom of the page, where the informer's name would be, has been torn clean off.
think: Grandma. In her good cardigan, with her buttons done up wrong. Somebody gave her to him. And somebody didn't want me to know who.
@clue ledger_wing
@end
""",

	# =====================================================================================
	# GALLERY (stage 3) - people: fennel
	# =====================================================================================
	"inv3_enter_gallery": """
@ifnot seen_inv3_enter_gallery -> first
think: The Gallery. The clock on the hearth, the grate, the darkroom cupboard.
@end
@label first
narr: The Gallery: a long room of old wardens in gilt frames, windows over the bay down one side, a fireplace at the far end.
narr: White dust lies along the floor in drifts. The little mantel clock isn't on the mantel any more.
narr: Fennel is sitting on a bench in the middle with his sketchbook open and his crutch across his knees, not drawing.
@log places The Gallery, white dust along the floor.
@end
""",

	"inv3_gal_clock": """
@ifnot seen_inv3_gal_clock -> first
think: The Gallery clock, thrown onto the hearth. Stopped at 11:05. Wound and set by the Warden, daily, to the second.
@clue gallery_clock
@end
@label first
narr: The little mantel clock lies on the hearth, where the aftershock threw it off the mantel. The glass is cracked across.
narr: The hands stopped at five past eleven. To the minute he posted on the board.
narr: On its back, a brass plate: "Wound and set by the Warden, daily, to the second."
think: Even the clocks are frightened of him.
@clue gallery_clock
@end
""",

	"inv3_gal_darkroom": """
@ifnot seen_inv3_gal_darkroom -> first
think: Pepper's own roll, pegged up in the darkroom: the Gallery at 8:52 and 9:00, then flash frames in the dark from 11:06 to 11:18.
@clue photo_roll
@end
@label first
narr: The darkroom cupboard beside the fireplace is open a crack, the red safelight still glowing inside. It smells of vinegar and wet paper.
narr: On a line across the back, pegged up to dry: six prints off one roll. Her camera prints the time in the corner of every frame, in little orange numbers.
narr: Two of the Gallery, stamped 8:52 and 9:00. Then four flash frames of the Gallery in the dark, dust in the air like snow: 11:06, 11:09, 11:13, 11:18.
think: "Changing my film," she said at dinner. And here's the film she changed it for.
think: I can look at them properly in my notebook. Snapjaw took the rest; these ones are still hers.
@clue photo_roll
@alibi pepper 8 PM proof
@alibi pepper 11 PM proof
@end
""",

	"inv3_gal_grate": """
@ifnot seen_inv3_gal_grate -> first
think: The Gallery grate: far more ash than on Night 3, and one typed corner, "...over the lazy cai".
@clue gallery_grate
@end
@label first
narr: The Gallery grate. On Night 3 there was one page's worth of ash in it. Now there's a thick grey cake, many sheets' worth, pressed flat.
narr: The fire was never lit. The coal's still clean in the scuttle.
narr: One corner didn't burn. A scrap of a typed line, small and neat: "...over the lazy cai".
think: The quick brown capybara jumps over the lazy caiman. Every one of us typed that, on Day 3.
@clue gallery_grate
@end
""",

	"inv3_gal_seat": """
@ifnot seen_inv3_gal_seat -> first
think: A little seascape drying on the window seat, painted on the back of a typed sheet.
@clue painted_page
@end
@label first
narr: Propped on the window seat to dry: a little seascape in oils, the size of a postcard. Grey sea, a white sail, the Gaol very small on the horizon.
narr: It's painted on the back of a sheet of paper. I held it up to the window, and typing showed through from the other side, backwards.
narr: "No. 313..." And further down, in blacker, squarer letters: "On information from: B. Thist..." The rest is under the paint.
think: Another page. Somebody painted a whole sea over it rather than let it be read.
@clue painted_page
@end
""",

	"inv3_gal_portraits": """
@ifnot seen_inv3_gal_portraits -> first
think: The old wardens, all facing the right way again.
@end
@label first
narr: The portraits along the north wall: wardens and officers, whiskers and medals, all facing the room again since Snapjaw turned them back round on Night 4.
narr: The fourth one hangs a little crooked. The house plan used to be pinned to its back. It isn't any more.
@end
""",

	"inv3_talk_fennel": """
@ifnot seen_inv3_talk_fennel -> first
fennel[sad]: The Conservatory with Bramble until a quarter to eleven, then my room. And the strip's yours, if you want to look again.
@clue dinner_sketch
@end
@label first
fennel[sad]: Mochi. I came up here to draw something that wasn't him. It turns out everything is him. Every surface.
mochi: Fennel, where were you last night, after dinner?
fennel[normal]: The Conservatory, with Bramble, from twenty past nine. Moonflowers. Nobody's ever drawn one opening. I have now. She fell asleep, mind.
fennel[normal]: At a quarter to eleven my leg filed its complaint, so I woke her and hobbled to my room.
fennel[normal]: The lights went at five past. I sat in the dark and swore at my knee.
fennel[normal]: Before dinner, six and seven, the Conservatory too, drawing her at her seedlings. She's a terrible model. She keeps apologising.
mochi: And at dinner you were sketching the whole time.
fennel[sad]: The strip. Yes. Snapjaw doesn't print drawings, he says. Here. Better you have it than nobody.
narr: He tore it out of his sketchbook and gave it to me: a row of little charcoal squares, the Dining Room clock in every one.
narr: The first, 8:05: Nibs at the roster by the door, pen in his teeth. Then an empty chair at 8:30, 8:40, 8:50, 9:05. And Grub's, four times.
narr: The last, 9:15: Nibs at the door in his coat, pen in his mouth, waving goodnight.
fennel[sad]: The last one I'll ever do of him. You never know it's the last one.
@clue dinner_sketch
@alibi fennel 6 PM
@alibi fennel 7 PM
@alibi fennel 9 PM
@alibi fennel 10 PM
@alibi fennel 11 PM
@alibi fennel 12 AM
@alibi bramble 6 PM proof
@alibi bramble 9 PM proof
@alibi bramble 10 PM proof
@log people fennel Says he drew moonflowers in the Conservatory with Bramble from twenty past nine until a quarter to eleven, then went to his room.
@end
""",

	# =====================================================================================
	# ATTIC (stage 3)
	# =====================================================================================
	"inv3_enter_attic": """
@ifnot seen_inv3_enter_attic -> first
think: The Attic. Rafters, trunks, and Zuzu's corner of wires.
@end
@label first
narr: Up under the roof again. Long rafters, trunks, a rocking horse with one glass eye, and at the far end Zuzu's corner: a desk, a screen, and wires everywhere.
@log places The Attic, Zuzu's corner of wires at the far end.
@end
""",

	"inv3_att_desk": """
@ifnot seen_inv3_att_desk -> first
think: Zuzu's screen: a log that starts at 9:48 PM and runs all night, until 6:51 this morning.
@clue packet_log
@end
@label first
narr: Zuzu's desk: a screen spliced into a fat bundle of the house's camera wires, and a keyboard with half the letters worn off.
narr: Whatever they wiped this morning, the screen still keeps its own log, scrolling up the side in tiny green letters.
narr: It starts at 9:48 PM. A line every few seconds, typed commands, all night long. A gap from 11:05 to 11:20. Then on again, until 6:51 this morning.
@clue packet_log
@end
""",

	"inv3_att_camera": """
@ifnot seen_inv3_att_camera -> first
think: A Snapjaw camera in the rafters, its wires cut and its lens taped over.
@clue dead_camera
@end
@label first
narr: High up in the rafters, one of Snapjaw's little crocodile cameras. Its red eye is dark.
narr: Its wires have been cut, neatly, and twisted back on themselves. A strip of black tape is wound round and round its lens.
@clue dead_camera
@end
""",

	"inv3_att_bait": """
@ifnot seen_inv3_att_bait -> first
think: The Attic's rat-bait tin. Untouched.
@clue bait_tin
@end
@label first
narr: The third rat-bait tin, by the chimney breast. The same grinning rat on the lid, the same label: aniseed, one to two hours, not for capybaras, mostly.
narr: A film of dust on the lid. Nobody's opened this one.
@clue bait_tin
@end
""",

	"inv3_att_trunks": """
@ifnot seen_inv3_att_trunks -> first
think: The Gaol's old record trunks.
@end
@label first
narr: A row of iron-bound trunks stencilled "GAOL RECORDS". I opened one. Ledgers, hundreds of them, all the same black leather as his.
narr: Every page I opened was blank.
@end
""",

	# =====================================================================================
	# THE PLOVER ROOM, his bedroom (stage 3)
	# =====================================================================================
	"inv3_enter_plover": """
@ifnot seen_inv3_enter_plover -> first
think: His room. The Plover Room.
@end
@label first
narr: Snapjaw's key turned in the lock of the Plover Room with a click like a full stop.
narr: His room. Neat. Very neat. The bed made with hospital corners. A window over the bay. It smells of ink and peppermints.
think: I feel like I should knock. I'm knocking on the inside of the door, quietly, anyway.
@log places The Plover Room, his bedroom. Locked until this morning.
@end
""",

	"inv3_plo_case": """
@ifnot seen_inv3_plo_case -> first
think: His case of old pens on the mantel. Every one chewed at the end. RETIRED.
@clue pen_case
@end
@label first
narr: On the mantelpiece, an open wooden case lined with red felt. In it, laid side by side like soldiers: his old pens.
narr: Every single one is chewed at the end. Some just dented. Some down to splinters.
narr: Inside the lid, a little label in his round handwriting: "RETIRED."
think: He kept them. Every one he'd ever chewed to bits. He gave them a home.
@clue pen_case
@end
""",

	"inv3_plo_desk": """
@ifnot seen_inv3_plo_desk -> first
think: His writing desk. Jars of powders, and a letter to Fizz he never sent.
@end
@label first
narr: His writing desk under the window: three jars of coloured powders, labelled in his hand, and a letter, half written.
narr: "Dear Fizz. Don't touch the blue jar. Don't touch any jar. I'm working on it. I'll have you out by" and then nothing.
@end
""",

	"inv3_plo_bed": """
@ifnot seen_inv3_plo_bed -> first
think: His bed, made with hospital corners. Not slept in.
@end
@label first
narr: The bed's made with hospital corners, tight enough to bounce a coin. Nobody slept in it last night.
narr: On the pillow, a paper bag of peppermints, the top folded over twice.
@end
""",

	# =====================================================================================
	# THE SERVANTS' PASSAGE (stage 3)
	# =====================================================================================
	"inv3_enter_passage": """
@ifnot seen_inv3_enter_passage -> first
think: The servants' passage, inside the walls.
@end
@label first
narr: Behind the tapestry, through the narrow door, the house has a second house inside it: a passage of bare boards, one slim servant wide, running off into the dark.
narr: Bruno's lamp makes it bright as a stage. White limewash has come down from the ceiling over everything.
@log places A narrow passage inside the walls, behind the Library tapestry. White limewash over the floor.
@end
""",

	"inv3_pas_door": """
@ifnot seen_inv3_pas_door -> first
think: The narrow door behind the tapestry, 80 cm across. Bruno stuck at the shoulders. No bolt on either side.
@clue passage_door
@end
@label first
narr: The door from the Library side is narrow: I measured it with my arms, about 80 centimetres across. No bolt on it, on either side.
narr: Bruno, who'd carried the lamp up for me, tried to come through after me and stuck fast at the shoulders.
narr: It took Fennel's crutch and a lot of words to get him out again backwards.
narr: Inside, white limewash from the ceiling lies over the floor like a sheet.
@clue passage_door
@end
""",

	"inv3_pas_tracks": """
@ifnot seen_inv3_pas_tracks -> first
think: One set of prints through the white limewash, there and back, each pressed down to the grey. The grey between them, smooth.
@clue passage_tracks
@end
@label first
narr: Under the white limewash there's an older film of dust, grey. I know that grey. It came down on Day 2, in the first aftershock, all over the house.
narr: One set of prints goes along the passage through the white, there and back. Each print presses right through the white to the grey underneath.
narr: Between the prints, I blew the white away very gently. The grey underneath is smooth. Not a mark in it.
@clue passage_tracks
@end
""",

	"inv3_pas_hem": """
@ifnot seen_inv3_pas_hem -> first
think: A wide, smooth line through the white dust beside the prints, and three lilac silk threads on a splinter of skirting.
@clue shawl_hem
@end
@label first
narr: Beside the prints, all the way along, a wide line has been drawn through the white dust, smooth and soft-edged, as if something trailed along the floor.
narr: Where the skirting board is split, three threads are caught on a splinter. Fine silk. Lilac.
@clue shawl_hem
@end
""",

	"inv3_pas_feather": """
@ifnot seen_inv3_pas_feather -> first
think: A long lilac ostrich feather, snapped, caught on the bracket above the passage door.
@clue hat_feather
@end
@label first
narr: Above the door at the Library end, an iron bracket sticks out of the wall. Something brushed against it hard.
narr: Caught on it, high up: a long lilac ostrich feather, snapped in half. The other half lies in the dust below.
@clue hat_feather
@end
""",

	"inv3_pas_bells": """
@ifnot seen_inv3_pas_bells -> first
think: A row of old service bells, one for every room. Nobody's rung them in fifty years.
@end
@label first
narr: A board of old service bells on springs, one for every room in the house, each with a faded label: LIBRARY. GALLERY. BLUE BEDROOM. WARDEN.
narr: They've all got a beard of grey dust. Except WARDEN, which has been polished.
@end
""",

	# =====================================================================================
	# AFTER THE INVESTIGATION: the ride down
	# =====================================================================================
	"investigation_end": """
@bg manor_hall
@music stop
@sfx chime
@show snapjaw happy center
snapjaw[happy]: Ding-dong! Pencils down, my darlings! Everybody to the Grand Hall. Your Splash Trial is waiting, and it hates to be kept waiting!
@hide all
narr: We came down the stairs in ones and twos. White dust on everybody, and nobody bothering to brush it off any more.
narr: Snapjaw stood under the Warden's portrait on the half landing. He rapped on the frame with one claw. Twice.
narr: The portrait swung open like a door. Behind it was a brass cage, and a shaft going straight down into the dark.
@anim c3_ride_down
@bg none
narr: Down through the floor. Down through the cellars. Down through the cliff. The cage creaked, and the rock went past and past.
@show bruno sad left
@show grub sad right
bruno[sad]: Grub. Stand next to Bruno. It is a long way down.
grub[sad]: Is it? I keep forgetting where we're going, love. Then I remember.
@hide all
narr: Lulu and Bramble stood in opposite corners of the cage, as far apart as a cage allows.
@show duchess normal left
@show reginald normal right
duchess[normal]: You're standing on my hem, Sir Lantern.
reginald[normal]: I am standing nowhere near your hem, madam. Your hem is standing on me.
@hide all
@show zuzu sad left
@show fennel sad right
zuzu[sad]: he'd have counted. how deep. how fast. he'd have made it a fact of the day.
fennel[sad]: Ninety-one seconds, mon ami. I counted for him.
@hide all
@show pepper sad center
pepper[sad]: No film. First trial of my life and I've got no film. Feels like walking into a fire without a bucket.
@hide all
think: Ten of us. At the first trial there were fourteen. Now there will be five portraits.
think: Professor, you'd have had it all on one sheet by now, in order, in your round handwriting. I'm going to try.
@bg trial
@music tension
@sfx splash
narr: The cage opened on a round chamber cut out of the rock: fifteen podiums around a glowing pool, and a throne on an island in the middle.
narr: It looked exactly like the last two. Somewhere, Nibs would have said, there's a catalogue.
@log timeline Day 6. Snapjaw took everyone down to the Splash Trial in a lift hidden behind the Warden's portrait.
@end
""",

	# =====================================================================================
	# THE TRIAL. Segments (plan S3 "Trial outline"): 1 opening, 2 debate, 3 free choice, 4 roll call, 5-8 debates,
	# 9 first overturn, 10 tea, 11 Grub (debate + bubbles), 12 Lulu, 13 debate, 14-15 the passage, 16 rebuttal,
	# 17 the vote offer (the false finish), 18 the jammed Rewind + second overturn, 19 the Duchess, recess (Main plays
	# the "recess" step, then comes back at @label after_recess), 20-24, 25 time pick + names, 26 frames + names, 27,
	# 28-29 debates, 30 third overturn, 31-33, 34 Rewind, 35 vote. The confession is its own script ("confession").
	# Trial record (@log trial) entries are what the group accepted; @log strike crosses one out only when disproved.
	# =====================================================================================
	"trial": """
@bg trial
@music trial
@card THE SPLASH TRIAL | Case 3: Murder at Warden's Rest
@sfx splash
@shake 8
narr: The pool heaved, and Warden Snapjaw came up out of it in a fountain of spray and landed on his throne with his arms wide.
snapjaw[happy]: Welcome, welcome, WELCOME, my darlings, to the third SPLASH TRIAL! Same pool, new island! I had it built to match. Snap-snap-snap!
snapjaw[happy]: Fifteen podiums! Ten guests! And five portraits: Coco, Wisp, Marigold, Tumble, and our dear Professor.
think: His portrait has a pen in it. Somebody drew it in, very small, in the corner of his mouth. Fennel, I think.
snapjaw[normal]: The rules, briefly, since you know them. Debate. Vote. Majority rules. Pick the culprit, and only the culprit is punished.
snapjaw[angry]: Pick WRONG, and everybody ELSE is punished, and the culprit checks out, free as a seagull!
snapjaw[happy]: And Mochi! The island air is very particular. Under SEVENTY percent on your Convince Meter, and nobody listens to a word you say.
snapjaw[happy]: Hints cost extra. I'm a businessman. Snap-snap-snap!
narr: Nobody laughed. For a moment nobody said anything at all. We'd done this twice, and somebody had always started.
think: It was always him. "Hypothetically," he'd say, and then the facts, one after another, in order, like ducklings.
reginald[normal]: Well. Somebody must read the file, I suppose. In the... in the usual manner.
lulu[sad]: He always read it. He did a little cough first. Like a real professor.
@choice What should I say?
> I'll read it. For him. -> open_read
> Let's start from what we know. -> open_know
@label open_read
mochi: I'll read it. He'd want somebody to. Ahem. Snapjaw File number three.
@jump open_file
@label open_know
mochi: Let's start from what we know, the way he would have. Snapjaw's file, out loud.
@label open_file
mochi: Victim: Professor Nibs. Found in the Library at seven this morning, at his desk, under the tall bookcase. The door had to be broken in.
mochi: Time of death: between half past nine and midnight. Cause of death...
snapjaw[happy]: Check your rule book! I'm very proud of that one. The rest of the page is a drawing. I'm very proud of that too.
grub[sad]: That's not a cause of death. That's a riddle.
reginald[angry]: Then let us not dance about it. Two lines of that Ledger were read aloud with his name under them. Plum's. And my mother's.
reginald[angry]: One of those two people is me, and I am not a fool. The other is HER.
duchess[angry]: How gallant. Accuse yourself first, so you can accuse me second.
duchess[angry]: You were on "patrol" all night, Sir Lantern. Nobody saw you. Nobody ever sees you. You're asleep by half past ten.
reginald[angry]: RESTING. MY. EYES.
lulu[sad]: And Zuzu shouted at him. Last night. Everybody knows. And Zuzu was the first one in this morning.
zuzu[angry]: yeah. i did. and then i brought him coffee. go on. say the rest.
bruno[normal]: Nobody says anything about Grub. Grub was with Bruno.
grub[sad]: Was I, Bruno? I keep asking. Nobody tells me.
bramble[sad]: ...couldn't it just... have fallen?... the house was shaking...
fennel[normal]: In my experience, mademoiselle, nothing in this house just does anything. Everything here is on purpose. Even the soup.
pepper[normal]: Everybody, hang on. Slow down. Facts first. He'd want facts first. Headlines never.
snapjaw[happy]: Oh, I do love the first five minutes. Everybody pointing at everybody. It's like a firework display of fingers.
reginald[normal]: Very well. Facts. Rule seven: the aftershock was posted on the board, a full day ahead, to the minute. 11:05.
reginald[normal]: At 11:05 the house shook, and a tall, top-heavy old bookcase fell on a man at his desk. A tragedy. Not a crime.
duchess[normal]: For once in his life the man is talking sense, darlings. I'm as shocked as you are.
think: I stood in that Library this morning. I looked at that bookcase for a long time. Something about it.
@minigame c3_debate_fell
mochi: It didn't simply fall, Reginald. A bookcase that tips over swings down from its base. The base stays against the wall.
mochi: This one's base was a good foot out into the room, with two fresh scrapes on the floorboards behind it. It walked before it fell.
bruno[normal]: Bruno saw. When Bruno lifted it. The bottom was out in the room. Bruno thought: strange.
zuzu[normal]: shaking makes things walk. a bit. not a foot. not something that heavy.
@shout mochi IT DIDN'T JUST FALL!
pepper[shock]: So somebody pushed it! In the dark! Somebody shoved it over on him!
duchess[shock]: In the blackout. While the rest of us were fumbling about for candles. Good heavens.
@log trial #c3_not_fallen The bookcase didn't simply fall: its base had been dragged a foot out from the wall.
reginald[normal]: Then let us establish the hour. That much, at least, must be simple.
@minigame c3_q_when
@if c3_said_before -> when_before
@if c3_said_after -> when_after
reginald[normal]: Precisely. The lights go, the house shakes, and in the confusion somebody shoves. It writes itself.
@jump when_done
@label when_before
mochi: Before the lights went out, I think. I don't know why I think it. It's just a feeling.
reginald[normal]: A feeling. Splendid. I shall have it minuted. But the shelf came down at 11:05, citizen, and he was under it.
@jump when_done
@label when_after
mochi: After the lights came back? I don't know. Maybe. Nothing felt right after the lights came back.
reginald[normal]: The lights were on again at twenty past, citizen, and the shelf was already down. No. It was done in the dark.
@label when_done
mochi: But the Library door was bolted. Zuzu heard it go across at twenty to ten. So did I. Clack.
reginald[normal]: Bolted at twenty to ten. By him. Who knows whom he let in afterwards? A bolt can be drawn back for a friend and shot again behind them.
bruno[normal]: And the frame was warped. Bruno said. From the shaking. Bruno had to break it.
think: Nobody looked at the bolt this morning. Bruno put his shoulder to the door, and then there was the bookcase. Nobody looked at anything else.
lulu[normal]: So it was the blackout! Somebody went in the dark! Lulu knew it! Lulu didn't know it. But Lulu thought it.
@log trial #c3_blackout He died at 11:05, when somebody pushed the bookcase over on him in the blackout.
snapjaw[happy]: Ooh, a shove in the dark! How very gothic! Then who was where, in the dark, my darlings? ROLL CALL!
snapjaw[normal]: The gentlemen of the Generator Room can wait their turn. Everybody else. Five past eleven. Go!
@minigame c3_roll_blackout
think: The Duchess and Lulu, together at the fitting. Everybody else alone in the dark: Zuzu, Bramble, Fennel, Grub, Pepper. And me, in the bath.
reginald[normal]: Five alone, and two pinning a frock. That hardly narrows the field, citizen.
lulu[happy]: Lulu and the Duchess were together! Lulu has never been so glad to be stuck full of pins!
reginald[angry]: Nonetheless! One name has been on everybody's lips since breakfast on Day 3. Plum's line, read aloud, and his name under it.
duchess[angry]: And your mother's line, Sir Lantern, read aloud, with HIS name under it. We're a matched pair. Go on.
reginald[angry]: Mine comes after yours, madam. Ladies first.
@minigame c3_debate_duchess
mochi: She wasn't alone, Reginald. There's a ticket pinned to Lulu's gown in the Duchess's own writing. Fitting, half past ten, one hour.
mochi: And the pins tell the rest. Half the hem pinned in a neat line, and the rest stuck in crooked and close together. By feel.
lulu[normal]: That's when the lights went! The Duchess pinned the rest of Lulu in the dark! She said words!
duchess[normal]: I said several words. I stand by all of them.
mochi: From half past ten until half past eleven, the Duchess was in the Music Room with Lulu. Straight through 11:05.
@shout mochi SHE WASN'T ALONE!
reginald[sad]: ...Very well. A Puddlesworth withdraws. Gracelessly, but he withdraws.
duchess[happy]: Gracelessly is how you do everything, darling. It's very nearly endearing.
@log trial #c3_duchess_fitting The Duchess was at Lulu's fitting in the Music Room from half past ten to half past eleven, through the blackout.
duchess[normal]: Now. Since we're doing it in order. Where were YOU at five past eleven, Sir Lantern?
reginald[normal]: On patrol. As I have said. Upstairs, in the dark, alone, as is proper.
reginald[angry]: And if we want a man who was alone in the dark with nobody to see him, we need look no further than the Generator Room.
reginald[angry]: Brawnsworth was a soldier. He told us so himself, on the beach. Three years. A man who learned his trade in an army...
mochi: That isn't evidence, Reginald.
reginald[angry]: I beg your pardon?
mochi: Where somebody learned to splint a leg isn't evidence of anything. If you've got evidence, say it. If not, don't.
narr: Bruno said nothing. He looked at the edge of his podium as if something were written on it.
fennel[normal]: He splinted mine, for the record. Very neatly. It's the only part of me that is neat.
reginald[angry]: Very well! Then the plain facts. I was on patrol upstairs, and he was alone downstairs!
@minigame c3_debate_reginald
mochi: You weren't upstairs, Reginald. The generator log: "B. 9:30. ON." A tick every quarter of an hour. Then: "STOPPED 11:05."
mochi: And under it, in careful copperplate: "Witnessed, R. Puddlesworth."
@shout mochi YOU WERE IN THE GENERATOR ROOM!
narr: Reginald went very red, then very white, then a sort of moustache colour.
reginald[sad]: ...I signed it. Habit. A Puddlesworth witnesses what he sees.
reginald[sad]: When the lights went I came down the back stairs with my lantern, and held it while he coaxed the thing round.
reginald[sad]: At twenty past, the lights came on. I left.
reginald[normal]: And... honour compels me. He was there. In the Generator Room, at 11:05, with his paws in the machine. I held the light.
reginald[normal]: Brawnsworth did not leave that room while I was in it.
bruno[normal]: ...Thank you, Sir Reginald.
reginald[normal]: Don't.
@log trial #c3_reginald_gen At 11:05 Reginald was in the Generator Room with Bruno, holding the lantern.
lulu[sad]: Then... then that only leaves the row. Zuzu, Lulu's sorry. But everybody's thinking it.
zuzu[sad]: so say it.
lulu[sad]: You screamed at him. At twenty to ten. And you were the first one through the door this morning.
@ifnot seen_inv3_att_desk -> zuzu_nolog
@minigame c3_debate_zuzu
mochi: The screen in the Attic keeps its own log. It starts at 9:48 PM. A line every few seconds, typed, all night long.
mochi: Six minutes after the row, Zuzu was up under the roof, typing. And didn't stop until the lights went out.
zuzu[sad]: ...you read my log.
mochi: Only the times. Not what's in them.
zuzu[normal]: ...ok. ok. that's fair.
@jump zuzu_done
@label zuzu_nolog
@minigame c3_q_zuzu_stairs
mochi: Up the back stairs. I was sitting on the bottom step. Zuzu came down from the Library, walked right past me and went up towards the Attic.
mochi: And behind them the bolt went across. Clack. He shot it himself, after they'd gone.
@label zuzu_done
reginald[normal]: But then the blackout! A quarter of an hour of dark, and the Attic is right above the Library.
zuzu[sad]: ...yeah. alone, in the dark. nobody can say otherwise. i know.
think: That's true. Nothing puts Zuzu anywhere at five past eleven. Nothing puts most of us anywhere.
@log trial #c3_zuzu_attic After the row at twenty to ten, Zuzu went up to the Attic, not back into the Library.
zuzu[angry]: but you want somebody with a reason? a real one? not mine. hers.
narr: Zuzu turned on their podium and pointed straight across the pool.
zuzu[angry]: pepper. my mum's line. "on information from: pepper q." the only line in that book nobody says is forged.
pepper[sad]: Zuzu. I've told you. I don't remember that story. I've filed a lot of stories.
zuzu[angry]: and the gallery grate. full of ash. a typed corner, "over the lazy cai". the samples. your darkroom's in the gallery.
pepper[shock]: Everybody burns paper in that grate! It's the only one in the house that draws!
@minigame c3_debate_pepper
mochi: Pepper didn't come over in the dark, Zuzu. Her own roll was pegged up to dry in the darkroom. Four flash frames, all of the Gallery.
mochi: Dust coming down like snow, stamped 11:06, 11:09, 11:13 and 11:18. The whole blackout, on the far side of the house.
pepper[happy]: Thank you, partner. Thank you. I'd hug you, but I'm three podiums away and I'd fall in.
pepper[normal]: I owe you one. I'm good for it. Ask Bruno about the cakes.
bruno[happy]: Paid in full. Three. With a B on.
zuzu[sad]: ...fine. the grate's still somebody's.
think: The samples. Somebody took them off his desk on Night 3, and the Tribunal never found out who. That's still nobody's.
@log trial #c3_pepper_gallery Pepper was in the Gallery taking flash pictures all through the blackout, by her own roll.
duchess[normal]: And since we're tidying, Sir Lantern. Before the lights went. Your famous patrol. Where, exactly?
reginald[sad]: ...The terrace. The telescope. My mother's window is the fourth from the left in the west wing. It has a geranium on the sill.
reginald[sad]: I stand there every night until her light goes out. That is my patrol. Laugh, if you like.
narr: Nobody laughed. The Duchess, of all people, looked down at her hat.
@log people reginald Says that before the blackout he was on the terrace at the telescope, as every night, watching his mother's window in the Gaol.
@checkpoint c3_cp_overturn 20
@label c3_cp_overturn
snapjaw[happy]: Well, well! Everybody's accounted for and nobody did it! The Duchess was being pinned, Sir Lantern was holding a lamp...
snapjaw[happy]: ...Pepper was flashing, and the rest of you were sitting in the dark feeling sorry for yourselves. Shall we just blame the house?
grub[sad]: Maybe it was the house, love. I keep saying.
think: The house. Rule seven. The aftershock, on the dot. We've done nothing but argue about 11:05 since we sat down.
think: But I knelt next to him this morning. His arm, under the shelf. And Marigold's manual, in the wreck.
@minigame c3_q_dead_before
@anim c3_overturn1
mochi: His arm was broken under the bookcase. Bent where an arm doesn't bend. But round the break the fur lay flat, and the skin was pale.
mochi: No swelling. No bruise. And Marigold's manual says it in plain words: a bone broken after death will neither swell nor bruise.
@shout mochi HE WAS ALREADY DEAD!
@sfx gasp
lulu[shock]: Already...?
fennel[shock]: Then the bookcase fell on... on nobody. On what was left of him.
duchess[shock]: Then all of that, darlings. The roll call. The fitting. Sir Lantern's lamp. None of it...
reginald[shock]: None of it matters a jot. Good heavens.
@log strike c3_blackout
@log trial #c3_dead_before He was already dead when the bookcase fell on him: his broken arm never swelled or bruised.
@if c3_said_before -> said_before
@jump overturn_on
@label said_before
think: Before the lights went out. I said so. I didn't know why. Now I do.
@convince +3
@label overturn_on
pepper[shock]: But it walked, Mochi. You said so yourself. A foot. Something moved it.
mochi: Something moved it long before 11:05. High on the wall where it stood: two clean screw holes. And up on the cornice, six screws in a row.
mochi: Under the white dust. Somebody took that brace off the wall and left the bookcase standing on nothing, waiting for the aftershock.
zuzu[normal]: rule seven. "i am punctual." you could set your watch by it. somebody did.
mochi: And his blotter says when. "4:30 out. Tide." And then: "5:40 back. Shelf rocks. Tell Bruno."
bruno[sad]: He never told Bruno. Bruno would have fixed it. Bruno would have...
narr: Bruno stopped. His paws were shaking on the rail of his podium.
mochi: Between half past four and twenty to six, while he was down on the beach, somebody loosened his bookcase by hand.
@shout mochi IT WAS LOOSENED IN THE AFTERNOON!
@log trial #c3_loosened Somebody took the screws out of the bookcase's wall brace between 4:30 and 5:40, while he was on the beach.
snapjaw[happy]: Ooh, a brand-new hour! I'll put it on your little board. There! Isn't it pretty?
@alibi row 5 PM
think: Half past four to twenty to six. Where was everyone? I asked. Every one of them answered.
grub[normal]: That one I know! The kitchen. Making the soup. Mochi was chopping. You were, love. Onions.
mochi: I was. With Grub the whole time, until twenty to six.
@alibi grub 5 PM
bramble[normal]: ...the Conservatory... potting my seedlings... with Fennel...
fennel[normal]: Drawing her potting. She's a terrible model. She keeps apologising to the seedlings.
@alibi bramble 5 PM
@alibi bramble 5 PM proof
@alibi fennel 5 PM
@alibi fennel 5 PM proof
bruno[normal]: The cliff path. A crate from the wreck. Bruno was alone. Bruno is usually alone with crates.
@alibi bruno 5 PM
reginald[normal]: The terrace, on watch. Alone. You have heard about the terrace.
@alibi reginald 5 PM
duchess[normal]: My room, sewing that wretched gown. Alone, darling, and glad of it.
@alibi duchess 5 PM
lulu[normal]: The Music Room! Practising! Alone! Lulu is always alone in the Music Room. That's what practising is.
@alibi lulu 5 PM
zuzu[normal]: attic. mapping cameras. alone.
@alibi zuzu 5 PM
pepper[normal]: The Gallery darkroom. Developing. Alone, partner, unless you count the chemicals. They're very good listeners.
@alibi pepper 5 PM
@alibi nibs 5 PM
think: Bramble and Fennel together, Grub and me together. Everybody else on their own, all afternoon, all over the house.
bramble[sad]: ...I didn't hear anything... from the Conservatory you can't hear the Library... you can't hear anything but the fountain...
duchess[normal]: Then what killed him, darling? If he was dead before the shelf ever touched him. Something he ate?
grub[shock]: Everybody ate the same! One pot! One loaf! I...
think: Not something he ate. Something he drank. He asked for tea at ten.
@minigame c3_q_tea
mochi: The dumbwaiter car was up at the Library end, with a tray in it. A teapot, a little milk jug, and a round space where a cup should be.
mochi: The tea was cold, with pale grains settled in the bottom of the pot. And the bell tape in the pantry: since six last night, one trip up. Just one.
think: And at five to ten in the Grand Hall, with Reginald: a rattle inside the wall, far up. Then a little bell. Ting.
reginald[shock]: The bats! I said it was bats! ...It was not bats.
mochi: He asked for tea at ten. Somebody sent it up, and somebody put something in it.
@shout mochi THE TEA CAME UP THE DUMBWAITER!
@log trial #c3_tea_up A pot of tea with something in it went up the dumbwaiter at about five to ten. The only trip all night.
reginald[angry]: And who makes the tea in this house? Who stands at that hatch every night of the week? Who can't account for a single hour of last night?
narr: Every head turned, slowly, to the podium at the end of the row. Grub had both paws over his mouth.
reginald[angry]: The cook!
grub[sad]: I don't... Mochi, I don't remember. I really don't. I asked you, didn't I? Last night. I asked you if I'd made his tea.
@minigame c3_debate_grub
mochi: Grub isn't pretending, Reginald. Marigold's manual has a page with its corner turned down. Bites from bats.
mochi: "Days or weeks later: fever, itching at the bite, restlessness, lost hours, trembling paws, drooling, and a horror of water."
mochi: He couldn't hold a ladle still yesterday. He couldn't bring himself to taste his own soup. He won't go near a jug of water.
think: Nibs read that page in the wreck yesterday. He looked at Grub's paw, and closed the book, and didn't say a word.
@minigame c3_bubbles_sick
@shout mochi GRUB IS SICK!
grub[sad]: Sick. Oh. ...That's almost better, isn't it, love? Sick, I can be. I can't be the other thing.
bruno[sad]: Bruno has to say something. Bruno lied.
bruno[sad]: Grub was not with Bruno at half past nine. Bruno went down alone. Bruno said it so nobody would look at Grub.
bruno[sad]: Bruno is sorry. To everybody. To Mochi most.
zuzu[normal]: it's ok, bruno. i'd have lied too. i'd have lied worse.
fennel[sad]: A lie for a sick friend. I have heard far uglier ones told for far less.
think: The scratches on the Library door. Rows of four, knee-high, and splinters under his claws. He went to that door last night. He doesn't know why.
@log trial #c3_grub_sick Grub has been ill since the bat bite: lost hours, shaking paws, and he can't bear water. He wasn't with Bruno at 9:30.
reginald[angry]: Very well! If not the cook, then somebody else stood at that hatch with that pot!
@minigame c3_q_tray_who
mochi: The rope at the pantry hatch has bright pink glitter caught in it, right at paw height. Where you'd grab it to send the car up.
mochi: And the Duchess's powder tin, in Marigold's locker on the wreck. Nearly full, with two little dents in the top.
mochi: And one fleck of pink glitter on the lid.
narr: Every head turned to the one podium in the room that sparkled.
@anim c3_turn_lulu
lulu[sad]: Lulu did it.
lulu[sad]: Lulu did it! Lulu put it in the tea! Two pinches! Lulu sent it up! Lulu KILLED him!
@sfx gasp
@shake 10
bramble[shock]: ...Lulu...
bramble[sad]: ...you could have told me... whatever it was... you used to tell me everything...
duchess[shock]: My tin? You took my tin out of that locker?
lulu[sad]: Grub said where it was! On the wreck! Lulu took it when everybody was busy, and this morning Lulu ran all the way down and put it back.
lulu[sad]: Lulu only wanted him to sleep. If he slept past midnight, he couldn't find out. About Saffron's page. About the line with Lulu's name on it.
lulu[sad]: Lulu said something once. About Saffron. To a man with a notebook, after a concert. Years ago. A silly, showing-off thing...
lulu[sad]: And then at the fitting Lulu stood still for a whole hour and thought about that tea the whole time. And then Lulu cried in Mochi's room.
think: Lulu, on the end of my bed, crying until ten past twelve. Asking me not to ask.
@log trial #c3_tea_killed Lulu put two pinches of the Duchess's sleeping powder in his tea, and says that is what killed him.
reginald[angry]: Then there it is! The tea, the powder, the confession! A dead man under a shelf he never even felt!
@minigame c3_debate_tea
mochi: Two pinches can't stop a heart, Reginald. Marigold wrote it down, and taped it inside her cabinet door.
mochi: "One pinch: a good night. Two pinches: sleeps through anything, eight to ten hours. Never more than three. A whole tin would stop a heart."
mochi: The tin is nearly full. Two dents. Two pinches. That's sleep. Not death.
mochi: And he didn't even sleep. The tea came up at five to ten, and his blotter has working notes in a steady hand, with times, until five past ten.
@shout mochi TWO PINCHES CAN'T KILL!
lulu[sad]: ...Lulu didn't...?
duchess[normal]: You didn't, darling. You only drugged a chemist with my own sleeping powder. I shall be very cross about that later. Much later.
lulu[sad]: Lulu is sorry. To the Duchess. To Mochi. To... to him.
narr: Bramble half lifted a paw towards her, across the gap between their podiums. Then she put it down again.
@log strike c3_tea_killed
@log trial #c3_tea_sleep Two pinches of the powder only make you sleep. He was still writing in a steady hand at five past ten.
fennel[normal]: Then where is his cup? The pot is in the car. The tray has a hole the shape of a cup. Somebody is missing a cup.
@minigame c3_q_came_back
mochi: The side table by the hatch is filmed with white dust from the aftershock. In the dust there's one clean ring, the size of a teacup's foot.
mochi: Clean. The dust came down all round that cup at 11:05. And then, later, somebody lifted it off the table and took it away.
zuzu[normal]: and the door was bolted. so not the door.
mochi: Behind the tapestry on the far wall there's a narrow door into a passage inside the wall. No bolt on it, either side.
@shout mochi SOMEBODY CAME BACK THROUGH THE WALL!
bruno[sad]: Bruno tried that door. Bruno got stuck. Fennel had to pull.
fennel[happy]: With my crutch, like a cork out of a bottle. My finest hour in this house.
@log trial #c3_came_back After 11:05 somebody came back into the Library through the passage behind the tapestry, and took his cup.
reginald[normal]: A passage in the wall! A creeping, crawling thing! Then whoever crept left a trail, citizen.
@minigame c3_q_trail
mochi: Beside the prints in the passage, all the way along: a wide, smooth line through the white dust, like something soft dragged over the floor.
mochi: And on a splinter of the skirting, three threads of fine silk. Lilac.
@minigame c3_q_trail_who
narr: Every head turned, the way they had turned to Grub, and to Lulu. The Duchess sat up very straight under her hat.
pepper[happy]: Scoop!
pepper[sad]: Sorry. Sorry. Reflex. Nineteen years of reflex.
duchess[angry]: How dare you. HOW DARE YOU. All of you.
@log trial #c3_duchess_trail The trail in the passage is a trailing lilac hem.
@checkpoint c3_cp_showdown 20
@label c3_cp_showdown
@music trial_climax
think: The Duchess. Plum's line, with his name on it. A door in the wall, a lilac trail, and her own powder in his tea.
think: It fits. Every piece of it.
@minigame c3_rebuttal_duchess
mochi: Lulu's gown is lilac, yes. But Lulu's gown hasn't got feathers.
mochi: On the iron bracket over the passage door, high up, at hat height: a long lilac ostrich feather, snapped in half.
narr: The Duchess put one paw up to her hat. Slowly. To the place on the brim where there was a gap.
@shout mochi IT WAS YOUR HAT!
duchess[sad]: ...
@log trial #c3_duchess_did_it The Duchess came through the passage and killed him.
@music snapjaw
snapjaw[happy]: Well! WELL! A grudge, a secret door, a lilac trail and a snapped feather! My, my, my. That's a whole hat of evidence.
snapjaw[happy]: I could open the vote right now, you know. Just say the word. I am SO hungry for a vote.
think: It all fits. The motive, the passage, the trail, the feather, the cup. I could say it now.
@minigame c3_q_vote_offer
@if voted_early -> early_vote
mochi: Not yet. Let me run it through once more, from the top. Properly. He'd want it done properly.
snapjaw[normal]: Tsk. Spoilsport. Fine! A Case Rewind, then! From the very beginning! I'll even work the projector.
@minigame c3_rewind_false
narr: The reel stuck. The picture shook on panel four and froze there: half a capybara in a lilac hat, with one paw on a tapestry.
think: She went through the passage before the fitting, and killed him at his desk... No. That's not right. The passage. The floor of the passage.
@minigame c3_q_tracks
@anim c3_overturn2
mochi: The passage floor has two layers of dust. Grey underneath: that came down on Day 2, in the first aftershock, all over the house.
mochi: White on top: that came down at 11:05 last night. Rule seven. Two aftershocks, both posted on the board, both on the dot.
mochi: One set of prints goes through the white and presses down into the grey. But between the prints, the grey is smooth. Not a mark in it.
mochi: Nobody walked that passage between Day 2 and 11:05. Whoever made those prints went in after the aftershock. After he was already dead.
@shout mochi SHE CAME AFTER HE WAS DEAD!
@sfx gasp
reginald[shock]: After...? Then she can't have...
@log strike c3_duchess_did_it
@log trial #c3_passage_after Nobody walked the passage between the Day 2 aftershock and 11:05. The one set of prints came after he died.
narr: The Duchess took off her hat. She held it in her lap with both paws, the way she had on the bottom step this morning.
duchess[sad]: He was already dead, darlings.
duchess[sad]: I heard the crash at five past eleven. And then nothing. No shouting. No Nibs swearing at his books. Nothing at all.
duchess[sad]: After the fitting I went to have it out with him. Plum's line. I had decided I would scream at him until he told me the truth.
duchess[sad]: I knew the servants' ways from the house plan behind the portrait. A door he couldn't bolt. I thought: let him be startled, for once.
duchess[sad]: He was at his desk under all those books, and he was cold. And the cup on the table smelled of my powder. Violets. I'd know it anywhere.
duchess[sad]: So I took it. And the top sheet off his desk, in case it had my name on it. I was frightened, darlings. I'm not used to it.
narr: She reached into the crown of her hat, of all places, and took out a bundle wrapped in a lilac handkerchief, and a folded sheet of paper.
@clue nibs_cup
@clue nibs_sheet
duchess[sad]: There. I never washed it. I never read the sheet. I couldn't.
reginald[angry]: Madam, you have lied to this court all morning. Why on earth should we believe a word of it now?
lulu[sad]: She hid the cup with Lulu's tea in it. To hide Lulu's tea. Or her own powder. Lulu doesn't know which.
zuzu[angry]: convenient. "he was already dead." anybody could say that.
pepper[normal]: Sorry, Duchess. From up here it reads like a cover story. I'd run it on page two at best.
grub[sad]: I don't know what to believe any more, love. I don't know what I believe about me.
narr: Nobody believed her. You could see it go round the podiums, a little wave of nobody believing her.
think: I believe the dust. The dust doesn't lie. She went in after. But if she didn't... then who? How?
@music tension
snapjaw[happy]: My, my. A murder with no murderer. How very modern. I need a minute to think, and so do my chemicals.
snapjaw[happy]: RECESS, my darlings! Twenty minutes! Up the lift with the lot of you. Stretch your legs. Don't kill anyone.
snapjaw[normal]: Pepper's little roll from this morning has been sitting in my darkroom all day. I think it's time I printed it.
pepper[sad]: My roll. You're printing my roll? Now?
snapjaw[happy]: Sixteen frames, Pepper, darling! You said it yourself: a photo without a timestamp is just a picture. Yours have stamps!
@checkpoint after_recess 25
@anim c3_recess
@flag trial_break recess
@end
@label after_recess
@music trial
@clue scene_photos
narr: The lift brought us back down into the round chamber. The pool had gone very still.
narr: Everybody had a stack of prints, still damp, still smelling of vinegar.
snapjaw[happy]: Back, back, back to your podiums! Sixteen frames, fresh from my darkroom. I've looked at every one. I'm not telling.
think: I can look through them in my notebook. Every frame, every corner. Nobody's said a word about them yet. Everybody's waiting for somebody else to.
reginald[normal]: Then let us begin again where we stopped. With that cup. That cup is a confession, madam, whatever you say.
@minigame c3_q_not_tea
mochi: The cup smells of violets. The Duchess's powder. That's all it smells of. Nothing else.
mochi: And his own notes, the sheet she took off his desk. "9:58. Tea tastes of powder. Bless them. Not drinking that."
think: Bless them. He knew somebody was trying to put him to sleep. And he forgave them, before he even knew who.
mochi: He tasted it, put the cup down, and never drank it. And then at 10:14: "Tongue numb. Pen tastes of liquorice."
@shout mochi IT WASN'T THE TEA!
lulu[sad]: He said bless them. He said... bless...
narr: Lulu put her face in her paws. The Duchess, without looking, passed her the lilac handkerchief.
@log trial #c3_not_tea It wasn't the tea. He tasted it at 9:58 and didn't drink it. At 10:14 his tongue was numb.
zuzu[normal]: frame 1. the door. look. the bolt's still shot across, and the brass keeper's torn right out of the frame.
bruno[sad]: Bruno said the frame was warped. Bruno was wrong. It was bolted. Bruno broke the bolt out of the wood.
reginald[angry]: Then I am lost, citizen. Utterly. A bolted door. One trip up the dumbwaiter, and that was the tea. Nobody in the wall until he was dead.
@minigame c3_debate_reach
mochi: Something did get into him, Duchess. It didn't need a way in. It went in with him.
mochi: His tongue and his front teeth were stained dark, nearly black. He chewed his pens. All of them. Always.
mochi: And his last line: "Tongue numb. Pen tastes of liquorice." He wasn't writing about the tea. He was writing about his pen.
@shout mochi IT WAS ALREADY IN HIS MOUTH!
grub[sad]: His pen. He was always chewing that pen. I told him he'd get splinters in his gums.
@log trial #c3_in_mouth Nobody got in to him. Whatever killed him was on his pen, in his own mouth.
fennel[normal]: His pen. But his pen was on the floor this morning, mon ami, by the hatch. I saw you crouch over it.
@minigame c3_q_floor_pen
mochi: The pen on the floor by the hatch is smooth from end to end. A gold clip. Not one tooth mark.
mochi: And on the mantel in his room, a case of every pen he ever owned. Every one chewed. Some down to splinters. "RETIRED."
mochi: He never had a pen for an hour without chewing it. That pen on the floor was never in his mouth.
@shout mochi THAT ISN'T HIS PEN!
zuzu[sad]: somebody swapped it.
@log trial #c3_swapped The pen on the floor was a new one he never chewed. Somebody swapped it for his.
bruno[normal]: Then where is his own pen, Mochi? The chewed one?
@minigame c3_q_what_killed
mochi: At the bottom of the dumbwaiter shaft, under the pantry hatch, in the muck. One pen, chewed to splinters at the end.
narr: I'd brought it with me in a twist of paper. I took it out, and a napkin, and wiped it from end to end, in front of everybody.
narr: Under the muck, packed into the tooth marks, there was something grey. I held it up to my nose.
mochi: Aniseed.
mochi: Snapjaw's rat-bait smells of aniseed. "Acts in one to two hours." There's a tin in the Cellar, one in the Conservatory, one in the Attic.
@shout mochi IT WAS RAT-BAIT ON HIS PEN!
snapjaw[happy]: "Not for capybaras!" It says so right on the tin! "Mostly!" I can hardly be blamed for people not reading the small print!
grub[sad]: Liquorice. He wrote liquorice. That's what aniseed tastes like, if you don't know. If you're tired.
@log trial #c3_bait There was rat-bait paste in the tooth marks of his chewed pen, and the pen went down the dumbwaiter shaft.
lulu[angry]: Snapjaw's bait. And who lays Snapjaw's bait in this house? Everybody knows who.
bramble[shock]: ...Lulu...
bramble[sad]: ...for the rats... Grub's pantry had rats... I only wanted to help...
@minigame c3_debate_bramble
mochi: Bramble never left the table, Lulu. Fennel drew every empty chair at dinner, with the clock in every square. Hers is never empty.
mochi: And his pen only left him once all evening. At 8:05 he chewed it, pocketed it, and hung his coat on the hook. At 9:15 he took it back out.
mochi: If anybody put something on that pen, they did it at the hooks, in between. And Bramble was in her chair the whole time.
@shout mochi SHE NEVER LEFT THE TABLE!
bramble[sad]: ...thank you, Mochi...
narr: Lulu looked at Bramble for a long moment. Then she looked at the floor. That was all.
@checkpoint c3_cp_hooks 20
@label c3_cp_hooks
@music trial_climax
snapjaw[happy]: Ooh, now we're cooking! When, Mochi? When could anybody get at that pen? Show me on my lovely clock!
@minigame c3_time_hooks
mochi: From 8:05, when he hung up his coat with the pen in the pocket, until 9:15, when he took it down and put it in his mouth.
mochi: Before that it was in his paw or his teeth all day. After that it never left his mouth. The hooks are the only time it was out of his reach.
@minigame c3_who_left
mochi: And in that window, five of us left the table. Reginald at half past eight, for his wax. Lulu at twenty to nine, for her lip balm.
mochi: Pepper at ten to nine, to change her film. Zuzu at five past nine, for a wire. And Grub, in and out of the kitchen, four times.
reginald[sad]: The wax. Every night at half past eight. The whole table could set its watch by my moustache.
zuzu[normal]: i went for a wire. it's on snapjaw's tray now. i can show you the wire.
pepper[normal]: Film, partner. You can't develop a roll you haven't changed.
grub[sad]: I don't know where I went. I just went. Bread, I think. There was always more bread.
lulu[sad]: Lip balm. Strawberry. It's on the tray too.
@log trial #c3_hooks The pen was only out of his reach on the coat hooks, from 8:05 to 9:15. Five of us left the table in that time.
snapjaw[happy]: Five! What a lovely number. Now: who swapped the pen at seven this morning, in front of all of you? My projector is dying to know.
pepper[normal]: My frames. Every one stamped. If anybody crossed that room, it's in there somewhere. Look for the hatch.
@minigame c3_frames_pick
mochi: Frame 9, from the door, 7:04. At the far edge, by the hatch: a chewed pen on the floor, and the hatch shut.
mochi: Frame 12, from the far wall, 7:05. In the corner: a clean pen where the chewed one was, and the hatch open a crack.
mochi: Between those two frames somebody crossed the room, swapped the pens and opened the hatch. And frames 10 and 11, in between...
mochi: ...are each taken from further round the room. Further towards the far wall.
think: Zuzu kneeling at the body. Bruno under the shelf. Reginald and Lulu by the door. Fennel. Me. The same six, in the same places, in both.
fennel[normal]: I am in both, by the door, leaning on my stick and weeping. Not my best side. Not my best morning.
@minigame c3_who_reach
mochi: Six of us are in both frames, standing exactly where we stood. We never moved. And Grub isn't in the room yet: he's in frame 15, in the doorway.
mochi: That leaves the ones who aren't in either frame at all. The Duchess. Bramble. And whoever was holding the camera.
duchess[normal]: Somewhere behind you all, darling. I couldn't see a thing for Bruno.
bramble[sad]: ...by the window, I think... I couldn't look at him...
@log trial #c3_frames Between frames 9 and 12, the only ones free to cross to the far wall were the ones in no picture.
duchess[normal]: Darling, anybody might have grabbed a clean pen off his box this morning and swapped it in a panic.
@minigame c3_q_spare
mochi: Frame 3. The side table, 7:02, before anybody had touched a thing. His box of new pens: eleven in it, and one empty slot.
mochi: On Day 3 he counted that box out loud. Twelve. On Day 4 he counted it again. Twelve, still. "The last twelve new pens on this island."
mochi: So a new pen was already gone at 7:02. Whoever swapped it didn't grab one in a panic. They brought it with them.
mochi: Nobody brings a clean pen to swap for a chewed one unless they already know what's on the chewed one.
@shout mochi THE SWAP WAS PLANNED!
zuzu[normal]: so whoever swapped it is whoever poisoned it. same person.
mochi: The same person. Somebody who left the table between 8:05 and 9:15, and could cross that room between frame 9 and frame 12.
@log trial #c3_spare A new pen was already gone from his box at 7:02, before anybody touched a thing. Whoever swapped the pens came ready.
pepper[normal]: Okay. Okay. Hang on, partner. Let's not get ahead of the story.
@minigame c3_debate_zuzu2
mochi: Zuzu was closest to him, Pepper. Kneeling at the desk, holding his paw. In frame 9 and in frame 12, in exactly the same spot.
mochi: The hatch is on the far wall. Zuzu never got up off that floor until Bruno lifted them off it.
zuzu[sad]: i didn't let go of him. not till they made me.
@minigame c3_debate_fennel
mochi: Fennel sat next to me all through dinner, Pepper, with his crutch leaning on my chair. He can't go three steps without it.
mochi: And every square in his strip is drawn from the same seat, with the clock in it. There isn't a gap anywhere between 8:05 and 9:15.
fennel[normal]: Thank you, Mochi. Also, for the record, I have never hopped in my life. I glide. Badly.
think: Left the table: Reginald, Lulu, Pepper, Zuzu, Grub. Free to cross the room: the Duchess, Bramble, and whoever held the camera.
think: One name is on both lists. Only one.
pepper[normal]: Me. That's what everybody's looking at. Me.
pepper[normal]: Partner. I left at ten to nine and I came back at two minutes past. And I was in the Gallery the whole time. Two frames, stamped.
pepper[normal]: 8:52. 9:00. The Gallery. Two minutes up the stairs at a run and two minutes back. I timed it. I time everything.
@log trial #c3_pepper_dinner Pepper's own photos put her in the Gallery at 8:52 and 9:00, the whole time she was away from the table.
@sfx gasp
snapjaw[happy]: OH. Oh, this is DELICIOUS. Two lists, and the one name on both of them has a timestamp! Nobody fits!
snapjaw[happy]: Nobody did it! The house did it! I did warn you all about the house! Shall we vote for the house, my darlings? Snap-snap-snap!
reginald[shock]: Then... nobody? After all of that?
grub[sad]: I said. I said it was the house.
bruno[sad]: Bruno does not think a house can poison a pen.
think: No. The pen didn't swap itself. The box didn't count itself down to eleven. Somebody did this.
think: Then something we all believe is wrong. Something nobody here has ever doubted. Not once. Not in three trials.
pepper[normal]: Check the stamp, partner. The truth's in the timestamps.
@minigame c3_q_timestamp
@anim c3_overturn3
mochi: Look at the 8:52 frame, everybody. Not at the stamp. Behind it. On the mantelpiece over the fireplace.
mochi: The Gallery clock. "Wound and set by the Warden, daily, to the second." It kept perfect time until the aftershock threw it on the hearth at 11:05.
mochi: In Pepper's 8:52 frame, that clock says twenty past five.
@shout mochi THE CLOCK SAYS TWENTY PAST FIVE!
@sfx gasp
@shake 10
pepper[shock]: ...
mochi: The date-back on her camera can be set by hand. She reset it on the beach on Day 1, in front of all of us, because the sea had stopped it.
mochi: She took those two frames at twenty past five in the afternoon, with the stamp set to 8:52 and 9:00.
mochi: Twenty past five. Right in the middle of the hour somebody was loosening his bookcase.
@log strike c3_pepper_dinner
@log trial #c3_clock In the 8:52 frame, the Gallery clock behind it reads twenty past five.
snapjaw[happy]: Ooooh! Then SAY it, Mochi! Say it to my face! Who?
@minigame c3_q_who_moved
@shout mochi IT WAS YOU, PEPPER!
narr: Pepper didn't move. Her paws went to her chest, to where her camera always hung. It wasn't there.
pepper[normal]: Partner.
pepper[normal]: You're good. You've always been good. But a clock in the background isn't a pen in my paw.
@minigame c3_rebuttal_pepper
mochi: Your own roll, Pepper. Frame 9, from the doorway. Frame 10, from further round. Frame 11, further still. Frame 12, from the far wall.
mochi: Your camera walked to the hatch. The pen changed between 9 and 12. And the one person in none of those frames is the one taking them.
mochi: Every eye in that room was on the bookcase. Every eye except the camera's.
@shout mochi YOU WERE NEVER IN YOUR OWN PICTURES!
bruno[sad]: But why? Pepper. Pepper paid Bruno the cakes. Why would Pepper...?
@minigame c3_q_why
mochi: Nibs found out who typed the Ledger. His notes: "Entries: one face, nicked e. Names: another face, the prison office machine. Two machines."
mochi: Every entry in that book was typed on one machine, with a nick out of every small e. The names were added afterwards, on another.
mochi: He needed one old typed Puddle to check. "Ask G. for his shelf paper." Grub's pantry shelves are lined with them.
mochi: The Day 2 Puddle. Typed on Pepper's portable, before the ribbon went. Every small e has the same little nick.
@shout mochi YOU TYPED THE LEDGER!
narr: For a long moment there wasn't a sound in the chamber. Not the pool. Not even Snapjaw.
zuzu[sad]: ...the whole book.
reginald[shock]: Every line. My mother. Plum. All of it. One typewriter.
duchess[shock]: Then the names under them... Then he never... Nibs never...
think: Plum's line. The Dowager's. Bramble's father. Fizz. Grandma. Every page we hid from each other and fought over.
bramble[sad]: ...my father's page... and Fennel's name under it... I nearly stopped speaking to him over that...
fennel[sad]: You did stop, mademoiselle. For an afternoon. It was the longest afternoon of my life.
grub[sad]: Lulu read me my mum's page. Reginald's name was on it. I put extra salt in his tea for three days. I'm sorry, Reginald.
reginald[sad]: ...I noticed, Pemberton. I drank it anyway.
@log trial #c3_ledger The entries in the Ledger were typed on Pepper's portable typewriter.
snapjaw[happy]: Well! Mochi, my darling. From the top, if you please. All the way through. I'll work the projector.
think: All of it. In order. The way he would have. For him.
@minigame c3_rewind_final
@shout mochi IT WAS YOU, PEPPER QUILL!
narr: Nobody looked at the throne. Everybody looked at the podium with the empty paws.
@music snapjaw
snapjaw[happy]: Snap-snap-snap! And now, my favourite part, for the third time running! It's VOTING TIME!
snapjaw[happy]: Who killed Professor Nibs? Majority rules. Seventy percent, Mochi, or nobody listens!
think: This is it. Before we vote... should I say something?
@choice One last word before the vote...
> Trust the clock. -> last_clock
> Do it for him. -> last_nibs
@label last_clock
mochi: Everyone. Don't vote on a feeling. He never did. Vote on the clock. It's the only face in this house that never lied to us.
@jump last_done
@label last_nibs
mochi: He'd tell us not to guess. Measure, then guess, then measure again. We've measured. Let's do this for him.
@label last_done
pepper[sad]: ...Vote, partner. You've earned it.
@minigame c3_vote_final
@ifnot vote_correct -> wrong
@sfx correct
@shout snapjaw CORRECT!
snapjaw[happy]: Ding-ding-ding! The one who killed Professor Nibs was Pepper Quill, the Ace Journalist!
snapjaw[happy]: Three for three! Oh, I'm so proud of you all. You're practically detectives. Snap-snap-snap!
@end
# ---------------------------------------------------------------- the early vote Snapjaw offers (segment 17)
@label early_vote
snapjaw[happy]: Ooh! Decisive! I adore decisive! Vote away, my darlings, vote away!
@minigame c3_vote_early
# ---------------------------------------------------------------- WRONG VERDICT (gameover3_screen.gd names the culprit)
@label wrong
@sfx wrong
@shout snapjaw WRONG!
snapjaw[happy]: Wrong, wrong, WRONG! Oh, my darlings. I did so hope you'd get it wrong.
@end
""",

	# =====================================================================================
	# THE RECESS (the "recess" flow step between the trial's two halves: scripts/screens/recess3d_screen.gd walks the
	# Grand Hall; with --2d, "recess_walk" plays instead). Talks are flavour only: nothing here is needed to solve the case.
	# The prints are handed over in "recess_darkroom", and the trial gives them again after its after_recess label.
	# =====================================================================================
	"recess_intro": """
@bg manor_hall
@music tension
narr: The cage spat us out into the Grand Hall, blinking. Daylight through the tall windows, white dust on the tiles. Like coming up from underwater.
narr: Snapjaw went the other way, to the little cupboard under the stairs. A red bulb came on over its door, and the door shut behind him.
@show snapjaw happy center
snapjaw[happy]: My darkroom! Formerly a broom cupboard. The prints will be ready when I come out. Don't you DARE open that door.
@hide all
think: Everybody's standing about in little clumps, not looking at each other. I could talk to somebody.
think: Or I could go and wait by the cupboard under the stairs for those prints.
@end
""",

	"recess_bramble": """
bramble[sad]: ...Lulu wouldn't look at me... when you said I never left the table... she looked at the floor...
bramble[sad]: ...I used to know what she was thinking... before the pages... now I don't know what anybody's thinking...
mochi: Bramble, you don't have to be sorry for laying bait for rats.
bramble[normal]: ...I'm sorry anyway... it's a habit... Fennel says it's my best one...
@end
""",

	"recess_bruno": """
bruno[sad]: Mochi. Bruno lied in front of everybody.
bruno[sad]: Bruno does not lie. Bruno is bad at it. Bruno's ears go hot.
mochi: You lied to look after Grub.
bruno[normal]: Yes. Bruno would do it again. But Bruno's ears would still go hot.
narr: He looked across the hall at Grub, who was standing very still in the middle of the tiles, looking at nothing.
bruno[sad]: Bruno will stand next to him. Downstairs. Whatever happens.
@end
""",

	"recess_duchess": """
duchess[sad]: Nobody believed me, darling. I wouldn't have believed me either. I've been lying to all of you since breakfast.
duchess[normal]: The feather. Fancy that. I've lost feathers in better places than a wall.
duchess[sad]: He was so cold, Mochi. I've sat up with a great many people at the end, and I've never touched anybody that cold.
duchess[normal]: Find out who did it. Then I can go back to disliking him properly. I'd like that. It would feel more like him.
@end
""",

	"recess_fennel": """
fennel[normal]: I am drawing everyone during the break, mon ami. Look. Nobody is standing where they usually stand.
fennel[normal]: Lulu is on the far side from Bramble. Reginald is on the far side from Bruno. Zuzu is on the far side from everyone.
fennel[sad]: A room tells you who has fallen out with whom faster than any of us ever will.
mochi: Who's on the far side from you?
fennel[happy]: Nobody. I am too slow to get away from anybody. It is the one advantage of the stick.
@end
""",

	"recess_grub": """
grub[sad]: Is it lunch, love? It feels like lunch. Then I remember.
grub[normal]: Sick. You said I'm sick. I keep saying it over to myself. It's a good word. It's got an end to it.
grub[sad]: My head itches, Mochi. From the inside. And the pool down there... I don't like the pool. Don't let them stand me near the pool.
mochi: I won't. Bruno won't either.
grub[sad]: Good. Good. Bruno's a good lad. Big, but good.
@end
""",

	"recess_lulu": """
lulu[sad]: Lulu doesn't want to talk. Lulu wants to sit on the stairs and be a statue.
lulu[sad]: Two pinches. Lulu counted them. Lulu wanted to be careful. Isn't that stupid? Lulu wanted to be careful.
lulu[sad]: He said bless them. He didn't even know it was Lulu, and he said bless them.
mochi: He'd have said it if he did know, Lulu.
lulu[sad]: ...That's worse. That's so much worse, Mochi.
@end
""",

	"recess_pepper": """
pepper[sad]: No camera, partner. First recess of my life without a camera. My paws don't know what to do with themselves.
pepper[normal]: Sixteen frames. I can't remember a single one. I never look when I shoot. I look later.
pepper[sad]: Now he's looking first. Feels like somebody reading your diary out loud. Over a microphone. In a cave.
mochi: You'll get to see them too.
pepper[normal]: Sure. Sure I will. Facts first, right?
@end
""",

	"recess_reginald": """
reginald[normal]: Citizen. I have a confession of my own. Not to the court. To you.
reginald[sad]: I said that man gave my mother to that place, and I hated him for it, and he signed my roster every single night.
reginald[sad]: And now I am told, very nearly, that perhaps he didn't. And I can't ask him. Do you see? I can't even ask him.
mochi: You can sign his line on the roster tonight.
reginald[normal]: ...Prof. N. Yes. Perhaps I shall. In pencil. Lightly.
@end
""",

	"recess_zuzu": """
zuzu[sad]: i had a whole speech. on the stairs this morning. i practised it with the coffee.
zuzu[sad]: "i'm sorry i said you sounded like the warden. you don't. he doesn't say sorry and you always do."
zuzu[normal]: something like that. it was better with the coffee.
mochi: He'd have liked it.
zuzu[sad]: he'd have corrected my grammar. that's how you knew he liked it.
@end
""",

	"recess_darkroom": """
snapjaw[happy]: Ah! Mochi! Right on time. Hot off the fixer! Sixteen frames, numbered, every one with her little orange stamp.
narr: He handed me a stack of damp prints that smelled of vinegar. Then another stack, and another, one for every podium.
snapjaw[happy]: Copies for everybody! I'm terribly generous with other people's photographs. Now back down the lift, my darlings! Recess is OVER!
@clue scene_photos
think: I can go through every frame in my notebook. Every corner of every one.
@end
""",

	# With --2d there is no Grand Hall to walk in: the recess is told instead.
	"recess_walk": """
@bg manor_hall
@music tension
narr: The cage spat us out into the Grand Hall, blinking. Daylight through the tall windows, white dust on the tiles.
narr: Snapjaw shut himself in the cupboard under the stairs with a red bulb over the door. Nobody talked much.
narr: Lulu sat on the stairs. Bramble stood by the window. Reginald stood as far from Bruno as the hall allowed, and Bruno stood next to Grub.
narr: Twenty minutes later the cupboard door opened, and out came Snapjaw with a tray of damp prints that smelled of vinegar.
@show snapjaw happy center
snapjaw[happy]: Hot off the fixer! Sixteen frames, numbered, every one with her little orange stamp. Copies for everybody! Back down, my darlings!
@hide all
@clue scene_photos
think: I can go through every frame in my notebook. Every corner of every one.
@end
""",

	# =====================================================================================
	# AFTER A CORRECT VOTE: the confession, on the courtroom stage (chapters.gd "after_vote"). Then the execution.
	# =====================================================================================
	"confession": """
@bg trial
@music sad
narr: Pepper stood at her podium with her empty paws held together in front of her, the way you'd hold a camera that isn't there.
pepper[normal]: Facts first. Headlines never. That's what Mr. Pica used to say. My editor. He's ninety. He's in the west wing.
pepper[normal]: So here are the facts, partner. You might as well have them from the source.
pepper[sad]: For eleven years I sold tips to an agency. Little ones. Who was seen where. Who said what about whom.
pepper[sad]: They paid well, and they never asked a thing.
pepper[sad]: I never once asked what they did with them. A tip is just a fact, I told myself. Facts don't hurt anybody.
pepper[sad]: The agency was him.
narr: She didn't look at the throne. Snapjaw gave a little wave anyway.
pepper[sad]: On Day 3, after breakfast, he slipped me a page. The cover page of that Ledger. "Source for all entries: P.Q."
pepper[sad]: Every soul in that prison is there because of something I typed. Every one. Your mum, Zuzu. That one's even true.
zuzu[sad]: ...
pepper[sad]: He added the names afterwards, on the office machine, so you'd all hate each other instead of me. And it worked. It worked so well.
pepper[normal]: And then Nibs said he'd find out who typed it. By midnight. Hypothetically.
pepper[sad]: I tried not to. I want that on the record. I stole his samples on Night 3 and burned them in the Gallery grate. That should have been enough.
pepper[sad]: Then on Day 4 he said he didn't need them. Just one old Puddle. Line a drawer, wrap a fish. And I'd collected every one. Except the pantry.
pepper[sad]: I never thought about the pantry. Who reads the shelf paper?
mochi: Pepper...
pepper[normal]: The rest you know. The screws at five. The stamp set by hand, like on the beach. Two pictures of an empty room. One new pen in my pocket.
pepper[normal]: Twenty past five, right there in my own frame. Nineteen years with a camera, and I never once looked at the background.
pepper[sad]: Snapjaw took the roll at the door before I could print it. I told myself all day I'd have caught the pen, if I'd printed it first.
pepper[sad]: I wouldn't. I'd have looked at the body. Everybody does.
pepper[sad]: On the Mudlark I told you I'd made Tumble's alibi for him. By accident. Logging every cough.
pepper[sad]: This time I made one on purpose. For me. That's the difference, partner. That's the whole difference.
reginald[sad]: My mother has been in that place for two springs.
pepper[sad]: I know. I wrote it down. That's what I do. I write it down.
duchess[sad]: And Plum? And all those names? All those pages we hid from each other?
pepper[sad]: Nobody here gave anybody to him. Not one of you. It was only ever me.
narr: Lulu made a small sound. Across the gap between their podiums, Bramble shut her eyes.
grub[sad]: You ate my soup. Every night. You said it was the best soup on any island.
pepper[sad]: It was, Grub. That one's true too.
bruno[sad]: Pepper.
pepper[normal]: Bruno.
pepper[sad]: The cakes were terrible. I know they were. The B was supposed to be a B and it came out like a pretzel.
pepper[sad]: But they were the only debt I ever managed to pay. Every other one, I just... kept adding to.
bruno[sad]: Bruno ate all three.
pepper[happy]: I know you did. I took a picture.
@music snapjaw
snapjaw[happy]: Sniff! A scoop to the very end! And I've prepared something very special for my favourite stringer.
snapjaw[happy]: Every story needs an ending, and every ending needs a deadline! Hold the front page, my darlings!
@card STOP PRESS | Pepper Quill's Final Edition
snapjaw[happy]: It's PUNISHMENT TIME! Snap-snap-snap!
@end
""",
}

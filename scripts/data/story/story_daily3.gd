extends RefCounted
## Chapter 3 ("Murder at Warden's Rest") daily-life story scripts (SPOILERS: depth-and-case3-SPOILERS.md, S3).
## Flow (chapters.gd CH[3] "next"): aftermath -> quake (cutscene) -> day1 -> freetime -> night1 -> day2 -> freetime2 ->
## evening2 -> day3 -> freetime3 -> night3 -> day4 -> night4 -> day5 -> freetime5 -> evening (Day 5, 4:30 PM to dinner) ->
## night (Night 5) -> discovery (Day 6, 7 AM; hands over to the investigation). The epilogue is in story_end3.gd.
## Free Time: one step per day, the shared freetime_intro / freetime_outro / hangout_<id> scripts tell the days apart by the
## flags c3_day2 / c3_day3 / c3_day5 (set by day2 / day3 / day5), and each guest's arc by <id>_ft1.._ft4 (part D: Day 5 only).
## Day 4's Tea-Time Tribunal plays `@minigame c3_tribunal` (scripts/data/story_minigames3.gd, Drops clues.gd STORY3).
## Flag c3_ledger: set at Day 3's breakfast, from then on the hangouts know about the Ledger.
## Loose Ledger pages (page_<space>) can be read in Free Time from Day 3 and set read_page_<space>.

const SCRIPTS := {
	"aftermath": """
@card CHAPTER 3 | Murder at Warden's Rest
@bg ship_deck
@music sad
narr: Some days later. Morning, by the clock, anyway. Down here the clock is the only one who can tell.
think: Nobody sleeps below deck any more. We drag our blankets up and sleep in a ring around the little tub, like a litter of very sad dumplings.
@show grub sad center
narr: Grub came up the stairs with a tray of teacups and set one down on the rail in front of me.
narr: Yuzu tea. He makes it every morning now, whether anyone drinks it or not.
grub[sad]: Drink it while it's hot. Marigold always said... well. You know what she always said.
narr: He'd brought his good pots up on deck too, stacked by the tub. None of us trust anything below the waterline any more.
@hide all
@show bramble normal left
narr: In a teacup by the tub, Bramble had planted one sprig of chamomile in lake-bed mud. It hadn't died yet. We all watched it like it might.
bramble[normal]: ...It's growing... a little... I think it likes the dark...
@show fennel normal right
fennel[normal]: Then I shall paint it in the dark. Which is to say, in charcoal. It is the only colour I have left.
@hide all
@show reginald normal center
narr: Sir Reginald was tying himself to the rail with a length of mooring rope. Firmly. With a great many knots.
reginald[normal]: Night watch, day watch, and every watch in between. If I fall asleep at my post, at least I shall not fall off it.
@show zuzu normal farright
zuzu[normal]: it's a boat sitting on mud, reggie. worst case, you slide gently into mud.
reginald[angry]: Then I shall slide into it with dignity.
@hide all
@show duchess normal left
narr: The Duchess arrived in the largest hat any of us had ever seen. Lilac, with a feather that had its own weather.
duchess[normal]: Don't look at me like that, darlings. If I am to be miserable, I shall be miserable in a hat.
@show pepper normal right
pepper[normal]: Bruno. Those three cakes I owe you. The minute we're somewhere with a working oven. On the record.
@show bruno happy center
bruno[happy]: ...Bruno will wait. Bruno is very good at waiting.
@hide all
@show lulu sad center
narr: Lulu sat on the stairs, humming something with no tune to it. She'd been humming it for days.
mochi: That's pretty, Lulu.
lulu[sad]: Is it? Lulu doesn't even know what it is. It just keeps coming out.
@hide all
@sfx qk_tremor
@shake 3
narr: The tea in my cup shivered into little rings.
@show nibs normal center
nibs[normal]: Tremor. The third one today. Statistically unremarkable. A drained lake bed settles, the rock adjusts, and everything is perfectly fine.
nibs[shock]: ...Hypothetically.
@show zuzu normal farright
zuzu[normal]: you said hypothetically like it was a question.
@hide all
@log timeline Breakfast on deck. The tea rattled in another small tremor, the third one today.
think: The cup on the rail started to rattle. Gently, at first. Then not gently at all.
@end
""",

	"day1": """
@card DAY 1 | Warden's Rest
@bg manor_shore
@music stop
@sfx qk_waves
narr: Sand. Warm, dry sand, and a sun so bright it hurt.
narr: I lay on my back where the sea had dropped me and looked straight up. A sky. A real one, with clouds drifting across it like bath foam.
think: Weeks underground. I'd forgotten the sky was this big. I'd forgotten it was there at all.
@sfx qk_gulls
narr: Behind me the Mudlark lay on her side in the shallows, one smokestack sheared clean off. Gulls were already landing on her.
narr: Ahead, a cliff went straight up out of the beach, and on top of it sat a house the size of a small town.
narr: Out in the bay, on its own black rock, sat the biggest prison I had ever seen.
@music daily
@show lulu shock left
lulu[shock]: Lulu is alive! Lulu is ALIVE! Everybody count yourselves! Lulu counts... one!
@show zuzu normal right
zuzu[normal]: two. my laptop is dead though. so one and a half.
@hide all
narr: We counted. Eleven. All eleven of us, sandy and soaked, crawling out of the wreck one at a time like baby turtles.
think: All eleven. I said it again in my head, just to hear it.
@sfx gasp
@show fennel sad center
fennel[sad]: Ah. AH. Nobody touch me. My left leg is no longer on speaking terms with the rest of me.
@show bruno normal farright
narr: Bruno was beside him before the rest of us had stood up, with the green first-aid box from the ship's infirmary under one arm.
bruno[normal]: Bruno will look. Hold still, please. ...Cracked, maybe. Not broken all the way. Bruno will splint it.
narr: He snapped a slat off a broken crate, padded it with a towel and began to bind it. Quick and firm, not one wasted move.
@show lulu normal farleft
lulu[normal]: Bruno, you're so good at that! Where did you learn to do splints?
bruno[normal]: Bruno did three years in the IDF. They teach you splints. ...Breathe out, Fennel.
narr: That was all. He went back to the splint and tied it off with a neat, flat knot.
narr: A little way up the beach, Sir Reginald had been wringing seawater out of his plume. He stopped wringing. He didn't say anything.
@hide all
@show fennel normal center
narr: Bruno cut down a broken oar for a crutch. Fennel tried it, wobbled, and announced to the whole beach that he would never walk unaided again.
fennel[sad]: Paint me like this. The Shipwrecked Artist, on a crutch, in charcoal. Somebody write that down. Somebody weep.
@hide all
narr: Then we went back into the wreck for whatever the sea hadn't taken.
@show grub happy left
grub[happy]: My good pots! Every one of them! And a sack of flour that's only wet on one side! Don't tell my mum, but I could cry.
@show duchess normal right
duchess[normal]: My hatbox, darlings. Dry inside. The hat is perfectly fine. I was not worried. I was merely screaming.
@hide all
@show nibs happy left
nibs[happy]: My barometer survived! The pressure is rising. Statistically, we are about to have a lovely afternoon.
@show reginald normal right
reginald[normal]: My foil. Salt in the guard, but the blade is true. A Puddlesworth is never unarmed.
@hide all
@show bramble happy center
bramble[happy]: ...the chamomile... in its teacup... it rode out a whole flood in a teacup... I'm so proud of it...
@hide all
@show pepper happy center
@sfx sp_type
pepper[happy]: And she types! My portable! The ribbon's soaked, but she types. The Daily Puddle lives!
narr: She pulled her camera out of her coat and frowned at the little lit window on the back of it.
pepper[normal]: The sea's stopped my date-back. Hang on.
narr: She turned a tiny wheel on the back with her thumbnail. Click, click, click. Day, hour, minute.
pepper[normal]: There. Back on the record. A photo without a timestamp is just a picture, partner.
@hide all
@sfx static
voice: Testing. Testing. Ahoy, shipwrecks!
narr: A loudspeaker on a pole at the top of the beach crackled into life. It had a little crocodile crest on it. Of course it did.
snapjaw[happy]: Welcome to my island! Up the path, darlings. The house is expecting you. Mind the steps. There are four hundred and twelve.
@log timeline Washed up on the island. All eleven of us. Fennel's leg is hurt, and Bruno splinted it on the beach.
@bg manor_hall
@music stop
narr: There were four hundred and twelve. Bruno carried Fennel up most of them. Fennel narrated the whole climb.
narr: At the top stood the house: two great wings, a clock tower, and a crack running down the front from the roof to the step.
narr: The doors swung open by themselves. Inside was a hall like a cathedral, black and white marble, with a staircase that split in two halfway up.
@anim c3_welcome
@music snapjaw
@show snapjaw happy center
snapjaw[happy]: My little house by the sea! I built it myself, to keep an eye on my work.
snapjaw[normal]: My work being the Gaol, over there on the rock. Finest prison on the coast. Six hundred cells, one gate, no boats.
snapjaw[happy]: I was its Warden for thirty glorious years. And now I'm yours! The Mudlark is firewood, so this is home sweet home.
@show reginald angry farleft
reginald[angry]: We are not prisoners, sir! We are shipwrecked gentlefolk! There is a difference!
snapjaw[happy]: Is there? Do tell me what it is, one day. I'd love to know. Now: house rules!
@hide reginald
snapjaw[normal]: The usual six. No leaving. Nighttime is ten till seven, and nobody goes outdoors at night. The terrace has a roof, so it's indoors. I'm generous.
snapjaw[normal]: Bedroom doors lock from the inside. Sleep tight! A killer nobody catches gets to check out, and a body means an investigation, then a trial.
snapjaw[normal]: And rule six, as ever: no violence against Warden Snapjaw. He bites.
snapjaw[happy]: Rule seven. The ground is still settling, my darlings. Aftershocks get posted on the notice board a day ahead. I am punctual.
snapjaw[happy]: And rule eight. When a body turns up, pockets are turned out at the door, and every camera comes to my darkroom. I print everything. I read everything.
@clue rules3
@show pepper angry farleft
pepper[angry]: Every camera? My camera?! That's press property! You can't just develop a journalist's film!
snapjaw[happy]: I can and I will, and I'll frame the best ones. Only if somebody dies, of course. So, probably.
@show zuzu normal farright
zuzu[normal]: "i read everything." cool. normal thing to say. not a threat at all.
@hide all
@show snapjaw happy center
narr: He pinned a card to the big notice board by the stairs and patted it flat. A crocodile crest at the top, and one line underneath.
snapjaw[happy]: AFTERSHOCK. TOMORROW, 3:10 PM. Set your watches! I already have. Snap-snap-snap!
@log timeline New house rules. Rule seven: aftershocks are posted a day ahead. Rule eight: pockets turned out and cameras taken when a body turns up.
@hide all
@music daily
narr: Then he gave us the tour, walking backwards up and down the corridors like a museum guide who hated the museum.
@bg manor_cloakroom
narr: A cloakroom with a long row of brass hooks, and through an arch, a Dining Room with a table you could land a boat on.
snapjaw[normal]: Coats on the hooks before dinner, if you please. I'll explain at dinner. I love explaining at dinner.
@bg manor_kitchen
@show grub happy center
grub[happy]: Oh. Oh, look at her. Look at that range. Eight burners and a bread oven. I think I'm in love.
grub[happy]: There's a little lift in the wall for sending trays upstairs, too! A dumbwaiter! I've always wanted a dumbwaiter!
@hide all
@bg manor_terrace
narr: A terrace hanging over the sea, with deckchairs, a tea table, and a brass telescope on a tripod, pointed straight at the prison.
narr: Snapjaw threw a velvet cover over the telescope before anyone could touch it.
snapjaw[happy]: Not yet! Tomorrow evening. Opening night! You'll love the view. Everyone always does.
@bg manor_corridor
narr: Upstairs, the Bedroom Wing: a long red corridor of doors, each with a brass plate. Not our names. Birds.
snapjaw[normal]: Curlew, Dunlin, Gannet, Heron... Island birds! Find your key on your pillow, and your door at the end of it. Mochi, you're the Curlew.
narr: Three doors at the top of the stairs stayed locked: the Library, the Gallery and the Music Room.
snapjaw[happy]: Tomorrow! A house should be unwrapped slowly, like a present. Or a bandage.
@log timeline Tour of the house. The Library, Gallery and Music Room are locked until tomorrow. Bedrooms are named after island birds.
@hide all
@bg manor_hall
@show grub normal farleft
grub[normal]: One more thing. A house like this has a cellar, and a cellar has wine, and a stew needs a glass of red. Where is it?
@show snapjaw happy farright
snapjaw[happy]: The cellar? Down those steps. It's... occupied. But do go and see! I insist.
@hide snapjaw
@show zuzu normal farright
zuzu[normal]: i'll come. a house this old has a fuse box down there somewhere. and fuse boxes have camera wires.
@show reginald normal center
reginald[normal]: Then I shall lead. Stand aside. A Puddlesworth goes first into the dark. It is practically our family motto.
@hide all
@bg manor_cellar
@music tension
narr: The cellar was a long brick tunnel lined with dusty racks. It was cold, and it smelled of old corks and something else. Something musty.
narr: Reginald held his foil out in front of him like a lantern. Grub went straight for the racks.
@show grub happy farleft
grub[happy]: Oh, these are lovely. Look at the dust on them! Why is the ceiling... rustling?
@show zuzu shock farright
zuzu[shock]: grub. don't. move.
@hide all
@sfx gasp
@anim c3_bats
@music daily
narr: When the last of them had flapped back up into the dark, there were three of us bleeding and one of us laughing over a loudspeaker.
snapjaw[happy]: Marvellous, aren't they? Bigger wings, sharper teeth, worse manners. Nobody else on the coast has bats like mine.
@show grub sad farleft
grub[sad]: Ow. Ow ow ow. Right on the stirring paw. How am I meant to stir with a hole in my stirring paw?
@show zuzu angry farright
zuzu[angry]: one bit me on the paw and looked me in the eye while it did it. personal. it was personal.
@show reginald angry center
reginald[angry]: A scratch! A mere scratch. A Puddlesworth has bled for far less noble reasons.
@hide all
narr: Upstairs, Bruno opened the green box and bandaged Grub's paw, then Zuzu's. He did both with the same quick, flat knot.
@show bruno normal left
bruno[normal]: Sir Reginald. Your paw, please.
@show reginald normal right
reginald[normal]: I can manage, thank you.
narr: He took a roll of bandage from the box without looking up and wound it round his own paw himself. Badly.
@hide all
@show nibs normal center
nibs[normal]: Bat bites are mostly harmless, statistically. Keep them clean, keep them dry, and... well. Mostly harmless.
@hide all
snapjaw[normal]: Free time until supper, my darlings! Do try not to bleed on anything antique.
@log timeline Bats in the wine cellar. Grub, Zuzu and Reginald were bitten on the paw. Bandaged upstairs. The cellar is shut until tomorrow.
think: Three bandaged paws, one house, one island. Day one. It's going to be a long week.
@end
""",

	"night1": """
@bg manor_kitchen
@music daily
narr: Supper was Grub's soup, in the kitchen, out of his good pots, with bread made from the dry side of the flour.
narr: Grub stirred it left-pawed, with his bandaged paw tucked against his apron. It was still the best thing I'd eaten in weeks.
@show grub happy center
grub[happy]: Seconds for everyone! Thirds for Bruno. Fourths if nobody's looking.
@hide all
narr: Bruno pulled out the chair beside him for Reginald, the way he always had.
narr: Reginald took his bowl to the far end of the table and sat there instead. Bruno pushed the chair back in. Neither of them said anything.
@show duchess normal left
duchess[normal]: Four-poster beds, darlings. With canopies. I may forgive the caiman one tenth of one percent.
@show nibs happy right
nibs[happy]: Eight burners, eleven bedrooms, four hundred and twelve steps. Statistically, the nicest place we've ever been kidnapped to.
@hide all
@show bramble happy center
bramble[happy]: ...there's a kitchen garden out the back... all weeds and broken glass... I'm going to fix it...
@hide all
@sfx chime
@bg manor_corridor
@music stop
narr: At ten, a bell rang through the whole house, and somewhere a great many bolts slid home at once.
@anim c3_searchlight
@bg manor_bedroom_night
narr: The Curlew Room had a four-poster bed, a fireplace, and a window that faced the bay.
narr: Every few seconds a white beam swept across the ceiling, slid down the wall, crossed my pillow and was gone. Then it came back.
think: The searchlight on the prison tower. It never stops. Round and round, all night.
narr: Through the wall I could hear Lulu humming her tuneless song. Down the corridor, someone paced. Someone else gave up and lit a lamp.
think: Nobody slept. I know, because at three in the morning, half of us were sitting on the stairs in our dressing gowns.
@show pepper sad left
pepper[sad]: Three oh four AM. Eleven of us awake, counting the beam. It comes round every nine seconds, if anyone's wondering.
@show lulu sad right
lulu[sad]: Lulu wasn't wondering. But now Lulu's counting. Thanks, Pepper.
@hide all
think: Nothing happened. Nobody screamed, nothing broke, nobody went missing. Just the beam, round and round, and the sea.
think: It should have felt like a good night. It didn't.
@log timeline Night 1. The prison searchlight sweeps every room facing the bay. Nobody slept. Nothing happened.
@evening
@end
""",

	"day2": """
@card DAY 2 | Settling In
@flag c3_day2
@bg manor_hall
@music daily
@sfx sp_type
narr: I woke to the sound of a typewriter. Clack-clack-clack-DING. It was not yet six.
narr: By the time I came down, the big notice board in the Grand Hall had been taken over.
narr: Top left: the Daily Puddle, Island Edition. One sheet, typed on Pepper's portable. SHIPWRECKED: ELEVEN SURVIVE, ONE SMOKESTACK DOES NOT.
@show pepper happy left
pepper[happy]: Morning edition! Circulation eleven, price nothing, corrections never. Facts first, headlines never. That's the rule.
@hide all
narr: Next to it, Grub's menu. No words on it at all. A drawing of a pot, a drawing of a fish, a drawing of a very happy face.
@show grub happy right
grub[happy]: It's a menu! Everyone can read a fish. Fish stew, and if you're good, the happy face is a tart.
@hide all
narr: Then Reginald's watch roster, in a careful copperplate hand. NIGHT WATCH: R. PUDDLESWORTH. DAY WATCH: R. PUDDLESWORTH.
@show reginald normal left
reginald[normal]: And a copy by the Dining Room door, for signing. Every guest, every meal, so that the watch knows who is accounted for.
@hide all
narr: And in the bottom corner, in round, cheerful handwriting: FACT OF THE DAY. A capybara can hold its breath for five minutes.
@show nibs happy center
narr: Professor Nibs was still standing in front of it, admiring his own work and chewing the end of his pen.
@show lulu shock farleft
lulu[shock]: Ew! Professor! You're eating your pen!
nibs[normal]: I'm thinking WITH my pen. Different thing. I used to think with pencils. Pencils were a phase. I graduated.
@show zuzu normal farright
zuzu[normal]: he's chewed through every pen he's ever owned. it's not a habit. it's a lifestyle.
@hide all
narr: Pinned dead centre, above everything else, was a card with a crocodile crest. AFTERSHOCK. TODAY, 3:10 PM. I AM PUNCTUAL.
@show nibs normal center
nibs[normal]: Nobody can predict an aftershock to the minute. It's simply not possible. Seismology doesn't work like that.
snapjaw[happy]: I can! Snap-snap-snap! And good morning! The rest of the house is open. Library, Gallery, Music Room. And the cellar, now my bats are calm.
@hide all
@log timeline The notice board: the Daily Puddle, Grub's menu, the watch roster, the Fact of the Day. A card says the aftershock is at 3:10 PM today.
@log timeline The Library, Gallery, Music Room and Wine Cellar opened.
@bg manor_library
narr: The Library was two storeys of books, green leather chairs, a fireplace, and a big desk under a tall bookcase.
narr: On a writing table in the corner sat a typewriter, heavy and black, the size of a small piano.
@show zuzu normal left
zuzu[normal]: whoa. a typewriter. no wifi, no screen, no cloud. it's the most secure computer in the house.
@show pepper normal right
pepper[normal]: A second typewriter? Huh. Older than mine. Sticky keys, I bet. Mine's better.
snapjaw[happy]: Three on the island, my darlings! Hers, this one, and the old machine in the prison office, where every intake form was typed.
snapjaw[normal]: Don't go looking for that one. It's mine.
@hide all
@show nibs happy center
nibs[happy]: A desk! A real desk, with a lamp and a blotter! I shall work here every night. Science needs a desk the way soup needs a pot.
@hide all
@bg manor_gallery
narr: The Gallery ran the length of the upper floor: tall windows down one side, portraits down the other, dozens of them, in heavy gilt frames.
@show fennel happy left
fennel[happy]: Look at them all. Admirals, bishops, a lady with a parrot. Not one painted by anyone I've ever heard of. I adore every one.
@show duchess normal right
duchess[normal]: That one is wearing my hat. Not a copy, darling. MY hat. In oils. I shall be having words with that woman.
@hide all
narr: On the mantel stood a little round-topped clock in dark polished wood, on a brass foot, ticking away to itself.
snapjaw[normal]: Every clock in my house is wound by me, every morning, to the second. Hall, Gallery, Dining Room, all of them. I am punctual.
@show pepper normal center
@sfx sp_flash
pepper[normal]: Mind if I take a few for the Puddle? Click. Day 2: the Gallery, and its many disappointed ancestors.
@hide all
@bg manor_music
narr: The Music Room had a grand piano, a harp with half its strings, a gramophone with a horn like a lily, and a dressmaker's dummy in the corner.
@show lulu happy left
lulu[happy]: A PIANO! Lulu has a piano! Lulu is never leaving this room. They'll find Lulu here in a hundred years, still playing.
@show duchess happy right
duchess[happy]: And a dress form, darlings. A proper one, with a cage skirt. At last, somewhere to work.
@hide all
@bg manor_cellar
narr: The cellar smelled less of bat today and more of something sharp and sweet, like liquorice sweets.
narr: Low tins sat along the bottom racks. Each one had a cartoon rat on the lid, lying on its back with little crosses for eyes.
narr: SNAPJAW'S RAT-B-GONE. SMELLS OF ANISEED! RATS CAN'T RESIST! WORKS IN ONE TO TWO HOURS!
@show bramble sad left
bramble[sad]: ...rat bait... in a house with a kitchen garden... oh dear... the poor rats... and the poor garden...
@show grub angry right
grub[angry]: Not near my kitchen. Not near my flour. Not near anything I put in a mouth.
snapjaw[happy]: There are tins in the Attic and the Conservatory too, for when you get there. I like my house rat-free and my guests well-fed!
@hide all
@log timeline Rat-bait tins in the Wine Cellar with cartoon rats on the lids. Snapjaw says there are more in the Attic and the Conservatory.
think: A day to settle in. The aftershock isn't until 3:10. I've got time to see how everyone's doing.
@end
""",

	"evening2": """
@bg manor_hall
@music tension
narr: At 3:09 PM, most of us were in the Grand Hall, staring at the clock over the stairs. Nobody had planned to be. We just were.
@show nibs normal center
nibs[normal]: It won't happen. Aftershocks don't keep appointments. In approximately thirty seconds I will be proved right.
@hide all
@anim c3_aftershock
@music daily
narr: When it stopped, everything was grey. The floor, the stairs, the banisters, us. Plaster dust had sifted down from every ceiling in the house.
@show snapjaw happy center
snapjaw[happy]: Three ten! To the second! Didn't I say? You'll get used to it. Everyone does, eventually.
@hide all
@show lulu happy left
lulu[happy]: Look! Lulu's footprints! Like walking in snow! Everybody's footprints show!
@show fennel normal right
fennel[normal]: Every step leaves its signature. How horribly honest of the floor. I shall sketch it before anyone ruins it.
@hide all
@show nibs shock center
nibs[shock]: To the SECOND. That isn't seismology. That's... that's... hypothetically, that's a timetable.
@hide all
@log timeline 3:10 PM | The aftershock came exactly on time. Grey plaster dust came down all over the house, and footprints show in it.
@bg manor_kitchen
narr: Everyone queued at the big stone sink in the kitchen to wash the dust out of their fur. Bramble worked the pump.
@show bramble happy left
bramble[happy]: ...here, Grub... your turn... it's lovely and cold...
narr: She splashed a scoop of water towards him, the way you would to anyone. Grub jerked back so hard he hit the dresser and set every plate rattling.
@show grub shock right
grub[shock]: Don't! Don't... sorry. Sorry, love. I'll wash later. Cold water. Gives me the shivers today.
@hide all
think: Funny. I've known a lot of capybaras. I've never seen one back away from water before.
@show reginald normal center
reginald[normal]: Nor shall I wash in a scullery, thank you. A Puddlesworth bathes in a bath, on a Sunday, like a civilised creature.
@hide all
think: ...Then again, maybe some capybaras just don't.
@bg manor_cloakroom
@music daily
narr: At eight, a gong. Grub's first proper dinner. Snapjaw met us in the cloakroom outside the Dining Room, tapping the row of brass hooks.
@show snapjaw normal center
snapjaw[normal]: House rule, my darlings. Coats on the hooks, and everything in them. Nothing goes on my table but plates. I've seen how you lot eat.
snapjaw[happy]: Hats, bags, notebooks, little sticky tins of things. Hooks! From tonight, at every dinner, forever.
@hide all
narr: Everyone grumbled about what they had to leave behind in a pocket.
@show reginald angry left
reginald[angry]: My moustache wax! A gentleman re-waxes between courses! What if I droop?
@show lulu sad right
lulu[sad]: Lulu's lip balm lives in Lulu's paw. It doesn't like pockets. It gets lonely.
@hide all
@show zuzu normal left
zuzu[normal]: my earbuds live in my mouth. where do i put the earbuds. this is a human rights issue.
@show nibs normal right
nibs[normal]: My pen! What if I have a thought between the soup and the fish? Thoughts don't wait for dessert.
@hide all
narr: Several people swore blind they never put anything down anywhere. Snapjaw just tapped the hooks until they did.
narr: On his way in, Nibs signed Reginald's roster by the door, gave the end of his pen a good long chew, put it in his coat pocket and hung the coat up.
narr: Nobody else signed the roster. Reginald noticed, and said so, at length.
narr: Reginald hung his own coat, came back for the wax, put it back, came back for it again, and was finally led away by the elbow.
@show reginald sad center
reginald[sad]: I shall droop. I shall droop, and history will remember it.
@hide all
@bg manor_dining
narr: Dinner was fish stew and a tart with a happy face drawn on it in jam. It was the first time since the flood that we'd all sat down together.
@show grub happy center
grub[happy]: Eat up, eat up! There's more in the pot. There's always more in the pot. That's the first rule of a kitchen.
@hide all
@show bruno happy farleft
bruno[happy]: Bruno has had three bowls. Bruno will have a fourth. For Grub's feelings.
@show duchess normal farright
duchess[normal]: The tart has a face on it, darlings. I cannot eat a thing that is smiling at me. ...Pass it here.
@hide all
narr: Nibs was first up, as he would be every night. He took his own coat off the hook, pulled out the pen, and chewed it all the way out of the door.
@show nibs happy center
nibs[happy]: Library! Science waits for nobody. Goodnight, all. Splendid tart, Grub.
@hide all
@log timeline First proper dinner. New house rule: coats on the hooks in the cloakroom, everything in the pockets, nothing on the table.
@sfx chime
snapjaw[happy]: Ding-dong! Everyone to the terrace, please! Yes, Professor, you too. It's opening night!
@bg manor_terrace_dusk
@music tension
narr: The sun was going down behind the prison. In every one of its six hundred windows, a small light had come on.
narr: Somebody had wheeled a television out onto the terrace. It switched itself on.
@anim snn_c3_2
@anim c3_passes
narr: Mine was stiff yellow card with a crocodile crest, a cell number, and a photograph.
think: Grandma. In her good cardigan, sitting on a bunk, blinking at the camera like she's just been woken from a nap.
narr: Nobody spoke for a long time. One at a time, we took turns at the telescope, and found our window, and looked.
think: She went to see her sister by the sea last summer, and never wrote back. I thought... I don't know what I thought.
@show reginald sad left
reginald[sad]: Mother. They took her two springs ago and told me she'd gone abroad for her health. She's been across the bay all along.
@alibi reginald motive
@log people reginald His mother, the Dowager, is in a cell in the Gaol. They took her two springs ago.
@show duchess sad right
duchess[sad]: Plum. My niece. They came for her two winters ago and nobody would say where. She's nineteen, darlings. She sews buttonholes.
@alibi duchess motive
@log people duchess Her niece Plum, nineteen, is in a cell in the Gaol. They took her two winters ago.
@hide all
@show bruno sad left
bruno[sad]: Little Sesame. Bruno's youngest student. She went missing last year. Bruno looked everywhere. Everywhere but there.
@alibi bruno motive
@log people bruno Sesame, his youngest student from the dojo, is in a cell in the Gaol. She went missing last year.
@show lulu sad right
lulu[sad]: Miss Pip. Lulu's first singing teacher. She stopped answering Lulu's postcards. Lulu thought she was cross with Lulu...
@alibi lulu motive
@log people lulu Miss Pip, her first singing teacher, is in a cell in the Gaol. Her postcards stopped coming back.
@hide all
@show bramble sad left
bramble[sad]: ...Dad... the council said he'd been moved to a home... a nice one, with a garden... that isn't a garden...
@alibi bramble motive
@log people bramble Her father, a nurseryman, is in a cell in the Gaol. She was told he'd moved to a home.
@show fennel sad right
fennel[sad]: Saffron. My sister. She painted an unflattering face on a locket, and they came for her. I thought she'd fled the country.
@alibi fennel motive
@log people fennel His sister Saffron, a painter of miniatures, is in a cell in the Gaol. He thought she'd fled.
@hide all
@show zuzu sad left
zuzu[sad]: mum. they took her radio, and then they took her. she hates the dark. ...is there a radio in there.
@alibi zuzu motive
@log people zuzu Their mum, who ran a radio station from her kitchen, is in a cell in the Gaol.
@show grub sad right
grub[sad]: That's my mum. Her letters stopped last autumn. She's got a bad hip. Who puts a lady with a bad hip on a bunk?
@alibi grub motive
@log people grub His mum, who taught him to cook, is in a cell in the Gaol. Her letters stopped last autumn.
@hide all
@show pepper sad left
pepper[sad]: Mr. Pica. My first editor. They shut his paper down and he went with it. Facts first, headlines never. He's ninety.
@alibi pepper motive
@log people pepper Mr. Pica, her first editor, is in a cell in the Gaol. He went when his paper was shut down.
@show nibs sad right
nibs[sad]: Fizz. My lab assistant. After the explosion they took her away for questioning, and nobody would say where. She's twenty-two.
@alibi nibs motive
@log people nibs Fizz, his lab assistant, is in a cell in the Gaol. Taken for questioning after an explosion.
@hide all
@show snapjaw happy center
snapjaw[happy]: Aren't they lovely? Every one of them here on somebody's information. Fed, watered, and lights on till midnight.
snapjaw[normal]: You heard the offer. I shan't repeat it. I'll simply leave the telescope out for you. Enjoy the view!
@hide all
@log timeline Dusk on the terrace: a Visitor's Pass each, and the telescope. Everyone has someone in the Gaol. Checking out would free them.
narr: He went inside humming. The rest of us stayed out on the terrace until the cold drove us in, and almost nobody looked at anybody else.
@show zuzu sad left
@show nibs sad right
narr: Zuzu sat down on the terrace steps next to Nibs, close enough that their shoulders touched. Neither of them said anything.
@hide all
@show bramble sad left
@show fennel normal right
fennel[normal]: Come inside, Bramble. You'll catch your death out here, and then who would look after the chamomile?
bramble[sad]: ...it'd be all on its own... in its teacup... like the rest of us...
@hide all
think: Her light was still on when I finally went in. I checked twice.
@evening
@end
""",

	"day3": """
@card DAY 3 | The Ledger
@flag c3_day3
@bg manor_gallery_turned
@music tension
narr: The first sound on the third morning wasn't Pepper's typewriter. It was Lulu screaming.
@anim c3_portraits
narr: Every portrait in the Gallery had been turned to face the wall. Dozens of them. Only the backs showed: brown canvas, string and dust.
snapjaw[happy]: Morning, darlings! Do you like it? I call it "The Guests Have Seen Enough." I was up all night!
@show fennel angry left
fennel[angry]: Vandal! There were old masters on these walls! Probably! I hadn't finished looking at them!
@hide all
narr: Behind one of the biggest frames, where the portrait should have been, someone had pinned a sheet of old, brown paper.
narr: A plan of the house. Every floor, every room. And dotted lines running inside the walls between rooms that didn't share a door.
narr: In the corner, a tiny legend: SERVANTS' WAYS.
@show duchess normal left
duchess[normal]: Secret corridors. How very Gothic, darlings. I feel like a heroine in a novel. A rich one.
@show zuzu happy right
zuzu[happy]: hidden passages. sick. this house has backstage.
@hide all
@show pepper normal left
@sfx sp_flash
pepper[normal]: Got it. Click. For the archive.
@show bruno normal right
bruno[normal]: Bruno would not fit in a wall. Bruno does not fit in most doors.
@hide all
narr: That was about half of us. The rest were still asleep, or still in the corridor, or still screaming. Then the breakfast gong went.
@log timeline Morning: every portrait in the Gallery turned to the wall. Behind one, an old plan of the house with dotted lines marked servants' ways.
@bg manor_dining_day
@music snapjaw
narr: Breakfast was toast, jam and tea. On the table, in the middle of the toast, sat a book.
narr: Big, heavy, bound in black leather, with a brass clasp. Snapjaw sat down at the head of the table and laid one claw on it.
@show snapjaw happy center
snapjaw[happy]: My Ledger! The Gaol's intake book. Every prisoner in it, and why they're there, and who was kind enough to tell me about them.
snapjaw[normal]: Every single prisoner was handed over on someone's information. And every single informer... is sitting at this table.
@anim c3_ledger
narr: He'd read four lines out loud. Then he'd torn the rest out of the book in handfuls and stuffed them into his coat.
narr: The four pages he'd read lay among the toast crumbs. Typed lines, small and neat. Under each, the informer's name, typed in blacker, squarer letters.
@show snapjaw happy center
snapjaw[happy]: The rest I'll tuck away round the house after breakfast. And some of those lines might be forged, my darlings.
snapjaw[normal]: I won't say which. Where would be the fun in that? Snap-snap-snap!
@hide all
@log timeline The Ledger at breakfast. Read aloud: Plum Velveteen and the Dowager Puddlesworth, both Prof. N. Zuzu's mum, Pepper Q. Miss Pip, B. Thistlewood.
@log timeline The rest of the Ledger was torn out and hidden around the house. Snapjaw says some lines might be forged.
@flag c3_ledger
@music sad
narr: The Duchess picked up Plum's page with two claws, as if it might bite.
@show duchess angry farleft
duchess[angry]: Professor. Plum is nineteen.
@show nibs shock farright
nibs[shock]: I have never met your niece! I've never met anyone! I'm a chemist! I spend my days with beakers!
@show reginald angry center
reginald[angry]: My mother, sir! My MOTHER! Is that what chemists do between beakers?!
@hide all
@show zuzu angry left
zuzu[angry]: you.
@show pepper shock right
pepper[shock]: Zuzu, I swear. I swear on my press card. I have never typed your mum's name in my life. I'd remember. I'd REMEMBER.
narr: Zuzu took the page, folded it very small and walked out without a word.
@hide all
@show lulu sad farleft
lulu[sad]: ...Bramble?
@show bramble shock farright
bramble[shock]: I've never... I don't even know who... Lulu, I've never met her... I've never met anyone with a cell...
narr: Bramble snatched up her page and held it out across the table with both paws.
bramble[sad]: Professor... can you test it? Typewriters... ink... can you prove a line's forged? Please?
@show nibs normal center
nibs[normal]: Hypothetically. Handwriting, typefaces, ink. I'd need samples. From everyone. ...This afternoon, in the Library. All of you.
@hide all
@log timeline Nibs will take handwriting and typing samples from everyone this afternoon, in the Library.
snapjaw[happy]: And the Conservatory, the Marble Bath and the Attic are open, my darlings! More rooms, more hiding places! Off you pop!
@log timeline The Conservatory, Marble Bath and Attic opened.
@bg manor_hall
@music tension
narr: After that, the house came apart at the seams. Doors slammed. Drawers came out. Cushions were gutted.
narr: Lulu tore through the Music Room like a small pink storm, and wouldn't say what she was looking for.
narr: Nibs shut himself in the Library for an hour, came out with nothing in his paws, and said nothing about it.
narr: Zuzu, who wasn't speaking to anyone, came back from the kitchen with two cups of tea, put one down by Nibs's elbow, and walked off again.
narr: The Duchess went from room to room with her long scissors, slitting cushions open like fish.
@show duchess angry left
duchess[angry]: If there's another page in this house with Plum's name on it, I want it. If there's one with mine, I want it more.
@show fennel normal right
fennel[normal]: I'm hunting too. Slowly. On a crutch. If a page wants to be found by me, it will have to come and find me first.
@hide all
@bg manor_kitchen
@sfx hx_thud
narr: In the kitchen, Grub dropped a stack of plates. Then a pot. Then a spoon. Lulu ran in to help him pick them up.
@show grub angry left
grub[angry]: GET OUT OF MY KITCHEN! Out! Out out OUT!
@show lulu shock right
lulu[shock]: L-Lulu was only...
grub[sad]: ...Lulu. Love. I don't know why I... I've got a headache, that's all. My paw itches. I'm sorry. I'm so sorry.
@hide all
@bg manor_hall
narr: Pepper sat on the bottom stair with her camera in her lap. She wasn't taking pictures. For Pepper, that was the most frightening thing all day.
@show pepper sad center
pepper[sad]: I've written a thousand stories. I know what a byline is worth. Mine's on that page, and I've never seen it before in my life.
@show bruno normal farright
narr: Bruno sat down beside her, and the whole staircase creaked. He put a cup of tea in her paws.
bruno[normal]: Bruno does not think Pepper did a bad thing. Also, Pepper still owes Bruno three cakes. Bruno is keeping count.
@show lulu sad farleft
narr: Lulu came and sat on her other side, and leaned on her, and didn't say anything at all.
pepper[happy]: ...Three cakes. On the record. You'll get them, big guy. Paid in full.
@hide all
@bg manor_bath
@music daily
narr: I went to look at the Marble Bath, because I am who I am, and even on a day like this, I wanted to see it.
think: A long pool in white marble under a glass roof. Drained, dusty, and absolutely magnificent. A ten. A ten, with the water in.
narr: Bruno was down in the empty pool with a spanner, tightening a valve. He'd heard I was coming.
@show bruno happy right
bruno[happy]: Bruno is fixing the pipes. Then Mochi can have a bath. A big one.
@hide all
narr: Then Reginald came in with his foil, looking for a flat place to practise his footwork, and saw who was in it.
@show reginald normal left
reginald[normal]: ...Brawnsworth.
@show bruno normal right
bruno[normal]: Sir Reginald.
reginald[normal]: Three years, you said. On the beach.
bruno[normal]: Three years.
reginald[normal]: I have read about what armies do, you know. A Puddlesworth reads. We do not enlist.
bruno[sad]: Bruno was young. Bruno carried things, and people. Some of what Bruno did, Bruno would do again. Some of it, no.
reginald[angry]: That is not an answer.
bruno[normal]: No. It is not.
narr: Bruno went back to the valve. Reginald stood there a moment longer, then went to find somewhere else to practise.
@hide all
think: I didn't say anything. I'm not sure there was anything for me to say.
@bg manor_dining_day
@sfx chime
narr: At lunch, every screen in the house came on at once.
@anim snn_c3_3
narr: By the end of lunch, three people had asked Bruno to check the bolts on their bedroom doors.
@bg manor_library
@music daily
narr: At three, as promised, we crowded into the Library. Nibs had cleared the big desk and laid out paper, ink, and the black typewriter.
@show nibs happy center
nibs[happy]: Everyone writes this sentence by hand, and types it on the machine. The quick brown capybara jumps over the lazy caiman.
snapjaw[normal]: I heard that.
nibs[normal]: Pepper, yours on your portable too, please. And everyone can use my pen. It's broken in.
narr: He held it out. The end was gnawed to splinters. Nobody took it.
@show lulu shock farleft
lulu[shock]: EW! It's wet! Can't we use a new one?!
nibs[normal]: Absolutely not.
narr: He tapped a little box on the side table by the wall and counted out loud, one claw at a time.
nibs[normal]: Twelve. The last twelve new pens on this island. Touch them and I'll know.
@hide all
narr: So we used the inkwell and the old dip pens from the desk drawer, which were only slightly less disgusting.
@show duchess normal left
duchess[normal]: I do not type, darling. I have people for that. I shall write. Beautifully. Look at that capital T.
@show reginald normal right
reginald[normal]: My hand is my own business. I shall write it plainly. Very plainly. Plainer than usual, if anything.
@hide all
@show fennel happy left
narr: Fennel wrote his sentence in perfect copy of Nibs's own round handwriting, just to see Nibs's face, then wrote it again in his own.
fennel[happy]: Forgive me. A copyist's reflex. Give me any hand and I can do it in my sleep.
@show grub sad right
narr: Grub took the longest. He held the pen like a ladle and wrote one slow letter at a time, with his tongue between his teeth.
grub[sad]: Don't look. Nobody look. I'm a cook, not a... I cook.
@hide all
@show bruno normal left
bruno[normal]: Bruno writes big. Bruno is sorry about the paper. Bruno will sign it B. Just B. Bruno always signs B.
@show bramble sad right
bramble[sad]: ...mine's shaking... does that count... will it still work if it's shaking...
@hide all
@show zuzu normal left
zuzu[normal]: typing, fine. handwriting... my handwriting is a crime scene. don't hold it against me.
@show lulu sad right
lulu[sad]: Lulu always dots her i's with hearts. Is that allowed? Lulu doesn't know how to write without hearts.
@hide all
@sfx sp_type
narr: Pepper typed hers on her portable, quick and flat and perfect, and handed it over without a word.
narr: Nibs put every sheet into one card folder, tied the ribbon, and put his paw on it.
@show nibs normal center
nibs[normal]: This stays on this desk, and this desk stays with me. Tomorrow I'll have answers. Hypothetically. Probably.
@hide all
@log timeline In the Library, everyone wrote a sample by hand and typed it for Nibs. He counted his box of new pens aloud: twelve.
think: Everybody's afraid of that folder. I can see it on their faces. I can't tell which of them has a reason.
think: The afternoon's still young. The house is still full of pages. I could look around, or look in on someone.
@end
""",

	"night3": """
@bg manor_cloakroom
@music daily
narr: Dinner, the third night. Already the routines felt like they'd always been routines.
narr: Nibs signed the roster by the door, chewed his pen, pocketed it, hung his coat. Reginald went back for his wax twice.
narr: Tonight's laugh belonged to Zuzu, who tried to hang their earbuds on a hook by the wire, missed, and spent five minutes fishing them out of the Duchess's hat.
@show duchess angry left
duchess[angry]: Out. Out of my hat. It has its own hook for a reason, darling, and the reason is you.
@show zuzu normal right
zuzu[normal]: in my defence, your hat is the size of a satellite dish.
@hide all
@bg manor_dining
narr: Nobody sat where they'd sat the night before. Zuzu took the chair furthest from Pepper. The Duchess and Reginald took the end furthest from Nibs.
narr: Lulu sat by Grub, and Bramble sat by Fennel, and between them the table felt about a mile long.
narr: Nibs was first up, as always. Coat off the hook, pen out, chewing all the way to the door.
@show nibs normal center
nibs[normal]: Library. Samples. Don't wait up.
@hide all
@log timeline Dinner, Night 3. Nibs left first, for the Library, with his samples.
@sfx chime
@bg manor_bedroom_night
@music stop
narr: The bell at ten. The bolts. The searchlight, round and round. Tonight, for once, I fell asleep almost at once.
narr: It didn't last.
@anim c3_night3
@bg manor_hall_night
@music tension
narr: A minute later we were all out on the landing in our dressing gowns, and Nibs was standing in the Library doorway, waving an empty paw.
@show nibs angry center
nibs[angry]: The folder! My samples! I went down for a cup of cocoa, I came back, and it's GONE! Every sheet!
@log people nibs Says he left the Library for a cup of cocoa, and when he came back the folder was gone.
snapjaw[happy]: A theft! In MY house! How thrilling. I'm not getting involved. I'm on holiday.
@hide all
@show reginald angry left
reginald[angry]: Then we shall establish where everyone was! I was in my room, and asleep by half past ten, and I shall thank you not to ask how I know.
@log people reginald Says he was asleep in his room by half past ten.
@show duchess normal right
duchess[normal]: In my room, darling, lying awake. Without my sleeping powder I lie awake every night. It's lost in the wreck, along with my temper.
@log people duchess Says she was awake in her room. She has no sleeping powder.
@hide all
@show bruno normal left
bruno[normal]: Bruno was in Bruno's room. Bruno was doing push-ups. Bruno cannot sleep with the searchlight, so Bruno does push-ups.
@log people bruno Says he was in his room, doing push-ups.
@show lulu sad right
lulu[sad]: In Lulu's room. Asleep. Lulu was asleep. With the door locked. Like the rules say.
@log people lulu Says she was asleep in her room with the door locked.
@hide all
@show zuzu normal left
zuzu[normal]: attic. mapping cameras. there's a whole nest of them up there. nobody came past me. nobody i saw anyway.
@log people zuzu Says they were in the Attic, mapping cameras.
@show pepper normal right
pepper[normal]: My room. Typing up today. Somebody has to write it down, even if I'm in it. I didn't hear a thing over the keys.
@log people pepper Says she was in her room, typing.
@hide all
@show fennel normal left
fennel[normal]: I was drawing the searchlight. One cannot climb stairs on a crutch quietly, so I simply didn't. I was in my room.
@log people fennel Says he was in his room, drawing.
@show bramble sad right
bramble[sad]: ...in my room... I was asleep, I think... I had a bad dream about the prison...
@log people bramble Says she was asleep in her room.
@hide all
narr: Grub came up the stairs last, slowly, holding the banister with his good paw. He blinked at us as if he wasn't sure where he was.
@show grub sad center
grub[sad]: What's... is it breakfast? I was in the kitchen. I think. Or bed. I was somewhere. Why's everyone up?
@log people grub Says he was in the kitchen, or in bed. He wasn't sure.
@hide all
@show nibs normal center
nibs[normal]: Everyone check your things. If someone's taking samples, they might be taking pages, too.
@hide all
narr: Doors banged up and down the corridor. Then, from the far end, a sniff. Then another. Smoke. Faint, and coming from the Gallery.
@bg manor_gallery_turned
narr: In the Gallery fireplace, under the turned-round portraits, a sheet of paper had burned down to a curl of black ash.
narr: One corner hadn't caught. On it, in black, square type, half a name: ...ISTLEWOOD.
@show bramble shock center
bramble[shock]: That's mine. That's my page. Miss Pip's page. It was in my drawer... I was going to have it tested... I was going to prove...
narr: She didn't finish. She looked round at all of us, one at a time. Nobody looked back.
@hide all
@log timeline After midnight, Night 3: Nibs's folder of samples went missing from the Library desk. Bramble's page was found burned in the Gallery grate.
snapjaw[happy]: Two crimes in one night! And nobody dead! You're getting so much better at this. Back to bed, darlings!
think: Nobody went back to sleep. Not really. Everyone locked their doors, and I heard every one of them check the bolt twice.
@evening
@end
""",

	"day4": """
@card DAY 4 | Fallout
@bg manor_hall
@music sad
narr: Nobody went back to sleep after the fire in the Gallery. By six the whole house was up, and nobody was talking.
narr: Doors that had always stood open were shut. Keys turned behind people who were only going as far as the bathroom.
narr: And for the first morning since we landed, there was no typewriter. No clack-clack-clack-DING before breakfast. Just the sea.
narr: The Daily Puddle was on the notice board as usual, but it was written by hand.
narr: Neat pencil capitals between ruled lines, and a little drawing of a gull.
@show pepper sad left
pepper[sad]: Don't look at it like that. The ribbon's gone. The salt got into it on the beach, and last night it finally gave up the ghost.
pepper[normal]: So it's hand-lettered until further notice. Facts first, headlines never. Even in pencil.
@hide all
narr: Next to it, Grub's menu: a pot, a loaf, and a face that wasn't smiling today. Just a straight line for a mouth.
narr: And above everything, dead centre, a new card with a crocodile crest.
narr: AFTERSHOCK. TOMORROW, 11:05 PM.
@show snapjaw happy center
snapjaw[happy]: A night one, my darlings! Tomorrow at five past eleven, in the dark. Posted a day ahead, as promised. I am punctual.
@show reginald normal farleft
reginald[normal]: Eleven-oh-five. I shall be on watch. A Puddlesworth meets the tantrums of the earth standing up.
@show zuzu normal farright
zuzu[normal]: you'll be asleep. you're always asleep by half ten.
reginald[angry]: Resting. My. Eyes.
@hide all
@log timeline The Daily Puddle is hand-lettered today. Pepper says her ribbon has gone. A new card on the board: AFTERSHOCK, TOMORROW, 11:05 PM.
@bg manor_dining_day
@music daily
narr: Breakfast was quiet enough to hear the toast going cold.
narr: Lulu came down last, in full stage glitter.
narr: Pink on her cheeks, pink on her ears, as if she were about to walk out in front of ten thousand people.
@show lulu sad right
lulu[sad]: Lulu wears it when Lulu's scared. Miss Pip always said, if you're frightened, sparkle louder. So Lulu is sparkling. Very loudly.
@hide all
narr: She sat beside Grub. Bramble sat down at the far end, by herself, with a cup of tea she didn't drink.
narr: Fennel thumped the whole length of the table on his crutch, sat down next to her, very deliberately, and stole her toast.
@show fennel normal left
fennel[normal]: Anybody who wishes to stare at Bramble may stare at me instead. I'm far more interesting. I have a limp.
@hide all
@sfx gavel
@show snapjaw happy center
snapjaw[happy]: Good morning, criminals! Two crimes in one night, and not one confession. I'm almost proud of you.
snapjaw[normal]: So here's a treat. At ten o'clock, in this very room: the Tea-Time Tribunal!
snapjaw[happy]: A little trial, just for fun. No votes, no punishments, and nobody checks out. I bring the tea. You bring the accusations.
@show nibs normal farleft
nibs[normal]: A trial with no consequences. Statistically, that's just an argument with biscuits.
snapjaw[happy]: Exactly! My favourite kind. And at three this afternoon, the Gaol's Visiting Hour. Thirty seconds each. Don't be late.
snapjaw[normal]: The cliff path, the boathouse and the prison are open from today. Wipe your feet in my prison. I've only just had it cleaned.
@hide all
@log timeline Snapjaw called a Tea-Time Tribunal at ten, about the burned page and the missing samples. Visiting Hour at the Gaol at three.
@log timeline The cliff path, the boathouse, the prison yard and the Visiting Room opened.
think: A trial with nothing riding on it. I've got an hour. I want to see that fireplace again before anybody starts telling me what happened to it.
@bg manor_gallery_turned
@music tension
narr: The Gallery was cold and still smelled of smoke. The portraits faced the wall, as if they didn't want to be asked.
narr: In the grate, nothing was left but a flake of ash curled like a dead leaf, and the one corner that hadn't caught. ...ISTLEWOOD.
narr: The fire had never been lit. The logs were stacked, clean and dry. Only the page had burned.
@clue night3_ash
narr: Some of the ash had puffed out of the grate onto the hearth rug in a little grey fan. I knelt down beside it.
narr: Scattered over it, lying on top of the ash, was a sprinkle of bright pink glitter.
@clue night3_rug
think: Just there, by the grate. Nowhere else on the rug.
@bg manor_library
narr: Then the Library. The big desk under the tall bookcase, the green lamp, the blotter, and a mug with a cold brown skin of cocoa on it.
narr: Where the folder had been, a clean square on the blotter. Nothing else gone. The door had a bolt on the inside, and nothing was broken.
@clue night3_desk
@show nibs sad center
nibs[sad]: I went down for cocoa a little after midnight, and I didn't bolt it. Who bolts a door to fetch cocoa? Twelve minutes, I was gone. Twelve.
nibs[normal]: And here's the box of new pens on the side table, look. Twelve, still. Whoever it was, they only wanted paper.
@hide all
@log places The Gallery grate: ash, and one corner that didn't burn. Pink glitter on the hearth rug, lying on top of the ash.
@log places The Library desk: a cold mug of cocoa, and a clean square on the blotter where the folder of samples was.
@bg manor_dining_day
@music snapjaw
@anim c3_tribunal
narr: At ten, we sat round the long table in the Dining Room, with a teapot the size of a bucket in the middle of it.
narr: Snapjaw sat at the head with a pair of silver sugar tongs, which he banged on the table whenever he felt like it. Which was often.
@show snapjaw happy center
snapjaw[happy]: Order! Order! I've always wanted to say that from this end. Two crimes, my darlings.
snapjaw[normal]: One: a page from my Ledger, burned in the Gallery grate.
snapjaw[normal]: Two: the Professor's folder of samples, lifted from his desk. Both after midnight.
snapjaw[happy]: You all told me where you were. Let me read it back to you. I wrote it down. I always write it down.
@hide all
narr: He read it out, and every one of them sounded thinner in the daylight than it had at midnight.
narr: Reginald asleep by half past ten. The Duchess awake in her room. Bruno doing push-ups. Lulu asleep with her door locked. Zuzu in the Attic.
narr: Pepper typing in her room. Fennel drawing in his. Bramble asleep. Grub in the kitchen, or in bed, or somewhere.
think: It's the page at the back of my notebook. The Alibi Board. Where everyone says they were, hour by hour, and who backs them up.
think: Last night, almost nobody can back anybody up. That doesn't make any of them guilty. Mostly it means they were asleep. That's the trouble.
@show reginald angry left
reginald[angry]: Then allow me to prosecute, since nobody else has the backbone! The page named Miss Thistlewood. It lived in her drawer.
reginald[angry]: She asks for it to be tested in front of us all, and that very night it is conveniently BURNED. I say she burned it herself!
@show bramble shock right
bramble[shock]: ...I didn't... I wanted it tested... I wanted to prove it wasn't me...
@show duchess normal farleft
duchess[normal]: A very touching performance, darling. I've given several of those myself.
@hide all
snapjaw[happy]: A suspect! Lovely. A proper Splash Debate, then. Nothing rides on it, Mochi. Shoot whatever you like.
@minigame c3_tribunal
@music tension
@show lulu shock center
lulu[shock]: That's... anybody could get glitter on a rug! Lulu walks through the Gallery every day!
mochi: It's lying on top of the ash, Lulu. It landed there after the page burned.
narr: Lulu opened her mouth. Nothing came out. The glitter on her cheeks caught the light from the window.
lulu[angry]: ...FINE! Lulu burned it! Lulu went to Bramble's room after dinner, to talk, and Bramble wasn't there, and the drawer was open!
lulu[angry]: And there was Miss Pip's name, right on top, with Bramble's underneath it! So Lulu took it!
lulu[sad]: And Lulu couldn't sleep with it in the room.
lulu[sad]: So after midnight Lulu took it to the Gallery and burned it. Lulu knelt there and watched it go.
lulu[sad]: Lulu didn't want it tested. Lulu didn't want anybody testing anything. Lulu didn't want to KNOW.
@hide all
@show bramble sad left
bramble[sad]: ...Lulu... it was the only way I had to prove it... now nobody can prove anything... ever...
@show lulu angry right
lulu[angry]: Don't. Don't talk to Lulu. Not now. Not ever again.
narr: Bramble put her cup down very carefully, as if it might break, and didn't say another word.
@hide all
think: I've seen them braid each other's hair. Share a blanket on deck. That's over. I felt it go, like a plate sliding off a shelf.
@log timeline At the Tribunal, Lulu said she took Bramble's page from Bramble's room after dinner on Night 3, and burned it in the Gallery after midnight.
@log trial #tribunal_page The Tea-Time Tribunal agreed that Lulu burned Bramble's page.
@show reginald angry left
reginald[angry]: Then that settles the samples too! One thief, one night! Miss Starling took them!
@show lulu shock right
lulu[shock]: Lulu didn't! Lulu doesn't even know which drawer the Library's in!
@show zuzu normal center
zuzu[normal]: she means desk. and she's right. she gets lost in the music room, and she practically lives there.
@hide all
@show duchess angry left
duchess[angry]: And what about you, darling? The Attic sits right on top of the Library.
duchess[angry]: Down the back stairs, a quick snatch, back up to your little cameras.
@show zuzu angry right
zuzu[angry]: the attic sits on top of everything. that's what attics do. you were "lying awake". did anyone see you lie?
@hide all
@show bruno normal left
bruno[normal]: Bruno was doing push-ups. Bruno heard nothing but Bruno counting. Bruno got to four hundred and twelve. Like the steps.
@show pepper normal right
pepper[normal]: And I was typing. Ask my neighbours. Actually, don't. They'll only tell you I type too loud.
@hide all
@show reginald normal center
reginald[normal]: Then the facts are plain. Nobody saw anything, because everybody was asleep, or pretending to be.
@show duchess normal farright
duchess[normal]: Including you, Sir Reginald. Asleep at your post by half past ten, by your own account. Regular as a cuckoo.
reginald[angry]: RESTING. MY. EYES.
@hide all
@sfx gavel
@show snapjaw happy center
snapjaw[happy]: Order! The Tribunal finds that it has no idea at all who took the samples! Isn't that delicious?
snapjaw[normal]: Unsolved! I'll leave it open, so you can all go on looking at each other. Court adjourned. Do finish the biscuits.
@hide all
@log trial #tribunal_samples The Tea-Time Tribunal could not agree on who took the samples.
@show nibs normal center
nibs[normal]: Oh, never mind the samples. I lay awake all night thinking about it. I don't need them.
nibs[normal]: Look at a Ledger page. The entries are typed small and light.
nibs[normal]: The informers' names are typed big, black and square. Two faces. Two machines.
nibs[happy]: Handwriting doesn't come into it! It's typewriters. There are three on this island. I tried the Library's at dawn. Neither face.
nibs[normal]: The prison office machine, the Warden won't let me near. Which leaves one. Pepper, I'd like to rule yours out.
@show pepper sad farright
pepper[sad]: I'd hand it over this minute, Prof, but there's no ribbon. No ribbon, no sample. That's why today's Puddle is in pencil.
nibs[normal]: Then an old Puddle will do. Anything typed on it before the Ledger ever turned up.
pepper[normal]: I collected the back numbers. For the archive. Old news goes yellow if you leave it lying about. Sorry, partner.
nibs[happy]: Then I'll find a stray. There's always one. Somebody always keeps an old paper, to line a drawer or wrap a fish.
nibs[normal]: I'll be at my desk, the same as every night. Answers for everyone, soon. Hypothetically. Probably.
@hide all
narr: He went back up to the Library, chewing his pen. Several people watched him go, and none of them looked happy about it.
@log timeline Nibs says he doesn't need the samples: the informers' names are typed on a different machine from the entries. He wants an old typed Daily Puddle.
@log people pepper Says her typewriter ribbon has gone, and she collected the old Puddles for her archive.
@bg manor_dining_day
@music daily
@sfx chime
narr: Lunch was soup. At the first spoonful, every screen in the house came on at once.
@anim snn_c3_4
narr: Nobody finished their soup.
@bg manor_boathouse
@music tension
narr: At three, Snapjaw led us down the cliff path to the boathouse, where a little steam launch sat waiting with a crocodile painted on its funnel.
narr: Bruno lifted Fennel aboard like a parcel. The Duchess held her hat on with both paws, all the way across the channel.
@anim c3_visiting
@bg manor_visiting_room
@music sad
narr: A long grey room. A row of booths, a sheet of thick glass down the middle, a black telephone on either side.
narr: Thirty seconds each. Then a buzzer, and the line went dead, and a guard on the far side moved them along.
narr: Grandma was fourth in her queue. She'd done her cardigan buttons up wrong. She picked up the phone and peered at me through the glass.
narr: "Have you had a bath, pet? A proper one? You look as if you haven't had a proper bath in weeks."
mochi: Not a proper one, Grandma. The pipes...
narr: "Then go and have one. A hot one. And stop worrying about me. They give us cocoa." Then the buzzer. Then the click.
think: I'll have a bath. I promised. The best bath of my whole life, and next time I'll tell her all about it.
@show reginald normal center
narr: Sir Reginald went in with his chest out and his plume straight, and said "Mother" into the phone as if he were reporting for duty.
narr: On the other side, a very small, very old capybara in a lace collar looked him up and down, and said something short.
reginald[sad]: She said my moustache was crooked. Thirty seconds, and she spent them on my moustache.
reginald[sad]: ...It was crooked. She's always right. She has always, always been right.
@hide all
@show bramble sad center
narr: Bramble's father didn't know her at first. He held the phone the wrong way round and smiled at her politely, like a stranger at a bus stop.
bramble[sad]: ...then he knew me... right at the end... he asked whether the blue rose had opened... I said yes...
bramble[sad]: ...it didn't... it never did... but he looked so pleased... was that wrong... Mochi... was that wrong of me...
@hide all
@show grub sad center
narr: Grub's mum had a bad hip and a big voice. You could hear her through the glass without the phone.
narr: "You look peaky, love. What's wrong with your eyes? Are you drinking enough water?"
narr: At the word water, Grub flinched so hard that the phone cord snapped tight.
grub[sad]: I'm fine, Mum. I'm fine. I'm... she was still talking when it went dead. She was still talking.
grub[sad]: She always knows when I'm not right. Always has. She knew from all the way over there.
@hide all
@show duchess normal center
narr: The Duchess went last of us. Plum was nineteen and fierce-looking, with a needle stuck through her collar.
narr: She held up a tiny hat, sewn out of a pillowcase.
narr: The Duchess didn't pick up the phone.
narr: She put one claw flat on the glass, over the little hat, and kept it there for thirty seconds without a word.
narr: When the buzzer went, she straightened her own hat and walked out, and she didn't say anything at all for the rest of the afternoon.
@hide all
narr: Little Sesame bowed to Bruno through the glass, the way he'd taught her, and he bowed back so low his forehead touched it.
narr: Zuzu's mum asked if there was a radio in the house. Lulu sang Miss Pip the first line of a scale, and Miss Pip sang back the second.
narr: Fennel's sister held up a thumbnail with his face painted on it in soot. Mr. Pica, who is ninety, corrected Pepper's grammar down the phone.
narr: Fizz asked Nibs if he'd finished the radio yet. He said nearly. She said nearly was what he said about everything.
@log timeline Visiting Hour at the Gaol: thirty seconds each, through glass. Grandma told me to go and have a proper bath.
@bg manor_terrace_dusk
@music sad
narr: Nobody spoke on the launch home. At the top of the cliff path, half of us went straight to the telescope without a word, and queued for it.
narr: The Duchess and Sir Reginald stood side by side at the rail, waiting their turn, closer together than I had ever seen them stand.
@show reginald sad left
reginald[sad]: Fourteenth from the left, third from the top. If you look very hard, Duchess, you can see her moving about.
reginald[sad]: She's tidying. She always tidies.
@show duchess sad right
duchess[sad]: Plum's is on the corner. She keeps her light on to sew by. She'll ruin her eyes. I've told her a hundred times.
@hide all
narr: Nibs came up the path last of all. He looked at the two of them at the rail, and at the telescope, and went inside without taking his turn.
@show fennel normal left
fennel[normal]: Look at them. United at last, by a grudge. Nothing brings people together like somebody else to hate.
@show bramble sad right
bramble[sad]: ...don't, Fennel... he looked so tired... he looked like he wanted to say something, and couldn't think how...
@hide all
think: Lulu and Grub sat on the steps with their heads together. Bruno sat a step below them, like a wall. Zuzu wasn't there at all.
@bg manor_cloakroom
@music daily
narr: Dinner, the fourth night. Coats on the hooks.
narr: Nibs signed the roster, chewed his pen, pocketed it and hung up his coat. Reginald went back for his wax twice.
narr: Tonight's laugh was Fennel's.
narr: He hung his crutch on a hook along with his coat, out of sheer habit, and was left standing on one leg a yard from the table.
@show fennel sad left
fennel[sad]: Nobody move. I have become a flamingo. A flamingo in mourning for its crutch.
@show bruno happy right
narr: Bruno picked him up under one arm and carried him to his chair. Fennel waved to us all the way, like royalty.
@hide all
@bg manor_dining
narr: Nobody talked much. Nibs went up first, as always: coat off the hook, pen in his mouth, chewing all the way to the door.
@bg manor_kitchen
narr: After dinner, a smell came out of the kitchen that nobody could put a name to. Somewhere between a bakery and a house fire.
@show pepper happy left
pepper[happy]: Bruno! In here! Close your eyes. No peeking. On the record: Pepper Quill pays her debts.
@show bruno shock right
narr: On the table sat three cakes. One was flat, one was burnt down one side, and one leaned like the clock tower. Each had a B on top, in jam.
pepper[normal]: Lemon, chocolate, and the third was going to be lemon too, but it had its own ideas. Grub only shouted at me twice.
bruno[happy]: ...Bruno will eat all three. Now. Before anybody can say they are bad.
narr: He did. Every crumb. Grub leaned in the doorway with his arms folded, wincing at the state of his bread oven, and didn't say a word.
pepper[happy]: Paid in full, big guy.
bruno[happy]: Paid in full. Bruno will remember. Bruno does not need it written down.
@hide all
narr: Lulu stayed behind to help Grub with the washing up. She was the only one he ever let near his sink.
@log timeline Pepper baked Bruno the three cakes she owed him. He ate all three.
think: Three cakes, and for ten minutes everybody in that kitchen forgot about the Ledger. Ten minutes. I'll take it.
@end
""",

	"night4": """
@bg manor_bedroom_night
@music stop
@sfx chime
narr: The bell at ten. The bolts. The searchlight, round and round. I turned my key and checked it twice, like everybody else.
narr: Somewhere around two in the morning, the whole house woke up at once.
@anim c3_night4
@bg manor_corridor
@music tension
narr: Lulu's door stood wide open. Lulu was out in the corridor in her nightie, pressed flat against the opposite wall, screaming.
narr: In her doorway stood Grub. Just stood there, in his apron, swaying a little, with his bad paw hanging at his side.
narr: His mouth was open. There was a long string of drool on his chin. His eyes weren't looking at anything at all.
@show lulu shock left
lulu[shock]: He was STANDING over Lulu! Lulu woke up and he was just standing there, over the bed, not saying anything!
@show grub shock right
grub[shock]: What... where... Lulu? Why am I... this isn't my room. Is it? Lulu, love, why are you screaming?
@hide all
@show bruno normal center
narr: Bruno got there first.
narr: He put himself between them without touching either of them, and spoke very softly, the way you talk to a frightened horse.
bruno[normal]: Grub. It is Bruno. You are in the wrong room. Bruno will take you to the right one. Come.
@hide all
@show grub sad center
grub[sad]: I don't remember getting up. I don't remember the stairs. I was in the kitchen, and then... Lulu, I'd never. You know I'd never.
@hide all
narr: Bruno walked him back down the corridor, one big paw on his shoulder. Grub kept looking back. Lulu didn't look at him once.
@show lulu sad center
lulu[sad]: Lulu always leaves her door unlocked. In case anybody needs Lulu in the night. Lulu thought that was a nice thing to do.
lulu[sad]: Not any more.
@show bramble sad right
bramble[sad]: ...Lulu... if you don't want to be on your own tonight... my door's just there...
lulu[sad]: Lulu will manage. Lulu always manages.
@hide all
@show fennel normal left
fennel[normal]: I heard the scream from the far end, and I'm told I got here in record time for a man with one leg. Four minutes. A personal best.
@hide all
@show zuzu normal left
zuzu[normal]: everybody lock your doors. i mean it. even you, reggie.
@show reginald normal right
reginald[normal]: I was awake throughout, naturally. On watch. I simply arrived after the screaming. Which is when a watchman is most needed.
@hide all
narr: Up and down the corridor, keys turned. Bolts went across. Then a chair went under somebody's door handle, and then another.
think: Grub. Grub, who feeds everyone. I keep telling myself it's the fever. People do strange things with a fever.
think: Lulu trusted him more than anyone in this house. Now she's going to sleep with a chair against her door.
@log timeline Night 4, about 2 AM: Lulu woke to find Grub standing over her bed. He said he didn't remember getting up. Bruno took him back to his room.
@log people grub Says he doesn't remember getting up, or the stairs. The last thing he remembers is the kitchen.
@log people lulu Says she always used to leave her door unlocked, in case somebody needed her in the night.
@evening
@end
""",

	"day5": """
@card DAY 5 | Everyone Careful
@flag c3_day5
@bg manor_corridor
@music tension
narr: In the morning there were chairs under half the door handles in the Bedroom Wing, and the other half had been bolted so hard they stuck.
narr: People came down to breakfast in twos. Nobody had planned it. Nobody wanted to be the one who walked in alone.
@bg manor_dining_day
@music daily
@show grub sad center
narr: Grub stood at the end of the table with a tray of eggs, and didn't put it down until Lulu looked at him. She didn't.
grub[sad]: I'm sorry, Lulu. I'm so sorry. I'll sleep in the kitchen. I'll tie myself to the range. Reginald can lend me his rope.
@hide all
@show bruno sad left
narr: Bruno unwound the bandage on Grub's paw right there at the table. Underneath, the bite had gone an angry purple, hot to look at.
bruno[sad]: This is not good, Grub. Bruno does not like this. Grub must rest today. No stairs. No big pots.
@show grub angry right
grub[angry]: Rest! And who's cooking, then? You? You burn water, Bruno. I've watched you do it.
@hide all
narr: Nibs watched the bandage come off and went very quiet. He started to chew his pen, and then he stopped.
narr: Everybody had a plan for being careful. Reginald had ruled a new column on his roster, headed DOORS, and was ticking it as people came in.
@show reginald normal left
reginald[normal]: Bolted, Duchess? Tick. Bolted, Brawnsworth? Tick. Bolted, Miss Starling? Chair under the handle? Tick, and a commendation.
@show zuzu normal right
zuzu[normal]: i rigged a bell on my door. a spoon and a bit of wire. if anyone opens it in the night, it goes tink, and i wake up and scream.
@hide all
@show duchess normal left
duchess[normal]: I slept with my scissors under the pillow, darlings. Open. I shall have to buy a new pillow. I shall have to buy a new everything.
@show fennel normal right
fennel[normal]: I drew everyone coming in to breakfast this morning. You all came in twos. It looks like the end of a very sad ark.
@hide all
@show snapjaw happy center
snapjaw[happy]: Morning, my careful little things! Salvage day! The Mudlark's open, so pop down and pick her clean.
snapjaw[normal]: And the Generator Room, below the kitchens. That's what keeps your lights on. At five past eleven tonight it'll trip. It always does.
snapjaw[happy]: You'll have a little while in the dark. Do behave in it. My cameras can't see in the dark either. Well. Mostly.
@show bruno normal farright
bruno[normal]: Bruno will sit with the generator tonight. Bruno does not sleep much now anyway. When it trips, Bruno will start it again.
snapjaw[normal]: Suit yourself, big one. Mind the moving parts. Some of them are mine.
snapjaw[happy]: Oh, and I turned my wardens in the Gallery back round last night. Two days facing the wall is plenty. They'd started to sulk.
@hide all
@log timeline The Mudlark wreck and the Generator Room opened. Snapjaw says the generator will trip at 11:05 tonight, in the aftershock.
@log timeline Snapjaw says he turned the Gallery portraits back round to face the room in the night.
@log people bruno Says he'll sit with the generator tonight, and start it again when it trips.
@bg manor_shore
@music daily
@sfx qk_gulls
narr: Down the four hundred and twelve steps...
narr: ...and across the sand to where the Mudlark lay on her side with her one good smokestack pointing at the sky.
narr: Fennel stayed at the top of the cliff with his sketchbook.
narr: A man on a crutch, he said, had no business on a ladder, and the wreck looked better from up there.
narr: Everyone else climbed in through the hole in her side and scattered through the tilted corridors like hermit crabs.
@show zuzu happy left
zuzu[happy]: the radio room's dry. the radio room is DRY. i'm taking everything that isn't nailed down, and some of what is.
@show reginald normal right
reginald[normal]: I am retrieving the ship's bell. A watch must be rung. One cannot keep a proper watch with a pocket watch and good intentions.
@hide all
@show pepper happy left
pepper[happy]: My darkroom chemicals! Developer, fixer, and a tray with only one crack.
pepper[happy]: I can develop my own rolls again. The Gallery cupboard will do nicely.
@show bramble normal right
bramble[normal]: ...the ship's geraniums... in the captain's cabin... they're still alive... nobody watered them for a week and they're still alive...
bramble[happy]: ...I'm taking them up to the Conservatory... they can keep the chamomile company...
@hide all
@show duchess normal center
duchess[normal]: Three hatboxes, darlings, and a parasol. One must be ready for any weather, including the end of the world.
@hide all
@bg manor_wreck
narr: I found Grub in the infirmary with Lulu and Nibs. It was strange to be back. The cot was still there. Marigold's cap wasn't.
@show grub sad center
grub[sad]: I tidied in here, after. Couldn't bear all her things just lying about. Put the lot in her locker. Cap, clipboard, her lavender soap.
grub[normal]: And that silver tin of the Duchess's. The powder Marigold took off her. Felt wrong to leave it on the side, and wrong to throw it out.
@show lulu sad farleft
lulu[sad]: Lulu misses her. She used to make Lulu drink water, and Lulu hated it. Lulu would drink a whole bucket now, if she asked.
@hide all
@show nibs normal right
narr: Nibs had found Marigold's shelf of medical books, fat and wavy from the sea, and was turning the pages of one very carefully.
narr: He stopped at a page with a drawing of a bat on it. He read it. He looked across the room at Grub's paw. Then he closed the book.
nibs[normal]: I'll read the rest later. At my desk, with a proper light. Statistically... no. I'll read it later.
@hide all
think: The Duchess ought to know her powder's down here. She hasn't slept properly in a week, and she's let everybody know it.
@bg manor_shore
narr: On the way back across the beach, the tide had come in a little, and a thin sheet of sea lay between us and the bottom step.
narr: Everyone splashed through it without thinking. Except Grub, who stopped dead at the edge with his pots in his arms, and wouldn't go on.
@show grub sad center
grub[sad]: I can't. I can't put my feet in it. It's only water. I know it's only water. I can't.
@show bruno normal right
bruno[normal]: Then Grub will not. Bruno will carry Grub, and Grub will carry the pots. It is a good system.
@hide all
narr: He did, all the way across and up the first forty steps, with Grub clutching his pots and staring at the sea over Bruno's shoulder.
@bg manor_cliff_path
narr: The Duchess was at the top of the steps, sitting on a hatbox to get her breath back, fanning herself with a glove.
@show duchess normal center
duchess[normal]: My powder? In the nurse's locker? Down four hundred and twelve steps, which I have just this minute come up? Tomorrow, darling.
duchess[happy]: Tomorrow I shall send Bruno down with a list. Tonight I shall lie awake and be brave about it.
@hide all
@log timeline Salvage at the Mudlark. Grub says he put Marigold's things in her locker in the infirmary, with the Duchess's powder tin.
@log places The Mudlark's infirmary: Marigold's locker, and a shelf of her medical books, swollen from the sea.
@bg manor_dining_day
@sfx chime
narr: Lunch. Every screen in the house came on right on cue, as if it had been waiting for our soup to go cold.
@anim snn_c3_5
narr: Somebody laughed. Then nobody did.
think: An afternoon to ourselves. Doors locked, everyone careful. I could look in on somebody. I'd better make it count.
@end
""",

	# Free Time. One step per day (main.gd FREETIME_STEPS, chapters.gd "freetime_slots"); the day scripts set flags
	# c3_day2 / c3_day3 so these can tell the days apart. Everyone can be visited again each day.
	"freetime_intro": """
@if c3_day5 -> d5
@if c3_day3 -> d3
@if c3_day2 -> d2
@bg manor_hall
@music daily
@card FREE TIME | Day 1
think: Free time until supper. The house is enormous, and everyone's already scattered through it like spilled bath beads.
think: Some of them are hurt, all of them are frightened, and none of them will say so. I've got time for *two visits*.
@end
@label d2
@bg manor_hall
@music daily
@card FREE TIME | Day 2
think: Free time until the aftershock. Everyone's off poking around the rooms that opened this morning.
think: The card on the notice board says 3:10. That leaves time for *three visits*, if I'm quick.
@end
@label d3
@bg manor_hall
@music tension
@card FREE TIME | Day 3
think: Free time, of a sort. The house is still full of torn-out pages, and half of us are still hunting for them.
think: If I come across one, I could read it. Whether I should is another question. I've got time for *two visits*.
@end
@label d5
@bg manor_hall
@music tension
@card FREE TIME | Day 5
think: Free time. The house is all locked doors and careful faces. Everybody's sitting where they can see the way out.
think: At half past four I've promised to help Grub in the kitchen. Until then, I've got time for *two visits*.
@end
""",

	"freetime_outro": """
@if c3_day5 -> d5
@if c3_day3 -> d3
@if c3_day2 -> d2
@bg manor_hall_night
@music stop
narr: The sun went down over the sea. Across the bay, the prison lit up window by window, like a ship that would never sail.
narr: Then every screen in the house blinked on at once. Even the old television in the hall, which wasn't plugged in.
@anim snn_c3_1
think: ...Supper. I'm going to go and have supper and not think about any of that.
@end
@label d2
@bg manor_hall
@music stop
narr: By three o'clock the whole house had drifted back to the Grand Hall. Nobody said why. Everybody kept glancing at the clock.
@end
@label d3
@bg manor_corridor
@music stop
narr: The light went orange, then grey. Doors closed one by one along the Bedroom Wing, and a key turned in every one of them.
think: Dinner soon. The third night. I wonder how many of us will sit where we sat last night.
@end
@label d5
@bg manor_hall
@music stop
narr: The clock over the stairs struck the half hour. Half past four. Somewhere below, a ladle was already rattling against a pot.
think: The kitchen. I promised Grub.
@end
""",

	# Each guest has a short arc over up to three visits (flags <id>_ft1, _ft2, _ft3), whatever the day.
	# The background follows where they spend that day's Free Time (rooms3.gd FREE_BY_DAY).
	"hangout_bramble": """
@if c3_day3 -> w3
@if c3_day2 -> w2
@bg manor_shore
@jump go
@label w2
@bg manor_terrace
@jump go
@label w3
@bg manor_conservatory
@label go
@music daily
@if bramble_ft3 -> d
@if bramble_ft2 -> c
@if bramble_ft1 -> b
@show bramble happy center
narr: Bramble was kneeling over a row of chipped flowerpots she'd found somewhere, moving her chamomile out of its teacup with a spoon.
bramble[happy]: ...Mochi... look... roots... it put down roots in a teacup, in a flood... I think it's earned a proper pot...
@ifnot c3_ledger -> a1
bramble[sad]: ...I keep looking at it so I don't have to look at anyone... is that silly... it's the only thing here that hasn't changed...
@label a1
mochi: What are you going to grow here?
bramble[normal]: ...herbs for Grub's kitchen... thyme, sage, a bit of mint... he's cooking for eleven with one good paw... it's the least I can do...
bramble[sad]: ...but there are rats... I saw one by the bins... and Snapjaw's tins everywhere, with those horrid little crossed-out eyes...
bramble[normal]: ...I don't like poison... but I don't like rats in Grub's flour either... sometimes a gardener has to be a bit cruel, for the garden's sake...
bramble[happy]: ...Grub says I can have the bit of garden by the kitchen door... as long as there's mint... he's very particular about mint...
narr: She patted the soil down round the chamomile, very gently, like tucking someone into bed.
bramble[happy]: ...there... it's home now... come and visit it whenever you like... it likes company...
@flag bramble_ft1
@jump done
@label b
@show bramble normal center
narr: Bramble was writing a letter on the back of a seed packet, in tiny careful letters, one at a time.
bramble[normal]: ...it's to Dad... I know I can't send it... I write him one every week anyway... I have since I left home...
bramble[happy]: ...he grows roses nobody else can... a blue one, once... well, nearly blue... he cried when it opened...
@ifnot c3_ledger -> b1
bramble[sad]: ...they told me he'd gone into a home... and all this time he's been over there... with a light that goes off at midnight...
@label b1
mochi: What do you tell him in the letters?
bramble[happy]: ...the weather... what's flowering... that I'm eating properly... the usual lies...
bramble[normal]: ...and about all of you... he'd like Bruno... he likes anyone who can lift a wheelbarrow with one paw...
think: She folded the seed packet in half and tucked it in her apron, next to all the others. There must have been fifty of them.
@flag bramble_ft2
@jump done
@label c
@show bramble sad center
narr: Bramble had sanded Fennel's crutch smooth and was rubbing beeswax into it with a rag, round and round.
bramble[normal]: ...he keeps getting splinters... he makes such a fuss... so I'm fixing it... he's my friend... he's still my friend...
bramble[sad]: ...Lulu won't look at me... I'd never even heard of Miss Pip until breakfast, Mochi... never...
bramble[sad]: ...can I tell you something... I wrote a letter once... not a kind one... to the council... I didn't sign it...
bramble[sad]: ...Dad was getting forgetful... leaving the gas on... I thought they'd help... they moved him... he never knew it was me...
bramble[sad]: ...that's why my paw shook in the Library... if Nibs puts my writing next to that letter... everyone will know what I did...
think: She went back to the crutch, round and round with the rag. She didn't ask me not to tell. I don't think she'd thought of it.
@flag bramble_ft3
@jump done
@label d
@show bramble sad center
narr: Bramble was on her knees by the door to the kitchen garden in her gardening gloves, pushing something into a crack in the step with a trowel.
bramble[sad]: ...Snapjaw's bait... from the tin in here... I hate it... the lid has a little dead rat on it, with crosses for eyes...
bramble[sad]: ...but they've got into Grub's flour now... and Grub isn't well... I want his kitchen clean for him, for when he's better...
bramble[normal]: ...a gardener has to be a bit cruel sometimes... Dad used to say that about slugs... he always said sorry to them first...
mochi: Did you get to talk to him? Yesterday, at the Gaol?
bramble[sad]: ...he asked about the blue rose, and I lied... Lulu won't speak to me...
bramble[sad]: ...Fennel brings me tea and doesn't ask me anything... he's the only one left...
narr: She peeled the gloves off inside out, very carefully, and folded them into her apron pocket.
bramble[normal]: ...the moonflowers open tonight, after dinner... come and see, if you like... nobody ever watches the moonflowers...
@flag bramble_ft4
@label done
@hide all
@flag hung_bramble
@skill deep_roots
@end
""",

	"hangout_bruno": """
@if c3_day5 -> w5
@bg manor_shore
@jump go
@label w5
@bg manor_cliff_path
@label go
@music daily
@if bruno_ft3 -> d
@if bruno_ft2 -> c
@if bruno_ft1 -> b
@show bruno happy center
narr: Bruno was coming up from the wreck with a crate on each shoulder and a third balanced on his head.
bruno[happy]: Mochi! Bruno is bringing up the useful things. Tins. Rope. Blankets. Four hundred and twelve steps. Bruno counts every one.
@ifnot c3_ledger -> a1
bruno[sad]: Carrying is good today. When Bruno's paws are full, Bruno's head is quiet.
@label a1
@choice What should I say?
> Let me help carry something. -> a_help
> Don't you ever get tired? -> a_tired
@label a_help
narr: He set the smallest crate in my arms. I nearly went over backwards. He caught me, crate and all, with one paw.
bruno[happy]: Next time, Bruno will give Mochi a smaller crate. A crate for ants.
@jump a_end
@label a_tired
bruno[normal]: Bruno gets tired. Then Bruno sits on the step and eats something. Then Bruno is not tired. It is a good system.
@label a_end
@if c3_day5 -> a5
bruno[happy]: Also, Pepper owes Bruno three cakes. Bruno is not in a hurry. Bruno is only counting. Like the steps.
@jump a6
@label a5
bruno[happy]: Also, Pepper paid Bruno three cakes yesterday. Bruno ate them all. Bruno is still counting the crumbs.
@label a6
bruno[normal]: Bruno counts everything. Steps. Crates. People. Bruno counted eleven on the beach, then counted again, to be sure.
think: He went off up the cliff path with all three crates, humming. The steps creaked under him the whole way.
@flag bruno_ft1
@jump done
@label b
@show bruno normal center
narr: Bruno sat on an upturned crate with the green first-aid box open on his knees, rolling bandages into neat little wheels.
bruno[normal]: Bruno is making more bandages. Grub's paw needs a new one every morning. It is hot, Mochi. Too hot. Bruno does not like it.
bruno[sad]: Grub says it is nothing. Grub says it is only itchy. Grub is Bruno's friend. Bruno will look after Grub's paw.
mochi: Is Grub all right, do you think?
bruno[normal]: Grub is tired. Grub is cooking for eleven. Everyone is tired. ...Bruno will watch him. Bruno is good at watching.
narr: He held up a finished roll. It was perfectly round. He looked at it the way other people look at photographs.
bruno[happy]: Bruno's sister taught Bruno bandages. She said, Bruno, big paws must learn small things. Bruno is still learning.
@flag bruno_ft2
@jump done
@label c
@show bruno normal center
narr: Bruno was writing a letter, which took a long time, because his pen was very small and his paw was very big.
bruno[normal]: Little Sesame's family. Her mother has three other little ones. So for a long time, Bruno has sent them money.
bruno[normal]: Bruno sends it under another name. A made-up one. So they don't feel they owe Bruno anything. Nobody should owe Bruno.
bruno[sad]: That is why Bruno did not want to write for Nibs. If someone puts Bruno's writing next to the letters, they will know.
bruno[sad]: And now there are pages. And names on pages. Bruno does not want his name on anything.
think: He signed the letter with one big careful B and folded it twice. There was nowhere to send it. He put it in his pocket anyway.
@flag bruno_ft3
@jump done
@label d
@show bruno normal center
narr: Bruno was halfway up the cliff path with a crate on his shoulder, resting on a step. He moved over so I could sit down too.
bruno[normal]: Bruno is carrying the last of the wreck up. Rope, lamp oil, a box of tins with no labels.
bruno[normal]: Grub says tins with no labels are an adventure.
bruno[sad]: Grub is not well, Mochi. Bruno has seen fevers. Bruno has seen bites. Bruno does not like the way Grub looks at water.
bruno[normal]: If anybody blames Grub for anything, Bruno will stand in front of him.
bruno[normal]: Bruno is very wide. It is the one useful thing about being Bruno.
mochi: You're a good friend, Bruno.
bruno[happy]: Bruno had three cakes yesterday. Bruno is a very full friend. ...They were bad cakes.
bruno[happy]: Do not tell Pepper. They were the best bad cakes in the world.
narr: He stood, lifted the crate as if it were a hatbox, and went on up the steps, counting under his breath.
narr: Two hundred and six. Two hundred and seven.
@flag bruno_ft4
@label done
@hide all
@flag hung_bruno
@skill iron_hide
@end
""",

	"hangout_duchess": """
@if c3_day3 -> w3
@bg manor_dining_day
@jump go
@label w3
@bg manor_music
@label go
@music daily
@if duchess_ft3 -> d
@if duchess_ft2 -> c
@if duchess_ft1 -> b
@show duchess normal center
narr: The Duchess had taken down a pair of velvet curtains and was cutting them into something with long, terrifying scissors.
duchess[happy]: These curtains have been begging to be a gown for a hundred years, darling. I am simply answering the call.
@ifnot c3_ledger -> a1
duchess[sad]: And if I stop cutting, I shall have to think. So I shan't stop.
@label a1
mochi: That's a magnificent hat, by the way.
duchess[happy]: Isn't it? Lilac silk, and an ostrich feather. The feather has its own weather. It once put out a candle across a ballroom.
duchess[normal]: I don't sleep, you know. Not without my powder. One pinch a night, since I was a girl. Marigold kept it in her cabinet on the ship.
duchess[sad]: And now it's in that wreck, under the gulls. So I lie awake all night, getting sharper and sharper, like these scissors.
narr: Snip. A curtain became a sleeve.
duchess[happy]: There. Nobody likes me sharp, darling. Luckily, I look divine.
@flag duchess_ft1
@jump done
@label b
@show duchess normal center
narr: The Duchess was stitching a tiny hat, no bigger than a teacup, out of the curtain scraps.
duchess[normal]: For my niece. Plum. I made her first hat when she was four. It had a cherry on it. She wore it to bed.
@ifnot c3_ledger -> b1
duchess[sad]: They took her two winters ago. And this morning a book told me that dreadful little chemist was the one who told them where to look.
duchess[angry]: Hypothetically, he says. I'll give him hypothetically.
@jump b2
@label b1
duchess[normal]: She's apprenticed to a milliner now. Or she was. She sews the most beautiful buttonholes in the world.
@label b2
mochi: She sounds lovely.
duchess[happy]: She's impossible, darling. She argues with mirrors. She's the only creature alive who ever made me laugh at a funeral.
narr: She held the little hat up to the light, turned it, and put it away in her hatbox without finishing it.
@flag duchess_ft2
@jump done
@label c
@show duchess sad center
narr: The Duchess sat very straight, holding a stack of her own handwriting from the Library, and didn't look at me when I came in.
duchess[sad]: I wrote to him, darling. The Warden. Every year on Plum's birthday. Begging. On my very best paper.
duchess[sad]: Three letters. Twelve pages each. I said things a Velveteen never says. He never answered.
duchess[angry]: And now that chemist wants my handwriting. If he holds it up next to those letters, everyone will know I begged.
duchess[normal]: I would rather be eaten. Don't look at me like that. It's a perfectly reasonable position.
duchess[sad]: And if you ever meet my Plum, darling, you will not tell her that her aunt begged. Promise me.
@flag duchess_ft3
@jump done
@label d
@show duchess normal center
narr: The Duchess had Lulu's costume on the dress form and was walking round and round it with a mouthful of pins, glaring at the hem.
duchess[normal]: Mmf. Don't speak, darling, I'll swallow one. ...There.
duchess[normal]: Lulu's gown, for a concert she says she'll give to cheer us all up. Heaven help us.
duchess[sad]: Thirty seconds, yesterday. Do you know how long thirty seconds is, when you can't trust your own voice? A year. A whole year.
duchess[sad]: Plum made that little hat out of her pillowcase. I taught her that stitch. She was showing me she still remembers it.
mochi: Did anyone fetch your powder from the wreck?
duchess[normal]: Tomorrow. I am a woman of my word, and my word was tomorrow. Tonight I shall pin that child into a gown and not sleep, as usual.
duchess[angry]: And I shall not think about that chemist. Not once, all evening. You can see how well it's going.
@flag duchess_ft4
@label done
@hide all
@flag hung_duchess
@skill poise
@end
""",

	"hangout_fennel": """
@if c3_day3 -> w3
@if c3_day2 -> w2
@bg manor_shore
@jump go
@label w2
@bg manor_terrace
@jump go
@label w3
@bg manor_conservatory
@label go
@music daily
@if fennel_ft3 -> d
@if fennel_ft2 -> c
@if fennel_ft1 -> b
@show fennel normal center
narr: Fennel was propped on his crutch with a sketchbook against his chest, drawing fast in charcoal and groaning between lines.
fennel[sad]: Mochi. Witness my suffering. Every stroke costs me. I am a martyr to art and to a cracked shin.
@ifnot c3_ledger -> a1
fennel[normal]: And to this house, which has grown very quiet since breakfast. Quiet is terrible for an artist. You can hear yourself think.
@label a1
narr: He turned the book round. Little drawings in strips, like a comic: the beach, the climb, Grub's soup, Lulu asleep on a stair.
fennel[normal]: I draw everything. Small, quick, in rows, every scene of the day. It's my diary. I don't trust words. Words lie. Charcoal can't be bothered to.
@choice What should I say?
> Can I be in one? -> a_me
> They're really good. -> a_good
@label a_me
fennel[happy]: You're in eleven of them. You always look as if you're about to recommend a bath. It's very restful.
@jump a_end
@label a_good
fennel[happy]: I know. But thank you. One so rarely hears it from someone with taste.
@label a_end
@flag fennel_ft1
@jump done
@label b
@show fennel normal center
narr: Fennel was copying a painting on a tiny square of card, a face no bigger than my thumbnail.
fennel[normal]: My sister Saffron taught me this. Miniatures. Faces for lockets. I copied every stroke of hers until I could copy anyone's.
fennel[happy]: Any hand, any brush, any signature. Give me five minutes. It's a gift. It is also, I'm told, a crime in several countries.
@ifnot c3_ledger -> b1
fennel[sad]: Saffron is over there now, behind one of those lights. And somewhere in this house there's a page with her name, and somebody else's under it.
@label b1
mochi: Have you ever copied something you shouldn't have?
fennel[happy]: A cheque, once. My own. I couldn't believe I'd really been paid that much. The bank agreed with me.
think: He put the card away before I could see whose face it was.
@flag fennel_ft2
@jump done
@label c
@show fennel sad center
narr: Fennel was sitting still for once, crutch across his knees, watching Bramble on the far side of the room without drawing her.
fennel[normal]: Bramble is the only person I have ever met who has never once asked me for anything. Not a portrait. Not a favour. Not even a compliment.
fennel[sad]: This morning I watched Lulu look at her as if she were a stranger. I have never wanted to throw a crutch at anyone more.
fennel[normal]: If I ever found anything in this house that would hurt her, Mochi, I'd paint it over. And I'd sign somebody else's name to the paint.
think: He laughed when he said it. I'm not sure it was a joke.
@flag fennel_ft3
@jump done
@label d
@show fennel normal center
narr: Fennel was painting, for once, instead of drawing.
narr: A tiny square of card, the smallest brush I've ever seen, and his tongue between his teeth.
fennel[normal]: Saffron painted my face on her thumbnail yesterday, in soot. Soot, Mochi. I've spent all morning failing to do half as well in paint.
fennel[sad]: I found something in this house, the other day. A page. I did what I told you I'd do.
fennel[sad]: I won't tell you what it said. There's a little less of it now.
mochi: Fennel...
fennel[happy]: Shh. Art is mostly knowing what to leave out. Tonight, the moonflowers, with Bramble.
fennel[happy]: She thinks nobody ever watches them. I intend to prove her wrong.
@flag fennel_ft4
@label done
@hide all
@flag hung_fennel
@skill artists_eye
@end
""",

	"hangout_grub": """
@bg manor_kitchen
@music daily
@if grub_ft3 -> d
@if grub_ft2 -> c
@if grub_ft1 -> b
@show grub happy center
narr: The kitchen smelled of onions and bay leaves. Grub was at the range with three pots going and his bandaged paw tucked into his apron.
grub[happy]: Mochi! Come in, come in, taste this. Careful, it's hot. Don't tell my mum I said it, but that might be the best stock of my life.
@ifnot c3_ledger -> a1
grub[sad]: Somebody's got to keep cooking. If I stop cooking, I'll start thinking, and I'm a terrible thinker. Ask anyone.
@label a1
narr: There was a shelf of old cookbooks over the range, fat and greasy and stuck together. He hadn't opened a single one.
grub[normal]: Books? No, love. I cook by nose. Books are for people who sit still. Mum never used a book in her life.
grub[normal]: Paw itches something rotten, mind. Bruno says leave it. Bruno's very bossy for someone who can't boil an egg.
narr: He stirred, sniffed, frowned, stirred again, and gave me a spoonful. It was perfect. It always was.
@flag grub_ft1
@jump done
@label b
@show grub normal center
narr: Grub was sitting down at the kitchen table, which I had never once seen Grub do while anything was on the stove.
grub[normal]: Just resting the legs. Bit of a headache. Bit hot. It's the range, I expect. Eight burners. Like cooking inside a dragon.
grub[happy]: Be a love and fetch me a jug of water from the pump? I don't fancy the pump today. Don't know why. Don't fancy it.
narr: I fetched it. He didn't drink it. He pushed it to the far end of the table, and kept glancing at it, as if it might move.
@ifnot c3_ledger -> b1
grub[sad]: Everybody's shouting about pages. I've not even looked for one. What would I do with a page? I'm a cook.
@label b1
@flag grub_ft2
@jump done
@label c
@show grub sad center
narr: Grub was sitting on the floor by the range with a ladle in his paw, very still, staring at nothing.
grub[sad]: Mum taught me to cook. Couldn't read a word, my mum. Neither can I, much. That's the secret. Don't tell anyone.
grub[sad]: She used to say: Grub, love, a cook who can't read can still feed a whole town. And I did. I fed everyone.
grub[angry]: And then he wants SAMPLES. Writing! In front of everybody! Like I'm at school! Like I'm STUPID!
narr: He threw the ladle. It hit the dresser and clattered to the floor, and he stared at it as if somebody else had thrown it.
grub[sad]: ...Sorry. Sorry, Mochi. I don't know where that came from. I've never thrown a ladle in my life. Mum'd skin me.
@flag grub_ft3
@jump done
@label d
@show grub sad center
narr: Grub was sitting by the range next to a pot that had stopped bubbling some time ago. He didn't seem to have noticed.
grub[sad]: Mochi. Sit with me a bit? I don't like being on my own today. Things go missing when I'm on my own. Time, mostly.
grub[sad]: Mum said I looked peaky. Through all that glass, she said it. She always knows. Even when I was little and hid it under my hat.
grub[angry]: And then I go and stand over poor Lulu like a... like a... I don't even know what I was like. Nobody will tell me.
grub[sad]: If I go funny again, love, you hit me with a pan. The big one. I mean it. I'd sooner have a bump on the head than frighten anybody else.
narr: He laughed, and then he stopped laughing, and looked at the pump by the sink for a long time.
@flag grub_ft4
@label done
@hide all
@flag hung_grub
@skill comfort_food
@end
""",

	"hangout_lulu": """
@if c3_day2 -> w2
@bg manor_terrace
@jump go
@label w2
@bg manor_music
@label go
@music daily
@if lulu_ft3 -> d
@if lulu_ft2 -> c
@if lulu_ft1 -> b
@show lulu normal center
narr: Lulu was trying to write a song. She had a pencil, a page of crossed-out lines, and a very determined frown.
lulu[sad]: Lulu wants to write something happy for everyone. But every time Lulu opens her mouth, the hum comes out instead.
narr: She hummed it for me. The tuneless little song from the ship. It went round and round and never landed anywhere.
@ifnot c3_ledger -> a1
lulu[sad]: It's worse since breakfast. It's like it knows something Lulu doesn't.
@label a1
@choice What should I say?
> Maybe it's a song that isn't finished yet. -> a_fin
> Hum it with me. -> a_hum
@label a_fin
lulu[happy]: Ooh. A song that's waiting for its ending! That's so Lulu. Lulu's going to write that on her hand.
@jump a_end
@label a_hum
narr: We hummed it together. It sounded slightly less lost with two of us. Only slightly.
@label a_end
lulu[happy]: Lulu's first teacher used to say: if you can't sing, breathe. If you can't breathe, smile. If you can't smile, have a biscuit.
@flag lulu_ft1
@jump done
@label b
@show lulu sad center
narr: Lulu was putting on lip balm for the fourth time in a minute, without a mirror, staring at the floor.
lulu[sad]: Mochi. Can Lulu tell you a secret? A tiny one. A long, long time ago, before Lulu was famous...
lulu[sad]: A reporter bought Lulu a strawberry milkshake. Lulu was so excited somebody wanted to listen. And Lulu talked and talked.
lulu[sad]: About everyone. Lulu doesn't even remember what Lulu said. That's the scary part.
@ifnot c3_ledger -> b1
lulu[shock]: And now there's a book of who told on who, and pages everywhere, and what if one of them says LULU?
@label b1
mochi: You were young. Everybody says things.
lulu[sad]: Lulu knows. But not everybody's things end up in books.
think: She put the lip balm away, then took it straight back out again.
@flag lulu_ft2
@jump done
@label c
@show lulu angry center
narr: Lulu was practising scales, very loudly, so loudly that it took her a while to notice me.
lulu[angry]: Lulu's fine. Lulu is FINE. Lulu doesn't want to talk about Bramble. Lulu doesn't want to talk about pages.
lulu[sad]: Miss Pip is seventy-three. She taught Lulu for free because Lulu's mum couldn't pay. And Bramble's name is on her page.
lulu[angry]: And everyone wants to TEST things now. Test the pages, test the writing, test everybody. Why can't everyone just stop?
mochi: Lulu... are you all right?
lulu[sad]: ...No. But Lulu's going to sing until she is. That's how it works. Miss Pip said so.
think: She went back to her scales. Each one a little higher, a little louder, a little more like shouting.
@flag lulu_ft3
@jump done
@label d
@show lulu sad center
narr: Lulu was standing very still in the middle of the Music Room with her arms held out, practising for the fitting.
lulu[sad]: The Duchess says Lulu has to stand still for a whole hour. Lulu is practising. It's very hard. Lulu's arms have opinions.
lulu[sad]: Mochi. Can Lulu ask you something? If you did a small bad thing, so that a big bad thing wouldn't happen... is that still bad?
mochi: What sort of small bad thing?
lulu[normal]: Lulu doesn't know. A pretend one. For a song. Lulu's writing a song about it, that's all. That's all it is.
lulu[sad]: Bramble used to tell Lulu when Lulu was being silly. Now nobody does. And Grub... Lulu can't even look at Grub.
narr: She put her arms back up and held them there, trembling a little, until I left.
@flag lulu_ft4
@label done
@hide all
@flag hung_lulu
@skill encore
@end
""",

	"hangout_nibs": """
@if c3_day2 -> w2
@if c3_day3 -> w2
@bg manor_terrace
@jump go
@label w2
@bg manor_library
@label go
@music daily
@if nibs_ft3 -> d
@if nibs_ft2 -> c
@if nibs_ft1 -> b
@show nibs happy center
narr: Professor Nibs was scribbling sums on a scrap of paper, chewing his pen between lines like a beaver with a deadline.
nibs[happy]: Mochi! Allow me to explain how many days of flour we have. Nobody asked. Allow me anyway. Eleven. Twelve, if Bruno is merciful.
@ifnot c3_ledger -> a1
nibs[sad]: It's easier to count flour than to count who isn't speaking to me. The flour doesn't glare.
@label a1
mochi: Doesn't that pen taste awful?
nibs[normal]: Ink, mostly. A little bit of plastic. A hint of desperation. I've chewed every pen I've ever owned. I started on pencils.
nibs[happy]: My mother said I'd grow out of it. I did grow out of pencils. Into pens. She was very disappointed. Science marches on.
nibs[normal]: Also, the barometer says sunshine for a week. I've decided to believe it. A scientist must choose his optimism carefully.
think: The end of it was gnawed down to splinters. He put it back in his mouth to think about the flour again.
@flag nibs_ft1
@jump done
@label b
@show nibs normal center
narr: Nibs was trying to pour something from one bottle to another with one paw and hold a notebook with the other. It wasn't going well.
nibs[sad]: This is when Fizz would hand me the funnel. My lab assistant. Twenty-two years old. She always knew what I needed before I did.
nibs[happy]: She once set her own eyebrows on fire to prove a point. The point was correct! A small explosion, Tuesday. We still talk about it.
@ifnot c3_ledger -> b1
nibs[sad]: And she's over there. And now there are people in this house who think I'd tell on someone. Me. I can't even tell a joke.
@label b1
think: I held the funnel for him. He said thank you three times and spilled it anyway.
@flag nibs_ft2
@jump done
@label c
@show nibs sad center
@if c3_day5 -> c5
narr: Nibs was alone at the big desk, under the bookcase, with his folder of samples in front of him and his chin on his paws.
@jump c6
@label c5
narr: Nibs was alone at the big desk, under the bookcase, with a Ledger page and a magnifying glass in front of him and his chin on his paws.
@label c6
nibs[sad]: The Duchess won't look at me. Reginald won't stop looking at me. I have never met either of their families. Not once.
nibs[normal]: Zuzu brought me a cup of tea at breakfast anyway. Didn't say anything. Just put it down and left. Zuzu is a good egg.
nibs[sad]: I found... well. Never mind what I found. Some pages are better left where they are. Hypothetically.
nibs[happy]: Tomorrow, I'll have answers for everyone. That's the lovely thing about science, Mochi. It doesn't care who's angry.
@flag nibs_ft3
@jump done
@label d
@show nibs normal center
narr: Nibs was at the big desk with a Ledger page, a magnifying glass and a cold cup of tea in front of him. He looked as if he hadn't slept.
nibs[normal]: Mochi! Come and look. No, don't, it's all terribly boring. Typefaces. Little nicks in little letters. Science is mostly squinting.
nibs[sad]: Zuzu doesn't want me to finish. They say if I prove a line is true, it ruins somebody, and if I prove one's forged, it ruins somebody else.
nibs[sad]: They're not wrong. But Fizz is over there, and the Dowager, and Plum, and people think I put them there.
nibs[sad]: I didn't. I want everyone to know I didn't.
mochi: Is that why you're doing it?
nibs[happy]: Partly. And partly because I've never once been right about anything that mattered. Barometers don't count. I'd like to be right once.
narr: He put the end of his pen in his mouth, chewed, made a face, and kept chewing anyway.
nibs[normal]: Nearly there. Hypothetically. Probably. Come back tomorrow and I'll tell you everything.
@flag nibs_ft4
@label done
@hide all
@flag hung_nibs
@skill hypothesis
@end
""",

	"hangout_pepper": """
@if c3_day5 -> w2
@if c3_day3 -> w3
@if c3_day2 -> w2
@bg manor_shore
@jump go
@label w2
@bg manor_gallery
@jump go
@label w3
@bg manor_gallery_turned
@label go
@music daily
@if pepper_ft3 -> d
@if pepper_ft2 -> c
@if pepper_ft1 -> b
@show pepper happy center
@if c3_day5 -> a5
@sfx sp_type
narr: Pepper had her portable typewriter balanced on her knees and was typing so fast the bell sounded like a fire alarm.
pepper[happy]: Mochi! Tomorrow's Puddle. Exclusive interview with a gull. He had no comment. I'm running it anyway.
@jump a6
@label a5
narr: Pepper had a sheet of card on her knees and was lettering tomorrow's Puddle in pencil, as fast as other people type.
pepper[happy]: Mochi! Tomorrow's Puddle. Exclusive interview with a gull. He had no comment. I'm running it anyway. In pencil.
@label a6
@ifnot c3_ledger -> a1
pepper[sad]: If I keep typing, I'm a reporter. If I stop, I'm one of the people on that page. So. I keep typing.
@label a1
mochi: Have you always worked on newspapers?
pepper[normal]: Started on the gossip pages. Who wore what to which party. Who left with whom. Paid the rent, just about.
pepper[happy]: Then old Mr. Pica gave me my first real story. Facts first, headlines never. He had it painted over his desk.
narr: Ding. She whipped the sheet out of the roller and blew on it, though it was already dry.
pepper[happy]: There. A story's not a story until it's on paper. Everything else is just talk, partner.
@flag pepper_ft1
@jump done
@label b
@show pepper normal center
@if c3_day5 -> b5
narr: Pepper had a cookbook open on her lap, one of Grub's greasy ones from the kitchen, and was frowning at it like a crossword.
pepper[normal]: Three cakes. I owe Bruno three cakes. I said it on the record, and Pepper Quill pays her debts.
pepper[sad]: Problem: I have never baked a cake. I've reviewed forty-one. I've never made one. How hard can it be?
mochi: Grub could help you.
pepper[happy]: Already asked. He showed me the bread oven and said, quote, don't touch anything. I'm treating that as a yes.
@jump b4
@label b5
narr: Pepper had one of Grub's greasy cookbooks on her lap, open at a page with a scorch mark the exact shape of a cake tin.
pepper[happy]: Three cakes, paid in full. And I am never baking again. Grub says his oven will never be the same, and I believe him.
pepper[normal]: Bruno said thank you nine times. Nine. I counted. Do you know how rare that is? For me?
@jump b1
@label b4
@ifnot c3_ledger -> b1
pepper[sad]: Bruno sat with me on the stairs this morning. He didn't ask me a single question. Do you know how rare that is? For me?
@label b1
@flag pepper_ft2
@jump done
@label c
@show pepper sad center
narr: Pepper was sitting with her camera in her lap again, turning the little wheel of the date-back round and round without looking at it.
pepper[sad]: Zuzu won't look at me. I never typed their mum's name, Mochi. Not once. I'd remember. I'd remember a thing like that.
@if c3_day5 -> c5
pepper[normal]: If anyone wants to check my typewriter, they can. Nibs has my sample. He can have all the samples he likes.
@jump c6
@label c5
pepper[normal]: If anyone wants to check my typewriter, they're welcome to it. It won't tell them much without a ribbon. Neither will I, today.
@label c6
pepper[sad]: Mr. Pica always said, the facts don't care how you feel about them. I never used to think that was sad.
think: Click, click, click went the little wheel. Day, hour, minute. Round and round and back again.
@flag pepper_ft3
@jump done
@label d
@show pepper normal center
narr: Pepper sat in a window of the Gallery with a sheet of card and a pencil, lettering tomorrow's Puddle by hand, very slowly.
pepper[normal]: Pencil. Mr. Pica would laugh himself silly. He started out with a pencil and a lamp-post, he always says. Now look at me.
pepper[happy]: He corrected my grammar yesterday. Through a prison telephone. Ninety years old, and he still found a comma in the wrong place.
pepper[sad]: Zuzu walked straight past me this morning. Two days now. I keep writing them notes and tearing them up.
mochi: How were the cakes, in the end?
pepper[happy]: Terrible, partner. And he ate every crumb and told me they were the best he'd ever had. Bruno can't lie. He did it anyway, for me.
narr: She looked down at the Puddle. The headline said ISLAND ENJOYS A QUIET DAY. She rubbed it out, and wrote it out again exactly the same.
@flag pepper_ft4
@label done
@hide all
@flag hung_pepper
@skill scoop_sense
@end
""",

	"hangout_reginald": """
@if c3_day3 -> w3
@bg manor_hall
@jump go
@label w3
@bg manor_terrace
@label go
@music daily
@if reginald_ft3 -> d
@if reginald_ft2 -> c
@if reginald_ft1 -> b
@show reginald normal center
narr: Sir Reginald stood at attention with his foil at his side and a bandage on his paw, guarding absolutely nothing.
reginald[normal]: Halt! Who goes there? ...Ah. It's you. Carry on. The watch is kept. The watch is always kept.
@ifnot c3_ledger -> a1
reginald[angry]: Today more than ever. There are people in this house I would not turn my back on, and I shan't.
@label a1
mochi: Do you really stay up all night?
reginald[normal]: A Puddlesworth never sleeps on watch. He merely rests his eyes, from about half past ten, in an upright and dignified position.
reginald[sad]: Nobody signs my roster, you know. I posted it by the Dining Room door. Only the Professor signs. Every meal. In that dreadful round hand.
reginald[normal]: Discipline is a lonely calling. Now move along, citizen. Or stay. It is... pleasant to have company on watch.
@flag reginald_ft1
@jump done
@label b
@show reginald normal center
narr: Reginald was re-waxing his moustache with tremendous care, in a hand mirror, one curl at a time.
reginald[normal]: Mother taught me fencing. Mother fences with a parasol. She once disarmed a burglar and then made him tea.
reginald[happy]: She'd have had this house in order by lunch. Bolts oiled, bats evicted, the caiman made to wipe his feet.
reginald[normal]: She calls me Reggie. Nobody else is permitted to call me Reggie. Least of all Zuzu, who does it constantly.
@ifnot c3_ledger -> b1
reginald[angry]: And that book says the Professor gave her up. The PROFESSOR. Who chews pens. I can barely be in a room with the man.
@label b1
think: He went back to his moustache. His paw shook a little on the second curl. He did it again until it didn't.
@flag reginald_ft2
@jump done
@label c
@show reginald sad center
narr: Reginald was sitting alone with his sample sheet from the Library, reading it over and over as if it might confess.
reginald[sad]: I'll tell you a thing, citizen, and if you repeat it I shall deny it with my last breath. I write letters to the newspapers.
reginald[normal]: Many letters. Strongly worded. Unsigned. Disgusted, of Puddlesworth Manor. Outraged, of Puddlesworth Manor. That sort of thing.
reginald[sad]: Forty years of it. If the Professor holds my hand up against the letters page, I shall never be able to show my face at the club again.
think: He folded the sample very small and put it in his breast pocket, over his heart, like a shameful medal.
@flag reginald_ft3
@jump done
@label d
@show reginald normal center
narr: Sir Reginald was at the telescope, as still as a heron, with one eye pressed to it and his plume drooping in the breeze.
reginald[normal]: Ah. Citizen. One keeps watch, you know. Over the bay. Over the shipping. There is no shipping. One watches it anyway.
reginald[sad]: Third row from the top, fourteenth from the left. Her light goes out at midnight.
reginald[sad]: I know, because I have watched it go out four nights running.
reginald[normal]: The terrace counts as indoors, the caiman says. So a man may keep his watch from here, and stay within the rules. Technically.
mochi: She said your moustache was crooked.
reginald[sad]: She did. And it was. I have re-waxed it six times since. It will not lie straight. Nothing lies straight in this house.
@flag reginald_ft4
@label done
@hide all
@flag hung_reginald
@skill en_garde
@end
""",

	"hangout_zuzu": """
@if c3_day2 -> w2
@if c3_day3 -> w2
@bg manor_hall
@jump go
@label w2
@bg manor_library
@label go
@music daily
@if zuzu_ft3 -> d
@if zuzu_ft2 -> c
@if zuzu_ft1 -> b
@show zuzu normal center
narr: Zuzu was lying flat on their back on the floor with a notebook on their chest, staring at the ceiling and making little crosses on a map.
zuzu[normal]: cameras. fifty-eight so far. one in the chandelier. one in a stuffed owl. one in the other stuffed owl.
@ifnot c3_ledger -> a1
zuzu[angry]: helps to have something to count. better than counting who to hate.
@label a1
mochi: What will you do when you've found them all?
zuzu[happy]: nothing. yet. it's just nice to know where the eyes are. you can't hide from a thing you haven't counted.
narr: They held up the bandaged paw and squinted at it.
zuzu[normal]: also the bat looked me in the eye while it bit me. i think about that a lot. i think the bat had a camera too.
zuzu[happy]: bruno tied the bandage. bruno ties bandages like he's mooring a ship. can't feel my fingers. ten out of ten.
@flag zuzu_ft1
@jump done
@label b
@show zuzu happy center
narr: Zuzu had a tangle of salvaged wire, a soldering iron and half a radio spread across the floor.
zuzu[happy]: me and nibs are building a radio. he does the chemistry for the battery, i do the wires. he's ok. for an old guy.
zuzu[normal]: mum taught me to solder when i was six. she ran a radio station out of our kitchen. totally illegal. totally the best.
@ifnot c3_ledger -> b1
zuzu[sad]: and now she's over there. and there's a page with a name on it. and i know whose.
@label b1
think: They touched two wires together. A little crackle came out of the speaker, and they smiled at it like a pet.
mochi: Does it pick anything up?
zuzu[happy]: one station. it's static, and once a night a man reads out the shipping forecast. i love him. i'd die for him.
@flag zuzu_ft2
@jump done
@label c
@show zuzu angry center
narr: Zuzu was sitting in the window with their knees up and the folded page from breakfast in their paw, unfolding and refolding it.
zuzu[angry]: pepper. of everyone. she used to buy me fizzy drinks on the ship. she asked about my mum. she ASKED about her.
zuzu[sad]: and i can't even say nibs's test is a good idea, because my writing's on something i'd rather nobody matched.
zuzu[sad]: i forged a visitor's pass once. years ago. to get in and see her. it didn't work. they kept the pass.
zuzu[angry]: and nibs keeps saying his test will prove things. i don't want things proved. i want my mum.
think: They folded the page smaller, and smaller, until it wouldn't fold any more.
@flag zuzu_ft3
@jump done
@label d
@show zuzu normal center
narr: Zuzu was lying under a table in the Library with their head inside the box of a wall socket and a torch between their teeth.
zuzu[normal]: mmf. hold this. no, the other end. the warden's cameras all run back to one cable. i've nearly got it. by midnight it's mine.
zuzu[angry]: nibs keeps saying the test will set everyone free. it won't. it'll set one person free and hang everyone else out to dry.
zuzu[sad]: and my writing's on a fake pass in that prison. if he starts matching hands...
zuzu[sad]: i asked him to stop. he gave me the look. the hypothetically look.
zuzu[normal]: we'll sort it. we always sort it. we sorted the radio, and that was a disaster with a battery in it.
narr: They pulled a wire, and somewhere far off in the house, a little red light went out.
zuzu[happy]: one down. fifty-seven to go.
@flag zuzu_ft4
@label done
@hide all
@flag hung_zuzu
@skill autocomplete
@end
""",

	# Loose Ledger pages, readable in Free Time from Day 3 (freetime3d_screen.gd, the space's "ledger_page" anchor).
	# Each sets read_page_<space>; Mochi always puts the page back. The Bedroom Wing's page is left for the investigation.
	"page_terrace": """
@if read_page_terrace -> again
narr: Folded and slipped half under one of the planters: a page torn out of the Ledger. Typed small and neat:
narr: "No. 207. Hawthorn Thistlewood, nurseryman. Held for: growing a rose of an unregistered colour."
narr: Underneath, in blacker, squarer type: "On information from: F. Dauber."
think: Bramble's dad. And Fennel's name under it. I read it twice. Then I slid it back under the planter. It isn't mine to carry around.
@flag read_page_terrace
@log places A Ledger page under a planter on the terrace: Hawthorn Thistlewood, nurseryman. On information from: F. Dauber. I left it there.
@end
@label again
think: The page under the planter. I've read it. I'm not reading it again.
@end
""",

	"page_grand_hall": """
@if read_page_grand_hall -> again
narr: Tucked behind the frame of a portrait on the wall: a page torn out of the Ledger. Typed small and neat:
narr: "No. 88. Augustus Pica, newspaper editor. Held for: printing a correction."
narr: Underneath, in blacker, squarer type: "On information from: Z. Byte."
think: Pepper's old editor. And Zuzu's name. I put it back exactly how it was, corner tucked in. I don't want to be the one who finds this.
@flag read_page_grand_hall
@log places A Ledger page behind a portrait in the Grand Hall: Augustus Pica, newspaper editor. On information from: Z. Byte. I left it there.
@end
@label again
think: The page behind the portrait. I already know what it says.
@end
""",

	"page_dining_room": """
@if read_page_dining_room -> again
narr: Tucked behind the still life on the Dining Room wall: a page torn out of the Ledger. Typed small and neat:
narr: "No. 151. Mrs. Hetty Pemberton, cook. Held for: seasoning without a licence."
narr: Underneath, in blacker, squarer type: "On information from: R. Puddlesworth."
think: Grub's mum. And Reginald's name. I tucked it back behind the frame. My paws felt dirty for an hour afterwards.
@flag read_page_dining_room
@log places A Ledger page behind the still life in the Dining Room: Mrs. Hetty Pemberton, cook. On information from: R. Puddlesworth. I left it there.
@end
@label again
think: The page behind the still life. Once was enough.
@end
""",

	"page_kitchen": """
@if read_page_kitchen -> again
narr: Tucked behind the framed menu on the kitchen wall: a page torn out of the Ledger. Typed small and neat:
narr: "No. 236. Sesame, nine years old, student of the dojo. Held for: throwing a grown-up in a public park."
narr: Underneath, in blacker, squarer type: "On information from: G. Pemberton."
think: Bruno's little student. And Grub's name. In Grub's own kitchen, behind his own menu. I put it back. I don't think he's seen it.
@flag read_page_kitchen
@log places A Ledger page behind the framed menu in the kitchen: Sesame, nine, student of the dojo. On information from: G. Pemberton. I left it there.
@end
@label again
think: The page behind the menu. I'd rather not.
@end
""",

	"page_music_room": """
@if read_page_music_room -> again
narr: Tucked behind the still life by the Music Room door: a page torn out of the Ledger. Typed small and neat:
narr: "No. 174. Saffron Dauber, painter of miniatures. Held for: an unflattering likeness of a public figure."
narr: Underneath, in blacker, squarer type: "On information from: L. Starling."
think: Fennel's sister. And Lulu's name. I tucked it back behind the frame, and somewhere in the room a music box played three notes and stopped.
@flag read_page_music_room
@log places A Ledger page behind the still life in the Music Room: Saffron Dauber, painter of miniatures. On information from: L. Starling. I left it there.
@end
@label again
think: The page behind the still life. I know what it says.
@end
""",

	"page_library": """
@if read_page_library -> again
narr: Slipped between two books on a shelf: a page torn out of the Ledger. Typed small and neat:
narr: "No. 192. Fizz Bracken, laboratory assistant. Held for: a small explosion, Tuesday."
narr: Underneath, in blacker, squarer type: "On information from: D. Velveteen."
think: Nibs's assistant. And the Duchess's name. The page had been folded once and unfolded again, carefully. I put it back between the books.
@flag read_page_library
@log places A Ledger page between two books in the Library: Fizz Bracken, laboratory assistant. On information from: D. Velveteen. I left it there.
@end
@label again
think: The page between the books. I've read it.
@end
""",

	"evening": """
@card 4:30 PM | The Kitchen
@bg manor_kitchen
@music daily
narr: Grub was at the range when I came in, with a pot of soup going and a ladle in his good paw. The ladle was rattling against the side of the pot.
narr: Not stirring. Rattling. Tick-tick-tick-tick, like teeth chattering in the cold.
@show grub normal center
grub[normal]: Mochi, love. Onions. Fine as you can. Mum says you can tell a cook by the onions. She's never said why. I've never dared ask.
narr: I chopped. He stirred, or tried to. Every few seconds the ladle chattered and he grabbed it with his bad paw as well, and winced.
grub[sad]: Paws won't keep still today. Like they belong to somebody else. Somebody nervous.
narr: When the soup was nearly done, he filled the ladle and lifted it to his mouth to taste, the way he must have done ten thousand times.
narr: And stopped. The ladle hung an inch from his chin, trembling. He was breathing hard through his nose.
@show grub shock center
grub[shock]: I can't. I can't put it in my mouth. Mochi, you taste it. Please. Tell me if it wants salt. I can't. I can't, today.
narr: I tasted it. It was perfect. It always was. I told him so, and he sat down hard on a stool and put his face in his apron.
grub[sad]: Thirty years I've tasted every pot I ever made. Every single one. What's wrong with me, Mochi? What's wrong with me?
@hide all
think: I didn't know what to say. I said it was the fever. I said a lot of things. We finished the onions together, and then the bread.
narr: He kept forgetting what he'd put in. He salted the soup three times, and I quietly tipped a jug of water in after him when he wasn't looking.
narr: He watched that jug the whole time it was in my paw, the way you'd watch a dog you didn't know.
@log timeline 4:30 PM | Helped Grub in the kitchen. He couldn't keep the ladle still, and couldn't bring himself to taste the soup. I tasted it for him.
narr: At twenty to six I went up to wash and change for dinner.
narr: On the stairs I passed Nibs, coming in from the terrace, sandy to the knees, with his barometer under his arm.
@show nibs happy center
nibs[happy]: Tide's out! Four hundred and twelve steps, twice, to watch water go away. That's science, Mochi. Glamorous as ever.
@hide all
@log timeline 5:40 PM | Went up to change for dinner. Passed Nibs on the stairs, back from watching the tide on the beach.
@card 8:00 PM | Dinner
@bg manor_cloakroom
@music daily
narr: The gong at eight. The cloakroom, the hooks, the grumbling. Five nights in, it was as regular as the tide.
narr: Coats went up one by one. Reginald hung his, went back for his wax, put it back, and went back again.
narr: At five past eight, as every night, Nibs signed Reginald's roster by the door, the only one who ever did.
narr: He gave the end of his pen a good long chew, put it in his coat pocket and hung up the coat.
narr: Tonight's laugh was Bruno's. He hung his great coat on its hook, and the hook bent slowly down to the floor like a tired flower.
@show snapjaw happy center
snapjaw[happy]: Two hooks for the big one, from now on. I'll put it on your bill.
@show bruno sad left
bruno[sad]: Bruno is sorry to the hook.
@hide all
@anim c3_dinner5
@bg manor_dining
narr: Grub had made everything in one great pot, soup and then stew, with one long loaf on a board...
narr: ...and everyone helped themselves from the middle with the same ladle.
narr: The Dining Room clock ticked on the wall by the sideboard.
narr: Fennel sat down next to me, leaned his crutch against my chair and opened his sketchbook.
@show fennel happy left
fennel[happy]: Tonight's strip. Dinner, in the manner of a Dutch master. If anybody so much as gets up, I'm drawing it. Charcoal waits for no one.
fennel[normal]: And the clock goes in every one. A clock is the only honest face in any room. It never pretends it's earlier than it is.
@hide all
@show duchess normal left
@show lulu happy right
duchess[normal]: Lulu, darling. Tonight, half past ten, the Music Room. Bring yourself, and stand still for an hour. It's very nearly a gown.
lulu[happy]: A real fitting! Lulu is going to stand SO still. Like a statue. A sparkly statue.
@hide all
@show reginald normal left
reginald[normal]: Mochi. Five to ten, the Grand Hall. Somebody ought to witness the watch begin.
reginald[normal]: Nobody will sign my roster, but you might at least stand there.
mochi: I'll be there. And then I'm having a bath. A real one. The Marble Bath's working, and I promised my grandma.
@show bruno happy right
bruno[happy]: Bruno fixed the pipes.
bruno[happy]: Mochi will have the hottest bath on the island, and Bruno will be with the generator, so the lights stay on for it.
@hide all
@show bramble normal left
@show fennel normal right
bramble[normal]: ...Fennel and I are going to the Conservatory after... the moonflowers open at night... we're going to watch them do it...
fennel[happy]: Until a quarter to eleven, when my leg files its complaint. Nobody has ever drawn a moonflower opening. Nobody has had the patience.
@hide all
@show pepper normal left
pepper[normal]: Darkroom for me. Four days of rolls to develop, now I've got chemicals again. The Gallery cupboard, all night, if I'm lucky.
@show zuzu normal right
zuzu[normal]: attic. i'm into the warden's camera wiring. by midnight i'll have his whole feed. every camera in the house, on my screen.
@hide all
@show nibs happy center
nibs[happy]: Then we're racing, Zuzu! I'll have my answer by midnight too. One way or the other. And then everybody can stop looking at everybody.
nibs[normal]: Grub, would you send me up a pot of tea at ten? A big one. It's going to be a long night at the desk.
@show grub shock right
grub[shock]: Tea? Yes. No. Water. I... boiling it, pouring it, I... somebody else. Somebody else, Professor. Sorry.
nibs[normal]: Oh. Of course. Never mind, never mind. I'll manage. I always manage.
@hide all
@show lulu happy left
lulu[happy]: And on Saturday, Lulu is giving a concert! In the Music Room! For everyone! In the gown! Nobody's allowed to be sad at a concert.
@show reginald normal right
reginald[normal]: I shall attend. In my capacity as night watch. Concerts attract a criminal element. Tenors, mostly.
@hide all
@show duchess normal left
duchess[normal]: It's a gown, Lulu, not a lifeboat. Stand still tonight and it might even fit you.
@show bramble happy right
bramble[happy]: ...I'll bring flowers... if that's all right... I won't sit at the front...
narr: Lulu looked at her for a moment, then down at her soup, and didn't say yes, and didn't say no. Bramble took it as a yes. So did I.
@hide all
narr: And then it was just an ordinary dinner. That's what I keep coming back to. It was an ordinary dinner.
narr: The soup went round, and the stew, and the loaf. People got up and came back, the way people do.
narr: Every time somebody left the table, Fennel drew a little square in his strip: the table, the empty chair, and the clock over the sideboard.
narr: Half past eight: Reginald, for his wax, as every night. Back at twenty to nine, with his moustache shining.
narr: Twenty to nine: Lulu, for her lip balm. Back at a quarter to, smelling of strawberries.
narr: Ten to nine: Pepper, to change her film. Back at two minutes past nine, winding on a fresh roll.
narr: Five past nine: Zuzu, muttering about a wire. Back by ten past, with a screwdriver behind one ear.
narr: And Grub, in and out of the kitchen all evening, with bread, with stew, with more bread. Fennel gave up drawing him after the fourth time.
narr: Bruno, the Duchess and Bramble never left their chairs. Neither did Fennel, with his crutch against mine, or me.
@show nibs happy center
narr: At a quarter past nine, while everyone else was still on the pudding, Nibs was first up, as always.
narr: He took his own coat off the hook, fished out his pen, and gave it a good chew while he said goodnight to the room.
nibs[happy]: Goodnight, all! Splendid stew, Grub. Library, midnight, answers. Don't wait up. Honestly, don't. It'll be boring until it isn't.
narr: And he walked out chewing, the way he did every night, with the pen bobbing in the corner of his mouth.
@hide all
narr: The rest of us finished the pudding. Bramble and Fennel left together at twenty past, him on his crutch, her carrying his sketchbook.
narr: Bruno went off to the Generator Room. The Duchess swept out to find her pins.
narr: Lulu went to practise standing still. Zuzu went up. Pepper went to her darkroom.
narr: Grub was clearing the plates when I left. Or he had been. When I looked back from the door, the plates were there and Grub wasn't.
@log timeline 8:00 PM | Dinner from one pot and one loaf. Coats on the hooks, as every night. Nibs signed the roster on the way in.
@log timeline Left the table during dinner: Reginald at 8:30, Lulu at 8:40, Pepper at 8:50, Zuzu at 9:05. Grub in and out with the dishes.
@log timeline 9:15 PM | Nibs went up first, as every night, for the Library. He says he'll have his answer by midnight. Zuzu says the same about the cameras.
@log people duchess Says she'll fit Lulu's costume in the Music Room at half past ten tonight.
@log people lulu Says she'll be at the Duchess's fitting in the Music Room at half past ten.
@log people reginald Asked me to witness the start of his watch in the Grand Hall at five to ten.
@log people bramble Says she and Fennel will watch the moonflowers open in the Conservatory after dinner.
@log people fennel Says he'll draw the moonflowers in the Conservatory until a quarter to eleven.
@log people pepper Says she'll be developing film in the Gallery darkroom all night.
@log people zuzu Says they'll have Snapjaw's whole camera feed on their screen by midnight, from the Attic.
@log people nibs Says he'll have his answer by midnight, at his desk in the Library.
@log people grub Told Nibs that somebody else would have to make the tea at ten.
@alibi bramble 8 PM
@alibi bruno 8 PM
@alibi duchess 8 PM
@alibi fennel 8 PM
@alibi grub 8 PM
@alibi lulu 8 PM
@alibi pepper 8 PM
@alibi nibs 8 PM
@alibi reginald 8 PM
@alibi zuzu 8 PM
think: Everybody's got somewhere to be tonight. A fitting, a darkroom, a desk, a generator. And me: a bath.
think: Five days, and nobody's died. I'm almost starting to believe nobody will.
@end
""",

	"night": """
@bg manor_hall_night
@music tension
narr: I went to the Grand Hall early and sat on the bottom stair to wait for Reginald.
narr: The house was quiet. The clock over the stairs said twenty to ten.
narr: Then, from the Library at the top of the stairs, voices. Raised ones. Zuzu's, and Nibs's.
narr: I had never heard Nibs shout. I didn't know he could.
voice: ...then don't! just don't do it! nobody wants it!
voice: It isn't about WANTING, Zuzu! The truth doesn't care who wants it!
voice: you sound exactly like him. you sound like the warden.
@anim c3_row
@show zuzu angry left
narr: The Library door banged open. Zuzu came out fast, and Nibs came after them as far as the doorway, jabbing his pen at them like a little sword.
@show nibs angry right
nibs[angry]: Go and play with your cameras, then! By midnight I'll have it, and then you'll see! Everybody will see!
zuzu[angry]: fine. see it on your own.
narr: The door slammed. A second later, the bolt went across. Clack. I had never heard him bolt it before.
@hide all
@show zuzu sad center
narr: Zuzu came down the stairs two at a time, saw me sitting there, and stopped.
mochi: Zuzu? Are you all right?
zuzu[sad]: not now. ...not now, ok. i'll fix it in the morning. i'll bring him coffee. he likes it disgusting. four sugars.
narr: They went off up the back stairs towards the Attic without looking round.
@hide all
think: Their first fight. In all the time I've known them, I've never seen them have one. Not even over chess.
@log timeline 9:40 PM | Zuzu and Nibs argued in the Library. Nibs bolted the door after them. Zuzu went up the back stairs, towards the Attic.
@alibi zuzu 9 PM
@alibi nibs 9 PM
@music daily
narr: At five to ten, Sir Reginald came down the stairs in a greatcoat, with a lantern in one paw and his watch roster on a clipboard in the other.
@show reginald normal center
reginald[normal]: Ah! A witness. Splendid. Stand there. No, there, where the light falls. A changing of the watch should be seen to be done.
narr: There was nobody to change with. He saluted the empty hall, signed his own name on the roster, and held it out for me to see.
narr: Five nights of columns. R. PUDDLESWORTH, R. PUDDLESWORTH, R. PUDDLESWORTH. And on every dinner line, in round, cheerful handwriting: Prof. N.
reginald[sad]: The only one who ever signs. Every meal, without fail. The man who gave my mother to that place is the only one who honours my roster.
reginald[normal]: I have never known what to do with that, citizen. I still don't.
mochi: Maybe he just likes rules. You both do.
reginald[sad]: ...Do not say that to anyone. Least of all him.
narr: Somewhere inside the wall behind the stairs, something rattled, a long way up. Then a little bell, very faint. Ting.
reginald[normal]: Bats. This house is more bat than brick. I shall add them to my rounds.
@sfx chime
narr: Then the big bell for ten o'clock, and bolts going across all over the house.
reginald[happy]: Nighttime. My watch begins. Every corridor, every floor, until dawn. The house is in safe paws, Mochi. Go and have your bath.
@hide all
narr: He marched off towards the back of the house, his lantern swinging, and I listened to his boots fade away.
@log timeline 9:55 PM | Met Reginald in the Grand Hall to witness the start of his watch. The ten o'clock bell rang while we were there.
@log people reginald Says he'll patrol every corridor and every floor until dawn.
@alibi reginald 9 PM
@alibi reginald 9 PM proof
@bg manor_bath
@music sad
narr: The Marble Bath, at last. Bruno had fixed the pipes, and the long white pool had filled to the brim, steaming under the glass roof.
think: Grandma told me to have a proper bath. This is the most proper bath on the whole island.
narr: I slid in up to my chin. Hot. Really hot. The first real bath since the lake drained, since the flood, since everything.
think: Ten out of ten. No. Eleven. I'm allowed one eleven in my life, and I'm spending it here.
narr: The water smelled of nothing at all. No yuzu, no salts, no lake mud.
narr: Just hot water, and marble, and the steam curling up into the dark under the roof.
think: Grandma, you'd hate it. Too plain. You'd want a sprig of mint. You always want a sprig of mint.
narr: Through the glass roof I could see the searchlight swinging over the bay, and beyond it the Gaol and its six hundred little lights.
think: A page burned. Some papers gone. Grub at Lulu's bedside. Zuzu and Nibs not speaking. It's all coming apart, slowly, like wet bread.
think: But slowly. Maybe slowly is how this ends. Maybe we just wait, and somebody comes, and nobody ever does it.
narr: I soaked until my fingers wrinkled, and then some more. The clock on the wall said five to eleven. Ten minutes. Everybody knew what was coming.
narr: Four minutes past. I held on to the edge of the pool and counted, the way you count between the lightning and the thunder.
@anim c3_blackout
@music stop
narr: Darkness. Total darkness. The water still slopping from side to side, and something gritty falling into it, pattering like rain.
narr: Then, far above me, somewhere in the house, a crash.
narr: A long, heavy, tearing crash, like a wardrobe falling down a staircase. Then nothing at all.
think: Plaster. It's only plaster. Rule seven. He's punctual. It's only the house.
narr: I climbed out and felt my way along the wall in the dark, wrapped in a towel. White dust on everything. My paws, my ears, the floor, the towel.
narr: Somewhere a long way below, the generator coughed and didn't catch.
@log timeline 11:05 PM | The posted aftershock. Every light went out, and white plaster dust came down. A loud crash somewhere above.
@bg manor_cellar
@music tension
narr: I was halfway along the back corridor when I heard it. A low, broken sound from the cellar steps. Somebody crying, or humming, or both.
narr: At twenty past eleven, the lights flickered and came back on all over the house.
narr: All except the cellar. Its one bulb had shattered in the shaking.
narr: I went down anyway, feeling for the steps. In the light from the doorway behind me, I could just make him out.
@show grub sad center
narr: Grub was sitting on the little stool between the wine racks, in the dark, with white dust on his head and his paws in his lap, shaking.
narr: On the bottom racks around him, the rat-bait tins grinned their cartoon grins.
mochi: Grub? Grub, it's me. It's Mochi. What are you doing down here?
grub[sad]: Is it... is it breakfast? I was going to... the Professor wanted his tea. Didn't he? Did I make it? I can't remember if I made it.
grub[sad]: I don't remember coming down here. I don't remember the stairs. It all went dark and white and loud, and I was here.
narr: I took his paw to help him up. His claws were full of splinters, and he didn't seem to feel them at all.
grub[shock]: Don't let me near anybody, Mochi. Lock me in. I mean it. Lock me in my room.
@hide all
narr: I walked him up to his room. He locked himself in, and I heard him drag something heavy against the door.
@log timeline 11:20 PM | The lights came back. Found Grub sitting in the dark in the Wine Cellar. He didn't know how he got there. I took him up to his room.
@log people grub Says he doesn't remember going down to the cellar. He wondered whether he'd made the Professor's tea.
@alibi grub 11 PM
@bg manor_bedroom_night
@music sad
narr: I'd barely got back to the Curlew Room and wiped the dust out of my ears when someone knocked. Quietly. Three times.
narr: It was Lulu, in her dressing gown, white dust in her fur, her face all blotches. She'd been crying for a while.
@show lulu sad center
lulu[sad]: Can Lulu come in? Just for a bit. Lulu doesn't want to be on her own.
lulu[sad]: The fitting's over. The lights went, and the Duchess dropped every pin she owns.
mochi: Of course. Lulu, what's wrong?
lulu[sad]: Don't. Please don't ask Lulu anything. Lulu can't. Not tonight. Can Lulu just... sit here?
narr: She sat on the end of my bed and cried, quietly, the way you cry when you're trying not to wake anyone. I didn't ask. I sat with her.
narr: Once, around a quarter to twelve, something creaked inside the wall behind the bed. Slow. Like a footstep somewhere there was no floor.
lulu[shock]: What was that?
mochi: The house settling. It's been settling all week.
narr: At ten past twelve she wiped her face on my towel, said thank you three times, and went back to her own room.
narr: I heard her lock it, and then a chair go under the handle.
@hide all
@log timeline 11:35 PM | Lulu came to my room, crying, after the fitting. She asked me not to ask her anything. She stayed until ten past twelve.
@log people lulu Came to my room in tears after the fitting, and asked me not to ask her anything.
@alibi lulu 11 PM
@alibi lulu 12 AM
@alibi lulu 12 AM proof
think: Grub in the cellar. Lulu in tears. Zuzu and Nibs not speaking. Something's wrong in this house tonight, and I can't see what.
think: In the morning Zuzu will bring him his coffee, and they'll make it up. And I'll tell Grandma about the bath.
narr: I fell asleep with white dust still in my ears.
@evening
@end
""",

	"discovery": """
@card DAY 6 | The Library
@bg manor_corridor
@music stop
@sfx chime
snapjaw[happy]: Ding-dong! Seven o'clock, my darlings! Nighttime is over. Up you get, and mind the plaster!
narr: White dust on everything. The carpet, the banisters, the paintings. The house looked as if it had been out in the snow all night.
narr: I came out onto the landing in my dressing gown and heard it before I saw it. Knocking. Steady, patient knocking, and a voice.
@bg manor_hall
@show zuzu sad center
narr: Zuzu stood at the Library door with two mugs of coffee, knocking on the wood with the side of one of them.
zuzu[sad]: nibs. it's me. i brought coffee. the disgusting kind. four sugars. ...i'm sorry, ok? i'm sorry about last night.
zuzu[sad]: ...nibs?
@hide all
narr: Nothing. Zuzu put a mug down and tried the handle. It turned, but the door didn't move. Not a crack.
@show zuzu angry left
zuzu[angry]: nibs. NIBS. open the door. this isn't funny.
@hide all
narr: The others were coming now, doors opening all down the wing.
narr: Bruno came up the stairs from below, grey with oil after his night with the generator.
narr: Reginald, from his watch. Lulu, holding her own elbows.
narr: Fennel, thumping along on his crutch. The Duchess, already in her hat. Bramble, behind her.
narr: Pepper, with her camera round her neck, as always.
@show bruno normal center
narr: Bruno tried the handle. He leaned on the door with one shoulder, gently, then not so gently.
bruno[normal]: Frame's warped. The shaking last night. Stand back, please. Bruno will open it.
@hide all
@anim c3_door
@bg manor_library_after
@music tension
narr: The door went in with a shriek of splintering wood, and the cold air of the Library came out to meet us.
narr: White dust, everywhere. On the chairs, the rug, the lamp.
narr: Books lay in drifts across the far side of the floor, hundreds of them, spines up, pages open.
narr: And the tall bookcase behind the desk wasn't standing any more. It had come down face first, right across the desk.
narr: Under it, sticking out from beneath the shelves, was the back of a white coat.
@show zuzu shock center
zuzu[shock]: no. no no no. NIBS!
narr: Zuzu was across the room before anyone could stop them, on their knees by the desk, coffee everywhere, pulling at the shelves.
@hide all
narr: Bruno went in after them, got both paws under the edge of the bookcase, and set his feet.
narr: Everybody piled in behind him. Reginald and Lulu by the door. Fennel next to me, wheezing.
narr: The Duchess somewhere behind us. Bramble, I think, by the window.
narr: Pepper's flash went off. Then again. Then again, from somewhere else. She always shoots like that, frame after frame, without looking.
@show bruno angry center
bruno[angry]: Bruno has it. Bruno has it. Zuzu, look. LOOK.
narr: Bruno heaved. Every one of us watched that bookcase.
narr: It came up an inch, two, four, groaning, books sliding off its back, plaster pouring off it like snow.
@hide all
narr: Zuzu reached in underneath. Then Zuzu went very still.
@show zuzu sad center
zuzu[sad]: he's cold. bruno. he's cold. he's so cold.
@hide all
@anim c3_body_found
@sfx body_found
@card A BODY HAS BEEN DISCOVERED!
@music sad
narr: Bruno let the bookcase down again. Slowly. Carefully. As if it could still hurt him.
narr: Then he lifted Zuzu off the floor, coffee and all, and held on, and Zuzu let him.
@show zuzu sad center
zuzu[sad]: i was going to say sorry. i had it all worked out. i practised it on the stairs.
@hide all
think: Professor Nibs. Who chewed every pen he ever owned. Who said hypothetically about everything, even the weather.
think: Who was going to have an answer for all of us by midnight.
@show lulu sad left
lulu[sad]: No. No, no. He was just at dinner. He said goodnight. He said don't wait up.
@show reginald sad right
reginald[sad]: I wanted him in a cell. I wanted him to know what it was like. I never wanted... not this. Not under his own books.
@hide all
@show duchess sad left
duchess[sad]: I said dreadful things to that man, darlings. I meant every one of them. I'd like them all back, please.
@show bramble sad right
bramble[sad]: ...he was going to prove it... for me... he said he'd find out the truth for all of us...
@hide all
@show fennel sad left
fennel[sad]: I drew him last night, walking out of the door with his coat on. Chewing.
fennel[sad]: I didn't know it was the last one. You never know it's the last one.
@show pepper sad right
pepper[sad]: Somebody take Zuzu out of here. Please. I can't stop shooting. It's the only thing my paws know how to do when it's bad.
@hide all
narr: Grub came last, up the stairs as slow as an old dog, one paw on the banister. He stopped in the broken doorway and blinked at us all.
@show grub sad center
grub[sad]: Is it... breakfast? Why's everybody up? What's happened to the door?
narr: Then he saw the desk. He made a sound I had never heard a capybara make, and sat down on the floor right there in the doorway.
@hide all
@music snapjaw
@show snapjaw happy center
narr: Snapjaw didn't come in. He stood in the doorway behind Grub in his best waistcoat, with a silver tray in his claws.
snapjaw[happy]: Rule eight, my darlings! Pockets out, at the door, one at a time. Everything on the tray. And every camera comes to my darkroom!
@show pepper angry farright
pepper[angry]: Not the camera. Not now! There's a whole roll still in it! Those are press photographs!
snapjaw[happy]: And I'm the press now. I print everything. I read everything. I'll let you all know what I think of them.
narr: He popped the back of her camera with one claw, wound the film out into his paw, and took the two spare rolls from her pocket for good measure.
snapjaw[happy]: Sixteen frames on this one. Lovely. I'll print them when I feel like it, and show you when I feel like it.
snapjaw[normal]: I may never feel like it.
@hide all
narr: One by one we filed past him, and turned our pockets out onto his tray.
narr: Reginald: moustache wax, a pocket watch, his roster. Lulu: lip balm and a crumpled tissue. Zuzu: earbuds, a screwdriver, a twist of wire.
narr: The Duchess: a pincushion, a tape measure and her long scissors. Bramble: seed packets folded small, and a pair of gardening gloves.
narr: Bruno: two rolls of bandage and a spanner. Pepper: a pencil, a notebook and a lens cap. Grub: a wooden spoon. Me: my room key.
narr: Fennel turned out three stubs of charcoal and his sketchbook. Snapjaw flicked through the pages, sniffed, and handed it back.
@show snapjaw normal center
snapjaw[normal]: Drawings. I don't print drawings. Anybody can draw anything.
@show fennel angry left
fennel[angry]: Anybody can photograph anything, sir. I, at least, have to look.
@hide all
@show snapjaw happy center
snapjaw[happy]: Well! A chemist, under his own books. Who'd have thought it? Statistically, I mean.
snapjaw[normal]: You know the rules. An investigation, and then a Splash Trial. And remember: the house didn't do this. One of you did.
snapjaw[happy]: Off you go! Snoop wherever you like. Snap-snap-snap!
@hide all
@log timeline Day 6, 7 AM: Zuzu couldn't get into the Library. Bruno broke the door in. Nibs was under the fallen bookcase, across his desk.
@log timeline Snapjaw had everyone turn out their pockets at the Library door, and took the film from Pepper's camera, as rule eight says.
think: Five days without a death, and I'd started to let myself believe there wouldn't be one.
think: The house didn't do this. One of us did. I'm going to find out who.
@end
""",
}

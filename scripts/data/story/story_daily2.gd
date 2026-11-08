extends RefCounted
## Chapter 2 ("Murder on the Mudlark") daily-life story scripts (story DSL, see docs/ARCHITECTURE.md section 3).
## Bible: docs/DESIGN2.md. aftermath (-> drain cutscene), prologue, freetime_intro, hangout_<id> x12, freetime_outro,
## motive, evening, night, discovery, epilogue.
## Hangouts set flag "hung_<id>" so later scenes can react (see evening).

const SCRIPTS := {
	# =====================================================================================
	"aftermath": """
@card CHAPTER 2 | Murder on the Mudlark
@bg lobby
@music sad
narr: Morning came to Yuzu Springs the way it always did. The lanterns brightened. The fountain gurgled. The shutters stayed shut.
narr: Only now, there were thirteen of us.
think: I barely slept. Every time I closed my eyes, I saw silver stars drifting down through the dark.
narr: On the edge of the fountain sat a white captain's hat with a gold anchor. Nobody had moved it. Nobody was going to.
@show bruno sad center
narr: Bruno sat on the floor beside it with his knees pulled up to his chin. For Bruno, that is a lot of knees.
bruno[sad]: ...Bruno keeps waiting for Coco to shout ahoy. Bruno knows she won't. Bruno keeps waiting anyway.
@show lulu happy farright
lulu[happy]: Okay! Um! Everybody! Lulu has an idea! A sing-along! A happy one! Lulu-lu~! ...Anybody?
narr: Nobody sang. Lulu's smile held on for three whole seconds before it wobbled.
lulu[sad]: ...Sorry. Lulu just thought... Coco would have hated all this quiet.
@hide lulu
@show pepper sad farleft
pepper[sad]: Hey, big guy. I know I said it last night, but I'm saying it again. In daylight. On the record.
pepper[sad]: I'm sorry I pointed at you. No more headlines without facts. That's my new rule.
bruno[normal]: ...Pepper already said sorry. Pepper does not need to keep saying it.
bruno[happy]: But Bruno is still counting the cakes. It is two.
pepper[happy]: ...Two cakes. Noted. Ha.
@hide all
@show grub sad left
narr: Grub came round with a tray of seaweed crackers, glistening with far too much butter. Coco's favorite.
grub[sad]: Nobody's allowed to skip these. Chef's rules. ...She'd have eaten six and complained there wasn't a seventh.
@show duchess sad right
duchess[sad]: I sat up all night sewing her a new hat, darling. Gold anchor and all. I ran out of gold thread at three in the morning.
duchess[normal]: So the anchor is... mostly gold. She would have laughed at it. Loudly. For a long time.
@hide all
@show reginald normal center
narr: Sir Reginald stood beside the fountain with his plumed beret held over his heart.
reginald[normal]: Friends. We have lost our Captain. And a magician who made a terrible choice, and paid for it.
reginald[normal]: Someone must hold this crew together now. I shall protect every one of you, *as the Captain would have*.
reginald[sad]: ...I am aware I am no Coco. I own no mop. But I have a foil, a moustache, and a great deal of resolve.
@show zuzu normal farleft
zuzu[normal]: honestly? solid pitch. i'd follow the moustache.
@show marigold normal farright
marigold[normal]: And I'll keep everyone in one piece. Water, sleep, three meals a day. That's my resolve. Nurse's orders.
@hide all
think: Wisp asked us to keep the lights on for each other at night. Looking around the lobby, I think we're all trying.
@music stop
@sfx chime
narr: Ding-dong, ding-dong. Every speaker in the lobby crackled at once.
@sfx boom
@shake 12
@music snapjaw
@show snapjaw happy center
snapjaw[happy]: Snap-snap-snap! Good morning, my thirteen survivors! Thirteen! What a lucky number! For me!
snapjaw[normal]: A teensy announcement. As of this morning, the guest wing is *closed for renovations*.
@show pepper angry farleft
pepper[angry]: Renovations?! All my notes are in my room!
snapjaw[happy]: Termites! Enormous ones! Their names are Gerald and Gerald. Your things have been moved. Your NEW home awaits!
snapjaw[happy]: Follow me, please! Single file! No running, no screaming, and no murdering on the stairs. Save it for later!
@hide all
@sfx door
@bg none
@music tension
narr: Behind the reception desk, a panel slid open onto a staircase. A spiral of rough stone, winding down into the dark.
narr: We went down. And down. And further down. The air turned cold and damp, and the walls began to sweat.
think: Two hundred hot springs, and I've never been this far underground. I have a bad feeling about this. A very soggy one.
@sfx hx_drip
narr: Somewhere far below, water dripped. Plip. Plip. Every drop echoed for a long, long time.
@show tumble normal farright
tumble[normal]: Zzz... huff... are we there yet... my knees have filed a complaint... huff...
@show bruno normal farleft
bruno[normal]: Bruno can carry Mr. Tumble.
tumble[happy]: Bless you, sonny. Maybe on the way back up. Pride first, piggyback second.
@hide all
@music stop
@sfx hx_wind
narr: At last the stairs opened into a cavern so huge that the lantern light gave up halfway to the ceiling.
narr: Glowing aqua fungus speckled the rock like a sky full of cold little stars. And below them...
narr: A lake. Wide, flat, and perfectly black. Not a ripple. Not one reflection that looked quite right.
@show lulu shock farleft
lulu[shock]: Lulu doesn't like it. Lulu doesn't like it AT ALL. What's under there? Don't answer that! Lulu-lu...
@show nibs normal farright
nibs[normal]: Hypothetically, an underground lake this size could be centuries old. Fascinating. Horrifying. Mostly fascinating.
@hide all
@sfx hx_chain
@show snapjaw happy center
narr: At the very edge of the water stood a giant brass lever. From its tip, a chain as thick as Bruno's arm ran straight down into the black.
think: It looks like the plug chain of a bathtub. The biggest bathtub in the world.
snapjaw[happy]: Welcome to the *Lower Lake*, my darlings! Isn't she gorgeous? Isn't she wet? Isn't she terribly in the way?
snapjaw[normal]: Your new home is right here. Well. Right UNDER here. Just one small problem to take care of first. Ahem.
narr: He wrapped both claws around the lever and leaned back, grinning with every single tooth.
@shake 8
snapjaw[happy]: *Time to pull the plug!* Snap-snap-snap!
@end
""",
	# =====================================================================================
	"prologue": """
@bg ship_dock
@music stop
@sfx hx_drip
narr: The roar faded away. The whirlpool gave one last enormous GLUG... and then there was only dripping, echoing off the cave walls.
narr: Where the black lake had been, wet mud stretched away under the fungus-light, steaming like the floor of a bath after the plug is pulled.
narr: Out in the middle, a sinkhole the size of a whale yawned in the mud, still burping up the occasional bubble.
narr: And beside a stone dock, streaming with mud and weeds, sat a ship.
think: An old paddle-steamer. Two tall smokestacks. A big red paddle wheel at the back. White-and-teal paint gone grey with grime.
think: It's been sitting at the bottom of that lake this whole time. Under the resort. Under US.
@music snapjaw
@show snapjaw happy center
snapjaw[happy]: Ta-daaa! Feast your eyes, my darlings, on the pride of my fleet! The ONLY ship in my fleet! The *Mudlark*!
snapjaw[happy]: Cabins for everyone! Brass fittings! A saloon! An infirmary! A real working boiler! A view of the mud from every porthole!
@show bruno shock farleft
bruno[shock]: ...Bruno thinks the boat is lying at the bottom of a hole.
snapjaw[angry]: She is RESTING. She is a LADY. Show some respect, you hairy boulder.
@hide bruno
@show duchess shock farright
duchess[shock]: Darling, it is dripping with MUD. And moss. And something is wriggling in that porthole.
snapjaw[normal]: That's Gerald. Don't let him in. He isn't allowed in.
@hide duchess
snapjaw[happy]: From today, the Mudlark is your *new home, sweet home*! Sleep aboard, eat aboard, and who knows... maybe even die aboard!
snapjaw[normal]: New home, new rules! Read them, love them, keep them dry. I'll know if you skim. Snap-snap-snap!
@clue rules2
@show pepper angry farleft
pepper[angry]: Wait. The gangway goes up at night? And cabin doors have *no locks*?! Why on earth are there no locks?
snapjaw[happy]: Fire safety first! I am a very responsible warden. Now then... ALL ABOARD!
@hide all
@bg ship_deck
@music daily
@sfx hx_creak
narr: The gangway clanked down onto the dock. The deck boards creaked under our paws, damp and spongy, but they held.
narr: Paper lanterns swung on lines between the smokestacks. Old lifebuoys hung along the rail. And near the bow...
think: Wait. Is that a wooden onsen tub? On a riverboat? In a cave?
think: Cedar. Hand-joined. Properly deep. Bone-dry and stone-cold, sadly. But whoever built this ship knew their baths. I hate that I'm impressed.
@show nibs happy center
nibs[happy]: A paddle-steamer! Splendid! Allow me to explain how she works. Nobody asked. Allow me anyway.
nibs[normal]: Coal goes into the furnace. The furnace heats the boiler. Steam drives the pistons, and the pistons turn the paddle wheel.
nibs[happy]: Hypothetically, with enough coal, this old girl could steam right out of here! ...If there were any water left to steam on. Hm.
@show zuzu normal farleft
zuzu[normal]: also. cameras. there. there. and there. one on the smokestack. one inside a lifebuoy.
nibs[shock]: Inside a lifebuoy?!
zuzu[normal]: snapjaw logo on every lens. he's not even hiding it. kinda respect it ngl.
@hide all
@show bruno normal left
@show nibs normal right
bruno[normal]: Professor. The boiler makes hot steam. Does the boiler also make the tub warm?
nibs[normal]: Hypothetically, yes. There are pipes under the deck. No coal, no steam. No steam, no hot bath.
bruno[happy]: Then Bruno will *shovel the coal*. Bruno is good at heavy things. Everybody will have warm baths. Bruno promises.
think: Bruno, you beautiful mountain. I could hug you. I won't, because of all the coal that's coming. But I could.
@hide all
@show grub happy left
grub[happy]: And I've already claimed the galley! There's an iron stove in there the size of a carriage! I'm in love. Don't tell my mum.
@show marigold normal right
marigold[normal]: There's a little *infirmary* on the lower deck, too. Dusty, but it'll do. I'll have it *set up* by this afternoon.
marigold[normal]: Old ship, wet planks, thirteen of us. There'll be splinters by suppertime, mark my words. Everybody watch your step.
@hide all
@bg ship_hall
@sfx door
narr: Below deck, a narrow corridor ran along the ship, lit by little brass lamps. Wooden doors lined the walls, each with a brass number.
@show snapjaw happy center
snapjaw[happy]: Cabin assignments! I chose them myself, using a very scientific method. I threw darts at a list.
snapjaw[normal]: This corridor: *Cabin 1, Mochi. Cabin 2, Old Man Tumble. Cabin 3, Pepper Quill.* Everyone else, follow the nameplates!
narr: He dropped a little brass key into my paw. It turned in the lock just fine. The lock just didn't do anything at all.
snapjaw[happy]: Your keys! Purely decorative! Remember Rule 3, my darlings: no locks! Fire safety first! Snap-snap-snap!
@hide snapjaw
@show pepper angry left
@show tumble normal right
pepper[angry]: Hold on. Cabin 3? Next to HIM? These walls are plywood! I'll be sharing a wall with *the snoriest capybara alive*!
tumble[normal]: Zzz... eh? Me? Nonsense. *I'll be quiet as a mouse*, sonny.
pepper[angry]: Sonny?! I'm not a... Look, mister, I've heard you nap! The whole resort heard you nap! The shutters rattled!
tumble[happy]: Everybody's sonny when you're ninety-one, sonny. ...Zzz...
pepper[shock]: He's asleep. Standing up. Mid-argument. Honestly? I'm timing that. That might be a record.
@hide all
think: Cabin 1, right next door to Mr. Tumble. Honestly? I don't mind at all.
think: I like a little white noise. Bathhouse fans, rain on a roof, a good steady snore. It all sounds like somebody's home.
@show snapjaw happy center
snapjaw[happy]: Now, off you go! *Free time until dinner!* Explore! Bond! Snoop! I'll be watching from every lifebuoy!
@sfx door
@hide snapjaw
think: A new cage. A muddier one. But we're all still here. All thirteen of us. Let's keep it that way.
@end
""",
	# =====================================================================================
	"freetime_intro": """
@bg ship_deck
@music daily
@card ABOARD THE MUDLARK | Free Time
think: Free time. On a ship. At the bottom of a drained lake. Under a resort. Run by a caiman. My life has gotten very strange.
think: Everyone's spread out across the Mudlark... claiming cabins, poking into corners, trying very hard not to look at the mud.
think: This ship is big and creaky and full of places to hide. I'd rather know where everyone is. And how they're holding up.
think: I've probably got time for *three visits* before dinner. Choose wisely, Mochi.
@end
""",
	# =====================================================================================
	"freetime_outro": """
@bg ship_deck
@music stop
narr: The cave has no sunset. The fungus on the walls just glowed a little brighter, and the lanterns on deck flickered on, one by one.
think: Up above, it must be evening by now. Down here, it's hard to tell the difference between afternoon and forever.
@sfx chime
snapjaw[happy]: Ding-dong! Attention, passengers! Please gather in the dining saloon at once! I have something for you. Postage paid!
think: Postage? ...I really don't like the sound of that.
@end
""",
	# =====================================================================================
	"hangout_bruno": """
@bg ship_boiler
@music daily
narr: The boiler room was hot, loud and black with dust. The furnace door glowed orange, and a mountain of coal filled one corner.
@show bruno happy center
@sfx hx_thud
narr: SHUNK. A shovelful of coal the size of an armchair flew into the fire. Bruno wiped his brow and left a long black stripe across it.
bruno[happy]: Mochi! Welcome to Bruno's new sauna. It is like the old sauna. But dirtier. And it eats coal.
think: Fifty-five degrees, zero humidity, strong notes of soot. Honestly? Four out of ten. Bruno is glowing like it's a ten.
bruno[normal]: Bruno will shovel *every morning at 6:30*, so the deck tub is warm when everybody wakes up. And at night, Bruno *banks the fire*.
narr: He stomped over to show me the pressure gauges, and the whole floor shook. His boots were enormous. Each one could have been a rowboat.
@choice What should I say?
> Those are some serious boots. -> bruno_boots
> Doesn't the heat bother you? -> bruno_heat
@label bruno_boots
bruno[happy]: *Bruno's boots are size 'mountain'.* The shop did not have mountain. Bruno's little sister sewed two boots into one.
@jump bruno_end
@label bruno_heat
bruno[happy]: No. Bruno likes heat. Heat is honest. You always know where you stand with a furnace. It only wants coal.
@label bruno_end
bruno[normal]: *Coal dust is very bad for boots.* It eats the leather. So Bruno has a *spare pair*, all clean, *drying in the laundry*.
bruno[normal]: Coco taught Bruno that. Look after your gear, and your gear looks after you. Ship-shape, she said.
bruno[sad]: ...Bruno keeps thinking about Coco. And Wisp. Bruno could lift this whole boat. But Bruno could not stop any of it.
narr: He looked down at the shovel in his huge paws for a long moment. Then his grip tightened until the handle creaked.
bruno[sad]: Bruno is very strong, Mochi. Bruno has to be careful. Always careful. Because if Bruno is ever not careful...
mochi: Bruno?
bruno[happy]: ...Hehe. Never mind. Bruno is sweaty and silly. Go have a nice day, Mochi. Bruno will make the bath warm for you.
@flag hung_bruno
@skill iron_hide
@end
""",
	# =====================================================================================
	"hangout_lulu": """
@bg ship_deck
@music daily
narr: Up on the promenade deck, beside the little wooden tub, someone was singing. Something bouncy, with a lot of yo-ho in it.
@show lulu happy center
lulu[happy]: ...yo-ho, yo-ho, a sparkly life for me~! Oh! Mochi! You caught Lulu rehearsing! Was it cute? It was cute, right?
mochi: Very cute. Is that a sea shanty?
lulu[happy]: A sea-shanty POP song! Lulu invented a whole new genre! Shanty-pop! Shan-pop? Pop-tide? Lulu's still workshopping it!
lulu[sad]: ...It's for Coco. She sang shanties in the bath, super loud and super badly. Lulu wanted her to have a good one.
narr: Lulu glanced over the rail. Out past the mud flats, a few pools of black water still glinted in the dark.
lulu[shock]: Eep! Don't look at the water! It's so dark you can't see the bottom! Anything could be down there! A sea monster! A sad eel!
@choice What should I say?
> It's only puddles now. Snapjaw drained it. -> lulu_puddles
> I'll stand between you and the water. -> lulu_guard
@label lulu_puddles
lulu[sad]: That's exactly what a sea monster WANTS you to think, Mochi. Puddles are just lakes in disguise.
@jump lulu_end
@label lulu_guard
lulu[happy]: Aww! Mochi is Lulu's bodyguard! Lulu will make you a tiny sparkly badge! It'll say BODYGUARD! In pink!
@label lulu_end
lulu[normal]: Wisp said to keep the lights on for each other at night. So Lulu's going to be brave and do the opposite of hiding!
lulu[happy]: Tonight, Lulu and Bramble and Fennel are going to *stargaze on the deck*! Well... *fungus-gaze*. There are no stars down here.
lulu[happy]: Bramble says the cave fungus glows super pretty at night, and Fennel wants to paint it. Lulu's bringing snacks and courage!
think: Her paws were still shaking a little. But this time she was smiling anyway. Somehow, that's braver.
lulu[happy]: Okay! From the top! Mochi, you're on backup vocals! Yo-ho, yo-ho~! Lulu-lu~!
@flag hung_lulu
@skill encore
@end
""",
	# =====================================================================================
	"hangout_pepper": """
@bg ship_hall
@music daily
narr: The door of Cabin 3 was propped open with a stack of notebooks. A card pinned to it read: PEPPER QUILL - NEWSROOM - KNOCK FIRST. SCOOPS ONLY.
@show pepper happy center
pepper[happy]: Mochi! Welcome to the Mudlark Gazette, circulation thirteen! You're standing in our headquarters. Also my bedroom.
mochi: Wow. You've really moved in.
pepper[normal]: A reporter needs a base. A desk, a lamp, nine pencils, and the most important tool of the trade...
narr: She whipped something silver out of her pocket and thumbed the button. Click. A tiny dial began to tick.
pepper[happy]: My *stopwatch*! *A journalist times EVERYTHING.* The last trial taught me that. The truth's in the timestamps, partner.
pepper[normal]: Grub's soup: forty-one minutes. Zuzu's longest blink: nine seconds. Bruno apologizing for existing: about every forty seconds.
@choice What should I say?
> Time me holding my breath! -> pepper_breath
> Isn't timing everything exhausting? -> pepper_tired
@label pepper_breath
narr: I puffed out my cheeks. Pepper clicked. I held on for a very respectable while, then let go with a noise like a deflating bath toy.
pepper[happy]: Fifty-two seconds! Nibs says we can do five minutes. You're a disgrace to capybara-kind. Scoop!
@jump pepper_end
@label pepper_tired
pepper[sad]: ...Kind of. But if I'm busy counting seconds, I'm not counting how many of us are left. So. I count seconds.
@label pepper_end
narr: She rapped her knuckles on the wall. Tok, tok. It sounded like knocking on a cracker.
pepper[angry]: And listen to THAT. Plywood! These *walls are paper-thin*! I'll hear every sneeze, every sniffle, every secret on this corridor.
pepper[normal]: Which is great for a reporter. And terrible for a reporter who would like to sleep.
pepper[happy]: Tell you what. You're in Cabin 1, I'm in Cabin 3. If anything weird happens on this corridor, we compare notes. Deal?
mochi: Deal. Co-reporters.
pepper[happy]: Co-reporters! I'll time how long it takes you to regret that. Starting... now! Click!
@flag hung_pepper
@skill scoop_sense
@end
""",
	# =====================================================================================
	"hangout_duchess": """
@bg ship_laundry
@music daily
narr: The ship's laundry was all wash tubs, wet sheets, and a smell like a damp dog wearing an even damper dog.
@show duchess angry center
duchess[angry]: Mochi! Do NOT come in here without a mask, darling. This room is a crime against textiles.
narr: She was holding a long lilac shawl up to the lamp, inspecting every inch of it the way a jeweler inspects a diamond.
duchess[normal]: This is my *lilac shawl*. Silk. *Hand-dyed* by me, with lavender from my mother's window box. *Irreplaceable.*
duchess[angry]: One afternoon on this boat and it already smells of coal. So it hangs here to air, and I stand guard. Like a lioness.
@choice What should I say?
> It's a really beautiful color. -> duchess_color
> Isn't it just a shawl? -> duchess_just
@label duchess_color
duchess[happy]: Isn't it? Lilac is the color of a sunset with standards. Nobody else is permitted to wear it. Ever.
@jump duchess_end
@label duchess_just
@shake 6
duchess[shock]: JUST a shawl?! Darling, the finest painting in the world is just paint. Go and stand in a corner and think about it.
@label duchess_end
narr: She swept over to a wicker *sewing basket* beside the tubs and drew out a pair of long, gleaming *scissors*.
duchess[normal]: At least someone left a sewing basket. Needles, thread, scissors. *For emergencies of fashion.*
narr: Snip. She clipped a single loose thread from the shawl with terrifying precision, then smiled at me over the blades.
duchess[happy]: There. A loose thread is like a loose tongue, darling. Best dealt with quickly.
narr: On a rack by the wall, two enormous boots sat drying side by side, like a pair of beached rowboats.
duchess[angry]: And I must share a room with those monstrosities. Bruno's, I assume. Nothing else on earth is that size.
duchess[normal]: And don't you dare tell the nurse, but *I can't sleep without my sleeping powder*. One pinch a night, since I was a girl.
duchess[sad]: Without it I lie awake for hours, getting sharper and sharper. Like these scissors. Nobody likes me sharp, darling.
duchess[happy]: Now, make yourself useful. Hold this end. No, not like that. LIKE THAT. Better. Barely.
@flag hung_duchess
@skill poise
@end
""",
	# =====================================================================================
	"hangout_bramble": """
@bg ship_deck
@music daily
narr: Near the stern, Bramble knelt by a row of old lifebuoys, patting soft green moss into each one as if she were tucking it into bed.
@show bramble happy center
bramble[happy]: Oh... Mochi... look... the moss came all the way down the stairs with me... in my pockets... it was very brave...
mochi: You're planting... in lifebuoys?
bramble[normal]: They float... and they're round... and nobody was using them... a garden can grow anywhere, if somebody lets it...
narr: She pointed over the rail at the cave wall. Clusters of fungus glowed there, soft and aqua, like tiny lanterns breathing.
bramble[happy]: And these are my new favorites... cave fungus... they make their own light... no sun at all...
bramble[normal]: They're dim now... but they grow brighter as the night goes on... *brightest around eleven*... as if they wait for us to sleep...
@choice What should I say?
> Can I help with the moss? -> bramble_help
> Do mushrooms have feelings? -> bramble_feel
@label bramble_help
bramble[happy]: Oh, yes... gently... like a pillow... there... the moss says thank you... it says it very quietly...
@jump bramble_end
@label bramble_feel
bramble[normal]: Mm... I think they're a little lonely... all that dark... but they glow anyway... that's a sort of feeling, isn't it...
@label bramble_end
bramble[normal]: Lulu and Fennel and I will sit up here tonight and watch them... from a quarter past ten... Fennel wants to paint the glow...
bramble[sad]: I planted something by the bath for Coco, before we came down... something stubborn... I hope it keeps going without me...
bramble[sad]: And Wisp liked the light... so I'll keep these glowing for him... even after what he did... things can be both, I think...
bramble[happy]: Thank you for visiting, little sprout... come and watch the glow tonight, if you can't sleep... the moss would like that...
@flag hung_bramble
@skill deep_roots
@end
""",
	# =====================================================================================
	"hangout_nibs": """
@bg ship_saloon
@music daily
narr: In a corner of the dining saloon, Professor Nibs had set up a chessboard and was glaring at it like it owed him money.
@show nibs normal center
nibs[normal]: Ah, Mochi. Hypothetically speaking: if a knight moves in an L, why can't a bishop move in an M? Discuss.
mochi: Because... M isn't a direction?
nibs[happy]: Precisely the small thinking that loses chess games. I'm practicing. Tonight, I *challenge Zuzu to an all-night match*.
nibs[normal]: Right here in the saloon. From after dinner until one of us collapses. They claim to have a 'rating'. I have a doctorate.
@show zuzu normal farright
zuzu[normal]: i also have a doctorate. in being better at chess than you.
nibs[angry]: That isn't a real doctorate!
zuzu[happy]: neither is yours lol. see you after dinner, prof.
@hide zuzu
@choice What should I ask?
> Any fun facts about the ship? -> nibs_ship
> Any fun facts about capybaras? -> nibs_capy
@label nibs_ship
nibs[happy]: Paddle-steamers were nicknamed floating wedding cakes, for all the white trim. This one is more of a floating mud pie.
@jump nibs_end
@label nibs_capy
nibs[happy]: Gladly! We chatter, click, bark and purr. Yes, purr! You were purring at that onsen tub earlier. Don't deny it.
@label nibs_end
nibs[normal]: Another fact: our ears are tuned for *low sounds*. Rumbles. Hums. Grumbling stomachs. *We hear low sounds well*, and from far away.
narr: Somewhere deep below us, the boiler gave a long, low rumble. I heard it clearly, two whole decks away. Nibs raised a finger. Point proven.
nibs[sad]: ...I keep looking for a fact that explains what happened at the trial. Why someone would... There isn't one. So I play chess.
nibs[normal]: Chess has rules, Mochi. Every piece is in plain sight. Nobody hides a knight up their sleeve. It is the most honest game there is.
nibs[happy]: Now go. I must memorize three hundred openings before dinner. Hypothetically, two hundred. Fine. Eleven.
@flag hung_nibs
@skill hypothesis
@end
""",
	# =====================================================================================
	"hangout_zuzu": """
@bg ship_purser
@music daily
narr: Behind a door marked PURSER was a cramped little office: a desk, a dusty safe, a saggy armchair, and Zuzu, poking at something brass.
@show zuzu happy center
zuzu[happy]: mochi. c'mere. look at this absolute unit.
narr: On the desk sat a contraption with a big brass horn flaring out of the top, like a trumpet that had swallowed a tuba.
zuzu[normal]: the *Echo-Matic*. snapjaw brand. it's a dictaphone. records sound onto wax. like a voice memo, but it's 1890.
narr: Zuzu slid a little wax cylinder out of a rack on the wall, slotted it into the machine, leaned into the horn, and said, very seriously:
zuzu[normal]: lol.
@sfx tick
narr: A flick of a switch. The cylinder spun, the needle scratched, and the horn blasted it back, ten times louder and crackly as a campfire: LOL.
@shake 4
mochi: Gah! It's so loud!
zuzu[happy]: right?? the horn's an amplifier. old-school speaker. no electricity. just vibes and physics.
zuzu[normal]: specs. *each cylinder holds 4 minutes*. this is the *REPEAT lever*. flip it and it plays the same cylinder over and over.
zuzu[normal]: and you crank the spring here. *one winding runs two hours*. no batteries. no wifi. boomer tech. kinda goated tho.
@choice What should I do?
> Record something myself. -> zuzu_rec
> What would you even loop for two hours? -> zuzu_loop
@label zuzu_rec
zuzu[happy]: go for it. lean in. speak from the diaphragm.
mochi: Um... hello?
narr: The horn blared it straight back: HELLO? My voice cracked right in the middle. Preserved forever, in wax.
zuzu[happy]: lmao. this is the best day of my life.
@jump zuzu_end
@label zuzu_loop
zuzu[normal]: lofi beats. a cat purring. nibs saying 'hypothetically' on repeat to annoy nibs. the possibilities are endless.
@label zuzu_end
zuzu[normal]: nobody locks this office btw. no locks anywhere on this boat. *anyone could borrow it*. i might. for science.
zuzu[sad]: ...it's nice tho. old machines. you know exactly what they'll do. no surprises. no lying.
zuzu[happy]: ok. putting the cylinder back in the rack. future historians will study this moment. you're welcome.
@flag hung_zuzu
@skill autocomplete
@end
""",
	# =====================================================================================
	"hangout_reginald": """
@bg ship_deck
@music daily
narr: At the rail of the promenade deck, Sir Reginald was fencing a mop. The mop was winning.
@show reginald angry center
@shake 5
reginald[angry]: Have at thee! Parry! Riposte! ...Unhand my beret, you stringy villain! ...Ah. Mochi. Good afternoon.
mochi: Is that... a mop?
reginald[sad]: From the broom cupboard. The Captain fought with a mop, you see. I thought I should learn how it felt to lose to one.
reginald[normal]: She mopped me three times. Three! I shall practice until I can take a single point off her memory.
@choice What should I say?
> She'd be proud of you, Reginald. -> reg_proud
> Want me to hold the mop? -> reg_hold
@label reg_proud
reginald[sad]: ...Proud. Hm. She'd laugh first. Then she'd call me Reggie. Then, perhaps, proud. I should like that very much.
@jump reg_end
@label reg_hold
narr: I held up the mop like a sword. Reginald took one look at me, lunged, and stopped a whisker short of my yuzu.
reginald[happy]: Ha! Touche! ...You are a far less frightening mop than the Captain was. That is not a compliment, Mochi.
@label reg_end
reginald[normal]: Now, attend. I have appointed myself the *ship's night watch*. *In the Captain's honour.* Every night, I shall patrol.
reginald[happy]: Corridors! Deck! Gangway! No scoundrel shall creep about this vessel while Sir Reginald Puddlesworth the Third keeps watch!
mochi: All night? Won't you get tired?
reginald[normal]: Tired? A Puddlesworth does not get tired. A Puddlesworth merely... rests his eyes. Momentarily.
reginald[sad]: ...Very well. Honesty, as the Captain liked it. *I always fall asleep by half past ten.* Every night of my life. Out like a candle.
reginald[happy]: But until half past ten, I shall be MAGNIFICENT. And after that, I shall be magnificent with my eyes closed.
@flag hung_reginald
@skill en_garde
@end
""",
	# =====================================================================================
	"hangout_grub": """
@bg ship_saloon
@music daily
narr: Through the hatch behind the saloon, the galley steamed like a happy kettle. Grub stood in the middle of it, stirring three pots at once.
@show grub happy center
grub[happy]: Mochi! Get in here! Quick, taste this. Tomato soup for tonight. Thick enough to stand a spoon in. Literally. Look.
narr: He let go of the spoon. It stood straight up in the soup. Then, very slowly, it began to sink.
mochi: Wow. That's... honestly delicious.
grub[happy]: Ha! The stove on this tub is a beauty. Coal-fired! Bruno shovels, I sizzle. Teamwork makes the dream work!
grub[normal]: And tomorrow there's bread. Fresh every morning. I'm *up at 6 AM sharp* to start the dough. Bread waits for no capybara.
@choice What should I say?
> Six?! Don't you ever sleep in? -> grub_sleep
> You've been tasting a lot of this, huh? -> grub_taste
@label grub_sleep
grub[happy]: Sleep in? Mum had me kneading dough before I could walk. My paws wake up at six even when the rest of me doesn't.
@jump grub_end
@label grub_taste
grub[sad]: ...Maybe. A little. Seven bowls. Eight? Quality control is a very dangerous job, Mochi.
@label grub_end
grub[sad]: Ooh. Ugh. My tummy. I *ate way too much* today. When I'm scared I cook, when I cook I taste, and then I'm this.
grub[normal]: Marigold says she'll *bring me a tummy tonic tonight*. *Half past ten*, she said. Then straight to bed. No midnight snacks.
narr: His face did something complicated. Like a pudding trying to frown.
grub[angry]: No midnight snacks! Ever! She confiscated my *emergency cheese*, Mochi. From my HAT. Who searches a chef's hat?!
grub[angry]: Honestly, sometimes that nurse is so bossy I could just... just...
narr: He squeezed a lump of dough in his fist until it oozed out between his fingers. Then he looked down at it, and laughed.
grub[happy]: ...Bake her a cake. Ha! I could just bake her a cake. She's right, of course. She always is. Don't tell her I said that.
@flag hung_grub
@skill comfort_food
@end
""",
	# =====================================================================================
	"hangout_tumble": """
@bg ship_purser
@music daily
narr: In the purser's office, a lumpy grey blanket was snoring in the armchair. On closer inspection, it was Old Man Tumble.
@show tumble normal center
tumble[normal]: Zzz... hrrnk... zzz... hrrk!
narr: In the middle of a snore came a funny little squeaky cough, like a rubber duck clearing its throat. Then more snoring.
mochi: Mr. Tumble? Sorry... are you sleeping?
tumble[shock]: Eh? Wha? No, no. Just checking the insides of my eyelids for leaks. All clear. Who's that? Oh, the fruit-hat kiddo.
tumble[happy]: Pull up a crate. Best room on the boat, this. *Quietest room on the boat.* No boiler, no saloon, no Pepper.
mochi: Grub was looking for you earlier. Something about peeling potatoes?
tumble[happy]: Was he now. Was he now. Then I'd best stay asleep a while longer. *Sleep is the best alibi for getting out of chores, sonny.*
think: That is... not what alibi means. Probably. I decided not to argue vocabulary with a ninety-one-year-old.
@choice What should I say?
> You'd love the tub on deck, Mr. Tumble. -> tumble_tub
> Where's home for you, Mr. Tumble? -> tumble_home
@label tumble_tub
tumble[normal]: Cedar, is it? Hm. Pretty enough. Not a patch on mine, mind you. Let me tell you about mine.
@jump tumble_end
@label tumble_home
tumble[normal]: Little village, up where the river bends. Nothing much there. Except my hot spring, kiddo. Let me tell you about my hot spring.
@label tumble_end
narr: His half-closed eyes drifted somewhere very far away.
tumble[happy]: *Built it with my own paws*, sixty years ago. *A little stone tub*, round as a teacup. One stone at a time. Took me all summer.
tumble[happy]: Nothing fancy. No yuzu, no foam cushions. Just warm water coming up out of the ground, right where it wanted to. *Warm as a hug.*
tumble[normal]: Whole village soaks in it now. Kids splash about. Old fools like me fall asleep in it. Somebody always fishes me out.
think: I've rated two hundred hot springs. I've never heard anyone talk about one like that. I'd give it a ten without even seeing it.
tumble[normal]: ...Say, kiddo. Stay a minute, would you? Keep an old capybara company while he naps. Nobody should nap alone in a place like this.
narr: So I sat on a crate and kept him company. He was snoring again before I'd even finished sitting down.
@flag hung_tumble
@skill power_nap
@end
""",
	# =====================================================================================
	"hangout_marigold": """
@bg ship_infirmary
@music daily
narr: The infirmary was tiny, but already spotless. Labeled bottles in neat rows, a cot with tight corners, a little kettle on a burner.
@show marigold happy center
marigold[happy]: Mochi! Come in, come in. Mind the doorstop. Everyone trips on it. Bruno tripped on it twice and apologized to it both times.
narr: Holding the door wide open was a heavy brass *anchor doorstop*, its flukes polished to a shine.
marigold[normal]: I keep the door open so I can hear if anybody calls. That old anchor *weighs a ton*. *I can barely lift it.*
@choice What should I do?
> Try lifting the anchor. -> mari_lift
> Sit on the cot like a good patient. -> mari_cot
@label mari_lift
narr: I grabbed it with both paws and heaved. It came up a few inches, wobbling, and I put it down again very fast. Clunk.
marigold[shock]: Mochi! Lift with your legs! Do you want to be my first patient? ...Second. Bruno got a splinter.
@jump mari_end
@label mari_cot
marigold[happy]: A model patient! Tongue out. Ah. Lovely. Perfectly healthy, if a little pale. Drink some water.
@label mari_end
narr: She picked up a clipboard from the desk. Neat columns of tiny, careful handwriting filled the top page.
marigold[normal]: This is my *rounds log*. *I write down every visit.* Who, when, what I gave them. I even write down when I put the kettle on.
marigold[happy]: Old habit from the night shift. If it isn't written down, it didn't happen! See? '2:15 PM, Bruno, splinter. Very brave.'
marigold[normal]: Tonight's rounds: *10:30 PM, Grub's tummy tonic.* He's been taste-testing all day. Then back here and *kettle on*...
marigold[normal]: ...and at *11:00 sharp*, I bring *chamomile to Mr. Tumble*, for his old joints. Doctor's orders. Well, nurse's orders.
marigold[happy]: *He never wakes up for it, bless him.* I leave the cup on his nightstand, and he finds it in the morning.
marigold[sad]: ...Somebody has to look after people here, Mochi. I couldn't help Coco. I was too late. I won't be too late again.
marigold[happy]: So! Water, sleep, and come straight to me if anything hurts. Inside or out. Nurse's orders.
@flag hung_marigold
@skill first_aid
@end
""",
	# =====================================================================================
	"hangout_fennel": """
@bg ship_saloon
@music daily
narr: Fennel had set up his easel in the middle of the dining saloon and was painting it. All of it. Every lamp, every porthole, every chair.
@show fennel happy center
fennel[happy]: Mochi! Mon ami! Stand there. No, there. You are blocking the piano, which is good. The piano is ugly.
mochi: You're painting the whole saloon?
fennel[normal]: I am painting the Mudlark. Every room. A ship is a face, Mochi. It has wrinkles, scars, and secrets. I paint them all.
fennel[happy]: Earlier I painted the purser's office! So small! And on the wall, *a little rack of brass-capped wax cylinders*, all in a row...
fennel[happy]: ...*like jars of jam* in my grandmother's pantry! *Magnifique!* I do not know what they are for. I do not care! They are beautiful!
@choice What should I say?
> Can I see the painting? -> fennel_see
> Shouldn't you paint something cheerful? -> fennel_cheer
@label fennel_see
fennel[angry]: Non! It is not finished! ...Very well. One peek. With one eye. The left one.
narr: The saloon glowed on the canvas: brass lamps, portholes, the long table. And two chairs at the end of it, painted empty.
@jump fennel_end
@label fennel_cheer
fennel[sad]: Cheerful? In a ship at the bottom of a hole? Mochi, I paint what is there. ...Look. Two chairs at the end of the table.
narr: On the canvas, two chairs at the end of the long table stood empty. Fennel had painted every one of the others with someone in it.
@label fennel_end
fennel[sad]: ...Coco's chair, and Wisp's. To paint them full would be a lie. To leave them out would be worse.
fennel[normal]: A true artist paints what is there, Mochi. Even when it hurts. Especially then.
fennel[happy]: Now, hold still! I am adding you. Your yuzu is the brightest thing on this whole gloomy ship. Do not move. Do not breathe!
mochi: Can I blink?
fennel[angry]: Blinking is for amateurs! ...Fine. One blink. Make it a good one.
@flag hung_fennel
@skill artists_eye
@end
""",
	# =====================================================================================
	"motive": """
@bg ship_saloon
@music snapjaw
@card 5:00 PM | The Dining Saloon
narr: By five o'clock, all thirteen of us were crammed into the dining saloon. Nobody sat down. The brass lamps buzzed overhead.
@sfx boom
@shake 10
@show snapjaw happy center
snapjaw[happy]: Snap-snap-snap! Good evening, my darling deckhands! How do you like your new home? Muddy? Cozy? Haunted?
@show reginald angry farleft
reginald[angry]: Out with it, lizard. Whatever cruelty you have planned, say it, and spare us the theatrics.
snapjaw[angry]: CAIMAN! And the theatrics are the BEST part! ...Fine. A whole day aboard, and still nobody has checked out. Tsk, tsk.
snapjaw[happy]: You all look so homesick! So I had the post office send you a little something. Mail call!
@hide reginald
@sfx whoosh
@shake 6
narr: A hatch in the ceiling sprang open, and a flurry of postcards fluttered down over the table. Each one had a name on the back.
snapjaw[happy]: *Postcards from Home!* Lovely pictures of the places you love most! Read them. Treasure them. Weep on them, ideally.
@hide all
@music tension
narr: Mine landed face-up in front of me. A little hot spring beside a river, ringed with smooth stones and wild mint.
think: That's... that's where I had my very first soak. I was so small that Grandma had to hold me up by the scruff. I've loved baths ever since.
narr: In the photo, a huge cement mixer was backing up to the water, its drum already turning.
narr: On the back, in loopy green ink: *Wish you were here! In 3 days, this spring gets filled with concrete. Unless someone checks out!*
think: Concrete. They're going to pour concrete into it. My first spring, gone, like it was never there at all.
@show lulu sad farleft
narr: Across the table, Lulu was crying. Not idol crying. Real crying, the hiccupy kind.
lulu[sad]: That's Miss Pip's music school... she taught Lulu every song Lulu knows... they're boarding up the windows... Lulu-lu...
@show duchess angry farright
duchess[angry]: Absolutely not.
@shake 8
narr: The Duchess stared at her postcard for exactly one second. Then she tore it in half. Then into quarters. Then into confetti.
duchess[angry]: There. Nobody threatens what is mine, darling. NOBODY.
@hide all
@show reginald normal farleft
narr: Reginald slid his postcard into his fencing jacket without turning it over.
reginald[normal]: I shan't look. The Captain called these things bait. A Puddlesworth does not bite.
reginald[sad]: ...Though my paw is shaking rather badly. Pay it no mind.
@show bruno sad farright
bruno[sad]: ...Bruno's little sister. Her flower stall. A bulldozer. She is standing right in front of it in the picture.
bruno[sad]: Bruno would do anything for her. ...Anything.
narr: He folded the postcard very small, put it away very carefully, and didn't say another word.
@hide all
@show grub sad farleft
grub[sad]: Mum's restaurant. There's a wrecking ball outside it. With a little Snapjaw face painted on the ball.
@show pepper angry farright
pepper[angry]: The Daily Puddle's printing press! My first newsroom! They're going to melt it down into paperweights!
@hide all
@show nibs sad farleft
nibs[sad]: My old laboratory. Hypothetically, a fire hose that size could flood it in under a minute. I would rather not have done that math.
@show zuzu sad farright
zuzu[sad]: my mom's basement. my first server rack's down there. they're bringing a hose. ...not funny.
@hide all
@show tumble normal center
narr: At the end of the table, Old Man Tumble had nodded off in his chair, his postcard face-down on his belly, rising and falling with every snore.
@show grub normal farleft
grub[normal]: ...Honestly? Lucky. I wish I could sleep through this.
@hide all
@show snapjaw happy center
snapjaw[happy]: Three days, my darlings! Tick-tock, tick-tock! *Only someone who checks out can save their precious home!*
snapjaw[happy]: And last time, you managed it in under a day! I have such high hopes! Snap-snap-snap!
@sfx door
@hide snapjaw
@music stop
narr: The ceiling hatch snapped shut. For a long moment, nobody made a sound.
@show marigold normal center
marigold[normal]: ...Everyone. Look at me, please. Not at the postcards. At me.
marigold[normal]: Deep breath in. Hold it. And out. Good. Once more.
marigold[sad]: He wants us frightened and alone. So we'll be neither. Dinner at eight, all of us, at this table. That isn't a request.
@show reginald normal farleft
reginald[normal]: Hear, hear. And the Captain had us all state our plans at supper. We shall do the same tonight. Nobody creeps about unseen.
@hide all
think: I folded my postcard and put it in my hoodie pocket, picture side in. I could still feel it there, like a little cold stone.
think: Three days. Concrete. ...Nobody's going to do anything. Right?
@end
""",
	# =====================================================================================
	"evening": """
@bg ship_saloon
@music daily
@card 8:00 PM | Dinner in the Saloon
narr: Under the brass lamps, the long table was crowded with fresh bread, roasted roots, and a cheese board suspiciously light on cheese.
@show grub happy center
grub[happy]: Soup's on! Tomato, thick enough to stand a spoon in! Nobody's allowed to be sad on an empty stomach. Chef's rules!
think: After those postcards, nobody felt hungry. Then the smell hit us, and everybody felt a little bit hungry. Grub is a wizard.
narr: Grub swept around the table with the big pot, ladling as he went... right up until his foot caught on something enormous.
@show bruno shock farleft
@sfx splash
@shake 12
@show duchess shock farright
narr: SPLOOSH. A great red wave of tomato soup leapt out of the pot and landed, with a heavy splat, all over the Duchess's *lilac shawl*.
duchess[shock]: ...
duchess[angry]: GRUB. PEMBERTON.
grub[shock]: Oh no. Oh no no no! I'm so sorry, Duchess! I tripped! There was a foot! A huge foot! It came out of nowhere!
bruno[sad]: ...Bruno's foot does not come out of nowhere. Bruno's foot is always there. Bruno is sorry too.
duchess[angry]: Hand-dyed. Irreplaceable. And now it smells like a pizza. I shall rinse it and *hang it in the laundry to dry* the moment we're done.
duchess[angry]: And if anyone so much as breathes on it while it hangs there, darlings, I will know.
@hide all
@show marigold normal left
@show duchess angry right
marigold[normal]: Duchess, while you're dabbing. That little silver tin peeking out of your purse. That's your sleeping powder, isn't it?
@ifnot hung_duchess -> powder_known
duchess[angry]: Mochi! I told you that in confidence, darling!
mochi: I didn't say a word! I promise!
marigold[normal]: They didn't, dear. I could see it in your eyes at lunch. I'm a nurse.
@jump powder_go
@label powder_known
duchess[normal]: ...How do you know about my powder?
marigold[normal]: Your eyes at lunch, dear. I'm a nurse. I notice these things.
@label powder_go
marigold[normal]: May I? ...Oh. Oh, goodness, no. This is *far too strong, dear*.
narr: Marigold snapped the little tin shut and tucked it into the pocket of her scrubs.
marigold[normal]: I'm confiscating this. *Doctor's orders.* Well, nurse's orders. I'll mix you something gentler tomorrow.
@sfx shout
@shake 14
duchess[angry]: Give that BACK! You have no right! I haven't slept a single night without it since I was a girl!
marigold[sad]: Then tonight will be the first, I'm afraid. I would much rather you were cross with me than didn't wake up.
duchess[angry]: *You'll regret meddling with me, nurse!*
narr: The whole saloon went silent. Even the soup stopped dripping.
duchess[normal]: ...Hmph. I shall be in *my cabin*. *Alone*. *Unable to sleep, thanks to SOME people.*
@hide all
@show reginald normal center
reginald[normal]: ...Ahem. Friends. The Captain had us announce our plans at supper, so nobody could creep about unseen. Let us do the same.
reginald[happy]: I shall begin. Tonight I am the *ship's night watch*! Patrolling the decks *alone*, in the Captain's honour!
@if hung_reginald -> reg_known
@show zuzu normal farleft
zuzu[normal]: all night?
reginald[sad]: ...Until roughly *half past ten*. At which point I shall... rest my eyes. Briefly. With honour.
@jump reg_done
@label reg_known
mochi: Until half past ten, right?
reginald[angry]: Mochi! That was told in confidence! ...Yes. *Until roughly half past ten.* Then I rest my eyes. With honour.
@label reg_done
@hide all
@show marigold normal center
marigold[normal]: My turn. At *10:30* I'm bringing Grub his *tummy tonic*. Then it's back to the infirmary to put the *kettle on*...
marigold[normal]: ...and at *11:00 sharp*, *chamomile for Mr. Tumble*, for his joints. Then bed. My door is always open if anyone needs me.
@ifnot hung_marigold -> mari_done
mochi: And it all goes in the rounds log, right?
marigold[happy]: Every word! If it isn't written down, it didn't happen. You were listening! Bless you, Mochi.
@label mari_done
@hide all
@show grub normal left
grub[normal]: And after my tonic, it's *straight to bed* for me. I'm *up at six* to bake tomorrow's bread. Bread waits for no capybara.
grub[sad]: ...And no midnight snacks, apparently. Not that anybody left me any cheese to snack ON.
@show bruno normal right
bruno[normal]: Bruno's *spare boots* are *drying in the laundry*. Bruno will bank the fire, then *go to bed early*.
bruno[sad]: In Bruno's cabin. *Alone*. ...Bruno does not want to talk to anybody tonight. Bruno is sorry.
@hide all
@show nibs happy left
@show zuzu happy right
nibs[happy]: Zuzu and I will be right here in the saloon, playing chess. *All night*, if necessary. And it will be necessary.
zuzu[happy]: it won't. but sure. *all-nighter*. you bring the snacks. i'll bring your defeat.
@hide all
@show lulu happy farleft
@show bramble happy center
@show fennel happy farright
lulu[happy]: And Lulu and Bramble and Fennel are going *fungus-gazing on the deck*! *From 10:15!* Lulu's bringing blankets and snacks!
bramble[happy]: The glow is brightest around eleven... we'll stay until *half past*, maybe... the moss gets sleepy after that...
fennel[happy]: And I shall paint it! Glowing fungus by lantern light! *Magnifique!* Nobody will believe it is real!
@hide all
@show pepper normal left
pepper[normal]: Me? *In my cabin, writing my scoop.* The Mudlark Gazette doesn't write itself. *Unless SOMEONE snores.*
@show tumble normal right
tumble[normal]: Zzz... bed. Early. Very early.
pepper[angry]: That wasn't a plan. That was sleep-talking!
@hide all
@show reginald normal center
reginald[normal]: And you, Mochi?
mochi: Honestly? I can barely keep my eyes open. I'm going straight to Cabin 1. Bed. Done.
reginald[happy]: Splendid! Then all are accounted for. Nobody creeps about this ship tonight without *somebody* knowing.
reginald[normal]: *Nighttime begins at ten*, and the gangway goes up. Stay in your cabins or with your companions. And tomorrow, breakfast. All of us.
all: All of us.
@hide all
think: Thirteen plans. Thirteen... alibis. No. I'm doing it again. They're just plans.
think: Tonic at 10:30. Chamomile at 11. Chess in the saloon, fungus on the deck, Reginald on watch until he isn't.
think: Everyone accounted for. Everyone where they said they'd be. ...So why can't I shake the feeling that the whole ship is listening?
@end
""",
	# =====================================================================================
	"night": """
@bg ship_cabin
@music stop
@card 10:00 PM | Cabin 1
narr: My cabin was barely bigger than a bathtub. A bunk, a lamp, a little brass clock, a porthole full of cold aqua glow. And a door with no lock.
think: Fire safety first. Thanks, Snapjaw. I stared at that door for a long time.
@sfx chime
snapjaw[happy]: Ding-dong! Attention, passengers! It is now *10:00 PM*. Nighttime is in effect! The *gangway is now raised*!
snapjaw[normal]: Nobody on, nobody off, until 7 AM. Sleep tight, and don't let the Geralds bite! Snap-snap-snap!
@sfx hx_creak
narr: Outside, chains rattled and something heavy groaned upward. Then the whole ship settled, creaking, into the dark.
think: Okay. Lamp off. Big day. Sleep, Mochi.
narr: I'd barely pulled the blanket up when it started, right through the wall from Cabin 2.
narr: SNNNRRRK... hhhhh... SNNNRRRK... hhhhh...
think: Wow. Mr. Tumble really does fall asleep fast.
narr: It was loud. Loud and steady, like a little boat engine chugging away on the other side of the plywood.
narr: And every now and then, in the middle of it, a funny little squeaky cough. Hrrk! Like a rubber duck clearing its throat.
think: Pepper was right. These walls really are paper-thin. It's like he's snoring in the bunk right next to mine.
think: ...Honestly, though? It's kind of nice. A bathhouse fan. Rain on a roof. A good snore. All the best white noise sounds like home.
@music sad
narr: I lay on my back and watched the fungus-light swim slowly across the ceiling.
think: The postcard was still in my hoodie pocket. I didn't take it out. I didn't need to. I could see it with my eyes closed.
think: The little spring by the river. The mint. Grandma's paws holding me up. And a cement mixer, backing up to the water.
think: Is everyone else lying awake thinking about their postcard right now? ...Probably all of us.
narr: SNNNRRRK... hhhhh... Hrrk! ...SNNNRRRK... hhhhh...
think: There it is again. *The same little cough.* I've started waiting for it, like the chorus of a song.
think: Somewhere in there, I wondered if Marigold had dropped off Tumble's chamomile yet. If she had, I didn't hear a thing over the snoring.
think: So I counted snores instead of sheep. Fifty. A hundred. Two hundred. I lost count somewhere in the hundreds.
narr: Time went slow and syrupy in the dark. The hum of the ship. The tick of the little clock. And the snoring, on and on and on.
@music stop
@wait 1.0
narr: ...And then, *around midnight*, it simply stopped.
narr: Silence. No snores. No creaks. Just the faint, far-off drip of the cave, and the little brass clock, ticking past twelve.
think: Huh. He must have finally rolled over.
mochi: ...Goodnight, Tumble.
narr: I turned to the wall, pulled the blanket over my ears, and fell asleep almost before I'd finished the thought.
@end
""",
	# =====================================================================================
	"discovery": """
@bg ship_cabin
@music stop
@sfx chime
snapjaw[happy]: Ding-dong! Good morning, passengers! It is now 7:00 AM! Nighttime is over, and the gangway is down! Rise and shine!
@card 7:00 AM | The Next Morning
think: Morning already? I slept like a stone. A stone at the bottom of a drained lake, but still.
@sfx hx_slam
@shake 12
narr: CRASH! Somewhere below, something clattered to the floor. Plates. A lot of plates. And then a scream.
voice: AAAAH! No! No, no, no, NO!
think: That came from the lower deck!
@bg ship_hall
@show pepper shock right
narr: I burst out into the corridor. Pepper's door flew open at the same moment, her press cap on backwards, stopwatch still in her paw.
pepper[shock]: You heard that too?! That was Grub! Lower deck! Move, move, move!
@hide all
@bg ship_infirmary_body
@wait 0.6
narr: We clattered down the stairs and skidded to a stop at the infirmary. The door hung open, creaking on its hinges.
@show grub shock left
narr: Grub stood in the doorway, frozen. At his feet lay a dropped breakfast tray: a smashed cup, a plate, and two slices of toast, butter-side down.
grub[shock]: I... I was bringing her breakfast... cinnamon toast, crusts off... for looking after my tummy... I knocked, and... she's...
narr: Inside, a kettle sat on the little burner, scorched black and boiled bone-dry. And on the floor beside the cot...
think: Light-blue scrubs. A white nurse cap with a green cross, lying on its side a little way off.
think: No. Not her. Please, not her.
@show pepper shock right
pepper[shock]: M-Marigold?!
@sfx heartbeat
narr: Marigold Fern lay on the floor beside her cot, face-down and perfectly still. She didn't stir when Pepper said her name. She didn't stir at all.
@hide all
@sfx body_found
@music tension
@shake 14
@flash #ff4f6d
@card A BODY HAS BEEN DISCOVERED!
snapjaw[happy]: Ding-dong! Oh dear, oh dear! A body has been discovered! All passengers, please report to the infirmary! Chop-chop!
narr: Paws thundered on the stairs. One by one, the others crowded into the narrow passage outside the infirmary.
@show lulu shock farleft
@show reginald shock farright
lulu[shock]: Marigold? Marigold! Get up! You have to get up! You're the nurse! You're the one who makes everybody else get up!
reginald[shock]: No... I was on watch. I was ON WATCH. And I... I fell asleep. Half past ten. Out like a candle...
@hide all
@show duchess shock center
duchess[shock]: The nurse...? But I... last night, I said... oh. Oh, darlings, I don't feel well at all...
narr: The Duchess's eyes rolled up, and she toppled over backwards like a felled tree in a feathered hat.
@show bruno sad farleft
@shake 6
narr: Bruno caught her one-pawed before she hit the floor. His fur was black with coal dust, and he left two sooty pawprints on her cream shoulders.
bruno[sad]: ...Bruno has her. Bruno has her.
@hide duchess
@show pepper angry farright
pepper[angry]: Hold on. Bruno. *Why are you covered in coal?*
bruno[normal]: ...Bruno *shovels coal at 6:30 every morning*. For the tub. Bruno told everybody.
pepper[angry]: I'm not accusing anybody! I learned my lesson! I'm just... noting it. With a timestamp.
@hide all
@show grub sad farleft
grub[sad]: She brought me my tonic last night. Half past ten, right on time. She told me off about the cheese. She was fine. She was FINE.
@show tumble sad farright
tumble[sad]: ...Eh? What's all the... oh. Oh, no. Not the nurse. Not our nurse.
@hide all
@show nibs sad farleft
nibs[sad]: Hypothetically... no. I'm finished with hypothetically. This is the second time I've stood in a doorway like this.
@show zuzu sad farright
zuzu[sad]: ...she made me drink water like four times yesterday. i never even said thanks.
@hide all
@show bramble sad farleft
bramble[sad]: Oh... she smelled of lavender soap and clean cotton... like a garden first thing in the morning...
@show fennel sad farright
fennel[sad]: Her cap... lying there on its side... Non. I will not paint this. For once in my life, I will not.
@hide all
@music sad
think: Marigold. Who checked everyone's temperature. Who made us drink water. Who promised she'd never be too late again.
think: Yesterday she told me to come to her if anything hurt. Inside or out. And now...
@sfx boom
@shake 16
@music snapjaw
@show snapjaw happy center
snapjaw[happy]: Snap-snap-snap! Another full house! You lot really know how to make a warden proud!
@show reginald angry farleft
reginald[angry]: Proud?! She was the kindest of us all! She cared for every one of us, and you put that postcard in someone's paw!
snapjaw[normal]: I only deliver the mail, Sir Fencer. I don't do the dirty work. One of YOU did that.
@hide reginald
snapjaw[happy]: Investigation time! Here's your *Snapjaw File #2*. Everything my sensors know about our dear departed nurse!
@clue snapjaw_file2
snapjaw[normal]: And do remember Rule 2! The *gangway was raised all night*. Nobody got on, nobody got off. The culprit is *aboard this ship*.
snapjaw[happy]: Snoop wherever you like! When you're done, I'll call you down for Splash Trial number two! Snap-snap-snap!
@sfx door
@hide snapjaw
think: Marigold spent every moment here looking after us. Now it's our turn to look after her, the only way we have left.
think: Somebody on this ship knows exactly what happened in this room last night. ...And I'm going to find out who.
@end
""",
	# =====================================================================================
	"epilogue": """
@bg ship_deck
@music sad
narr: When it was over, we came back to the Mudlark. Nobody remembers the walk. Eleven capybaras, where this morning there had been thirteen.
narr: Nobody wanted to go below deck. So we sat up top, under the paper lanterns, around the little wooden tub. Bruno had kept it warm. Nobody got in.
think: Fifteen. Then thirteen. Now eleven. I keep counting. I can't make myself stop.
narr: Nobody looked toward the stern, where the big red paddle wheel stood still in the dark.
@show grub sad center
narr: Grub sat hunched on an upturned crate with a tea towel over his face. He hadn't stopped crying since the trial.
grub[sad]: I found her. I was bringing her toast. Cinnamon, crusts off, the way she likes it... liked it... and she was just lying there...
grub[sad]: And all evening I'd been grumbling about my cheese. My stupid cheese. She was only looking after me. She looked after everybody.
@show bruno sad farleft
narr: Bruno sat down beside him, very carefully, so the deck wouldn't tilt, and rested one enormous paw on his back.
bruno[sad]: ...Grub can cry. Bruno will sit. Bruno is very good at sitting.
@hide all
@show duchess sad center
narr: The Duchess stood at the rail with her lilac shawl folded over one arm. One corner was gone, cut clean away.
duchess[sad]: ...She was right, you know. About my powder. I lay awake all night, furious with her. I said she'd regret it. In front of everyone.
duchess[sad]: And she only took it because she was afraid I wouldn't wake up. She was looking after me, darlings. Even me. Even when I was horrid.
duchess[normal]: Tomorrow, I shall drink whatever gentle nonsense she would have mixed for me. Every drop. For her.
@hide all
@show pepper sad center
narr: Pepper opened her notebook to a page covered in neat little columns of times. She looked at it for a long moment.
pepper[sad]: Best timing work of my whole career. And for half that trial, I was using it to prove he was innocent.
narr: She tore the page out, crumpled it into a ball, and dropped it over the rail into the mud.
pepper[sad]: ...Facts first. Headlines never. And Bruno? That's three cakes now. I know. I'm counting.
@show bruno normal farleft
bruno[normal]: ...Three. Bruno is also counting.
@hide all
@show reginald sad farleft
reginald[sad]: I was the night watch. I fell asleep at half past ten, as I always do. Some guard I turned out to be.
@show lulu sad farright
lulu[sad]: Reggie... it isn't your fault. It isn't anybody's fault except... except...
narr: She couldn't finish. Nobody could.
@hide all
think: Old Man Tumble. Who called everybody sonny. Who napped through earthquakes. Who promised he'd be quiet as a mouse.
think: He told me about his little stone tub. Warm as a hug. Built with his own paws. And Snapjaw sent him a picture of a bulldozer.
think: My postcard showed a hot spring too. For one horrible second in that trial, I understood him. I hate that I did.
think: Old capybaras just close their eyes and listen, he said. I wonder what he was listening to, all those nights. I wonder if anyone ever asked.
@show nibs sad farleft
nibs[sad]: Two trials. Two friends lost each time. Hypothetically, if this continues... No. I refuse to finish that sentence.
@show zuzu normal farright
zuzu[normal]: then don't. we stop it. find whoever's behind snapjaw. pull HIS plug for once.
@hide all
mochi: Zuzu's right. Coco held us together. Marigold kept us alive. Neither of them should ever have had to.
mochi: Snapjaw drained a whole lake to build us a new cage. That means somebody, somewhere, has the keys. We're going to find them. All eleven of us.
@show bramble normal farleft
@show fennel normal farright
bramble[normal]: ...I'll plant something for her... chamomile, I think... it grows almost anywhere... even in mud...
fennel[normal]: And I will paint her. In her cap, telling us all to drink water. As she was. Always.
@hide all
@sfx chime
@music snapjaw
@shake 10
@show snapjaw happy center
snapjaw[happy]: Snap-snap-snap! Look at you all, huddled round the tub like a bowl of soggy dumplings! Adorable!
snapjaw[normal]: Speeches! Promises! Plans! You made promises last time too, my darlings. And here we are.
snapjaw[happy]: *Two down, plenty to go!* Sleep tight, passengers! The Mudlark has so many more cabins... and so many more surprises!
@sfx door
@hide snapjaw
@music sad
think: Laugh all you want, Snapjaw. You can drain a lake. You can't drain us.
think: Coco's courage. Marigold's care. I'm carrying both of them now. And I'm not putting either one down.
@card CHAPTER 2 — END | 11 guests remain aboard the Mudlark
@end
""",
}

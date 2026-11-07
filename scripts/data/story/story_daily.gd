extends RefCounted
## Daily-life story scripts (story DSL, see docs/ARCHITECTURE.md section 3).
## prologue, freetime_intro, hangout_<id> x14, freetime_outro, motive, evening, night, discovery, epilogue.
## Hangouts set flag "hung_<id>" so later scenes can react (see evening).

const SCRIPTS := {
	# =====================================================================================
	"prologue": """
@bg none instant
@music stop
@card CHAPTER 1 | A Soak to Die For
narr: Warm water. The scent of yuzu. Somewhere very far away, a little bell went ding...
narr: ...and then nothing at all.
think: Mmm... five more minutes... this futon is so... cold. And hard. And... marble?
@bg lobby
@wait 0.6
think: Wait. This isn't my room. Where... am I?
narr: A grand lobby glowed around me. Paper lanterns, polished cedar, a fountain shaped like a capybara having the bath of its life.
narr: And every window, every door, every exit... sealed behind thick *steel shutters*.
think: I'm Mochi. Ace Bath Connoisseur. I've soaked in two hundred hot springs... but I don't remember checking into this one.
think: I don't remember arriving at all. Good news: my yuzu is still on my head. Bad news: literally everything else.
voice: AHOY THERE! Another one's washed ashore! All hands, we've got a new sailor!
@music daily
@intro coco
coco[happy]: Ahoy, matey! Captain Coco, Ace Sailor, at your service! Welcome aboard the strangest ship I've ever sailed!
mochi: Um... hi. I'm Mochi. Do you know where we are?
coco[normal]: Not a clue! Woke up on a sofa with my hat on straight and my trusty watch still ticking. How bad can it be? HAR HAR!
coco[happy]: Don't you fret, sailor. Whatever this is, Captain Coco's got the wheel. There's a whole crew here. Come meet 'em!
think: She's so loud my ears are ringing... but somehow, I feel a little safer already.
@intro bruno
bruno[normal]: ...Hello. Bruno is Bruno. Bruno Brawnsworth. Wrestler.
bruno[sad]: Bruno is sorry he is so big. Bruno will try very hard not to sit on anyone.
@show coco happy farleft
coco[happy]: Sorry? HAR! You're a walking lighthouse, matey! Every crew needs a lighthouse!
bruno[happy]: ...Bruno has never been a lighthouse before. Bruno likes it.
think: A wrestler the size of a hot tub, who apologizes for existing. I like him already.
@intro lulu
lulu[happy]: Lulu-lu~! Hiii! Lulu Starling, Ace Pop Idol! Sparkle sparkle, nice to meetcha!
@sfx pop
@flash #ff9fd0
narr: She twirled, and a puff of *pink glitter* drifted off her cheeks and onto my hoodie.
lulu[normal]: Oopsie! That's my signature Bubblegum Pink. It gets everywhere. Like, everywhere-everywhere.
lulu[sad]: Um... does anyone know when we can go home? Lulu has a concert on Friday. Probably. Maybe...
think: Her smile is perfect. Her paws are shaking.
@intro pepper
@flash
pepper[happy]: Gotcha! Pepper Quill, Ace Journalist. Hold still, new face. That one's for the front page.
pepper[normal]: Name? Talent? Where were you last night? Secrets? Allergies? Enemies? Talk fast, I'm on deadline!
mochi: Mochi. Bath Connoisseur. I don't know. No. Citrus. ...No?
pepper[happy]: Boring! Love it. The boring ones always have the juiciest secrets. Scoop!
@intro duchess
duchess[normal]: Darling, do stop gawking. Duchess Velveteen, Ace Fashion Designer. You may admire the hat from there.
duchess[angry]: Someone kidnapped me in a TRAVEL shawl. Whoever did this has no mercy and no taste.
@show pepper happy farright
pepper[happy]: Ooh, can I quote you on that?
duchess[happy]: Darling, you may quote me on everything. Velveteen has four E's. Use all of them.
@intro bramble
bramble[happy]: Oh... hello, little sprout... I'm Bramble... Bramble Thistlewood... I help things grow...
bramble[normal]: There's a garden out back, did you know? The roses are a little wild... they've been waiting for someone...
bramble[sad]: Even behind steel walls, a garden still wants to bloom... isn't that a funny thing...
think: She talks like a slow, warm river. I could listen to her for hours. Or fall asleep. Possibly both.
@intro nibs
nibs[normal]: Professor Nibs, Ace Chemist. Hypothetically speaking, we were sedated, transported, and arranged on sofas.
nibs[happy]: Fascinating! Also, fun fact: the capybara is the largest rodent on Earth. You're welcome.
mochi: I... knew that. I am one.
nibs[normal]: Knowing a fact and appreciating a fact are two very different things, Mochi.
@intro zuzu
zuzu[normal]: zuzu. hacker. hi.
zuzu[normal]: no wifi. no signal. no exit. already checked. this place is locked down tight ngl.
@show nibs shock farleft
nibs[shock]: You've already probed the network? We've been awake for nine minutes!
zuzu[happy]: eight. skill issue.
@intro reginald
@shake 6
reginald[angry]: En garde, villain! ...Oh. Merely another guest. I say, you gave me a frightful turn.
reginald[happy]: Sir Reginald Puddlesworth the Third, Ace Fencer. The THIRD. The first two were splendid, and I am splendider.
@show coco happy farright
coco[happy]: HAR! Fancy name, fancy hat! Bet you can't out-fence an old sea dog with a mop, Reggie!
reginald[angry]: R-Reggie?! Madam, I accept your challenge! Name the hour!
coco[happy]: Tonight, after supper, in the gym! Loser swabs the deck!
@intro grub
grub[happy]: Hello hello! Grub Pemberton, Ace Chef! You look peckish. Here, have a yuzu bun. Have two!
mochi: Thank you! Wow... it's still warm.
grub[normal]: Found a kitchen down the hall, stocked to the rafters. Whoever runs this place isn't trying to starve us, at least.
grub[happy]: And if we're stuck here, well... we might as well stick together. Like rice! Ha!
@intro tumble
tumble[normal]: Zzz... zzz... eh? What? Is it breakfast? Did I miss a war?
tumble[normal]: Old Man Tumble. Ace Napper. I've napped through three earthquakes and a wedding. My own wedding.
@show grub happy farleft
grub[happy]: Bun, Mr. Tumble?
tumble[happy]: Ooh. Wake me when it's chewed... zzz...
@intro marigold
marigold[normal]: Oh! Are you hurt? Dizzy? Any nausea? Look at my paw. Follow it. Left... right... good.
marigold[happy]: Sorry! Marigold Fern, Ace Nurse. Whoever brought us here used a sedative. Everyone needs to drink water.
marigold[sad]: Small sips, please. I've already caught Bruno trying to drink from the fountain.
@show bruno sad farright
bruno[sad]: ...Bruno was thirsty.
@intro fennel
fennel[happy]: Stop! Do not move! The lantern light on your yuzu... it is MAGNIFIQUE!
fennel[normal]: Fennel Dauber, Ace Painter. I paint what others do not see. The cracks. The shadows. The tiny lies.
fennel[happy]: Your face says you are scared, mon ami. But your eyes? Ah... your eyes are already looking for clues.
think: ...Is it really that obvious?
@hide all
think: Thirteen capybaras... plus me. Fourteen. That's everyone. Isn't it?
@sfx drumroll
narr: A drumroll. From nowhere. Every head in the lobby turned at once.
@sfx poof
@flash #c9b8ff
@shake 8
narr: POOF! A burst of glittering *silver-violet sparkles* exploded in the middle of the room... and when it cleared, someone was standing there.
@intro wisp
wisp[happy]: Behold! Good morning, my dear audience! Wisp Vanderloo, Ace Magician, appearing as if from nowhere!
wisp[normal]: Forgive the theatrics. One must make an entrance. I've been standing perfectly still behind that pillar for forty minutes.
@show coco happy farleft
coco[happy]: HAR HAR HAR! Now THAT'S how you board a ship!
@show lulu happy farright
lulu[happy]: Ooh, sparkly! Lulu approves! Even if it's not pink!
think: Glitter season, apparently. First pink, now silver-violet. I'll be picking it out of my towel for a week.
@hide all
think: Fifteen of us. Fifteen strangers with fifteen strange talents. And not one of us knows how we got here.
@music stop
@sfx chime
narr: Ding-dong, ding-dong. A cheerful chime rang out from every speaker in the lobby at once.
voice: Ahem! Testing, testing. Is this thing on? Of course it's on. I built it.
@sfx boom
@shake 18
@flash #43a047
@music snapjaw
@show snapjaw happy center
narr: The reception desk split in two, and something rose out of the floor. Half green scales, half chrome. A top hat. A monocle. Teeth.
snapjaw[happy]: Snap-snap-snap! Welcome, welcome, my darling guests, to the luxurious YUZU SPRINGS RESORT!
snapjaw[normal]: I am your host, your concierge, your warden: WARDEN SNAPJAW! Please, hold your applause. Forever, ideally.
@show bruno shock farleft
bruno[shock]: A... crocodile?
snapjaw[angry]: CAIMAN! Caiman, you overgrown guinea pig! Do I look like I come from a swamp? Don't answer that.
@hide bruno
@show pepper angry farright
pepper[angry]: Okay, Mr. Caiman, quote of the day: why are we here, and when do we get to leave?
snapjaw[happy]: Leave? Oh, nobody leaves Yuzu Springs! You'll be staying with us forever and ever! Room service included!
snapjaw[normal]: Unless... you'd like to *check out*.
@hide pepper
@show nibs normal farleft
nibs[normal]: Hypothetically speaking... what exactly is the checkout procedure?
snapjaw[happy]: So glad you asked! It's simple. To check out, a guest must kill another guest... and get away with it!
@sfx gasp
@shake 8
all: WHAT?!
snapjaw[normal]: After a body is discovered, you'll investigate. Then we hold a *Splash Trial* down at my beautiful Trial Pool.
snapjaw[happy]: You'll debate, you'll accuse, you'll squabble... and then everyone votes for the culprit!
snapjaw[normal]: Vote right, and only the culprit gets punished. Vote wrong, and everyone ELSE gets punished, and the culprit checks out free!
@hide nibs
@show lulu shock farright
lulu[shock]: P-punished...? Like... no dessert? Right? Lulu-lu...?
snapjaw[happy]: Oh, much worse than no dessert! Here are the rules. Read them, love them, laminate them!
@clue rules
@hide lulu
@show coco angry farleft
coco[angry]: Enough of this bilge! I've sailed through hurricanes. I'm not scared of a talking handbag!
narr: Coco stomped to the front doors, grabbed the edge of the steel shutter with both paws, and heaved.
@shake 6
coco[angry]: Heave... HO! Come on, ye rusty barnacle... HEAVE!
@sfx whoosh
@show snapjaw angry left
@shake 22
@flash #ff4f6d
@expr coco shock
narr: SNAP! Snapjaw crossed the lobby in a blink. His jaws slammed shut a single whisker away from Coco's nose.
snapjaw[angry]: Rule Six, Captain. No violence against Warden Snapjaw. And my shutters count as me. I bite. Next time, I won't miss.
coco[shock]: ...!
@show snapjaw happy center
snapjaw[happy]: Snap-snap-snap! Now then! Enjoy your stay, settle in, and do try to murder each other soon. I get bored terribly easily!
@sfx door
@hide snapjaw
narr: With a clank, he sank back into the floor. The reception desk snapped shut behind him like a mouth.
@music stop
@hide all
think: Nobody moved. Nobody spoke. Fifteen strangers, all looking at each other... and wondering.
@show coco normal center
coco[normal]: ...Ahem. Listen up, crew.
coco[angry]: I don't care what that walking suitcase says. Nobody is killing anybody. Not on my watch.
coco[happy]: We're all in the same boat now, and I've never lost a sailor yet. *Nobody on my crew is checking out!*
@music daily
@show bruno happy farleft
bruno[happy]: ...Bruno is on the crew.
@show lulu happy farright
lulu[happy]: Lulu too! Lulu-lu~! Crew-crew~!
@hide bruno
@hide lulu
@show reginald happy farleft
reginald[happy]: Hmph. A gentleman would never stoop to murder. You have my sword, Captain. My foil, technically.
@show grub happy farright
grub[happy]: And my kitchen! Nobody plots murder on a full stomach. That's just science.
@hide reginald
@hide grub
@show zuzu normal farleft
zuzu[normal]: no murder. agreed. ez.
@show wisp happy farright
wisp[happy]: A pact! How marvelous. Then let this be our greatest trick, dear friends: we shall all walk out of here together.
coco[happy]: That's the spirit! Paws in, crew! On three! One... two... three...
@shake 8
all: NOBODY CHECKS OUT!
@hide all
narr: Fifteen paws, piled together in the middle of a lobby that wasn't ours. For a moment, it almost felt like a real crew.
@music stop
think: But I couldn't forget the way everyone's eyes had darted around the room when Snapjaw said "check out".
think: Fifteen strangers. Fifteen secrets. And a steel shutter between us and the rest of the world.
think: ...No. We made a promise. Nobody checks out. Right?
@end
""",
	# =====================================================================================
	"freetime_intro": """
@bg lobby
@music daily
@card DAY 1 | Free Time
think: Snapjaw left us alone for the afternoon. No exits. No phones. Just a very fancy cage that smells like citrus.
think: Everyone's scattered around the resort... exploring, sulking, or pretending really hard not to be scared.
think: If we're going to be stuck here together, I should get to know them. Who knows what I might learn?
think: I probably have time for *three visits* before evening. Choose wisely, Mochi.
@end
""",
	# =====================================================================================
	"freetime_outro": """
@bg lobby
@music stop
narr: The afternoon slipped away like bathwater down a drain.
think: Outside the shutters, it must be getting dark by now. Inside, the lanterns just glowed a little brighter.
@sfx chime
snapjaw[happy]: Ding-dong! Attention, my precious guests! Please gather in the Lobby at once. I have a little present for you!
think: A present from Snapjaw. That can't possibly be good.
@end
""",
	# =====================================================================================
	"hangout_coco": """
@bg bath
@music daily
@flag hung_coco
narr: Steam curled off the Yuzu Bath. Halfway across the water, a white captain's hat bobbed along happily.
@show coco happy center
coco[happy]: Ahoy, Mochi! Permission to come aboard granted! Water's perfect!
think: She's right. Forty-one degrees, yuzu-infused, mineral-rich... honestly? A nine out of ten.
mochi: You look right at home in there, Captain.
coco[happy]: HAR! A sailor's never happier than when she's in the water. Even if this water's got fruit in it.
narr: She held up a gold chain. On the end swung a chunky brass pocket watch, dripping wet and ticking away.
coco[normal]: See this? My captain's watch. Fully *waterproof*. Survived three shipwrecks, a kraken, and my cousin's wedding!
coco[happy]: Never take it off. Not to sleep, not to soak. A captain always knows the time!
@choice What should I say?
> A kraken? Really? -> coco_kraken
> Doesn't it get heavy in the bath? -> coco_heavy
@label coco_kraken
coco[happy]: Well... it was a very large squid. With an attitude. The watch didn't even get a scratch!
@jump coco_end
@label coco_heavy
coco[normal]: Heavy? This little anchor? It's lighter than a captain's responsibilities, matey. HAR!
@label coco_end
coco[normal]: Every night at *9:45 sharp*, I'm in this bath. Rain or shine, shipwreck or snapping lizard. Keeps me steady.
coco[sad]: ...I've got a lot of folks counting on me in here, Mochi. Gotta keep my head clear.
coco[happy]: But you? You're a good one. I can tell. Stick by me and we'll all sail home. Captain's promise!
think: It's hard not to believe her. Talking to Coco makes me feel braver.
@skill captains_courage
@end
""",
	# =====================================================================================
	"hangout_wisp": """
@bg lounge
@music daily
@flag hung_wisp
@show wisp normal center
narr: On the little Lounge stage, a figure in a starry cape stood frozen mid-bow. Not a twitch. Not a blink.
think: Is that... a statue of Wisp? Who brings a statue of themself to a hostage situation?
mochi: Um... hello?
@sfx poof
@flash #c9b8ff
@expr wisp happy
wisp[happy]: Behold! Hoho! Did I fool you, my dear audience? Be honest. It's good for my art.
mochi: For a second, yes! I couldn't even tell you were alive!
wisp[normal]: That, dear Mochi, is *The Living Statue*. I can stand perfectly still for *twenty minutes*. Not a single whisker.
wisp[happy]: The secret? Breathe slowly, think of nothing, and never, ever scratch your nose. The nose is the hardest part.
narr: He dusted off his white gloves. A cloud of glitter puffed into the air, *silver and violet*, sparkling in the lantern light.
wisp[happy]: My *Stardust Powder*! Every vanishing needs a POOF. I never go anywhere without a pocketful.
@choice What should I ask?
> Where did you learn magic? -> wisp_circus
> Can you make us vanish out of here? -> wisp_vanish
@label wisp_circus
wisp[happy]: At home, on *Lily Pond*! My family runs a *floating circus*. Rafts and lanterns and acrobats, drifting on the water.
@jump wisp_end
@label wisp_vanish
wisp[sad]: If I could, I'd have whisked us all to *Lily Pond* by now. My family's *floating circus* waits there, on the water...
@label wisp_end
wisp[sad]: I miss them dreadfully. ...And, between us, I miss the light. I don't care for the dark. I never have.
mochi: The great Wisp Vanderloo... is afraid of the dark?
wisp[happy]: Hoho! Every magician keeps one secret the audience never learns. Now you know mine. Guard it well!
@skill sleight_of_paw
@end
""",
	# =====================================================================================
	"hangout_bruno": """
@bg sauna
@music daily
@flag hung_bruno
narr: The sauna hit me like a warm, wet wall. Somewhere in the steam, something very large sighed happily.
@show bruno happy center
bruno[happy]: Mochi! Bruno is happy you came. Sauna is Bruno's favorite place in the whole world.
think: Ninety degrees, cedar benches, a hint of eucalyptus... Bruno has excellent taste.
mochi: Bruno, where's your headband? I've never seen you without it.
bruno[normal]: Bruno hangs his lucky *red headband* on his *hook in the changing room*. Always. Before going in.
bruno[sad]: Headband gets sweaty otherwise. Then it smells like Bruno's feet. Nobody wants that.
think: I tried very hard not to picture that. I failed.
@choice What should I say?
> Why is it lucky? -> bruno_lucky
> You really love the sauna, huh? -> bruno_love
@label bruno_lucky
bruno[sad]: Bruno's little sister made it. Bruno wore it in every match. Bruno never lost... while wearing it.
@jump bruno_end
@label bruno_love
bruno[happy]: In the ring, everyone is scared of Bruno. In the sauna, nobody is scared. Just warm. Just quiet.
@label bruno_end
bruno[normal]: Bruno will come every night. Little bit of sweat, little bit of quiet. Then Bruno sleeps like a baby boulder.
bruno[sad]: ...Everyone looks at Bruno and sees a monster. Big arms. Scary scar. But Bruno does not like fighting outside the ring.
mochi: I don't see a monster. I see someone with great taste in saunas.
bruno[happy]: ...Hehe. Mochi is a good friend. Bruno will protect Mochi. Big arms are good for that.
@skill iron_hide
@end
""",
	# =====================================================================================
	"hangout_lulu": """
@bg lounge
@music daily
@flag hung_lulu
narr: Someone was singing in the Lounge. High, sweet, and just a tiny bit wobbly.
@show lulu happy center
lulu[happy]: ...la la Lulu-lu~! Oh! Mochi! Did you hear that? Was it good? Be honest! No, wait, lie to me!
mochi: It was really good! Honestly.
lulu[happy]: Eeee! Then you get a special fan sparkle! Close your eyes!
@sfx pop
@flash #ff9fd0
@shake 4
narr: A puff of glitter hit me square in the face. Very pink. Extremely pink. Pink in places I didn't know I had.
lulu[normal]: That's Lulu's signature *Bubblegum Pink*! Lulu only ever uses pink. *Never any other color.* It's, like, my brand!
lulu[normal]: Silver is tacky, gold is so last tour, and blue is for sad songs. Pink is forever!
mochi: I think some of it went up my nose.
lulu[happy]: Then you're officially a Lulu fan! Welcome to the club! Membership is free, and the glitter is forever!
@choice What should I say?
> Do you ever get tired of smiling? -> lulu_tired
> Pink really suits you. -> lulu_pink
@label lulu_tired
lulu[sad]: ...Hehe. You noticed? Sometimes Lulu smiles so hard her cheeks hurt. But if Lulu stops, everyone gets sad.
@jump lulu_end
@label lulu_pink
lulu[happy]: Right?! Pink is brave! Pink is loud! Pink is... um... what Lulu wears when she's scared, so nobody can tell.
@label lulu_end
lulu[sad]: Lulu is really, really scared here, Mochi. Don't tell the others. Idols aren't allowed to be scared.
mochi: You don't have to perform for me. You can just be Lulu.
lulu[happy]: ...Just Lulu? Hehe. Okay. Just Lulu. ...You're nice, Mochi. Lulu-lu~!
@skill encore
@end
""",
	# =====================================================================================
	"hangout_pepper": """
@bg dining
@music daily
@flag hung_pepper
@show pepper happy center
@flash
pepper[happy]: Gotcha! Mochi, mouth full of snack, 2:14 PM. Scoop! Don't worry, it's a flattering angle. Mostly.
narr: Pepper spun her camera around to show me. There I was, cheeks stuffed, with a little *timestamp* glowing in the corner.
pepper[normal]: Every shot gets the time stamped right on it, to the minute. A real reporter doesn't do 'around'. She does 'exactly'.
pepper[happy]: *I photograph everything!* Breakfast, sunsets, suspicious behavior. Especially suspicious behavior.
pepper[normal]: And this baby's *flash* works in the dark, too. Lounge, hallway, broom closet. Nothing hides from Pepper Quill!
@choice What should I ask?
> Caught anything suspicious yet? -> pepper_sus
> Isn't that a bit... invasive? -> pepper_rude
@label pepper_sus
pepper[normal]: Grub hiding cookies in his hat. Duchess talking to a mannequin. Zuzu blinking at a wall. Nothing front-page... yet.
@jump pepper_end
@label pepper_rude
pepper[angry]: Invasive?! It's the public's right to know! ...Okay, the public is fourteen capybaras. Still counts!
@label pepper_end
pepper[normal]: Listen. Somebody brought us here. Somebody knows things. And the truth always leaves a trail. You just have to snap it first.
pepper[sad]: ...Plus, if I keep busy, I don't have to think about how none of my editors know where I am.
pepper[happy]: Tell you what, partner. You keep your ears open, I'll keep my lens open. Between us, nothing gets past!
mochi: Partners? Really?
pepper[happy]: Sure! Every great reporter needs a sidekick. ...Fine, a co-reporter. Don't let it go to your head. Scoop!
think: Co-reporter Mochi. Somehow that sounds exciting and exhausting at the same time.
@skill scoop_sense
@end
""",
	# =====================================================================================
	"hangout_duchess": """
@bg giftshop
@music daily
@flag hung_duchess
@show duchess happy center
duchess[happy]: Mochi, darling! Come, come. Welcome to my little exhibition. Do try not to breathe on anything.
narr: The gift shop had been transformed. Capybara-sized *mannequins* posed on pedestals, draped in silk, sequins, and enormous hats.
duchess[normal]: The resort left these poor mannequins naked. NAKED, darling. So I dressed them. It was a humanitarian crisis.
duchess[happy]: That one is 'Autumn Regret'. That one is 'Spa Day Revenge'. And that one is simply called 'Duchess'.
duchess[angry]: The only problem? That wretched *price-tag gun* on the counter. It tags EVERYTHING. Even my masterpieces.
duchess[angry]: A little white tag, tucked right into the collar: *GIFT SHOP — ¥4,800*. Art has no price, darling!
@choice What should I say?
> Why not just take the tags off? -> duchess_tags
> 4,800 yen is a bargain, honestly. -> duchess_bargain
@label duchess_tags
duchess[sad]: I tried! That gun tucks them in so cleverly that I miss half of them. They hide like little paper gremlins.
@jump duchess_end
@label duchess_bargain
@shake 6
duchess[shock]: A BARGAIN?! For 'Spa Day Revenge'?! Darling, I shall pretend you never said that. For your sake.
@label duchess_end
duchess[normal]: One, two, three... hm. Wasn't there one more on that pedestal? ...Oh, I must have miscounted. Beauty is distracting.
duchess[sad]: ...Fashion is how I stay brave, you know. If I must be a prisoner, I'll be the best-dressed prisoner in history.
duchess[happy]: You, however, need help. That hoodie is a cry for help. Stand up straight. There. Better. Barely.
narr: She plopped an enormous feathered hat on my head, squinted at me for a long moment... and took it straight back off.
duchess[normal]: No. Some hats are not for everyone, darling. Stick with the fruit. The fruit is working for you.
@skill poise
@end
""",
	# =====================================================================================
	"hangout_bramble": """
@bg garden_day
@music daily
@flag hung_bramble
@show bramble happy center
narr: Behind the resort, inside high walls topped with steel, a little garden grew. Stone lanterns. Moss. And roses everywhere.
bramble[happy]: Oh... Mochi... you found my garden... well, it isn't mine... but the roses don't know that...
narr: A flat stone path wound through the middle of the garden between two doors. Rose bushes leaned over it from both sides.
bramble[normal]: This path runs from the *Lounge's back door*... all the way to that little *side door of the bathhouse*...
bramble[normal]: Nobody uses it... *nobody* but the beetles... and me...
mochi: Where does that side door go?
bramble[normal]: Into the bathhouse *changing room*, I think... the one with all the little wooden buckets... you can't see it from the front...
mochi: These roses are so overgrown. They're practically eating the path.
bramble[happy]: Mm... that's why I prune them every evening... at *9:00*, when the lanterns come on... a little bedtime for flowers...
@choice What should I say?
> Can I help you prune? -> bramble_help
> Don't the thorns hurt? -> bramble_thorns
@label bramble_help
bramble[happy]: Oh... how sweet... but you'd have to be gentle... roses remember who was kind to them...
@jump bramble_end
@label bramble_thorns
bramble[normal]: Thorns aren't mean, though... they just catch things... a sleeve... a scarf... a secret...
@label bramble_end
bramble[sad]: I miss my greenhouse at home... I hope someone's watering the ferns... ferns get so lonely...
bramble[happy]: But a garden is a garden... wherever it's planted. Even here. Even us... Thank you for visiting, little sprout...
@skill deep_roots
@end
""",
	# =====================================================================================
	"hangout_nibs": """
@bg dining
@music daily
@flag hung_nibs
narr: Professor Nibs had covered an entire dining table in napkins. Every napkin was covered in tiny, frantic equations.
@show nibs happy center
nibs[happy]: Ah, Mochi! Excellent timing. Hypothetically speaking, would you like to hear a fact?
mochi: Do I have a choice?
nibs[normal]: Statistically, no. Fact: capybaras are semi-aquatic. We can hold our breath underwater for up to *five minutes*!
nibs[happy]: Five! Whole! Minutes! A human can barely manage one. Pathetic. Charming, but pathetic.
@choice What should I say?
> Five minutes? I want to try that! -> nibs_try
> What are all these equations for? -> nibs_math
@label nibs_try
nibs[shock]: Please don't! Holding your breath is one thing. Fainting underwater is quite another. Let's not test it.
@jump nibs_end
@label nibs_math
nibs[normal]: The shutters. Steel, three centimeters thick. Hypothetically, I could dissolve them... in roughly four hundred years.
@label nibs_end
nibs[happy]: Bonus fact: yuzu has roughly three times more vitamin C than a lemon. You're wearing a vitamin on your head.
mochi: Oh, I knew that one!
nibs[shock]: ...You did? Hm. Troubling. I shall have to find more obscure facts.
nibs[normal]: Another fact: our teeth never stop growing. That is why I chew pencils. It is science, not nerves.
narr: He was chewing a pencil very, very fast.
nibs[sad]: ...Fine. It's a little bit nerves. Facts are comforting, Mochi. Facts don't lie. Facts don't try to kill you.
nibs[happy]: One last fact, free of charge: you are a surprisingly good listener. Observation confirmed.
@skill hypothesis
@end
""",
	# =====================================================================================
	"hangout_zuzu": """
@bg hallway
@music daily
@flag hung_zuzu
narr: Zuzu was sitting cross-legged in the hallway, laptop balanced on their knees, face lit blue by the screen.
@show zuzu normal center
zuzu[normal]: oh. hey mochi. sit. don't touch the cable.
mochi: What are you doing?
zuzu[normal]: hacking snapjaw. or trying. his network is mostly firewalls and crocodile memes.
zuzu[happy]: found one fun thing tho. the sauna has a *door-log safety panel*. lol it *logs every door opening*. timestamps and everything.
zuzu[normal]: so nobody gets locked in and cooked. very thoughtful for a guy who wants us dead.
mochi: Could that help us somehow?
zuzu[normal]: idk. data is data. you never know what's useful until it suddenly is.
@choice What should I say?
> Can you get us out of here? -> zuzu_out
> Anything about Snapjaw himself? -> zuzu_snap
@label zuzu_out
zuzu[sad]: shutters run on a separate system. air-gapped. i tried. skill issue. mine, for once.
@jump zuzu_end
@label zuzu_snap
zuzu[normal]: one folder called GUESTS. encrypted. and one called SEASON 2. also encrypted. ngl that one freaks me out.
@label zuzu_end
zuzu[normal]: nibs and i are gonna camp in the library tonight. there's an old terminal. more ports to poke.
zuzu[sad]: ...real talk. i'm better with machines than people. machines don't look at you like you might murder them.
mochi: I don't think you're going to murder anyone, Zuzu.
zuzu[happy]: lol. thanks. you're ok, mochi. like, actually ok. added to friends list.
@skill autocomplete
@end
""",
	# =====================================================================================
	"hangout_reginald": """
@bg lobby
@music daily
@flag hung_reginald
narr: In the middle of the lobby, Sir Reginald was lunging at a potted plant with terrifying precision.
@show reginald angry center
@shake 6
reginald[angry]: Hah! Hah! HAH! Take that, you leafy scoundrel! ...Ah. Mochi. You saw nothing.
mochi: Is the plant... okay?
reginald[happy]: It shall recover. Its honor, less so. A fencer must practice daily, or his foil grows rusty and his moustache grows limp.
reginald[normal]: Captain Coco has agreed to be my sparring partner. We'll practice in the gym in the evenings. She fights with a mop.
@choice What should I say?
> Is Coco better than you? -> reg_better
> What does honor mean to you? -> reg_honor
@label reg_better
reginald[angry]: B-better?! I say! She is... unconventional! Nobody expects a mop to the moustache! ...She is rather good.
@jump reg_end
@label reg_honor
reginald[normal]: Honor means facing your opponent head-on. Never from behind. Only cowards strike from behind, Mochi.
@label reg_end
reginald[sad]: ...My family expects great things of the Third. I have spent my whole life trying to be worth the number.
reginald[normal]: But here there is no family. No trophies. Just fourteen strangers I've sworn to protect. And one plant I have wronged.
@show coco happy farright
coco[happy]: Oi, Reggie! Quit bullying the shrubbery and practice on something that fights back! Gym, tonight, after supper!
reginald[angry]: Madam! This plant fights back PLENTY! ...But very well. Tonight. And I shall not be mopped again!
@hide coco
reginald[happy]: You have a good stance, Mochi. Weight forward, eyes sharp. You'd make a decent fencer. Not a great one. Decent.
think: ...I'm choosing to take 'decent' as a compliment.
@skill en_garde
@end
""",
	# =====================================================================================
	"hangout_grub": """
@bg dining
@music daily
@flag hung_grub
narr: The dining hall smelled like heaven. Toasted rice, citrus, and something buttery I wanted to marry.
@show grub happy center
grub[happy]: Mochi! Perfect timing! I need a taste-tester. Open wide! Here comes the yuzu-glazed dumpling train! Choo choo!
mochi: Mmf...! That's... incredible!
grub[happy]: Ha! That's what I like to hear. Nothing brings folks together like a good meal. Food is love you can chew!
@choice What should I say?
> How do you stay so cheerful? -> grub_cheer
> Can I have the recipe? -> grub_recipe
@label grub_cheer
grub[sad]: Honestly? I'm scared silly. When I'm scared, I cook. When I'm really scared, I bake. There are four cakes in the oven.
@jump grub_end
@label grub_recipe
grub[happy]: A chef never reveals his secrets! ...It's butter. The secret is always more butter. Don't tell anyone.
@label grub_end
@show tumble normal farright
tumble[normal]: ...Did somebody say dumpling train? All aboard... zzz...
grub[happy]: Ha! He sleepwalks toward food. Every single time. Here you go, Mr. Tumble. Chew before you snore.
@hide tumble
grub[normal]: I'm making a big yuzu feast for dinner tonight. Everyone round one table. No room for murder at a full table!
grub[happy]: Oh! Say, Mochi... could you lend me a paw *washing dishes after dinner tonight*? Fifteen capybaras make a LOT of plates.
mochi: Of course! Count me in.
grub[happy]: You're a lifesaver! Like a life-preserver, but made of dumplings. Ha! See you in the kitchen tonight, partner!
think: A full belly and a dish-washing appointment. Honestly? Best deal in the whole resort.
@skill comfort_food
@end
""",
	# =====================================================================================
	"hangout_tumble": """
@bg lobby
@music daily
@flag hung_tumble
narr: Old Man Tumble was sprawled across a lobby sofa like a fuzzy grey blanket someone had dropped there.
@show tumble normal center
tumble[normal]: Zzz... zzzz... zz...
mochi: Mr. Tumble? Are you awake?
tumble[shock]: Eh? What? Who? I wasn't asleep! I was resting my eyes. And my ears. And the rest of me.
tumble[happy]: Oh, it's the young one with the fruit hat. Sit, sit. Sofa's warm. I warmed it. Took me three hours.
think: The sofa had a perfect Tumble-shaped dent in it. Three hours well spent, honestly.
@choice What should I say?
> What's the secret to a good nap? -> tumble_nap
> Aren't you scared, being stuck here? -> tumble_scared
@label tumble_nap
tumble[happy]: Never fight the yawn, kiddo. The yawn knows things. ...zzz... eh? Where was I?
@jump tumble_end
@label tumble_scared
tumble[normal]: Scared? At my age, every day's a bonus soak. I just try not to waste the warm water.
@label tumble_end
tumble[normal]: When you get old, you learn things. Like... toast always lands butter-side down. And *statues don't breathe*.
mochi: ...Statues don't breathe?
tumble[happy]: Nope. Not even a little. You can tell, if you watch long enough. Most folks don't watch long enough... zzz...
think: I have no idea if that was wisdom or something he was dreaming. Possibly both.
tumble[normal]: Zzz... mm... you're a good listener... come back and nap with me sometime... zzz...
@skill power_nap
@end
""",
	# =====================================================================================
	"hangout_marigold": """
@bg hallway
@music daily
@flag hung_marigold
narr: Marigold was going door to door down the guest wing, a clipboard in one paw and a thermometer in the other.
@show marigold normal center
marigold[normal]: Mochi! Perfect. Tongue out, please. ...Mm-hm. Temperature normal. Pupils normal. Yuzu... still on your head.
mochi: You're checking on everyone?
marigold[happy]: Somebody has to! Lulu hasn't eaten, Tumble hasn't moved, and Bruno is drinking from fountains again.
marigold[normal]: There's a little *infirmary* in the east wing. Half the shelves are empty, so I'm restocking it from the kitchen.
marigold[normal]: Every night I'll work there until nearly ten, then walk back past the bathhouse to my room. *Around 10*, like clockwork.
marigold[happy]: The walk goes right by the *bathhouse front door*. All that steam rolling out... wonderful for the sinuses.
@choice What should I say?
> Make sure you rest too, Marigold. -> mari_rest
> What's the strangest injury you've treated? -> mari_strange
@label mari_rest
marigold[sad]: ...Oh. Nobody ever tells the nurse that. Thank you, Mochi. I'll try. I'm terrible at it, but I'll try.
@jump mari_end
@label mari_strange
marigold[happy]: A wrestler who sprained his tail sneezing. Bruno. This morning. He made me promise not to tell. Oops.
@label mari_end
marigold[sad]: If something happens here... if someone gets hurt... I want to be ready. I couldn't bear being too late.
marigold[normal]: Fact of the day: a capybara's normal body temperature is about 38 degrees. Keep yours there. Drink water.
marigold[happy]: And come see me if you feel funny. Or scared. Scared counts too. Nurse's orders!
think: For the first time since I woke up in this place, somebody made me feel looked after.
@skill first_aid
@end
""",
	# =====================================================================================
	"hangout_fennel": """
@bg garden_day
@music daily
@flag hung_fennel
@show fennel angry center
narr: Fennel had set up an easel on the garden path and was glaring at a rose like it had insulted his mother.
fennel[angry]: Non! Non, non, non! The light is wrong! The rose is wrong! Everything is wrong except me!
mochi: Um... is this a bad time?
fennel[happy]: Mochi! Mon ami! Never! Come, look. Tell me what you see.
narr: The canvas showed the stone path, the rose bushes, and a door at either end. It was beautiful. And extremely detailed.
@choice What do I see?
> A gorgeous garden. -> fennel_garden
> A tiny beetle on the third rose? -> fennel_beetle
@label fennel_garden
fennel[angry]: Gorgeous! Bah! Anyone sees gorgeous! Look closer! The beetle, Mochi! The beetle on the third rose!
@jump fennel_end
@label fennel_beetle
fennel[happy]: OUI! You saw him! Magnifique! You have the eye of an artist, mon ami! Or of a very nosy capybara!
@label fennel_end
fennel[normal]: A true artist notices *every detail*. The beetle. The thorn. The crooked button. Even the price tags! Ha!
@show bramble normal farright
bramble[normal]: Fennel... you're standing on my thyme...
fennel[shock]: Pardon! Pardon! ...What is thyme?
bramble[happy]: ...It's what you're standing on...
@hide bramble
fennel[sad]: ...But here, I cannot paint the sky. Only steel. An artist without a sky is just a capybara with a brush.
fennel[happy]: So! I will paint all of you instead. Fifteen faces. My masterpiece. Hold still... no, don't, it looks fake. Statues are boring!
@skill artists_eye
@end
""",
	# =====================================================================================
	"motive": """
@bg lobby
@music snapjaw
@card DAY 1 | Evening
narr: By evening, all fifteen of us had gathered in the lobby, just like Snapjaw asked. Nobody sat down.
@sfx boom
@shake 10
@show snapjaw happy center
snapjaw[happy]: Snap-snap-snap! Good evening, my plump little prisoners! Did everyone enjoy their first day in paradise?
@show coco angry farleft
coco[angry]: Spit it out, lizard. What's this 'present' of yours?
snapjaw[normal]: Tsk. So impatient. Very well! It's been a whole day, and NOBODY has murdered ANYBODY. Frankly, I'm insulted.
snapjaw[happy]: So it's... *MOTIVE TIME!*
@sfx whoosh
@shake 8
narr: Panels slid open in the ceiling. Fifteen tablets floated down on tiny parachutes, each one with a name on the back.
@hide coco
snapjaw[happy]: I call them *Home Movies*! Little videos of the things you love most. Go on. Press play. I insist.
@hide all
@music tension
narr: My tablet flickered on. The picture was grainy, but I recognized it instantly.
think: That's... our hot spring. My family's hot spring. Grandma's little bathhouse up in the mountains.
narr: A huge drain opened at the bottom of the pool. The water swirled, faster and faster... and the steam began to fade.
think: No... no, no, no! Grandma built that spring with her own paws! Who's doing this?!
@sfx tick
narr: A timer appeared over the emptying pool. *72:00:00*. Then 71:59:59. Then 71:59:58.
think: Three days. Whatever this is... it ends in three days.
@show bruno sad farleft
bruno[sad]: Bruno's... dojo... the little ones who train there... why is the roof falling... no...
@show lulu shock farright
@shake 6
lulu[shock]: My fan club house... it's on fire?! That's not real! That can't be real! Lulu-lu...!
@hide bruno
@hide lulu
@show reginald angry farleft
reginald[angry]: Puddlesworth Manor! The family portraits! I say, put those down, you brutes!
@show grub sad farright
grub[sad]: That's my mum's restaurant... they're boarding up the windows... she's still inside...
@hide reginald
@hide grub
@show bramble sad farleft
bramble[sad]: My greenhouse... the glass is all cracked... everything's wilting...
@show duchess shock farright
duchess[shock]: My atelier! They're painting it BEIGE! Monsters! Absolute monsters!
@hide all
@show wisp normal center
narr: Across the room, Wisp stared at his screen without a word. No flourish. No 'behold'. Just silence.
narr: *Wisp's hands were trembling.*
mochi: Wisp...? Are you okay?
wisp[happy]: Hm? Oh! Hoho... perfectly. Merely a dreadful little film. Terrible production values. One star.
think: He was smiling. But he slipped the tablet under his cape awfully fast.
@hide wisp
@show coco sad farleft
coco[sad]: ...My ship. The Salty Biscuit. Sinking at the dock, with nobody aboard to bail her out.
@show snapjaw happy center
snapjaw[happy]: Oh, how tragic! How terrible! If only somebody could get out of here and save the day...
snapjaw[happy]: *Only someone who checks out can save their precious home!* Snap-snap-snap!
@sfx shout
@shake 14
coco[angry]: That's ENOUGH!
coco[angry]: Listen up, crew! Those videos are bait, and we are NOT biting. That's exactly what this scaly sea-slug wants!
snapjaw[angry]: CAIMAN!
coco[angry]: Nobody's checking out. We stick together, we find a way out, and THEN we save our homes. All of 'em. Together!
snapjaw[normal]: Hmph. We'll see how long that lasts, Captain. Three days is a long time to stay noble. Snap-snap-snap!
@sfx door
@hide snapjaw
narr: The floor swallowed him up again. The only sound left was fifteen tablets, ticking down.
@show coco normal farleft
@show wisp sad farright
coco[normal]: Hey. Magic-man. You alright? You've gone white as a sail.
wisp[sad]: ...Captain. I... yes. Forgive me. It seems even a magician can't make some things disappear.
coco[happy]: Chin up, sailor. Whatever was on that screen, we'll fix it. Captain's promise. And Coco never breaks a promise.
wisp[normal]: ...You are very kind, Captain Coco. Kinder than this place deserves.
@hide all
@music stop
think: Coco's words should have made me feel better. And they did... a little.
think: But I couldn't stop staring at the timer on my tablet. 71:56:12. 71:56:11...
think: Grandma's spring... Stay calm, Mochi. Nobody's going to do anything stupid. Nobody.
@end
""",
	# =====================================================================================
	"evening": """
@bg dining
@music daily
@card 8:30 PM | Dinner in the Dining Hall
narr: Grub had outdone himself. Yuzu rice, yuzu dumplings, yuzu-glazed pumpkin, and a yuzu cake the size of a wagon wheel.
@show grub happy center
grub[happy]: Dinner is served! Eat up, everyone! Nobody's allowed to be sad on an empty stomach. Chef's rules!
think: After those Home Movies, nobody felt like eating... until the smell hit us. Then everybody felt like eating.
@show coco happy farleft
coco[happy]: HAR HAR! Grub, you magnificent galley cook! If we ever get out of here, you're sailing with me!
@show tumble normal farright
tumble[normal]: Zzz... mmf... is there more cake...? zzz...
@hide grub
@hide tumble
@show nibs normal farright
nibs[normal]: A proposal. If everyone announces their plans for tonight, nobody can sneak about unnoticed. Hypothetically, a deterrent.
coco[happy]: Smart thinking, Professor! I'll go first. Reggie and I are dueling in the gym right after supper.
@hide nibs
@show reginald happy farright
reginald[happy]: *Until half past nine*, precisely! When the Captain retires, I shall stay in the gym and *practice alone*.
reginald[normal]: A fencer's work is never done. Especially a fencer who has been beaten by a mop. Twice.
coco[happy]: Three times, Reggie! And after that, I'm hitting the *Yuzu Bath at 9:45 sharp*, same as always!
narr: She flipped open her gold pocket watch and tapped the glass with a claw.
coco[normal]: This old girl's never wrong. *Waterproof*, too. She comes in the bath with me every night. Nothing comes between a sailor and her soak!
@hide all
@show bruno happy left
bruno[happy]: Bruno will sweat in sauna. *9:30*. Very relaxing.
bruno[normal]: Bruno will hang headband on his hook first. Like always.
@show pepper normal right
pepper[normal]: You and that sauna, big guy. Is there anything in the world you love more?
bruno[happy]: ...Cake.
@hide all
@show wisp happy center
@sfx poof
@flash #c9b8ff
wisp[happy]: And now... my turn! Ladies, gentlecapys, and esteemed others: tonight, I shall perform for you!
wisp[happy]: At *9:35*, in the Lounge, I present *The Living Statue*! *Twenty minutes* of perfect stillness! A feat unmatched!
@show zuzu normal farleft
zuzu[normal]: so... you stand there. and do nothing.
@shake 5
wisp[angry]: I stand there and do nothing BEAUTIFULLY, thank you!
@hide zuzu
@show lulu happy farleft
lulu[happy]: Lulu will watch! Lulu-lu~! Front row! Lulu loves a show!
@show fennel happy farright
fennel[happy]: I will come too, and sketch it! Twenty minutes of a perfect model who does not move? An artist's dream!
@hide lulu
@hide fennel
@show bramble happy farleft
bramble[happy]: Oh... I'd love to watch too... I'll prune my roses at *nine* first... like every evening... then I'll come...
@show tumble happy farright
tumble[happy]: Twenty minutes of watching someone stand still? Sounds like my kind of show... zzz... save me a comfy chair...
wisp[happy]: Hoho! An audience of four! Splendid! The curtain rises at 9:35 sharp. Do not be late, my dear audience!
@hide all
@show nibs normal farleft
nibs[normal]: Zuzu and I will be in the *library* all evening. There's an old terminal there that requires... investigating.
@show zuzu happy farright
zuzu[happy]: hacking. he means hacking.
@hide all
@show duchess normal farleft
duchess[normal]: I shall be in *my room*, darling. *Beauty sleep.* This face does not maintain itself.
duchess[angry]: Also, someone has made off with one of my gift-shop mannequins. If it was one of you, return it, or I'll dress you in beige.
@show pepper happy farright
pepper[happy]: Me? *I'll be around. Taking pictures!* Wherever there's a story, there's Pepper!
@hide all
@show marigold normal center
marigold[normal]: I'll be in the *infirmary* restocking. I should be *back around ten*. Please, everyone... be careful tonight.
@hide marigold
@show grub happy center
@ifnot hung_grub -> grub_ask
grub[happy]: And Mochi's helping me *wash dishes* in the kitchen, like we planned! Half past nine, partner. Don't be late!
mochi: Wouldn't miss it. Bring on the mountain of plates.
@jump grub_done
@label grub_ask
grub[happy]: Oh! Mochi! Could you lend me a paw *washing dishes* tonight? Kitchen, half past nine? There's a mountain of plates!
mochi: Sure, Grub. I'll be there.
@label grub_done
grub[happy]: Ha! Dish duty: the most dangerous job in the resort. Watch out for flying forks!
@show coco happy farleft
coco[happy]: There! Everybody's got a heading, and everybody knows where everybody else is. Nobody's sneaking anywhere tonight.
coco[normal]: Remember, crew: *Nighttime starts at ten*. Be in your cabins by then and lock your doors.
coco[happy]: And tomorrow morning, we all meet right here for Grub's breakfast. All fifteen of us. That's an order!
@shake 5
all: Aye aye, Captain!
@hide all
think: Fifteen plans. Fifteen... alibis. No. That's a terrible way to think about it. They're just plans.
think: Coco in the bath at 9:45. Wisp on stage at 9:35. Bruno in the sauna at 9:30. Me in the kitchen with Grub...
think: Everyone accounted for. Everyone safe. ...So why did it feel like the whole resort was holding its breath?
@end
""",
	# =====================================================================================
	"night": """
@bg kitchen
@music daily
@card 9:30 PM | The Kitchen
narr: The kitchen was warm and cluttered and smelled like soap and leftover yuzu. A big clock ticked above the sink.
@show grub happy center
grub[happy]: Right! You wash, I dry. Mind the big pot, it bites. Not literally. Not like Snapjaw.
mochi: Deal. Wow... you used every single pan in this kitchen, didn't you?
grub[happy]: And three from the gift shop! Ha! A clean kitchen is the sign of a chef who didn't try hard enough.
narr: Somewhere down the hall, very faintly, there was a soft *POOF*... followed by a chorus of 'ooooh!'
grub[normal]: That'll be Wisp's big show starting. 9:35 on the dot. Shame we're missing it. Then again... it's a statue. I can picture it.
think: Scrub. Rinse. Stack. The water was warm, the clock was ticking, and for the first time all day, I almost felt normal.
grub[sad]: ...Hey, Mochi. Can I tell you something? That Home Movie. My mum's restaurant. I keep seeing it when I close my eyes.
@choice What should I say?
> We'll get home, Grub. All of us. -> night_home
> Your mum would be proud of tonight's dinner. -> night_proud
@label night_home
grub[happy]: ...Yeah. Yeah, we will. Coco said so, and I'd never argue with a captain who eats three helpings.
@jump night_after
@label night_proud
grub[happy]: Ha... she'd say the dumplings needed more salt. But yeah. I think she would. Thanks, partner.
@label night_after
narr: We worked through the mountain. Bowls. Cups. A ladle that, as far as I could tell, had been used to stir a cake.
narr: Then, at about five to ten, a wave of applause drifted in from the direction of the Lounge.
grub[happy]: Hear that? Wisp's show must be over. Twenty minutes of standing still, and they're clapping like he cured a cold!
@sfx chime
narr: Ding-dong, ding-dong. Every speaker in the resort crackled to life.
snapjaw[happy]: Attention, guests! It is now *10:00 PM*. Nighttime is officially in effect!
snapjaw[normal]: The *Bathhouse is now locked*. My sensors are watching. Nobody in, nobody out, until 7 AM. Sweet dreams! Snap-snap-snap!
grub[normal]: That's our cue. Go on, Mochi, off to bed. I'll finish the last few. And thanks. Really.
@hide all
@bg room
@music stop
narr: My room was small, clean, and quiet. A futon. A lamp. A door that locked from the inside, at least.
think: I lay there in the dark, listening to the hum of the resort. Somewhere, a pipe gurgled. Somewhere, a door clicked shut.
think: Fifteen of us. One promise. Nobody checks out.
think: ...I fell asleep with my tablet's timer still glowing on the nightstand. 69:38:51. 69:38:50...
@end
""",
	# =====================================================================================
	"discovery": """
@bg room
@music stop
@sfx chime
snapjaw[happy]: Ding-dong! Good morning, my lovely guests! It is now 7:00 AM. Nighttime is over! Rise and shine!
@card DAY 2 | 7:00 AM
think: Morning already? I barely slept. My dreams were full of draining water and ticking clocks.
think: There's only one cure for a night like that. A morning soak. The Bathhouse should be unlocked by now.
@bg changing
@music daily
narr: The changing room was quiet. Wooden buckets stacked by the wall. Lockers. Coat hooks. And two capybaras, already there.
@show pepper happy left
@show marigold normal right
pepper[happy]: Morning, Mochi! You too, huh? I'm after a sunrise shot of the bath. Steam, lanterns, golden light. Front page!
marigold[normal]: And I'm here for my joints. Warm water is wonderful for circulation. Good morning, Mochi. Did you drink water?
mochi: ...Some?
marigold[happy]: Some is a start. Come on, let's go in together.
@hide all
@music stop
@bg bath_body
@wait 0.8
narr: The steam was thick this morning. Pale light, floating yuzu, the stone lantern still glowing faintly...
narr: ...and something else in the water.
think: Is that... a hat?
narr: A white captain's hat, drifting in slow circles. And beyond it, a striped shirt. Face down. Not moving.
@sfx heartbeat
think: No. No, no, no. That's...
@show pepper shock farleft
@shake 8
pepper[shock]: C... Coco?!
@show marigold shock farright
marigold[shock]: Captain! CAPTAIN COCO!
@sfx splash
narr: Marigold plunged into the water without a second thought and pressed a paw to Coco's neck. She waited. She waited too long.
marigold[sad]: ...She's cold. She's been gone for hours. I'm... I'm so sorry. I'm too late.
@hide all
@sfx body_found
@music tension
@shake 14
@flash #ff4f6d
@card A BODY HAS BEEN DISCOVERED!
snapjaw[happy]: Ding-dong! Oh my, oh my! Looks like somebody soaked a little too long! All guests, report to the Yuzu Bath! Chop-chop!
narr: The announcement was still echoing when the others started pouring in.
@show lulu shock farleft
@show reginald shock farright
lulu[shock]: N-no... that's Coco! That's Captain Coco! Somebody wake her up! Why isn't anybody waking her up?!
reginald[shock]: Captain... we fenced just last night. She beat me. She laughed. She was... she was laughing...
@hide lulu
@show bruno sad farleft
bruno[sad]: ...Coco said... nobody on the crew checks out... Coco promised...
@hide all
@show grub sad farleft
grub[sad]: She had three helpings last night... She said she'd see us all at breakfast... I made her pancakes...
@show tumble sad farright
tumble[sad]: ...I'm old. It's supposed to be the old ones first. Not her. Not like this.
@hide all
@show duchess shock farleft
duchess[shock]: This... this is a joke. A horrid, tasteless joke. Somebody tell me it's a joke!
@show fennel sad farright
fennel[sad]: The hat... floating like a little white boat... I do not want to remember this. But I will. I always do.
@hide all
@show nibs sad farleft
nibs[sad]: Hypothetically... no. There's nothing hypothetical about it. She's really...
@show zuzu sad farright
zuzu[sad]: ...not funny. not funny at all.
@hide all
@show bramble sad farleft
bramble[sad]: Oh... oh, Captain... the water was supposed to keep you warm...
@show wisp shock farright
wisp[shock]: ...Captain...
narr: Wisp said nothing else. He just stood at the back, staring at the water, his gloved paws clenched tight.
@hide all
@music sad
think: Coco. Loud, bossy, wonderful Coco, who promised we'd all sail home. Who said nobody on her crew would check out.
think: Yesterday she was laughing in this very water. And now...
@show pepper angry farleft
@music tension
pepper[angry]: Wait. Wait! Everyone, look at the edge of the bath. Right there, next to her.
narr: Lying on a foam-covered rock at the water's edge was a long strip of *red cloth*.
pepper[angry]: That's a *red headband*. And there's only one capybara here who wears a red headband.
@show bruno shock farright
@shake 8
bruno[shock]: B-Bruno's headband...? But... Bruno left it on his hook...
pepper[angry]: Oh, really? And you just happened to be in the bathhouse last night! In the sauna! Right next door!
bruno[sad]: Bruno... Bruno did not... Bruno would never hurt Coco...
@hide bruno
@show marigold sad farright
marigold[sad]: Pepper, please. Not now. Not while she's still... right there.
pepper[normal]: ...Fine. But I'm writing it down. Scoop or no scoop, somebody did this.
@hide all
@sfx boom
@shake 16
@music snapjaw
@show snapjaw happy farright
snapjaw[happy]: Snap-snap-snap! Ooh, a full house! And so early in the morning! I knew you had it in you!
@show reginald angry farleft
reginald[angry]: YOU! You monster! You did this! You drove one of us to...!
snapjaw[normal]: Me? I simply provided the motive. The paws that did the deed belong to one of YOU. Isn't that delicious?
@hide reginald
snapjaw[happy]: And now, as promised, it's time for an *investigation*! Here. The *Snapjaw File*. Everything my sensors know about the body.
@clue snapjaw_file
snapjaw[normal]: And remember the rules! The Bathhouse was *locked from 10 PM to 7 AM*. Nobody went in. Nobody came out. My sensors never lie!
snapjaw[happy]: Investigate wherever you like. When you're done, I'll call you all down for the *Splash Trial*!
snapjaw[happy]: Find the culprit... or don't! Either way, I get a show! Snap-snap-snap! Happy hunting!
@sfx door
@hide snapjaw
think: Coco is gone. And one of us... one of the capybaras standing in this room... did this to her.
think: I don't want to believe it. But if we vote wrong, everyone except the culprit gets punished. The truth is all we have.
think: ...Okay. Deep breath, Mochi. Coco protected all of us. Now it's my turn. I'm going to find out what really happened here.
@end
""",
	# =====================================================================================
	"epilogue": """
@bg lobby
@music sad
narr: The Bubble Lift carried us back up in silence. Thirteen capybaras, where yesterday there had been fifteen.
think: Yesterday morning, I didn't know any of them. Now two of them are gone, and it feels like a hole in the world.
narr: Nobody said anything for a long time. The lobby fountain gurgled. The lanterns glowed. The shutters stayed shut.
@show bruno sad center
narr: Then Bruno sat down, right there on the floor, and started to cry. Big, quiet tears that rolled down past his scar.
bruno[sad]: Coco... called Bruno a lighthouse... Coco was the first one who was not scared of Bruno...
bruno[sad]: And Wisp... Wisp did magic for everyone... Bruno thought Wisp was a friend... Bruno does not understand...
@show bruno sad right
@show pepper sad left
pepper[sad]: ...Bruno. Hey. Can I... say something?
pepper[sad]: I pointed my finger at you in front of everyone. I didn't have facts. I had a headline. That's the worst kind of journalism.
pepper[sad]: If Mochi hadn't kept digging, we'd have voted for you. And then all of us... I'm sorry. I'm really, really sorry.
bruno[normal]: ...Pepper was scared. Bruno was scared too. Scared makes everyone silly. Even Bruno. Especially Bruno.
bruno[happy]: Bruno forgives Pepper. ...But Pepper owes Bruno one cake.
pepper[happy]: ...Deal. Two cakes. I'll get Grub to bake 'em. Scoop of the year: Pepper Quill admits she was wrong.
@hide all
@show reginald sad farleft
narr: Reginald walked to the lobby fountain and set something down on its edge. A white captain's hat, still a little damp.
reginald[sad]: She never let me win. Not once. A true opponent. A true friend. I shall keep practicing, Captain. For both of us.
@show grub sad farright
grub[sad]: I'm making her favorite tomorrow. Seaweed crackers with way too much butter. Nobody's allowed to skip it.
@hide all
@show lulu sad farleft
lulu[sad]: Wisp's last trick... the stars... they were so pretty. Why does that make it worse? Lulu-lu...
@show tumble sad farright
tumble[sad]: Statues don't breathe, kiddo. But folks do. And folks make mistakes they can't take back. Remember that one.
@hide all
@show fennel sad farleft
fennel[sad]: I will paint them both. Coco, laughing in her bath. Wisp, taking his bow. As they were... before all this.
@show bramble sad farright
bramble[sad]: I'll plant something by the bath for her... something stubborn... something that blooms even in the cold...
@hide all
@show nibs sad farleft
nibs[sad]: I keep searching for a fact that makes any of this make sense. Hypothetically, there should be one. There isn't.
@show duchess sad farright
duchess[sad]: ...I'm sewing her a new hat, darling. Gold anchor and all. Somebody has to keep this crew looking like a crew.
@hide all
think: Wisp did something terrible. But it was Snapjaw who handed him the reason. Snapjaw who built this cage. Snapjaw who's laughing right now.
think: Somebody trapped us here. Somebody filmed those Home Movies. And somebody is going to answer for it.
@music stop
mochi: Everyone... I have something to say.
@show marigold normal farleft
@show zuzu normal farright
mochi: Coco made us a promise. Nobody on her crew checks out. She can't keep that promise anymore... so we'll keep it for her.
mochi: No more trials. No more votes. We find whoever's really behind Snapjaw, and we get out of here. All thirteen of us. Together.
zuzu[happy]: ...ngl, that was kinda cool. i'm in.
marigold[happy]: Me too. Everybody drink some water first. Then we'll take down a robot crocodile.
@hide all
@sfx chime
@music snapjaw
@shake 10
@show snapjaw happy center
snapjaw[happy]: Snap-snap-snap! Aww, look at you all! Bonding! Healing! Growing! It's enough to make a caiman cry!
snapjaw[normal]: Make all the promises you like, my darlings. Promises are like bubbles. Pretty, shiny... and oh so easy to pop.
snapjaw[happy]: Rest up, little guests! Plenty more fun where that came from! Your stay at Yuzu Springs has only just begun! Snap-snap-snap!
@sfx door
@hide snapjaw
@music sad
think: ...Laugh while you can, Snapjaw. Coco gave us her courage, and I'm not letting go of it.
think: Somewhere in this resort, the truth is waiting at the bottom of the water. I'll find it. However deep I have to dive.
@card CHAPTER 1 — END | 13 guests remain at Yuzu Springs
@end
""",
}

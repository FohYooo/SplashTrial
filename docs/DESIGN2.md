# SPLASH TRIAL — Case 2: "Murder on the Mudlark" — Design Bible (SPOILERS)

Read docs/ARCHITECTURE.md (contracts, DSL, art specs) and docs/DESIGN.md §2 (cast voices/looks) first.
Case 2 is **Chapter 2**. It follows directly after Case 1 (Captain Coco was murdered by Wisp Vanderloo, who was
executed). **13 survivors**: mochi, bruno, lulu, pepper, duchess, bramble, nibs, zuzu, reginald, grub, tumble,
marigold, fennel. Dead before Case 2 starts: coco, wisp. Dead after the murder: marigold (12 at the trial).
Mochi's pronouns: they/them. Everyone else as in DESIGN.md §2.

Design goal (user request): **the killer must NOT be obvious from the beginning.** Tumble is comic relief, barely
speaks, and has the strongest alibi in the case, witnessed by the PLAYER themself. Plant clues neutrally. Never write
lines that wink at Tumble before the trial's turn. Several capybaras look more suspicious (Bruno, Duchess, Grub).

---------------------------------------------------------------------------------
## 1. Premise & setting

The morning after the first execution, Snapjaw announces the guest wing is "closed for renovations". He leads the
survivors down a long spiral stair into a vast cavern under the resort: the **Lower Lake**, a black underground lake.
He pulls a giant plug lever: the lake **drains** in a roaring whirlpool (animated cutscene, see §8) and reveals an old
**paddle-steamer**, the ***Mudlark***, sitting on the mud flats at a stone dock. It is the new living area: guests sleep
in its cabins from now on. The gangway is raised at night.

Look: an old riverboat (white-and-teal paint gone grimy, brass fittings, red paddle wheel at the stern, twin smokestacks,
paper lanterns strung on deck, Snapjaw logos/cameras everywhere), inside a cave lit by glowing aqua fungus and lanterns.
Still part of the resort's spa theme: there is a small onsen tub on the promenade deck.

Ship areas (bg ids, see §7): dock, promenade deck, dining saloon, cabin corridor, guest cabin, Tumble's cabin, infirmary,
purser's office, boiler room, laundry.

### Mudlark Rules (clue `rules2`)
1. Guests may not leave the resort. The *Mudlark* is your new home, sweet home!
2. Nighttime is 10:00 PM - 7:00 AM. The gangway is raised during Nighttime. Nobody gets on or off the ship.
3. Cabin doors have no locks. Fire safety first!
4. A killer who isn't caught at the Splash Trial gets to CHECK OUT.
5. After a body is found: investigation, then a Splash Trial.
6. No violence against Warden Snapjaw (he still bites).

---------------------------------------------------------------------------------
## 2. Chapter flow (step ids; story ids live in scripts/data/story/story_daily2.gd / story_case2.gd)

`aftermath` (story) → `drain` (cutscene screen, §8) → `prologue` → `freetime` (3 slots) → `motive` → `evening` →
`night` → `discovery` → `investigation` (screen) → `investigation_end` → `trial` → (vote correct ? `execution` →
`epilogue` → `credits` : `gameover` → retry trial | title).
Chapter 2 is unlocked when Chapter 1's credits finish; Chapter 1's credits lead straight into Chapter 2's `aftermath`.
The title screen gets a "Chapter 2" entry once unlocked.

---------------------------------------------------------------------------------
## 3. Story beats

### 3.0 Aftermath (`aftermath`) — bg `lobby`, morning
- `@card CHAPTER 2 | Murder on the Mudlark`. The 13 survivors in the lobby the morning after. Grief for Coco and Wisp
  (short, sincere). Bruno still wearing Coco's spare captain's hat? NO — keep it simple: Bruno sad, Lulu tries to cheer
  everyone, Pepper apologizes to Bruno again, Reginald vows to protect everyone "as the Captain would have".
- Chime. Snapjaw: guest wing closed for renovations, everybody follow him downstairs. Long spiral stair (narration).
- Ends in a dark cavern at the edge of a black lake: Snapjaw grabs a giant lever shaped like a bath plug chain:
  "Time to pull the plug! Snap-snap-snap!" → `@end` (the `drain` cutscene follows).

### 3.1 Prologue (`prologue`) — bg `ship_dock`, then `ship_deck`, `ship_hall`
- Picks up right after the drain: the ship revealed, steaming mud, a whale-sized sinkhole where the plug was.
- Snapjaw presents the *Mudlark*, gives `@clue rules2`, assigns cabins with keys-that-don't-lock (rule 3):
  **Cabin 1: Mochi, Cabin 2: Tumble, Cabin 3: Pepper** (one corridor, thin wooden walls). Others are on the other
  corridors (no need to list).
- Reactions: Pepper groans her cabin is next to "the snoriest capybara alive". Tumble: "Zzz... eh? I'll be quiet as a
  mouse." Mochi thinks it's fine, they like white noise.
- Bruno volunteers to shovel coal for the boiler (warm water for the deck tub). Grub claims the galley.
  Marigold sets up the ship's infirmary. Zuzu notices Snapjaw cameras. Nibs explains how a paddle steamer works.
- Ends with Snapjaw: free time until dinner.

### 3.2 Free Time (`freetime_intro`, 12 hangouts `hangout_<id>`, `freetime_outro`)
Same rules as Case 1: 3 slots, each 10–18 lines at that character's spot on the ship, ends with `@skill <id>` (ids from
scripts/data/skills.gd BY_CHAR) and sets `@flag hung_<id>`. Pickable: bruno, lulu, pepper, duchess, bramble, nibs, zuzu,
reginald, grub, tumble, marigold, fennel. Planting (all neutral, light-hearted):
- **bruno** (`ship_boiler`): shovels coal, sweaty. Shows his enormous boots ("Bruno's boots are size 'mountain'").
  Says he keeps a SPARE pair drying in the laundry because coal dust is very bad for boots.
- **lulu** (`ship_deck`): rehearses a sea-shanty pop song by the deck tub; she's scared of the dark cave water.
  Plans to stargaze ("well, fungus-gaze") on deck tonight with Bramble and Fennel.
- **pepper** (`ship_hall`): sets up her "newsroom" in Cabin 3. Shows her stopwatch: "A journalist times EVERYTHING."
  Complains about the thin walls.
- **duchess** (`ship_laundry`): horrified by the ship laundry; hangs her lilac shawl ("hand-dyed, irreplaceable").
  Points out the sewing basket with scissors ("for emergencies of fashion"). Says she can't sleep without her
  sleeping powder.
- **bramble** (`ship_deck`): planting moss in old lifebuoys; notes the cave fungus glows brightest around 11 PM.
- **nibs** (`ship_saloon`): sets up a chessboard; challenges Zuzu to an all-night match tonight. Explains the
  Echo-Matic? NO (keep the dictaphone out of Nibs' hangout). He explains capybara hearing ("we hear low sounds well").
- **zuzu** (`ship_purser`): found the purser's office; plays with an old **Echo-Matic** wax-cylinder dictaphone
  (Snapjaw brand, brass horn). Records "lol" and plays it back. Explains: 4-minute cylinders, a REPEAT lever, one
  winding of the spring runs two hours. ("boomer tech. kinda goated tho.") Mochi records a little "hello". Zuzu says
  anyone could borrow it, the office is never locked. (This is the ONLY place the device is explained before the
  investigation. Make it feel like a fun tech toy scene, not a clue scene.)
- **reginald** (`ship_deck`): fencing practice at the rail; appoints himself the ship's night watch "in the Captain's
  honour" but admits he always falls asleep by 10:30.
- **grub** (`ship_saloon`/galley): cooking; gets up at 6 AM every day to bake bread; ate too much, Marigold will
  bring him a tummy tonic tonight.
- **tumble** (`ship_purser`): Tumble is dozing in the purser's office armchair "because it's the quietest room on the
  boat". Rambles about his tiny village hot spring he built with his own paws sixty years ago ("a little stone tub, warm
  as a hug"). Asks Mochi to keep him company while he naps. Accidentally wise line: "Sleep is the best alibi for
  getting out of chores, sonny." (Joke, not a wink.) Do NOT mention the dictaphone in this hangout.
- **marigold** (`ship_infirmary`): sets up the infirmary. Shows her **rounds log** clipboard: she writes down every
  visit. Her nightly routine: 10:30 PM Grub's tummy tonic, then she puts the kettle on and at 11:00 sharp brings
  chamomile to Mr. Tumble for his old joints ("doctor's orders, he never wakes up for it, bless him"). The heavy brass
  **anchor doorstop** holds her door open ("it weighs a ton, I can barely lift it").
- **fennel** (`ship_saloon`): paints the saloon; notices the purser's office has "a little rack of brass-capped wax
  cylinders, like jars of jam, magnifique". (Light.)

### 3.3 Motive (`motive`) — bg `ship_saloon`, 5 PM
- Snapjaw hands out **Postcards from Home**: each shows something precious at home that will be destroyed in 3 days
  unless someone checks out. Mochi's: their favorite little hot spring back home being filled with concrete.
- Reactions (short): Lulu cries, Duchess tears hers up, Reginald refuses to look. Tumble seems to have fallen asleep
  holding his ("Zzz..."), postcard face-down on his belly. (Neutral. Others have stronger reactions.)

### 3.4 Evening (`evening`) — bg `ship_saloon`, 8 PM dinner
Plans are said aloud (important for the trial):
- Grub spills tomato soup on the Duchess's lilac shawl. Duchess: hangs it in the laundry to dry.
- Marigold confiscates the Duchess's sleeping powder ("far too strong, dear, doctor's orders"). Duchess, furious:
  "You'll regret meddling with me, nurse!" (Everyone hears it.)
- Marigold repeats her rounds: 10:30 Grub's tonic, kettle on, 11:00 chamomile for Mr. Tumble.
- Bruno: spare boots drying in the laundry, he'll go to bed early in his cabin, alone.
- Nibs & Zuzu: all-night chess in the saloon. Lulu, Bramble & Fennel: on the promenade deck from 10:15 until about
  11:30 (glow-fungus watching, Fennel paints). Reginald: "night watch" (alone, by his own admission dozes off).
  Grub: bed after his tonic, up at 6 to bake. Pepper: "In my cabin, writing my scoop. Unless SOMEONE snores."
  Tumble: "Zzz... bed. Early. Very early." (one line). Duchess: alone in her cabin, "unable to sleep, thanks to SOME people".
- Mochi: tired, goes to Cabin 1.

### 3.5 Night (`night`) — bg `ship_cabin` (Mochi's cabin), night
- 10:00 PM nighttime chime. Mochi in bed. Through the thin wall: Tumble snoring, loud and steady, with a funny little
  squeaky cough now and then. Mochi finds it oddly soothing.
- Mochi lies awake thinking about the postcard; the snoring goes on and on.
- Around midnight the snoring simply stops. Silence. Mochi: "Finally... goodnight, Tumble." Falls asleep.
- (Don't mention exact cough timing here; Pepper's log has that. Do mention "the same little cough".)

### 3.6 Discovery (`discovery`) — bg `ship_hall` → `ship_infirmary_body`, 7 AM
- Morning chime. Mochi hears a crash and a scream from the lower deck. Runs down with Pepper.
- Grub stands in the infirmary doorway, a dropped breakfast tray (he was bringing Marigold her morning toast).
- Marigold is lying on the floor beside her cot, nurse cap fallen off, the kettle on the burner scorched dry. Non-graphic.
- `@card A BODY HAS BEEN DISCOVERED!` (`@sfx body_found`, `@music tension`). Everyone arrives. Grief.
  Duchess faints. Bruno is quiet and sooty. Pepper eyes Bruno ("Why are you covered in coal?" "Bruno shovels coal at
  6:30 every morning.").
- Snapjaw: Snapjaw File #2 (`@clue snapjaw_file2`), investigation announcement.

### 3.7 Investigation — see §5 (story_case2: `investigation_start`, `investigation_complete`, `inv2_*` scripts)
### 3.8 Investigation end (`investigation_end`) — the group rides the Bubble Lift down to the **Trial Pool** again.
### 3.9 Splash Trial (`trial`) — see §6. Same room (bg `trial`); there are now three memorial portraits (Coco, Wisp,
Marigold) on their podiums.
### 3.10 Verdict / Confession
- After the correct vote: Tumble's eyes open fully for the first time. Calm, clear voice. Confession: the postcard
  showed his little village hot spring being bulldozed. He planned it the moment he saw it. He knew Marigold would come
  with chamomile at 11:00 and find his bed empty, so she had to be the one... He is ashamed. "I haven't truly slept in
  forty years, sonny. Old capybaras just close their eyes and listen." Short and sad.
- Snapjaw announces "THE ENDLESS LULLABY" → execution screen.
- Wrong vote → Snapjaw "WRONG!" reveals Tumble → game over.
### 3.11 Epilogue (`epilogue`) — bg `ship_deck`, night
- 11 survivors on deck (after the execution). Grub can't stop crying (he found her). Duchess admits Marigold was right about the powder.
  Pepper tears out the page of her snore log. Mochi resolves again to find the mastermind.
- Snapjaw: "Two down, plenty to go!" `@card CHAPTER 2 — END` then credits.

---------------------------------------------------------------------------------
## 4. The Case (truth)

**Victim:** Marigold Fern. **Culprit:** Old Man Tumble.
**Weapon:** the infirmary's heavy brass **anchor doorstop**. Nibs: the bruise on the back of her head matches its fluke.
**Time:** about **10:40 PM** (her rounds log's last entry "10:40 kettle on" trails off into a smear; the kettle was found
boiled dry; she never brought the 11:00 chamomile — Tumble's teacup is clean and dry).

Timeline:
1. Afternoon (Day 1): Tumble borrows the Echo-Matic dictaphone from the (unlocked) purser's office and records four
   minutes of his own snoring on a blank cylinder (his natural snore has a little squeaky cough in it).
2. 10:00 PM: In Cabin 2 he places the dictaphone on the rug beside his bunk, horn against the wall shared with
   Mochi's Cabin 1, winds it fully (2 hours), flips the REPEAT lever, and slips out (corridor empty at night).
3. ~10:15: Laundry. He pulls on **Bruno's spare boots** (stuffing ship-issue socks into the toes) and snips a corner off
   the **Duchess's lilac shawl** with the sewing-basket scissors.
4. ~10:40: Infirmary. Marigold, back from Grub's tonic, puts the kettle on and writes "10:40 kettle on". He strikes her
   with the anchor doorstop from behind. He leaves the lilac scrap on her cot (to frame Duchess).
5. Boiler room: buries the doorstop in the coal pile, leaving huge but shallow, short-strided boot prints in the coal
   dust (to frame Bruno). Laundry: returns the boots. Back in Cabin 2 by ~11:10 via the back stairs; the recording masks
   any noise. The dictaphone's spring runs down at **midnight**: the "snoring" stops.
6. **6:00 AM**: Tumble carries the dictaphone back to the purser's office. Grub, up early to bake, sees a small hunched
   figure carrying "a big trumpet thing" in the dark and thinks it was the ship's ghost. Tumble burns the cylinder in the
   boiler furnace (before Bruno's 6:30 shoveling). He forgets the REPEAT lever is still ON.
7. 7:00 AM: Grub brings Marigold her breakfast and finds her.

Alibis for 10:40 PM (used in the trial):
- Mochi: Cabin 1, heard Tumble snoring nonstop 10:00–midnight. Pepper: Cabin 3, heard + LOGGED the snoring.
- Nibs & Zuzu: chess in the saloon until 1 AM (each other). Lulu, Bramble, Fennel: deck 10:15–11:30 (each other).
- No alibi: Bruno (asleep alone), Duchess (alone, no powder, "couldn't sleep"), Reginald (night watch, dozed off),
  Grub (asleep after the 10:30 tonic, also the last to see Marigold alive and the one who found her).
- Tumble: "asleep" — the strongest alibi of all.

---------------------------------------------------------------------------------
## 5. Clues (Truth Drops) — ids fixed (scripts/data/clues.gd), all 14 REQUIRED in Chapter 2

| id | name | where | gist |
|---|---|---|---|
| rules2 | Mudlark Rules | prologue | the six rules above (gangway raised at night, no locks) |
| snapjaw_file2 | Snapjaw File #2 | discovery | Victim Marigold, found in the infirmary at 7:00 AM by Grub. One heavy blow to the back of the head. Time of death 10:00 PM - midnight. |
| rounds_log | Marigold's Rounds Log | infirmary: Rounds log | "10:30 Grub - tummy tonic. 10:40 kettle on - Mr. Tumble's chamomile at 11:00 sharp!" The last line trails off into a smear. |
| lilac_thread | Lilac Silk Scrap | infirmary: Cot | a little scrap of lilac silk on Marigold's cot; same color as the Duchess's shawl |
| grub_ghost | Grub's Ghost Story | infirmary: talk Grub | at 6:00 AM, going to the galley, Grub saw a small hunched figure carrying "a big trumpet thing" go into the purser's office in the dark. He thinks it was the ship's ghost. |
| anchor_doorstop | Anchor Doorstop | boiler: Coal pile | the infirmary's heavy brass anchor doorstop, buried in the coal pile. Coal dust in the fluke, wiped clean of anything else. |
| boot_prints | Giant Boot Prints | boiler: Boot prints | huge boot prints in the coal dust from the door to the coal pile and back. Oddly shallow and close together. |
| wax_lump | Melted Wax Lump | boiler: Furnace | a blackened lump of melted wax in the furnace ash, with a little brass end-cap stuck in it. Bruno says it wasn't there when he banked the fire last night. |
| bruno_boots | Bruno's Spare Boots | laundry: Boot rack | Bruno's spare boots, coal dust in the treads. Crumpled ship-issue socks stuffed deep into both toes. Bruno left them clean to dry yesterday. |
| duchess_shawl | Duchess's Shawl | laundry: Drying line | hanging to dry after the soup accident. One corner is missing, cut in a perfectly straight line, like with scissors. |
| snore_alibi | Tumble's Snoring | cabin corridor: Cabin 2 door | Mochi heard Old Man Tumble snoring through the wall nonstop from 10:00 PM until midnight. Then it suddenly stopped. |
| pepper_log | Pepper's Snore Log | cabin corridor: talk Pepper | Pepper timed the snoring with her stopwatch: the same squeaky little cough at 10:04, 10:08, 10:12... exactly every 4 minutes, until it stopped at midnight. |
| tumble_bunk | Tumble's Bunk | Tumble's cabin: Bunk & rug | the bunk is neatly made, the pillow still smooth. Four small round dents in the rug beside the bunk, close to the wall shared with Cabin 1. |
| dictaphone | Echo-Matic Dictaphone | purser: Dictaphone | Snapjaw-brand wax-cylinder dictaphone. 4-minute cylinders, one winding = 2 hours. Its REPEAT lever is still switched ON, the spring fully run down, and no cylinder inside. It stands on four little round feet. |

Neutral writing: in the investigation, Tumble's bunk and the dictaphone are just "odd details". Mochi should NOT connect
them aloud during the investigation (at most "Huh. Weird." thoughts).

---------------------------------------------------------------------------------
## 6. Splash Trial — segment outline (trial data ids in scripts/data/trial_data2.gd; prefix `c2_`)

1. **Opening** — Snapjaw welcomes them back; three memorial portraits; rules recap is short (they know them).
   Pepper immediately accuses Bruno ("Coal all over him!"); Reginald accuses Duchess ("she threatened her!"); Grub
   panics because he found the body. Marigold's death: Nibs reads the file.
2. **Present — `c2_q_weapon`** (speaker nibs) "The file says one heavy blow. What did the culprit use?" → anchor_doorstop.
3. **Choice — `c2_q_time`** (speaker grub) "When was Marigold attacked?" options 10:00 PM / 10:30 PM / 10:40 PM / 11:00 PM /
   Midnight → 10:40 PM (rounds log + scorched kettle). Wrong line: think about her log.
4. **Splash Debate — `c2_debate_boots`** vs Bruno. Drops: boot_prints, bruno_boots, anchor_doorstop.
   Statements: Pepper "Giant prints in the coal! {Nobody has feet as big as Bruno}!" / Reginald "The brute {walked to that
   coal pile in his own boots}!" / Bruno "Bruno was asleep..." / Duchess "Disgusting. Coal everywhere." → answer: Reginald's
   statement, weak 0, drop bruno_boots (socks in the toes, shallow short prints: someone SMALL wore Bruno's boots).
5. **Splash Debate — `c2_debate_shawl`** vs Duchess. Drops: lilac_thread, duchess_shawl, rounds_log.
   Statements: Reginald "She threatened Marigold at dinner, I heard it myself!" / Lulu "That scrap is {the Duchess's
   lilac}!" (decoy weak spot) / Pepper "Her shawl was {torn off in the struggle}! Scoop!" / Duchess "I was in my cabin,
   darlings! Alone!" → answer: Pepper's statement, drop duchess_shawl (cut straight with scissors = planted, not torn).
6. **Choice — `c2_q_laundry`** (speaker nibs) "Bruno's boots and the Duchess's shawl... both were taken from the same
   place. Where did the culprit go first?" options Boiler room / Laundry / Galley / Purser's office → Laundry.
7. Dialogue: alibis at 10:40 (§4). Duchess, Bruno, Reginald, Grub have none. Arguments. Then Pepper: "At least ONE of
   us has a perfect alibi. Tumble! Mochi and I heard him snore the whole night!" Mochi agrees at first — they heard it too.
   Mochi then remembers: Marigold's 11:00 chamomile... and the "same little cough".
8. **Splash Debate — `c2_debate_snore`** Drops: snore_alibi, pepper_log, rules2.
   Statements: Pepper "I heard him {nonstop from ten until midnight}!" (decoy) / Lulu "Old capybaras just snore, it's
   natural!" / Pepper "Every snore was {perfectly natural}, cough and all!" / Tumble "Zzz... eh? Snoring? Me?" →
   answer: Pepper's 3rd statement, weak 0, drop pepper_log (the identical cough exactly every 4 minutes = a loop).
9. **Bubble Letters — `c2_bubbles_recording`** "A cough that repeats exactly every four minutes, all night long... That
   wasn't snoring. It was a ___!" → RECORDING (decoys e.g. "SPALMTEU"), time 70.
10. **Present — `c2_q_device`** (speaker zuzu) "ok but what on this boat can record a sound and loop it?" → dictaphone.
11. **Character — `c2_q_who`** (speaker nibs) "Then whose snoring was recorded on that cylinder?" exclude mochi → tumble.
12. Dialogue: everyone stunned. Tumble keeps "dozing". Then he speaks clearly for the first time.
13. **Rebuttal Showdown — `c2_rebuttal_tumble`** opponent tumble. Intro: "Sonny... I'm ninety-one. Let an old capybara
    sleep." Lines: "I can barely climb a staircase, let alone fight a nurse!" / "Anybody can record anybody, sonny!" /
    "I nap in that office every day! Of course I've seen the contraption!" / "Marigold was my friend. She brought me tea
    every night!" Final: "Prove that {contraption was ever beside my bunk}!" drops tumble_bunk, grub_ghost, wax_lump,
    dictaphone → tumble_bunk (four round dents = the dictaphone's four feet, by the shared wall; smooth pillow = never slept).
14. **Present — `c2_q_cylinder`** (speaker tumble) "Then where's the cylinder, eh? Play it for everyone!" → wax_lump
    (burned in the furnace; Grub's "ghost" at 6 AM carrying the trumpet = Tumble returning the dictaphone).
15. **Case Rewind — `c2_rewind_final`** 6 panels:
    1. "In the afternoon, the culprit borrowed the purser's ___ and recorded four minutes of his own snoring."
       [Echo-Matic dictaphone, ship's bell, speaking tube] (bg ship_purser)
    2. "At 10:00 PM he set it beside his bunk against Mochi's wall, flipped the ___ lever, and slipped out."
       [REPEAT, brake, whistle] (bg ship_tumble_cabin)
    3. "In the laundry he pulled on ___ and snipped a corner off the Duchess's shawl." [Bruno's spare boots,
       Reginald's fencing shoes, Grub's kitchen clogs] (bg ship_laundry)
    4. "At 10:40, while Marigold put the kettle on, he struck her with the ___." [anchor doorstop, kettle, wax cylinder]
       (bg ship_infirmary)
    5. "He left the lilac scrap on her cot, buried the doorstop in the ___, and returned the boots."
       [coal pile, furnace, laundry basket] (bg ship_boiler)
    6. "At 6:00 AM he carried the dictaphone back, where Grub mistook him for a ___, and burned the cylinder in the
       furnace." [ghost, burglar, Snapjaw] (bg ship_hall)
    culprit tumble; finale: "And the capybara who 'slept' through the whole night... is YOU, Old Man Tumble, the Ace Napper!"
16. **Vote — `c2_vote_final`** culprit tumble, fallback duchess, threshold 60.
17. Correct → confession (§3.10) → `@end`. Wrong → Snapjaw "WRONG!" reveals Tumble → `@end`.

The vote prompt names the victim (Chapter data `victim_name`).

---------------------------------------------------------------------------------
## 7. Art (all new, ship_* backgrounds 1280×720, ARCHITECTURE §6 rules; keep lower-left x<330,y>340 and lower-right
x>950,y>340 calm). Cave-lit riverboat look: warm lanterns + cold aqua fungus glow, brass and grimy teal paint.

| bg id | content |
|---|---|
| ship_dock | the drained Lower Lake: wet mud flats, the *Mudlark* paddle-steamer moored at a stone dock, steam rising, cave ceiling with stalactites + glowing aqua fungus, the empty plug hole whirl-scar in the mud, Snapjaw banners |
| ship_deck | promenade deck at night: rail, paper lanterns, smokestacks, small steaming wooden onsen tub, lifebuoys, cave glow beyond |
| ship_saloon | dining saloon: long table, brass lamps, portholes, piano, chessboard on a side table |
| ship_hall | cabin corridor: three wooden doors with brass numbers 1 2 3 (left to right), a brass speaking-tube mouth on the wall, narrow, lamplit |
| ship_cabin | a guest cabin at night (Mochi's): bunk, porthole with cave glow, small lamp, wooden wall |
| ship_tumble_cabin | Tumble's cabin, morning: bunk neatly made with smooth pillow, droopy nightcap on a hook, rug beside the bunk, nightstand with a clean teacup, porthole |
| ship_infirmary | ship infirmary, evening: cot, medicine cabinet, desk with clipboard, kettle on a little burner, door held open by a brass anchor doorstop |
| ship_infirmary_body | same infirmary, pale morning: Marigold lying on the floor beside the cot (cartoon, non-graphic: face-down, nurse cap with green cross fallen off beside her, light-blue scrubs), kettle on the burner scorched, door swinging (NO doorstop), dropped breakfast tray in the doorway |
| ship_purser | purser's office: desk with the Echo-Matic dictaphone (brass horn, four little round feet), wall rack of brass-capped wax cylinders with ONE empty slot, safe, armchair |
| ship_boiler | boiler room: big furnace with glowing door, coal pile, coal dust on the floor with huge boot prints, pipes and pressure gauges, shovel |
| ship_laundry | laundry: wash tubs, drying lines with sheets and a lilac shawl, boot rack with Bruno's enormous boots, sewing basket with scissors |

### Investigation hotspots (rect = [x, y, w, h]; the art must draw the object INSIDE its rect)
- infirmary (bg ship_infirmary_body): body "Marigold" [440,440,380,140]; cot "Cot" [560,260,330,130];
  log "Rounds log" [370,140,110,140] (clipboard on the wall/desk); kettle "Kettle" [370,320,130,110];
  door "Door" [880,140,90,320]. People: grub (left, sad), nibs (right, normal).
- boiler (bg ship_boiler): coal "Coal pile" [360,360,260,200]; prints "Boot prints" [560,590,340,100];
  furnace "Furnace" [680,140,240,260]; gauges "Pressure gauges" [420,130,160,120]. People: bruno (left, sad), reginald (right, angry).
- laundry (bg ship_laundry): rack "Boot rack" [380,430,220,160]; line "Drying line" [420,110,460,200];
  basket "Sewing basket" [660,470,160,110]; tubs "Wash tubs" [800,330,140,120]. People: bramble (left, sad), duchess (right, angry).
- hall (bg ship_hall): door1 "Cabin 1 (yours)" [370,180,150,310]; door2 "Cabin 2 (Tumble)" [560,160,160,330];
  door3 "Cabin 3 (Pepper)" [760,180,150,310]; tube "Speaking tube" [490,70,70,80]. People: lulu (left, sad), pepper (right, normal).
- tumble_cabin (bg ship_tumble_cabin): bunk "Bunk & rug" [400,330,440,330]; nightstand "Nightstand" [850,360,100,150];
  porthole "Porthole" [560,120,140,140]; nightcap "Nightcap" [380,120,110,140]. People: tumble (left, normal; he is sitting up, sleepy).
- purser (bg ship_purser): dictaphone "Dictaphone" [560,300,200,200]; rack "Cylinder rack" [370,130,170,210];
  safe "Safe" [800,330,140,180]; armchair "Armchair" [380,420,160,170]. People: zuzu (left, normal), fennel (right, normal).
Room order: infirmary, boiler, laundry, hall, tumble_cabin, purser. Start room: infirmary.
Script ids: `inv2_enter_<room>`, `inv2_<room>_<hotspot id>`, `inv2_talk_<char>` (all in story_case2.gd).
Clue → hotspot: rounds_log=infirmary/log, lilac_thread=infirmary/cot, grub_ghost=talk grub, anchor_doorstop=boiler/coal,
boot_prints=boiler/prints, wax_lump=boiler/furnace, bruno_boots=laundry/rack, duchess_shawl=laundry/line,
snore_alibi=hall/door2, pepper_log=talk pepper, tumble_bunk=tumble_cabin/bunk, dictaphone=purser/dictaphone.

### Clue icons `art/props/clue_<id>.svg` (200×200) for the 14 ids above.

---------------------------------------------------------------------------------
## 8. "PULL THE PLUG" — lake-drain transition cutscene (screen `drain`, user request 2026-11-08)

Between `aftermath` and `prologue`. Must use **the same movement and effect language as the trial** (slanted cut-in
panels, hard ink shadows, diagonal glitch/static wipes, radial speed lines, screen shake + hit-stop, punchy zooms,
yuzu/aqua/ink palette, big slanted title badges). ~35–45 s, skippable (hold Space/Enter/click 1 s after 2 s), autotest
finishes in ~0.3 s. Beats:
1. Black → static wipe in on the dark cavern, black still lake, lantern reflections. Slow push-in.
2. Snapjaw cut-in (slanted panel, his happy portrait, speed lines): "Time to PULL THE PLUG!"
3. Extreme close-up of a giant chain + plug lever; Snapjaw yanks it — hit-stop, flash, shake, "GLUG!" badge.
4. The lake drains: a huge whirlpool spirals into a plug hole in the center (animated spiral/rings, the water level
   dropping, streaks), rumble, reaction cut-ins of survivors (slanted strips sliding in: shock portraits of Lulu, Bruno,
   Pepper, Reginald — 2–4 of them), rotating camera feel.
5. As the water falls, the *Mudlark* rises out of it: smokestacks, then paddle wheel, mud cascading off, steam. Low-angle.
6. Big slanted title badge slam: "THE MUDLARK" / sub "your new home, sweet home!"; then the 13 survivors? NO —
   a wide shot of the ship on the mud flats, lanterns flickering on one by one.
7. Diagonal static wipe out to bg `ship_dock` (the final frame should match it).
Make your own art (dr_*.svg props) or draw procedurally. Audio: rumble, gurgle, chain, glug (generate new sfx `dr_*`).

---------------------------------------------------------------------------------
## 9. Execution — "THE ENDLESS LULLABY" (horror, same rules as DESIGN.md §8: stylized dark-red blood allowed, never pink;
no dismemberment, wounds on portraits or visible corpse; ~45–60 s, cursed-broadcast VHS look, skippable)
Beats: "PLEASE STAND BY" static + a music-box lullaby slightly out of tune → the paddle wheel of the *Mudlark* at night,
turning slowly over black water → Tumble in a giant wooden cradle hanging from a chain, tucked in, nightcap on, wide awake
and terrified (sad/shock portraits, desaturated) → a mobile of tiny Snapjaw heads spins above him, Snapjaw's red eye in
the dark, distorted laugh → the cradle rocks higher and higher toward the paddle wheel, lullaby speeding up and warping →
each swing a cut to black + heavy thud; the wheel splashes dark-red water, drips running down the paddles → silence; the
cradle swings back empty, rocking gently; the nightcap floats on the water; the music box winds down → the tiny Snapjaw
heads on the mobile all turn to the camera at once → smash to black, "SWEET DREAMS", static, "TRANSMISSION ENDED".

## 10. Game Over
Same "Mochi's Last Soak" screen; Snapjaw's line uses the chapter's culprit name ("The real culprit was Tumble!").

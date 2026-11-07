# SPLASH TRIAL: Murder at Yuzu Springs — Design Bible (SPOILERS)

An original murder-mystery trial game in the "killing game + class trial" genre,
starring 15 original capybaras. Everything here (names, mastermind, minigame names,
UI look) is original. Do NOT reference or imitate any existing franchise's names,
characters, catchphrases or art (no bears, no "Ultimate", no "Nonstop Debate",
no "Objection!", no pink blood). Tone: darkly comedic, warm, a little sad. Never gory:
deaths and executions are implied/slapstick, cartoon-style.

Credits (exact): **All the hard work done by Foh, Noomie and Dani, little bit of help from Claude**.

---------------------------------------------------------------------------------
## 1. Premise

15 talented capybaras wake up inside **Yuzu Springs Resort**, a luxurious hot-spring
resort sealed behind steel shutters. Their host is **Warden Snapjaw**, a robotic caiman
in a top hat and monocle (half chrome, half green scales, one glowing red eye). He
speaks with gleeful menace and laughs "Snap-snap-snap!".

**The Checkout Rule:** the only way to leave is to *check out* — kill another guest
and get away with it at the **Splash Trial**. After a body is found there's an
investigation, then the Splash Trial (a debate held around the trial pool). Everyone
votes for the culprit.
- Majority votes for the real culprit → only the culprit is "punished" (execution).
- Majority votes wrong → everyone EXCEPT the culprit is punished and the culprit checks out.

### Resort Rules (clue `rules`, shown on the in-game rules card)
1. Guests may not leave Yuzu Springs Resort. Shutters do not open. Don't even try.
2. Nighttime is 10:00 PM – 7:00 AM. Some areas are locked during Nighttime.
3. The Bathhouse is locked during Nighttime. Warden Snapjaw's sensors record that nobody enters or exits it then.
4. A guest who kills another guest and is not caught at the Splash Trial gets to CHECK OUT.
5. After a body is discovered, an investigation and a Splash Trial will be held.
6. Violence against Warden Snapjaw is strictly prohibited (he bites).

---------------------------------------------------------------------------------
## 2. Cast (15 capybaras + mastermind)

Talents use the format "Ace <Talent>". Pronouns given for writers. Each has a voice.

| id | Name | Talent | Pron. | Look (for art) | Voice / personality |
|---|---|---|---|---|---|
| mochi | **Mochi** (PLAYER) | Ace Bath Connoisseur | they | warm caramel fur, little yuzu fruit balanced on head, white towel around neck, orange hoodie | earnest, curious, kind, quietly sharp. Inner thoughts in `think:` lines. |
| coco | **Captain Coco** | Ace Sailor | she | reddish-brown fur, white captain's hat with gold anchor, navy/white striped shirt, gold pocket-watch chain | loud, bold, protective, "Ahoy!", nautical slang, big laugh. VICTIM. |
| wisp | **Wisp Vanderloo** | Ace Magician | he | dark chocolate fur, tall black top hat, PURPLE/VIOLET cape with SILVER stars, white gloves, monocle | theatrical, polite, mysterious, speaks in flourishes ("Behold!", "my dear audience"). Uses "Stardust Powder" (silver-violet glitter) for his POOF effects. CULPRIT. |
| bruno | **Bruno Brawnsworth** | Ace Wrestler | he | huge, dark brown fur, RED headband, wrestling singlet, scar on eyebrow | gentle giant, talks about himself in third person ("Bruno is sorry"), loves the sauna. RED HERRING #1. |
| lulu | **Lulu Starling** | Ace Pop Idol | she | light golden fur, big PINK bow, sparkly pink dress, microphone, pink glitter cheeks | bubbly, says "Lulu-lu~!", secretly anxious. Carries "Bubblegum Pink" glitter. RED HERRING #2. |
| pepper | **Pepper Quill** | Ace Journalist | she | sandy fur, newsboy/press cap with PRESS card, camera on strap, notebook | fast-talking, nosy, "Scoop!", rival-detective energy, accuses hastily. |
| duchess | **Duchess Velveteen** | Ace Fashion Designer | she | pale cream fur, wide sun hat with feather, pearl necklace, lilac shawl | haughty, dramatic, "Darling", runs the resort gift shop display out of boredom. |
| bramble | **Bramble Thistlewood** | Ace Gardener | she | olive-brown fur, flower crown, green overalls, trowel | slow, soft, poetic about plants, observant about her garden. |
| nibs | **Professor Nibs** | Ace Chemist | he | grey-brown fur, round goggles on forehead, lab coat, bow tie | pedantic, "Hypothetically speaking...", loves facts (capybaras can hold breath ~5 min). |
| zuzu | **Zuzu Byte** | Ace Hacker | they | dark grey fur, cat-ear headphones, black hoodie, glowing laptop sticker | terse, deadpan, internet slang ("lol", "ngl", "skill issue"). |
| reginald | **Sir Reginald Puddlesworth III** | Ace Fencer | he | tawny fur, white fencing jacket, plumed beret, thin moustache, fencing foil | pompous, honorable, "I say!", defensive when suspected (no alibi). |
| grub | **Grub Pemberton** | Ace Chef | he | chubby, toffee fur, tall chef's hat, white chef coat, wooden spoon | cheerful, food puns, feeds everyone. |
| tumble | **Old Man Tumble** | Ace Napper | he | grey-white grizzled fur, droopy nightcap, half-closed eyes, blanket shawl | always sleepy, rambling, accidentally wise, "Zzz... eh? What?" |
| marigold | **Marigold Fern** | Ace Nurse | she | soft orange-brown fur, white nurse cap with green cross, light-blue scrubs, stethoscope | caring, worried, precise about medical facts. |
| fennel | **Fennel Dauber** | Ace Painter | he | light brown fur with paint smudges, red beret, long scarf, paintbrush behind ear | dramatic artiste, "Magnifique!", notices visual details. |
| snapjaw | **Warden Snapjaw** | Mastermind | he | robotic caiman: green scales left half, chrome right half, top hat, monocle, red eye, sharp toothy grin, bow tie | gleeful, theatrical, mocking, puns about checking out, "Snap-snap-snap!" |

---------------------------------------------------------------------------------
## 3. Story beats (in order)

### 3.1 Prologue (`prologue`)
- Mochi wakes in the **Lobby** (bg `lobby`) with no memory of arriving. Steel shutters over the doors.
- Meets the others one by one (each gets an intro card `@intro <id>` + 2–4 lines showing personality).
  Order: coco, bruno, lulu, pepper, duchess, bramble, nibs, zuzu, reginald, grub, tumble, marigold, fennel, wisp (Wisp appears last with a POOF of silver-violet sparkles — plant the glitter!).
- Chime → **Warden Snapjaw** appears on stage, explains the Checkout Rule and Resort Rules. Gives `@clue rules`.
- Coco tries to pry the shutters; Snapjaw snaps at her. Coco vows "Nobody on my crew is checking out!" (she becomes the group's protector).
- Ends with the group agreeing nobody will kill anyone. Mochi narrates unease.

### 3.2 Free Time (`freetime_intro` + 14 hangouts `hangout_<id>`)
Day 1 afternoon. The player gets **3 Free Time slots**. Each slot: pick one capybara
to hang out with. Every hangout is a short scene (10–18 lines) at that character's
favorite spot, ends by granting their Skill (`@skill <skill_id>`). Hangouts plant
foreshadowing:
- **coco** (bath): Coco loves soaking; shows her waterproof captain's pocket watch she never takes off ("Survived three shipwrecks!"). Says she takes a bath every night at 9:45 sharp.
- **wisp** (lounge): rehearses "The Living Statue" — he can stay perfectly still for 20 minutes. Talks about his family's floating circus back home on Lily Pond. Throws Stardust Powder for a POOF. Mentions he hates the dark (sympathetic).
- **bruno** (sauna): Bruno loves the sauna; always hangs his lucky RED headband on his hook in the changing room before going in ("Headband gets sweaty otherwise").
- **lulu** (lounge): sings; shows her signature "Bubblegum Pink" glitter ("only pink, never any other color!").
- **pepper** (dining): shows off her flash camera with timestamped photos, "I photograph everything!"
- **duchess** (giftshop): shows her mannequin display in the gift shop — capybara-sized mannequins she dresses up. Complains the gift shop's price-tag gun tags everything "GIFT SHOP — ¥4,800".
- **bramble** (garden): shows the rose bushes along the garden stone path; says she prunes them every evening at 9:00. Mentions the path connects the Lounge's back door to a little side door of the bathhouse "that nobody uses".
- **nibs** (dining): capybara facts — "We can hold our breath for five minutes!"
- **zuzu** (hallway): tried hacking Snapjaw's network; found the sauna has a door-log safety panel ("lol it logs every door opening").
- **reginald** (lobby): fencing practice, honour, practices with Coco in the evenings.
- **grub** (dining): cooks, asks Mochi to help wash dishes after dinner tonight.
- **tumble** (lobby, on a sofa): naps; rambles about "when you're old you learn that statues don't breathe".
- **marigold** (hallway): checks on everyone; explains she walks back from the infirmary every night around 10.
- **fennel** (garden): painting; "a true artist notices every detail — even price tags!" (lightly).

### 3.3 Motive (`motive`)
- Evening. Snapjaw gathers everyone in the **Lobby**: "Motive time!" Each capybara gets a
  "Home Movie" on a tablet showing something precious at home in danger, with a 3-day timer.
  Mochi's shows their family hot spring being drained. Wisp sees his family's floating circus
  on Lily Pond being drained by bulldozers — he looks shaken (keep it subtle: "Wisp's hands were trembling").
- Snapjaw: "Only someone who checks out can save their precious home! Snap-snap-snap!"

### 3.4 Evening (`evening`) — Dining Hall, 9:00 PM dinner
- Grub serves a yuzu feast. Plans are said aloud (important for the trial):
  - Coco: "I'm hitting the Yuzu Bath at 9:45 sharp, same as always."
  - Wisp: "At 9:35 I will perform *The Living Statue* in the Lounge! Twenty minutes of perfect stillness!" Lulu, Bramble, Tumble, Fennel say they'll watch.
  - Bruno: "Bruno will sweat in sauna. 9:30. Very relaxing."
  - Reginald: practiced fencing with Coco in the gym until 9:30 earlier; will practice alone after.
  - Nibs & Zuzu: library. Duchess: "My room. Beauty sleep." Pepper: "I'll be around. Taking pictures!"
  - Marigold: "I'll be in the infirmary restocking, back around ten."
  - Grub asks Mochi to help wash dishes in the kitchen (Mochi's alibi with Grub, 9:30–10:00).

### 3.5 Night (`night`)
- Kitchen with Grub, washing dishes (9:30–10:00). Faint sounds of applause from the Lounge.
- Nighttime announcement at 10:00 (Snapjaw chime). Mochi goes to their room (bg `room`) and sleeps uneasily.

### 3.6 Discovery (`discovery`)
- 7:00 AM. Morning announcement. Mochi heads to the bathhouse for a morning soak and meets Pepper and Marigold there.
- In the **Yuzu Bath** (bg `bath_body`): Captain Coco floating face-down among the yuzu.
- Chime + `@card A BODY HAS BEEN DISCOVERED!` (sfx `body_found`, music `tension`).
- Everyone arrives; grief, shock, accusations start (Pepper eyes Bruno).
- Snapjaw hands out the **Snapjaw File** (`@clue snapjaw_file`) and announces the investigation.

### 3.7 Investigation (screen) — see §5
### 3.8 Investigation end (`investigation_end`)
- Snapjaw: "Time's up! Everyone to the Bubble Lift!" The group rides down to the **Trial Pool**.
### 3.9 Splash Trial (`trial`) — see §6
### 3.10 Verdict / Confession / Execution
- After the correct vote: Wisp confesses (motive: the circus video; he planned it as soon as he saw it; he's sorry, especially to Coco who was kind to him). Short, sad.
- Snapjaw announces "THE GRAND FINALE: Wisp's Last Vanishing Act" → execution video (screen).
### 3.11 Epilogue (`epilogue`)
- 13 survivors return upstairs. Bruno cries. Pepper apologizes to Bruno. Mochi resolves to find the mastermind.
- Snapjaw: "Plenty more fun where that came from!" `@card CHAPTER 1 — END` then credits.

---------------------------------------------------------------------------------
## 4. The Case (truth)

**Victim:** Captain Coco. **Culprit:** Wisp Vanderloo.

**Motive:** Snapjaw's Home Movie showed his family's floating circus being drained.

**What really happened:**
1. *Day 1 afternoon:* Wisp secretly took a capybara-sized **display mannequin** from Duchess's gift shop and hid it in the **storage closet behind the Lounge stage**. It still had its gift-shop price tag ("GIFT SHOP — ¥4,800") tucked in its collar.
2. *9:28 PM:* Bruno enters the sauna; he hung his red headband on his hook in the changing room first. The sauna door log records the door opening at 9:28.
3. *9:35 PM:* Wisp begins "The Living Statue" on the Lounge stage behind a half-drawn curtain. After a dramatic POOF of smoke, he swaps himself with the mannequin dressed in his spare cape and hat. Audience: Lulu, Bramble, Tumble, Fennel. They think he's standing perfectly still.
4. Wisp slips out the **Lounge back door**, runs along the **garden stone path** (his violet cape snags on a **rose bush** Bramble pruned at 9:00 → torn violet thread with silver stars), and enters the bathhouse through its little-used **garden side door**.
5. In the changing room, he grabs a **wooden bath bucket** from the stack and sees **Bruno's red headband** on the hook — takes it to frame Bruno.
6. *9:47 PM:* Coco is soaking. Wisp strikes her on the back of the head with the bucket. She falls into the water. Her waterproof **pocket watch** cracks on the bath floor and stops at **9:47**. The bucket rim cracks; glitter from his gloves (**silver-violet Stardust Powder**) sticks to the handle.
7. Wisp drops the headband on the bath edge next to Coco, stuffs the bucket **behind the lockers**, leaves through the garden side door, back down the path and into the Lounge.
8. *~9:46 PM:* Pepper snaps a flash photo of the "statue" through the Lounge doorway — the photo shows a small white **price tag** dangling from the statue's collar.
9. *9:52 PM:* Wisp swaps back behind the curtain and takes a bow at 9:55. The mannequin goes into the storage closet (silver-violet glitter on its shoulders).
10. *9:56 PM:* Bruno leaves the sauna (door log: 9:56), finds his headband missing from his hook, shrugs, and leaves by the front door. Marigold, walking back from the infirmary, sees him leave the bathhouse front door, red-faced and steaming. The steam hides the bath; Bruno never saw Coco.
11. *10:00 PM:* Nighttime, Bathhouse locked. Nobody enters until 7:00 AM.

**Alibis at 9:47:** Mochi + Grub (kitchen). Nibs + Zuzu (library). Lulu, Bramble, Tumble, Fennel (watching the "statue"). Bruno (inside sauna, proven by door log). Marigold (infirmary, alone). Duchess (her room, alone). Reginald (gym, alone). Pepper (roaming, took the 9:46 photo in the lounge doorway, then went to her room). Wisp (claims to be the statue).

---------------------------------------------------------------------------------
## 5. Clues ("Truth Drops") — ids are fixed (defined in scripts/data/clues.gd)

| id | Name | Where found | Description |
|---|---|---|---|
| rules | Resort Rules | prologue | The six Resort Rules (see §1). Bathhouse locked 10 PM–7 AM, sensors confirm no one entered/left. |
| snapjaw_file | Snapjaw File #1 | discovery | Victim: Captain Coco. Found in the Yuzu Bath at 7:00 AM. Cause of death: a single heavy blow to the back of the head; she fell into the water unconscious. Time of death: between 9:30 PM and 10:00 PM. No other injuries. |
| coco_watch | Coco's Pocket Watch | bath → body | Coco's waterproof captain's watch. The glass is cracked from a hard impact and the hands stopped at 9:47. |
| cushion_edge | Cushioned Bath Edge | bath → cushions | Every rock around the Yuzu Bath is covered with thick foam safety cushions ("SAFETY FIRST! — Snapjaw"). There's nothing hard to hit your head on. |
| bruno_headband | Bruno's Headband | bath → headband | Bruno's red headband, found on the bath's edge right beside where Coco was floating. Bruno says he left it on his hook in the changing room before going into the sauna. |
| marigold_account | Marigold's Account | bath → talk Marigold | Walking back from the infirmary at about 9:56 PM, Marigold saw Bruno leave the bathhouse front door, red-faced and steaming. She saw no one else. |
| cracked_bucket | Cracked Wooden Bucket | changing → lockers | A wooden bath bucket stuffed behind the lockers. Its rim is cracked and dented. The handle is speckled with sparkly SILVER-VIOLET glitter. |
| garden_door | Garden Side Door | changing → side door | A little-used side door in the changing room that opens onto the garden stone path. Can't be seen from the bathhouse's front entrance. Unlocked until Nighttime. |
| sauna_log | Sauna Door Log | sauna → panel | The sauna's safety panel records every time the door opens. Last night: 9:28 PM and 9:56 PM. No other openings. |
| cape_thread | Torn Violet Thread | garden → rose bush | A strand of shiny violet silk embroidered with tiny silver stars, snagged on a rose bush along the garden path between the Lounge's back door and the bathhouse side door. Bramble pruned that bush at 9:00 PM — it wasn't there then. |
| living_statue | The Living Statue | lounge → talk Lulu | Lulu, Bramble, Tumble and Fennel watched Wisp perform "The Living Statue" in the Lounge from 9:35 to 9:55 PM. The "statue" stood perfectly still behind a half-drawn curtain the whole time. |
| lulu_glitter | Lulu's Glitter | lounge → chairs | Pink glitter sprinkled on the front-row seat where Lulu sat. Lulu only ever uses her signature "Bubblegum Pink" glitter. |
| mannequin | Gift-Shop Mannequin | storage → mannequin | A capybara-sized display mannequin from Duchess's gift shop, found in the storage closet behind the Lounge stage. Silver-violet glitter on its shoulders. Duchess says it vanished from her display yesterday afternoon. |
| pepper_photo | Pepper's Photo (9:46 PM) | dining → talk Pepper | Pepper's flash photo of the Living Statue, taken from the Lounge doorway at 9:46 PM. A small white tag dangles from the statue's collar: "GIFT SHOP — ¥4,800". |

All 14 are required before the trial starts (`rules` and `snapjaw_file` are auto-given).

---------------------------------------------------------------------------------
## 6. Splash Trial — segment outline

Trial location: **The Trial Pool** (bg `trial`): a circular chamber deep under the resort; 15 wooden podiums
in a ring around a glowing turquoise pool; Snapjaw's throne on a rock island; Coco's podium has a framed
portrait with a cross of red tape (cartoon "memorial").

Convince Meter (0–100%) starts at 15% + skill bonuses. Need ≥ 60% at the vote.

1. **Opening** — Snapjaw explains the trial, the vote, and the Convince Meter
   ("Convince your fellow guests! If your Convince Meter is under 60% when we vote, they'll ignore you and vote with their gut!").
2. **Splash Debate 1 — `debate_accident`** (accident theory). Tumble: dozed off; Nibs: drowned unconscious;
   Duchess: "She slipped and {hit her head on the rocks}!" → shoot `cushion_edge`. Drops loaded: cushion_edge, coco_watch, snapjaw_file.
3. **Pick: `q_weapon`** (present a Truth Drop) "Then what did the culprit hit Coco with?" → `cracked_bucket`.
4. **Pick: `q_time`** (multiple choice) "When exactly was Coco attacked?" options 9:30 / 9:47 / 9:56 / 10:00 → 9:47 (from the watch).
5. **Splash Debate 2 — `debate_bruno`** Pepper: last seen leaving at 9:56; Duchess: headband beside Coco;
   Reginald: "Bruno {slipped out of the sauna}, attacked her at 9:47, and went back in!" → shoot `sauna_log`.
   Decoy weak spot: "headband" (shooting bruno_headband there is wrong). Drops: sauna_log, bruno_headband, marigold_account.
6. Dialogue: Bruno explains the headband was on his hook; someone took it to frame him.
7. **Splash Debate 3 — `debate_glitter`** Duchess: glitter on the bucket → Lulu! Pepper: "That glitter is
   {exactly the same as Lulu's}!" → shoot `lulu_glitter` (pink vs silver-violet). Drops: lulu_glitter, cracked_bucket, living_statue.
8. **Pick: `q_glitter_owner`** (pick a character) "Who uses silver-violet glitter?" → wisp.
9. Wisp: "Me? I was on stage in front of four witnesses!"
10. **Splash Debate 4 — `debate_alibi`** Lulu: on stage 9:35–9:55; Bramble: still as a statue; Fennel: never blinked;
    Wisp: "The statue on that stage {was me}, the one and only Wisp!" → shoot `pepper_photo`.
    Drops: pepper_photo, living_statue, mannequin, cape_thread.
11. Dialogue: the price tag → Duchess's mannequin! The statue was a mannequin.
12. **Pick: `q_mannequin`** (present) "Where's the mannequin now?" → `mannequin`.
13. **Bubble Letters — `bubbles_garden`** "How did the culprit get to the bathhouse unseen? Along the ___ path!" → GARDEN.
14. **Rebuttal Showdown — `rebuttal_wisp`** vs Wisp, ends with "Prove I ever set paw on that {garden path}!" → `cape_thread`.
15. **Case Rewind — `rewind_final`** reconstruct 6 panels (see trial_data).
16. **Vote — `vote_final`** culprit wisp, fallback (group's gut pick) bruno, threshold 60.
17. Correct → Snapjaw "CORRECT!" → Wisp's confession → `@end` (flag `vote_correct` true).
    Wrong → Snapjaw "WRONG!" reveals Wisp, announces punishment for everyone → `@end` (flag `vote_correct` false).

---------------------------------------------------------------------------------
## 7. Skills (Free Time rewards) — ids fixed (scripts/data/skills.gd)

| char | skill id | Name | Effect |
|---|---|---|---|
| coco | captains_courage | Captain's Courage | Start the trial with +10% convince. |
| wisp | sleight_of_paw | Sleight of Paw | Rebuttal Showdown timing window is 40% wider. |
| bruno | iron_hide | Iron Hide | Mistakes cost 25% less convince. |
| lulu | encore | Encore! | Correct answers give 25% more convince. |
| pepper | scoop_sense | Scoop Sense | In Splash Debates the correct weak spot sparkles after the first loop. |
| duchess | poise | Poise | Start the trial with +8% convince. |
| bramble | deep_roots | Deep Roots | Your first mistake in each minigame is forgiven. |
| nibs | hypothesis | Hypothesis | In Pick-the-Answer questions one wrong option is crossed out. |
| zuzu | autocomplete | Autocomplete | In Bubble Letters the next correct letter shimmers. |
| reginald | en_garde | En Garde | Rebuttal counters give double convince. |
| grub | comfort_food | Comfort Food | Start the trial with +5% convince. |
| tumble | power_nap | Power Nap | All minigame timers run 25% slower. |
| marigold | first_aid | First Aid | Once per trial, if convince falls below 20%, recover 15%. |
| fennel | artists_eye | Artist's Eye | In Case Rewind one wrong option per panel is crossed out. |

---------------------------------------------------------------------------------
## 8. Execution video — "THE FINAL VANISHING ACT" (HORROR style, user request 2026-11-07)
A found-footage / cursed-broadcast HORROR piece (~45-60 s). Dread through darkness, sound, wrongness and implication.
BLOOD is allowed (user request): stylized dark red (never pink/magenta) — seeping from the cabinet seams, drips, a spreading
pool, strobe-revealed splatter, dripping title text. Still NO dismemberment, body parts, wounds on portraits or visible corpse;
the fate happens inside the closed cabinet.
Look: decayed VHS (tracking noise, rolling bars, desaturation, film grain, heavy vignette, chromatic smear), flickering
practical lights, deep shadows, a sickly red + cold aqua palette, slow creeping camera moves, sudden cuts to black.
Beats (agent may refine): "PLEASE STAND BY" static cold open with heartbeat -> abandoned rotting big top at night, bulbs
flickering, an audience of identical blank-faced gift-shop mannequins -> Wisp alone in a spotlight, trembling (sad/shock
portraits, desaturated) -> Snapjaw's red eye in the dark, slow approach, a distorted laugh and a jump-cut close-up ->
Wisp is sealed in a tall magician's cabinet; blade silhouettes slide in one by one, each with a heavy thud and a cut to
black, the mannequins applaud stiffly -> silence; the cabinet creaks open: empty except his top hat rocking, silver-violet
glitter drifting down like ash -> every mannequin's head turns to the camera at once; one now wears Wisp's monocle ->
smash to black, distorted "THE SHOW MUST GO ON", static, "TRANSMISSION ENDED". Skippable (hold) after 3 s.

## 9. Game Over — "Mochi's Last Soak"
Snapjaw: "WRONG! The real culprit was Wisp!" Short animation: Mochi in a bathtub over a giant stove, thermometer
rising into the red, steam fills the screen, rubber duck floats away → "GAME OVER". Buttons: Retry Trial / Title.

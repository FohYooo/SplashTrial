# SPLASH TRIAL — Case 3: "Murder at Warden's Rest" — Design Bible (SPOILERS)

The full case (victim, culprit, method, timeline, clues, trial) is planned in
`splash-trial-case3-ideas/depth-and-case3-SPOILERS.md`, section S3. This file records what the game itself does, section by
section, as the packages that build Case 3 land. Same rules as `DESIGN.md` and `DESIGN2.md`, except the one below.

---------------------------------------------------------------------------------
## Punishments from Case 3 on (replaces "implied, never gory")

`DESIGN.md` said deaths and executions are implied or slapstick and never gory, and the Case 1 and 2 executions follow
that: every impact is a cut to black, and the fate happens inside a closed cabinet or off screen. **From Case 3 on that rule
no longer applies.** Cases 1 and 2 keep their executions exactly as they are.

- **Applies to:** the execution, the wrong-vote ending (Game Over), Snapjaw's kill after the trial, and every future case.
- **On screen.** The death is shown, not cut away from. It is told through hard silhouette frames (a white or dark-red
  field with the shapes in black, two or three frames long, with a hit-stop), impact cuts, shake and violent sound.
- **A lot of blood,** dark red (`#7a0010`, `#3a0008`, highlights `#b3001b`), **never pink**. The tape and grade shaders
  turn everything grey except the blood (`red_keep`).
- **Portraits are never changed.** Existing portraits only, desaturated, lit or tinted, squashed or hidden by the
  machinery; no wounds drawn on them, no new expressions, no body parts. The brutality is in the frames, the motion, the
  sound and the blood around the shapes.
- **No comic relief at the end.** The older tapes end on an eerie joke ("SWEET DREAMS"). These end on what was done.
- Original content only; the look is the series' own cursed-broadcast style (worn tape, camcorder HUD, captions).

---------------------------------------------------------------------------------
## Endings (Package 11)

Flow after a correct final vote (`chapters.gd`, `"after_vote": "confession"`):
`trial` → `confession` → `execution` → `epilogue` → `caiman_kill` → `epilogue_after` → `credits`.
A wrong vote (the final one, or the early one Snapjaw offers before the Case Rewind) goes to `gameover`, which in this
chapter is `gameover3_screen.gd` (`"gameover"` key), and Retry Trial resumes at the trial's last checkpoint as usual.

### Confession (`confession`, written with the trial)
Story id `confession`, played on the courtroom stage (the trial screen with `params.script`). It is optional: until it
exists the flow goes straight from the vote to the execution. It should end on the execution's title card and Snapjaw's
"PUNISHMENT TIME" line, as Cases 1 and 2 do: `@card STOP PRESS | Pepper Quill's Final Edition`.

### Execution — "STOP PRESS" (`execution3_screen.gd`, ~60 s)
| Time | Beat |
|---|---|
| 0 | PLEASE STAND BY over a newsreel test card; a press hammering somewhere under the static; one frame of a dummy's blank face |
| 4 | EXECUTION (failing red sign) / typed PEPPER QUILL — ACE JOURNALIST / STOP PRESS struck in letter by letter like type |
| 10 | The endless newsroom: rows of capybara dummy reporters facing away, typewriters, flashbulbs; the press on its dais at the far end |
| 17 | Pepper strapped upright to the bed of a giant platen press (sad, then shock, desaturated, lamp-lit); an insert of her camera taped into her paws |
| 22 | Through her viewfinder: the plate's face from below, the type reading her own name backwards; the camera's date-back reads 11 05 |
| 24 | Snapjaw's red eye behind the control-booth glass; the laugh; a jump-cut of his grin; the lever |
| 28 | The strokes. Stroke 1 stops above her hat, stroke 2 presses into it (white/red impact frames, flashbulbs). Her face. The viewfinder again, the plate rushing at the lens |
| 35.6 | The kill: white frame (the plate halfway, her silhouette crushed under it), red frame (all the way down), white (the spray), black. Music cut |
| 36 | The sight: the plate down on the bed, blood thrown out sideways and up over the press and the front row of dummies, squeezed from under the plate, the paper in the tray soaking through, pooling and dripping. [ SILENCE ] |
| 38.6 | Through her fallen camera: tilted floor level, the pool coming at the lens, the lens cracked and smeared, the date-back still lit |
| 41 | The press keeps running: rollers, page after page shot out of it, each her name as the headline, soaked red; one page held up to the lens |
| 50.6 | The newsroom again; every dummy turns to the camera at once, every flashbulb fires |
| 54 | PRINTED AS RECEIVED (typed, dripping), static, TRANSMISSION ENDED |

The camcorder clock is stuck at PM 11:05.

### Wrong vote — "THE LINE-UP" (`gameover3_screen.gd`, ~34 s, then the menu)
Snapjaw, red-lit: WRONG. THE REAL CULPRIT WAS (the chapter's culprit). The culprit walks out through a door of light
("Congratulations. You get to check out."), the door slams. Title: PUNISHMENT / EVERYONE ELSE / THE LINE-UP. Everyone else
alive at the trial stands in a prison line-up against a height chart, each under a caged lamp and a raised spiked gate,
holding a number. Mochi is last. The roll call: a name, the roll-call bell, the gate drops (white frame with the spikes at the
head, red frame with it all the way down), blood thrown up the wall and running down the bars; the next in line sees it. The
gaps shrink as the line gets shorter. Mochi alone: a heartbeat, "(I'm sorry. Everyone... I'm so sorry.)", the name, the gate
lowered slowly to just above Mochi's head, then dropped: straight to black, blood on the lens. GAME OVER, dripping, over the
empty line-up; Retry Trial / Title. A click or key skips straight to the menu.

### Epilogue (`story_end3.gd`, ids `epilogue` and `epilogue_after`)
- `epilogue` (bg `end3_hall`): back in the Grand Hall, Snapjaw tells them what the Ledger really was: every tip from one
  typist who sold to his agency for years; the informer names typed by him on the prison office machine; only Zuzu's line was
  true. Nobody at the table ever betrayed anybody. Grub, far gone, is standing at the foot of the stairs with the cleaver.
- `caiman_kill` (`caiman_kill_screen.gd`, ~24 s): the hall clock ticking; Grub's face (angry, sickly tint); the lunge in
  silhouette with the cleaver; Snapjaw's claw catches the swing (hit-stop); his face; the jaws close (white frame: the jaws in
  dark red and Grub in black between the teeth; red frame; white with the spray), and twice more; the hall: blood across the
  marble, the cleaver skidding and spinning, the chef's hat; everyone's faces cut in one after another, screaming (Lulu,
  Bramble, Reginald, the Duchess, Bruno, Zuzu, Fennel, Mochi); then all sound stops. Silence, a ringing that fades, the pool
  spreading, Snapjaw a dark shape. Black.
- `epilogue_after` (bg `end3_hall_after`, then `end3_terrace` / `end3_terrace_out`): "Rule 6," wiping his chin. Mochi says
  the word out loud: rabies. Bruno's cover story. Reginald and Zuzu unwind their bandages: healed. Lulu and Bramble don't
  speak. Reginald leaves a plate of toast by Bruno without looking at him; that's as far as it goes. The Duchess, Fennel. On the
  terrace, one of the Gaol's cell lights goes out across the water; nobody asks whose. Grandma's torn-off line is still out
  there. Card: CHAPTER 3 — END | 8 guests remain at the Warden's Rest.

### Credits
`chapters.gd` keys `credits_cast`, `credits_mourned` (Grub's card after the victim's) and `credits_quiet` (no fireworks,
sad music, the Gaol's cell lights along the bottom; one goes out when the roll stops).

### Assets
Art `art/props/sp_*`, `wv_*`, `ck_*`, `art/bg/end3_*` from `tools/gen_end3_art.py`; music `execution_press`,
`execution_lineup` and SFX `sp_*`, `wv_*`, `ck_*` from `tools/gen_end3_audio.py` (both reuse the helpers of the Case 2
execution generators). Debug flags: `--exec3-t=`, `--wrong3-t=`, `--kill-t=` (with `--shot=` the screen saves exactly that
frame; pass a long `--shot-delay` as a safety net), and `-- --chapter=3 --start=execution|gameover|caiman_kill|epilogue`.

---------------------------------------------------------------------------------
## Days 1 to 3 (Package 9, first half)

Story: `scripts/data/story/story_daily3.gd`, steps `day1`, `freetime` (2 visits), `night1`, `day2`, `freetime2` (3), `evening2`, `day3`,
`freetime3` (2), `night3`. Every S3 timeline item 1 to 12 is on screen, said plainly.

- **Day 1 (`day1`, `night1`).** Shore: all eleven alive; Bruno splints Fennel's cracked left leg with the ship's green first-aid box and
  says, when Lulu asks, "Bruno did three years in the IDF". Reginald, wringing his plume nearby, stops and says nothing. Fennel gets an oar
  crutch. Salvage: Grub's pots and flour, the Duchess's hatbox, Nibs's barometer, Reginald's foil, Bramble's chamomile, Pepper's portable
  typewriter (ribbon soaked) and her camera date-back reset by hand in front of everyone ("Day, hour, minute"). Snapjaw by loudspeaker; the
  climb (412 steps); `@anim c3_welcome`; the rules (see below, `@clue rules3`); the first aftershock card ("TOMORROW, 3:10 PM"); tour:
  cloakroom hooks ("I'll explain at dinner"), kitchen range and the dumbwaiter, terrace and the covered telescope, Bedroom Wing (bird names;
  Mochi is the Curlew Room); Library, Gallery and Music Room locked till Day 2. The cellar: Grub, Zuzu, Reginald and Mochi go down;
  `@anim c3_bats`; Grub, Zuzu and Reginald bitten on the paw. Bruno bandages Grub and Zuzu; Reginald refuses ("I can manage") and does his
  own. Nobody says the word rabies (the epilogue is the first time). Supper (`night1`): Reginald takes his bowl to the far end, away from
  Bruno. `@anim c3_searchlight`; nobody sleeps; nothing happens.
- **Rules as Snapjaw says them** (for `rules3`'s card): no leaving; nighttime 10 PM to 7 AM, nobody outdoors at night, the roofed terrace
  counts as indoors; bedroom doors lock from the inside; a killer nobody catches checks out, a body means investigation then trial; no
  violence against Warden Snapjaw; 7. aftershocks posted on the notice board a day ahead, "I am punctual"; 8. when a body turns up, pockets
  turned out at the door and every camera to his darkroom, "I print everything. I read everything." Pepper protests about her film.
- **Day 2 (`day2`, `evening2`).** Notice board: the Daily Puddle typed on Pepper's portable ("Facts first, headlines never"), Grub's menu in
  drawings only, Reginald's watch roster (a copy to sign by the Dining Room door; only Nibs ever signs), Nibs's Fact of the Day; Nibs chews his
  pen ("Pencils were a phase. I graduated"; Zuzu: he's chewed every pen he's owned). Card: AFTERSHOCK TODAY 3:10 PM. Library (big desk under
  a tall bookcase; a typewriter on a writing table; Snapjaw: three machines on the island, hers, this one, and the prison office's "where every
  intake form was typed"; Nibs will work at that desk every night). Gallery (portraits; the black marble mantel clock; Snapjaw winds every
  clock in the house to the second). Music Room (piano, dress form). Cellar: rat-bait tins, label "SMELLS OF ANISEED! ... WORKS IN ONE TO TWO
  HOURS!", more in the Attic and Conservatory. 3:10 PM `@anim c3_aftershock`, grey dust everywhere, footprints show in it. At the sink, Grub
  jerks back from Bramble's splash of water; Mochi notices ("I've never seen one back away from water"), then Reginald won't wash in a
  scullery either. 8 PM first proper dinner: the coats-on-hooks rule; grumbles (wax, lip balm, earbuds, Nibs's pen); Nibs signs the roster,
  chews, pockets the pen, hangs his coat; the laugh is Reginald's wax; Nibs first up, takes his coat, chews all the way out. Terrace at dusk:
  `@anim snn_c3_2` (the offer: you check out, they check out), the passes, `@anim c3_passes`, everyone's hostage (People entries and
  `@alibi <guest> motive`). Hostages: Grandma (Mochi), the Dowager (Reginald's mother, cell 411, taken two springs ago), Plum (the Duchess's
  niece, 19), Sesame (Bruno's youngest dojo student, 9), Miss Pip (Lulu's first singing teacher, 73), Hawthorn Thistlewood (Bramble's father,
  a nurseryman; she was told he'd gone into a home), Saffron Dauber (Fennel's sister, miniaturist), Zuzu's mum Ada Byte (ran a radio station
  from her kitchen), Grub's mum Hetty Pemberton (a cook), Mr. Augustus Pica (Pepper's first editor, 90), Fizz Bracken (Nibs's lab assistant, 22).
- **Day 3 (`day3`, `night3`).** Dawn: `@anim c3_portraits`, Gallery portraits turned (turned on Days 3 and 4: bg `manor_gallery_turned`, rooms3 `_gallery`;
  Snapjaw turns them back round on Night 4 and says so at the top of `day5`, so the Day 5 roll shows them facing out); the house plan
  with SERVANTS' WAYS seen by Mochi, Fennel, the Duchess, Zuzu, Pepper (photographs it) and Bruno ("Bruno would not fit in a wall").
  Breakfast: the Ledger, `@anim c3_ledger` (four lines; the page art shows entries in a light face and the names in a black square face, said
  plainly once in narration). Snapjaw tears out the rest to hide, "some lines might be forged". Bramble asks Nibs to test her page (Miss Pip's);
  Nibs announces samples. Conservatory, Marble Bath, Attic open. Page hunt: Lulu frantic in the Music Room; Nibs an hour alone in the Library,
  comes out with nothing and says nothing; Zuzu brings Nibs tea without a word; Grub drops things and snaps at Lulu; Pepper on the stairs,
  Bruno and Lulu sit with her (the cakes: "Paid in full"). Marble Bath: Bruno and Reginald's one quiet exchange (Reginald now calls him
  "Brawnsworth", never Bruno; no Ledger or hostage in that scene). Lunch: `@anim snn_c3_3`. 3 PM samples in the Library: everyone writes
  "The quick brown capybara jumps over the lazy caiman" by hand and types it on the Library machine, Pepper also on her portable; Nibs's
  chewed pen refused; he counts the box of new pens on the side table: "Twelve. The last twelve new pens on this island. Touch them and I'll
  know." Folder tied and kept on the desk. Dinner: the laugh is Zuzu's earbuds in the Duchess's hat; seating split (Zuzu far from Pepper,
  the Duchess and Reginald far from Nibs, Lulu by Grub, Bramble by Fennel); Nibs first up, "Library. Samples." Night: `@anim c3_night3`,
  12:20 AM, the folder gone from the Library desk (Nibs had gone for cocoa); statements (People entries): Reginald asleep by half past ten,
  the Duchess awake (no sleeping powder: Marigold kept it, it's in the wreck), Bruno push-ups, Lulu asleep with the door locked, Zuzu in the
  Attic mapping cameras, Pepper typing in her room, Fennel drawing in his room, Bramble asleep, Grub arrives last, unsure where he was.
  Then smoke: Bramble's page (Miss Pip's, kept in her drawer) burned in the Gallery grate, a corner with "...ISTLEWOOD". Nothing is settled.
- **Free Time arcs** (`hangout_<id>`, three visits each, whatever the day; the third visit is always after the Ledger). Secrets hinted
  there: Bramble's unsigned letter to the council about her father; Bruno's money to Sesame's family under a made-up name; the Duchess's
  begging letters to the Warden; Fennel the copyist; Grub can barely read or write; Lulu's milkshake with a reporter; Nibs found something
  in the Library and kept quiet; Pepper started on the gossip pages; Reginald's unsigned letters to the papers ("Disgusted, of Puddlesworth
  Manor"), and he rests his eyes on watch from about half past ten; Zuzu forged a visitor's pass years ago, and builds a radio with Nibs.
- **Loose pages** (optional, Free Time from Day 3, `page_<space>`, Mochi reads each and puts it back): terrace planter, Hawthorn
  Thistlewood ← F. Dauber; Grand Hall portrait, Augustus Pica ← Z. Byte; Dining Room still life, Hetty Pemberton ← R. Puddlesworth;
  kitchen framed menu, Sesame ← G. Pemberton; Music Room still life, Saffron Dauber ← L. Starling; Library shelf, Fizz Bracken ← D. Velveteen.
  The Bedroom Wing's page (Grandma, name torn off) is left for the investigation. Read-aloud pages: Plum Velveteen ← Prof. N.; the Dowager
  Puddlesworth ← Prof. N.; Ada Byte ← Pepper Q.; Miss Pip ← B. Thistlewood (burned on Night 3).
- **Animated scenes** (`scripts/data/anim_scenes.gd`, art `an_*` from `tools/gen_anim_art.py`, `an_flutter` / `an_squeak` from
  `tools/gen_anim_audio.py`): c3_welcome, c3_bats, snn_c3_1 (end of Day 1's Free Time), c3_searchlight, c3_aftershock, snn_c3_2,
  c3_passes, c3_portraits, c3_ledger, snn_c3_3, c3_night3.

## Days 4 to 6, to the body (Package 9, second half)

Story: `scripts/data/story/story_daily3.gd`, steps `day4`, `night4`, `day5`, `freetime5` (2 visits), `evening` (Day 5, 4:30 PM to the
end of dinner), `night` (Night 5) and `discovery` (Day 6, 7 AM), which hands over to `investigation`. S3 timeline items 13 to 28 are on
screen, said plainly; the escape attempt is cut. Day checkpoints: `day4`, `day5`, `discovery` (`day_starts`), plus `freetime5`.

- **Day 4 (`day4`).** No typewriter: the Daily Puddle is hand-lettered (Pepper: "The ribbon's gone", salt from the beach). New card:
  AFTERSHOCK TOMORROW, 11:05 PM. Breakfast: Lulu in full pink stage glitter ("sparkle louder"); Bramble alone, Fennel sits with her.
  Snapjaw calls the Tea-Time Tribunal for ten, and Visiting Hour for three; cliff path, boathouse, prison yard and Visiting Room open.
  Mochi looks at the Gallery grate and the Library desk first (`@clue night3_ash`, `night3_rug`, `night3_desk`; Nibs: twelve minutes gone
  for cocoa, door not bolted; the pen box on the side table still holds twelve). `@anim c3_tribunal`; Snapjaw reads back the Night 3 claims
  and Mochi names the Alibi Board; Reginald prosecutes Bramble (her page, her drawer). `@minigame c3_tribunal` (data in
  `scripts/data/story_minigames3.gd`; the answer is the glitter on top of the ash against Lulu's "asleep with the door locked"). Lulu
  confesses: she took the page from Bramble's empty room after dinner (her drawer open) and burned it after midnight. Lulu and Bramble are
  finished. The samples: Reginald accuses Lulu, the Duchess accuses Zuzu (Attic above the Library), Zuzu turns it on the Duchess, Bruno and
  Pepper repeat their claims, the Duchess mocks Reginald's half past ten; Snapjaw: unsolved. Trial record entries `tribunal_page`,
  `tribunal_samples`. Nibs shrugs off the theft: entries light, names black and square, "two faces, two machines"; the Library machine is
  neither face, the prison office machine is the Warden's, so he wants to rule Pepper's portable out; no ribbon, so an old typed Puddle;
  Pepper collected the back numbers "for the archive"; Nibs will find a stray ("to line a drawer or wrap a fish"); his desk every night.
  Lunch `@anim snn_c3_4` (Thirty Seconds). The launch from the boathouse, `@anim c3_visiting`. Visiting Hour: Grandma tells Mochi to have a
  proper bath; Reginald's mother says his moustache is crooked; Bramble's father doesn't know her at first and asks if the blue rose opened
  (she says yes); Grub's mum: "Are you drinking enough water?" and he flinches; the Duchess is the quiet one (claw on the glass over Plum's
  pillowcase hat, thirty seconds, no word). One line each for the rest (Sesame's bow, Zuzu's mum and the radio, Miss Pip's scale, Saffron's
  thumbnail, Mr. Pica's grammar, Fizz and "nearly"). Terrace at dusk: the Duchess and Reginald side by side at the telescope; Nibs walks past.
  Dinner: the routine; the laugh is Fennel hanging up his crutch. Cakes: three bad ones with a B in jam, "Paid in full", Bruno eats all
  three. Lulu stays to help Grub wash up (the only one he lets near his sink).
- **Night 4 (`night4`).** `@anim c3_night4`, about 2 AM: Lulu wakes to Grub standing over her bed, drooling, no memory; Bruno walks him
  back; Lulu used to leave her door unlocked; Bramble offers her door and is refused; everyone locks up, chairs under handles. `@evening`.
- **Day 5 (`day5`, sets `c3_day5`).** Doors and chairs; people come down in twos; Reginald's roster gets a DOORS column; Zuzu's spoon bell;
  the Duchess's scissors; Fennel's "sad ark". Grub apologises to Lulu, who won't look; Bruno unwraps the bite (purple, hot); Nibs watches
  and stops chewing. Wreck and Generator Room open; Snapjaw: the generator will trip at 11:05; Bruno will sit with it all night. Salvage
  (Fennel stays up top): Zuzu the radio room, Reginald the ship's bell, Pepper her darkroom chemicals (she can develop her own rolls in the
  Gallery cupboard), Bramble the geraniums, the Duchess her hatboxes. Infirmary: Grub put Marigold's things in her locker, "and that silver
  tin of the Duchess's"; Lulu there (she pockets it later, never shown); Nibs reads the bat page in Marigold's manual, looks at Grub's paw,
  closes it. On the beach Grub won't cross a sheet of seawater; Bruno carries him. The Duchess, told about the powder: "Tomorrow, darling."
  Lunch `@anim snn_c3_5` (the Blackout Buddy, 11:05 tonight).
- **Free Time, Day 5 (`freetime5`).** `freetime_intro` / `outro` label `d5`. Every `hangout_<id>` has a part D (`<id>_ft4`), reachable
  only by a fourth visit, so only on Day 5: Bramble lays Snapjaw's bait by the kitchen-garden door in her gloves and pockets them; Bruno
  will stand in front of Grub if anyone blames him; the Duchess pins Lulu's gown and hasn't fetched her powder; Fennel has painted over part
  of a page; Grub asks to be hit with a pan if he goes funny; Lulu asks if a small bad thing to stop a big one is still bad; Nibs nearly has
  it, "come back tomorrow"; Pepper letters the Puddle in pencil; Reginald watches his mother's window go out at midnight from the terrace
  ("technically" indoors); Zuzu kills one camera. Day 5 variants: Bruno is on the cliff path (bg `manor_cliff_path`) and the cakes are
  paid; Pepper has no ribbon; Nibs's folder is gone.
- **Day 5 evening (`evening`).** 4:30 PM, kitchen: Grub's ladle rattles, he can't bring it to his mouth, Mochi tastes the soup; he salts
  it three times; he watches the water jug (Mochi's and Grub's afternoon). 5:40: Mochi passes Nibs on the stairs, back from the beach.
  8 PM: the routine at 8:05 (roster, chew, pocket, hook); the laugh is Bruno's coat bending its hook; `@anim c3_dinner5`; one pot, one
  loaf, one ladle. Fennel beside Mochi, crutch against her chair, the Dining Room clock in every sketch. Appointments: the Duchess and Lulu,
  fitting, Music Room, 10:30; Reginald and Mochi, Grand Hall, 9:55; Mochi's bath; Bruno with the generator; Bramble and Fennel, the
  moonflowers in the Conservatory until 10:45; Pepper's darkroom; Zuzu's camera feed by midnight and Nibs's answer by midnight; tea at ten
  ("Tea? Yes. No. Water. I... somebody else."). Lulu's Saturday concert; Bramble will bring flowers. Exits (sketched): Reginald 8:30 to
  8:40 (wax), Lulu 8:40 to 8:45 (lip balm), Pepper 8:50 to 9:02 (film), Zuzu 9:05 to 9:10 (a wire), Grub in and out; Bruno, the Duchess,
  Bramble, Fennel and Mochi never leave. 9:15: Nibs first up, coat, pen, chewing out of the door. Afterwards Bramble and Fennel leave at
  9:20; Grub vanishes from the plates. Every guest's 8 PM row goes on the Alibi Board here, Nibs's too, so nothing marks him out.
- **Night 5 (`night`).** 9:40 in the Grand Hall: the row (`@anim c3_row`), Nibs jabs the pen, the bolt; Zuzu: "i'll bring him coffee".
  9:55 with Reginald (he signs on; on every dinner line of the roster, only "Prof. N."); a rattle in the wall and a faint "ting" (the
  dumbwaiter; Reginald: bats); the ten o'clock bell; he goes off to "patrol". The Marble Bath (Grandma's bath). 11:05 `@anim c3_blackout`:
  white plaster, every light out, a crash upstairs. 11:20, lights back: Grub on the cellar stool in the dark among the bait tins, no memory,
  "Did I make his tea?", splinters in his claws; he locks himself in. 11:35 to 12:10: Lulu in Mochi's room, crying, won't say why; at about
  11:45 a creak inside the wall (the passage). `@evening`.
- **Day 6 (`discovery`).** 7:00: Zuzu at the Library door with coffee; it won't move; the others arrive (Bruno grey from the generator);
  Bruno: "Frame's warped" (nobody looks at the bolt); `@anim c3_door`. Room (bg `manor_library_after`): white dust, books across the far side
  of the floor, the bookcase face down across the desk, a white coat underneath. Zuzu kneels at the desk; Bruno holds the bookcase up with
  both paws and every eye goes to it; Reginald and Lulu by the door, Fennel beside Mochi, the Duchess "somewhere behind us", Bramble "by
  the window, I think" (deliberately vague: they are out of frames 9 and 12); Pepper's flash going off from somewhere new each time (she
  always shoots like that). Zuzu: "he's cold". `@anim c3_body_found`, `@sfx body_found`, card. Reactions; Grub arrives last into the doorway
  (frame 15). Snapjaw at the door: rule 8, pockets onto a tray (Reginald wax, watch, roster; Lulu lip balm, tissue; Zuzu earbuds,
  screwdriver, wire; the Duchess pincushion, tape, scissors; Bramble seed packets and gardening gloves; Bruno bandage, spanner; Pepper
  pencil, notebook, lens cap; Grub a wooden spoon; Mochi her key; Fennel charcoal and his sketchbook, handed back: "I don't print
  drawings"); Pepper's film and two spare rolls taken, "Sixteen frames on this one". No pen on anyone; the narration never says so. The
  Snapjaw File is left to `investigation_start`.
- **Alibi Board** (`alibis.gd` DATA[3] slots): 6 PM to 12 AM for every guest, as each tells it (lies included), in Mochi's words. Proofs
  name only someone or something besides the guest's own word, and dinner rows have none (so the table isn't a proof): Bramble/Fennel back
  each other at 6, 9 and 10 PM; Lulu and the Duchess back each other at the fitting; Mochi backs Reginald at 9:55 and Lulu from 11:35;
  Pepper's 8 PM and 11 PM rows are backed by her own stamped photos. Bruno (his blackout claim is unbacked while Reginald still says
  "patrol"), Zuzu and Grub have none. Revealed here: all 8 PM rows; 9 PM for Zuzu, Nibs, Reginald (and proof); 11 PM for Grub and Lulu;
  12 AM for Lulu (and proof). Package 10 reveals the rest; adding Bruno's blackout proof would leave only two unbacked innocents.
- **Forced-scene attention** (aftermath to discovery, with Nibs as victim): Reginald 43, Grub 35, Lulu 35, Zuzu 31, Pepper 28, Bruno 27,
  the Duchess 25, Bramble 23, Fennel 22; median 28. Logbook People entries 3 to 5 each.
- **Plants for the trial** (all in forced scenes): the twelve pens still twelve on Day 4; the names in a second machine's face; Pepper's
  ribbon and archive, "wrap a fish"; Lulu's pink glitter; the 11:05 card a day ahead; the generator trips at 11:05; Grub's water, ladle and
  memory; the powder tin in the locker; Marigold's manuals; Pepper develops her own rolls in the Gallery; Nibs back from the beach at 5:40;
  8:05 and 9:15; the sketches and the clock; Fennel's crutch beside Mochi; the bolt at 9:42; the ting at 9:55; Grub's splinters; the creak
  at 11:45; "Frame's warped"; pockets out; sixteen frames; Fennel's sketchbook stays with Fennel.
- **Animated scenes** added: c3_tribunal, snn_c3_4, c3_visiting, c3_night4, snn_c3_5, c3_dinner5, c3_row, c3_blackout, c3_door,
  c3_body_found. New art (`tools/gen_anim_art.py`): `an_teapot`, `an_item_hourglass`, `an_glass` (see-through partition overlay),
  `an_item_torch`, `an_stewpot`, `an_door`, and the Tribunal Drops' icons `clue_night3_ash` / `_rug` / `_desk`. No new sound.

---------------------------------------------------------------------------------
## The investigation (Package 10, first half)

Data: `scripts/data/investigation_data3.gd` (rooms, hotspots, people, `STAGES`), scripts in
`scripts/data/story/story_case3.gd` (`investigation_start`, `investigation_complete`, `inv3_*`), Truth Drops in
`scripts/data/clues.gd` (`ORDER3`, `OPTIONAL3`, `TRIAL3`), 3D anchors in `scripts/world3d/rooms3.gd`.

**Start.** Snapjaw's file (`snapjaw_file3`: 9:30 PM to midnight, "Cause of death: check your rule book!") and the rules;
Mochi writes up three things she already saw: `ledger_read`, `bat_bite`, `grub_soup`. These five are `inv_start_clues`, so
no stage counts them. `@anim c3_inv_file`. Only the Library and the Grand Hall are open.

**Stage 1, Library and Grand Hall** (8 by hand): `fallen_bookcase` (bookcase), `wall_anchor` (wall_brace: two clean holes,
six screws in a row on the cornice under the white dust), `cup_ring` (side_table), `desk_contents` (desk, and the floor by
the hatch: one plain black pen, smooth), `nibs_blotter` (blotter: "4:30 out", "5:40 back. Shelf rocks. Tell Bruno.", notes to
10:05, no result), `arm_no_bruise` and `nibs_mouth` (body), `door_scratches` (Grand Hall, library_door). Flavour: tapestry
(after stage 3 the draught shows the narrow door; in 3D it then leads into the passage), books, the Library typewriter, the
broken door (keeper in the splinters), the hall notice board, clock, portrait. People: Zuzu (won't say what they did in the
Attic), Pepper (darkroom all evening, flash pictures in the blackout, the Puddle by candle), Reginald ("patrol"), the
Duchess (her room, then the fitting).
**Break 1, `inv3_stage2`** (after 8): Reginald demands Zuzu's screen; in the Attic Zuzu wipes something in front of everyone
(`@anim c3_inv_delete`). Settles nothing. The rest of the house opens; Mochi remembers the tea Nibs asked for.

**Stage 2, the house, kitchens, cellar, wreck, generator** (11 by hand, including the Library hatch, which only now opens:
`"opens_stage": 1` on one hotspot): `tray_grains` (Library hatch: tray, pot, milk jug, no cup; pale grains),
`bell_tape` (one hole since six), `pantry_glitter` (rope), `old_puddle` (Day 2 typed Puddle lining the pantry shelf, a nick in
every small e), `manual_injuries` + `manual_illness` (Marigold's manual, the bat page with its corner turned down),
`powder_record` (dose card: 1 pinch, 2 pinches 8 to 10 hours, never more than 3, a tin would stop a heart), `lulu_tin`
(locker: nearly full, two dents, a fleck of pink glitter), `bait_tin` (cellar; also the Conservatory's, scooped at, and the
Attic's, untouched), `generator_log` ("B. 9:30. ON", ticks, "STOPPED 11:05", "Witnessed, R. Puddlesworth", no other names),
`fitting_ticket` (10:30, one hour; half the hem pinned neatly, the rest crooked). People: Grub (lost hours, splinters),
Bruno (his false cover: Grub with him at 9:30; Reginald held the lantern at 11:05), Lulu (insists she was there the whole
time), Bramble (moonflowers with Fennel until 10:45, then her room).
**Mid-stage broadcast, `inv3_snn`** (after 14): `@anim snn_c3_6`, the Alibi Hourglass. Opens nothing; it keeps the cadence.
**Break 2, `inv3_stage3`** (after 19): Lulu holds out a jug of water to Grub at the fountain and he goes for her
(`@anim c3_inv_fountain`); Bruno walks him away. Snapjaw opens the Gallery, the Attic and the Plover Room with Nibs's key
(`@anim c3_inv_open`); Bruno brings the big lamp; the tapestry moves in a draught. From here Finish is always there.

**Stage 3, Gallery, Attic, Plover Room, passage** (10 by hand): `passage_door` (80 cm, Bruno sticks, no bolt either side),
`passage_tracks`, `shawl_hem`, `hat_feather`, `pen_case` (Plover Room mantel: every pen chewed, "RETIRED"), `shaft_pen`
(kitchen shaft bottom, a hotspot with `"opens_stage": 3`: with Bruno's lamp, a chewed pen in the muck), `gallery_clock` (on the
hearth, 11:05, "Wound and set by the Warden, daily, to the second"), `dinner_sketch` (Fennel gives Mochi his strip: 8:05 at
the roster, empty chairs 8:30, 8:40, 8:50, 9:05, Grub four times, 9:15 at the door), `photo_roll` (darkroom: her own roll,
8:52, 9:00, flash frames 11:06 to 11:18; reveals Pepper's 8 PM and 11 PM proofs), `gallery_grate` (many sheets of ash, a
typed corner "...over the lazy cai").

**Optional (16):** `packet_log` (Attic screen, 9:48 PM to 6:51 AM, dark 11:05 to 11:20), `conservatory_sketch` ("Night 5.
10:40. She snores."), `watch_roster`, `terrace_mud`, seven Ledger pages (`ledger_terrace`, `_hall`, `_dining`, `_kitchen`,
`_music`, `_library`, `_wing`: No. 9, Granny Mochi, the informer's name torn off), and five curios: `burned_glove` (Bramble's,
bait on the fingers), `painted_page` (Fennel's seascape over a page naming "B. Thist..."), `dead_camera` (Zuzu's),
`moustache_wax` (Reginald's, every night at 8:30), `music_box` (Plum's drawing).

**Handed over in the trial (`TRIAL3`):** `nibs_cup`, `nibs_sheet`, `scene_photos`. They are in no investigation list, so
nothing there asks for, grants or counts them; `check_depth.py` counts them as the case's evidence.

**Alibi Board.** Each talk reveals that guest's own rows (`@alibi`), and the cross-proofs come from the other person:
Lulu backs the Duchess's fitting (and Mochi Lulu's 11 PM), the Duchess backs Lulu's, Bramble and Fennel back each other;
`photo_roll` reveals Pepper's two photo proofs. `nibs_blotter` reveals his 6, 7 and 10 PM rows.
Evidence balance (`about` lists in clues.gd): the culprit sits on the median of the nine.

**The photographs.** `tools/render_evidence3.gd` renders the real 3D Library and Gallery with the standees posed (`MORNING`),
grades them as flash photos and prints the date-back time in orange: `art/evidence/c3_frame_01..16.jpg` (7:02 to 7:06) and
`c3_roll_1..6.jpg`. Frames 1 to 3 show the bolt still shot with its keeper in the splinters, the line dragged through the
white dust between the tapestry and the side table (trampled from frame 4 on), the ring with no cup and the box with eleven
pens and one empty slot (frame 3 is shot from above, close: twelve red-felt slots between cream ridges, new pens black with a
gold band and clip like the clean pen on the floor, the eighth slot bare red; countable at the viewer's 4x). Frame 9 (from the door, camera held high): the six (Zuzu kneeling, Bruno under the top end of the
bookcase, Reginald, Lulu, Fennel, Mochi), at the far right a chewed pen by the hatch and the hatch shut. Frames 10 and 11
come from further round towards the far wall. Frame 12 (from the far wall, a wide lens): the same six in the same places,
in the near corner a clean pen and the hatch open a crack (tray and pot in the gap). Frame 15 Grub in the doorway, frame 16
Snapjaw behind him. The Duchess and Bramble are in no frame. Roll: the 8:52 frame shows the darkroom with the mantel clock
behind at twenty past five (the Day 5 Gallery with `gallery_clock` 5:20), 9:00 the portraits, then four flash frames in
the dark Day 6 Gallery with the clock on the hearth at 11:05. Every detail is legible at the viewer's 4x and small at 1x.
The Library on Day 6 in the game is the "after" state: dust trail trampled, clean pen, hatch open a crack, bolt on the leaf.

---------------------------------------------------------------------------------
## The trial (Package 10, second half)

Script `trial` in `scripts/data/story/story_case3.gd`, minigames `c3_*` in `scripts/data/trial_data3.gd`, the recess in
`scripts/screens/recess3d_screen.gd` (scripts `recess_intro`, `recess_<guest>`, `recess_darkroom`; `recess_walk` with `--2d`), the
confession as story id `confession`. Threshold 70, mistakes 1.5x, hints only on request (each debate has one), 5 to 6 Drops per
debate with plausible wrong ones. The segments follow S3's outline in order:

| # | What | Data id | Answer |
|---|---|---|---|
| 1 | Opening: Mochi reads the file; everyone accuses everyone | | |
| 2 | "It simply fell" (Reginald) | `c3_debate_fell` | `fallen_bookcase` (early: `wall_anchor`) |
| 3 | When did he die? (free; "before" sets `c3_said_before`, +3 at step 9). The bolt: "drawn for a friend", "frame's warped" | `c3_q_when` | the group settles on the blackout |
| 4 | Roll call, 11:05 to 11:20 (Bruno and Reginald left for 6) | `c3_roll_blackout` | Duchess-Lulu, Lulu-Duchess, the rest Nobody |
| 5 | The Duchess "alone all night" | `c3_debate_duchess` | `fitting_ticket` |
| 6 | Reginald's patrol; his soldier jab at Bruno ("That isn't evidence.") | `c3_debate_reginald` | `generator_log`; "Honour compels me. He was there." The terrace and his mother's geranium come later, after step 8, so the army thread and the hostages never share a beat (plan 3.5, guard rail 3) |
| 7 | Zuzu's row | `c3_debate_zuzu` (`packet_log`), or `c3_q_zuzu_stairs` without the Attic log (Mochi saw them go up) | |
| 8 | Zuzu goes for Pepper (her line, the grate) | `c3_debate_pepper` | `photo_roll` (early: `gallery_clock`). She thanks Mochi. Then the Duchess asks Reginald where his patrol really was before the lights went: the terrace, the telescope, his mother's window (a People entry) |
| 9 | First overturn | `c3_q_dead_before` | `arm_no_bruise` + `manual_injuries`; then the screws, the blotter, the `5 PM` row for everyone. Nobody mentions Pepper's blackout photos |
| 10 | The tea | `c3_q_tea` | `tray_grains` + `bell_tape` (the 9:55 "ting") |
| 11 | Reginald accuses Grub; Bruno admits his cover | `c3_debate_grub`, `c3_bubbles_sick` | `manual_illness`; SICK |
| 12 | Who sent the tray? Lulu confesses to murder | `c3_q_tray_who` | `pantry_glitter` + `lulu_tin` |
| 13 | "Her tea killed him" | `c3_debate_tea` | `powder_record` (and the blotter's 10:05) |
| 14 | Someone came back | `c3_q_came_back` | `cup_ring` + `passage_door` |
| 15 | Whose trail? Pepper: "Scoop!" | `c3_q_trail`, `c3_q_trail_who` | `shawl_hem`; duchess |
| 16 | The Duchess denies everything (checkpoint `c3_cp_showdown` just before) | `c3_rebuttal_duchess` | `hat_feather` |
| 17 | Snapjaw offers the vote (the only early vote) | `c3_q_vote_offer` | run it through; "Vote now" goes to `c3_vote_early` (`false_vote`) and the Line-Up |
| 18 | Case Rewind jams on panel 4; second overturn | `c3_rewind_false`, `c3_q_tracks` | `passage_tracks` + `rules3` |
| 19 | "He was already dead, darlings." She hands over `nibs_cup` and `nibs_sheet`; nobody believes her | | |
| | Recess (`@anim c3_recess`, then the walk; checkpoint `after_recess`) | | `scene_photos` |
| 20 | It wasn't the tea | `c3_q_not_tea` | `nibs_cup` + `nibs_sheet` |
| 21 | "Nobody could have reached him" (Zuzu shows frame 1's bolt first) | `c3_debate_reach` | `nibs_mouth` (early: `nibs_sheet`) |
| 22 | The pen on the floor | `c3_q_floor_pen` | `desk_contents` + `pen_case` |
| 23 | What killed him: Mochi wipes the shaft pen, aniseed | `c3_q_what_killed` | `shaft_pen` + `bait_tin` |
| 24 | Lulu goes for Bramble's bait | `c3_debate_bramble` | `dinner_sketch` |
| 25 | When, and who left (checkpoint `c3_cp_hooks` before) | `c3_time_hooks`, `c3_who_left` | 8:05 to 9:15; Reginald, Lulu, Pepper, Zuzu, Grub |
| 26 | The two frames, and who could reach the far wall | `c3_frames_pick` (the last frame with the hatch shut and the first with it open: the hatch shows shut in the early frames and in 9, not at all in 10 and 11), `c3_who_reach` | frames 9 and 12; the Duchess, Bramble, Pepper (Grub is in frame 15) |
| 27 | Why bring a spare? | `c3_q_spare` | `scene_photos` (frame 3: eleven, against Day 3 and Day 4's twelve) |
| 28 | Pepper: "Zuzu was closest" | `c3_debate_zuzu2` | `scene_photos` |
| 29 | Pepper: "the artist isn't in his own sketch" | `c3_debate_fennel` | `dinner_sketch` (the crutch on Mochi's chair) |
| 30 | Nobody fits; Snapjaw gloats; "The truth's in the timestamps." Third overturn | `c3_q_timestamp` | `photo_roll` + `gallery_clock` |
| 31 | Who moved the pen? | `c3_q_who_moved` | pepper |
| 32 | "Prove I ever touched that pen" | `c3_rebuttal_pepper` | `scene_photos` (frames 9 to 12 walk to the hatch) |
| 33 | Why? | `c3_q_why` | `nibs_sheet` + `old_puddle` |
| 34 | Case Rewind, 7 panels | `c3_rewind_final` | |
| 35 | Vote: pepper, fallback the Duchess | `c3_vote_final` | |

- **Trial record** (`@log trial`): the bookcase didn't simply fall; died at 11:05 in the blackout (struck at 9); the Duchess's fitting;
  Reginald in the Generator Room; Zuzu to the Attic; Pepper in the Gallery through the blackout (never struck: it is true, it just
  stops mattering); already dead; loosened 4:30 to 5:40; the tea up the dumbwaiter; Grub ill; Lulu's tea killed him (struck at 13);
  two pinches only make you sleep; someone came back through the wall; the lilac trail; the Duchess killed him (struck at 18); the
  passage unused until after 11:05; not the tea; already in his mouth; swapped; rat-bait; the hooks window; the frames; the spare;
  Pepper's photos put her in the Gallery at dinner (struck at 30); the clock; the Ledger typed on her portable.
- **Right but too soon** (`early`, no cost, +3 when used for real): `arm_no_bruise` / `manual_injuries` at 5 to 8, `gallery_clock` at 8,
  `passage_tracks` at 14 to 16, `wall_anchor` at 2. Also listed as early, so a sharp player is never charged for being right, though
  they aren't the answer asked for: `watch_roster` at 6, `nibs_blotter` at 13, `nibs_sheet` at 21, `scene_photos` at 29.
- **Missing Drops**: required answers name who brings them up (`missing`), at the chapter's capped cost (18). Tested: a run without
  any stage-3 Drop pays 18 and still wins.
- **Checkpoints**: `c3_cp_overturn` (before 9), `c3_cp_showdown` (before 16: Retry after the early vote comes back here),
  `after_recess`, `c3_cp_hooks` (before 25); floors 20 to 25.
- **Recess**: Snapjaw sends everyone up the lift to the Grand Hall and shuts himself in the cupboard under the stairs with a red bulb.
  The walk has every guest in little clumps (Lulu on her own by the stairs, Bramble far from her, Reginald far from Bruno), each with a
  short talk (flavour only); talking to Snapjaw hands over the prints and ends it.
- **Confession** (`confession`, after a correct vote): the agency was Snapjaw; the cover page on Day 3; the names forged on the office
  machine; she stole and burned the samples on Night 3 and that should have been enough; she never thought of the pantry shelf paper;
  "I'd have looked at the body. Everybody does."; Tumble's alibi by accident, hers on purpose; Bruno and the cakes, "the only debt I ever
  managed to pay". Ends on `@card STOP PRESS | Pepper Quill's Final Edition` and PUNISHMENT TIME.


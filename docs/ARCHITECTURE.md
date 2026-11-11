# SPLASH TRIAL — Architecture & Contracts (read fully before writing code or assets)

Godot **4.7.2**, GDScript, GL Compatibility renderer, base resolution **1280×720** (stretch canvas_items).
Project root: `/Users/thomasschrauwen/Projects/Game-development/splash-trial` (res://).
Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot` (call it `$G` below).
Story/case bible with all spoilers: `docs/DESIGN.md`.

## 0. HARD RULES (everyone)
1. **Only touch files you own** (section 1). Never edit core files; if you need a core change, describe it in your final report.
2. **No `class_name`** anywhere. Reference other scripts with `const X := preload("res://...")`.
   Autoloads available everywhere: `Game` (scripts/core/game.gd) and `Audio` (scripts/core/audio.gd).
3. **Never run the Godot editor**: no `--editor`, `-e`, `--import`, `--export-*`. (It would create .import files and break the
   asset pipeline.) Allowed: running the game (`$G --path . ...`) and scripts (`$G --headless --path . -s tools/...`).
4. Assets are loaded **at runtime from raw files** (no import step): use `const Assets := preload("res://scripts/core/assets.gd")`
   → `Assets.portrait(id, expr)`, `Assets.bg(id)`, `Assets.prop(name)`, `Assets.svg(path)`. Never `load()`/`preload()` an .svg/.wav.
   Audio: `Audio.play_music(id)`, `Audio.sfx(id)`. Missing art/audio falls back gracefully — code must never crash on missing assets.
5. Use the shared style: `const Style := preload("res://scripts/ui/style.gd")` (palette, fonts, `Style.button()`, `Style.label()`,
   `Style.title_label()`, `Style.box()`). Look: night-purple panels, aqua borders, yuzu-orange/gold highlights. Not pink/black.
6. GDScript 4 gotchas: avoid `:=` when the right side is Variant (dictionary access, `load()`, `.new()` of untyped script) — use
   explicit types (`var d: Dictionary = data["x"]`). Typed arrays need exact types. Lambdas: `func() -> void: ...`. Use
   `create_tween()`; `await` signals. Indent with TABS. Godot 4.7 API (e.g. `set_anchors_and_offsets_preset`, `TextServer.AUTOWRAP_WORD_SMART`).
7. Everything must work in **autotest** mode (`Game.autotest == true`): no waiting for input, auto-pick/auto-solve quickly.
8. Original content only — no names/characters/catchphrases/art from existing franchises. No gore in Cases 1 and 2.
   From Case 3 on, punishments are brutal and on screen (dark-red blood, never pink; portraits never altered): `docs/DESIGN3.md`.

### Testing commands (run from project root)
```
# parse + run whole game headless, auto-playing (kill after ~60s; there is no `timeout` binary on macOS):
($G --headless --path . --quit-after 40000 -- --autotest 2>&1 & P=$!; sleep 60; kill $P) | grep -iE "error|warn|autotest" | head -50
# one minigame (data id from scripts/data/trial_data.gd), autotest or interactive:
$G --headless --path . --quit-after 20000 -- --minigame=debate_accident --autotest
# one story script:
$G --headless --path . --quit-after 20000 -- --script=prologue --autotest
# start at a flow step (title prologue freetime motive evening night discovery investigation investigation_end trial execution epilogue credits gameover):
$G --headless --path . --quit-after 20000 -- --start=investigation --autotest
# SCREENSHOT (opens a real window briefly; NOT headless). Delay in seconds; saves PNG then quits:
$G --path . --resolution 1280x720 -- --minigame=debate_accident --shot=/abs/path/out.png --shot-delay=3
#   (add --autotest to see the auto-solving state; add --all-skills to grant every skill)
# preview SVG art exactly as the game rasterizes it:
$G --headless --path . -s tools/svg2png.gd -- art/chars/coco_happy.svg /abs/out.png
$G --headless --path . -s tools/svg2png.gd -- --sheet /abs/sheet.png --cols 5 --cell 300 art/chars/*.svg
```
Look at PNGs with the Read tool. Fix every `SCRIPT ERROR` / `Parse Error` you see. Keep windowed screenshot runs short.

## 1. File ownership
| Owner | Files |
|---|---|
| CORE (lead) | project.godot, scenes/*, scripts/core/*, scripts/ui/*, scripts/data/{cast,clues,skills,story,trial_data,investigation_data}.gd, scripts/screens/{story,trial}_screen.gd, tools/svg2png.gd, tools/prepare_export.py, docs/* |
| art-chars | tools/gen_chars.py, art/chars/*.svg |
| art-bgs | tools/gen_bgs.py, art/bg/*.svg, art/props/clue_*.svg |
| audio | tools/gen_audio.py, audio/music/*.wav, audio/sfx/*.wav |
| story-daily | scripts/data/story/story_daily.gd |
| story-case | scripts/data/story/story_case.gd |
| explore | scripts/screens/freetime_screen.gd, scripts/screens/investigation_screen.gd |
| trial-a | scripts/trial/debate.gd, scripts/trial/rebuttal.gd (+ optional scripts/trial/trial_common.gd) |
| trial-b | scripts/trial/choice.gd, scripts/trial/bubbles.gd, scripts/trial/rewind.gd, scripts/trial/vote.gd |
| present | scripts/screens/{title,execution,gameover,credits}_screen.gd, art/props/exec_*.svg, art/props/title_*.svg (+ tools/gen_present_art.py) |
| stage (v2) | scripts/ui/trial_stage.gd, scripts/screens/trial_screen.gd, tools/gen_stage_art.py, art/props/stage_*.svg |
| horror exec (v2) | scripts/screens/execution_screen.gd, tools/gen_exec_horror_art.py (art/props/hx_*.svg), tools/gen_horror_audio.py (audio/music/execution_horror.wav, audio/sfx/hx_*.wav) |

## 1b. v2 style pass notes
- The trial runs ScriptPlayer with `stage_mode = true`: scripts/ui/trial_stage.gd draws the rotating courtroom (podium ring, throne,
  speakers) behind it, driven by the signals line_started / minigame_started / minigame_finished / bg_requested.
- Shared look helpers: Style.INK, cut_box(), slant_box(), italic_font(), slant_poly(), chamfer(), cut_rect(), draw_shape(),
  draw_stripes(), Style.Shape. Effects: `const Fx := preload("res://scripts/ui/fx.gd")` (glitch, wipe, speed_lines, streaks,
  shatter, capture, vignette, flash, shake, ripple, splash, silhouette_material, skip_heavy) — signatures in its header.
- Blood (execution only): stylized dark red, never pink. From Case 3 on it is shown on screen (see 1g).

## 1c. Chapters (v3)
- `scripts/data/chapters.gd` holds per-chapter data (victim, culprit, dead-before list, first step, step order "next",
  execution screen, investigation data file, 3D room script, free-time auto picks). `Game.chapter` (1 to `Chapters.LAST`) writes `Chapters.current`, which the
  data scripts read: `Story` (story_daily/story_case vs story_daily2/story_case2), `Clues.order()/required()` (ORDER vs ORDER2),
  `trial_data_index.gd` (trial_data vs trial_data2), investigation_data vs investigation_data2, `Cast.survivors()` /
  `alive_at_start()` / `roster_alive()`.
- Chapter 2 spoilers + content: docs/DESIGN2.md. Flow: aftermath → drain (cutscene screen) → prologue → ... like chapter 1.
- Chapter 1's credits lead straight into chapter 2. Saves store the chapter. In this branch `Game.chapter_unlocked` is still
  saved but no longer gates anything: the title's **Choose Case** list is always open.
- Case select: `Main.start_case(n)`. Case 1 is `start_chapter(1)`. A later case sets `_bridge_to`, plays the previous chapter's
  execution and epilogue, then `_on_finished` calls `start_chapter(n)` instead of going to the credits.
  Test with `-- --pick-case=2 --autotest`; screenshot the list with `--case-menu`.
- Debug: `--chapter=2` with any of `--start=`, `--script=`, `--minigame=` (e.g. `-- --chapter=2 --start=drain --autotest`).
  `python3 tools/check_content.py` checks every chapter.
- Chapter 3: Flow: aftermath → quake (cutscene screen) → day1 → freetime → night1 → day2 → freetime2 → evening2 → day3 → freetime3 → night3 →
  day4 → night4 → day5 → freetime5 → evening → night → discovery → investigation → …. The daily story, Day 1 to the body on Day 6's
  morning, is written (`story_daily3.gd`; spoilers in `docs/DESIGN3.md`).
  **Free Time on several days:** `main.gd` `FREETIME_STEPS` (freetime, freetime2 … freetime5) all play the free-time screen and are save
  checkpoints; `chapters.gd` `"freetime_slots"` gives each its visits (an int, or `{step: visits}`), read by `Chapters.freetime_slots(step)`.
  With a dictionary, `Game.hangouts_done` is cleared at each Free Time step, so everyone can be visited again each day. The shared scripts
  `freetime_intro` / `freetime_outro` / `hangout_<id>` tell the days apart by flags the day scripts set (`c3_day2`, `c3_day3`, `c3_day5`, each
  checked by an `@if` at the top, newest first), and each guest's arc by `<id>_ft1` … `_ft4` (a fourth visit is only possible on Day 5). A script that branches before its first `@bg` starts from black
  (`_first_bg` in both free-time screens). From Day 3, a space's `ledger_page` anchor is a loose page to read in 3D Free Time when story id
  `page_<space>` exists (`freetime3d_screen.gd` `_read_page`; it sets `read_page_<space>`). `check_content.py` and `check_depth.py` know the steps.
  `day_starts` in `chapters.gd` names each day's first step; those steps are save checkpoints. `Chapters.day_at(step)` gives the story day of any step, by
  walking the step order, and `Chapters.room_open(entry, day)` reads a room's or space's `"opens_day"`, so closed rooms need no saved state.
  `Clues.required()` is `ORDER3`; `Clues.order()` adds `OPTIONAL3`; `TRIAL3` are the Drops guests hand over in the trial (never
  required, granted or counted by the investigation; `Clues.everything()` adds them and `STORY3` for debug runs that start late).
  **The investigation** (spoilers: `docs/DESIGN3.md`, "The investigation"): `investigation_data3.gd`, 15 rooms in three stages
  (`STAGES`: two story breaks with `@anim` scenes and a broadcast in between), scripts `inv3_*` in `story_case3.gd`. Its five
  automatic Drops are `inv_start_clues`. A hotspot can carry `"opens_stage"` too. In 3D a link door (the Library tapestry) only
  acts as a door, and only names where it goes, once the place behind it has opened.
  **The trial** (spoilers: `docs/DESIGN3.md`, "The trial"): story id `trial` in `story_case3.gd`, minigames `c3_*` in `trial_data3.gd`
  (about 40 segments: debates with 5 to 6 Drops, two-part presents, a roll call, a time pick, several-guest picks, a frame pick in the
  evidence viewer, two rebuttals, the false finish with Snapjaw's vote offer and a Case Rewind that jams, the final Rewind and vote).
  Four `@checkpoint`s with floors; `@log trial` entries crossed out with `@log strike` only when disproved; `@anim` slams at the turns
  (`c3_overturn1..3`, `c3_turn_lulu`) and `c3_ride_down` in `investigation_end`. The trial adds the Alibi Board's `5 PM` row
  (`@alibi row 5 PM`; the slots are in `alibis.gd`).
  **The recess:** a trial script can stop for a break: `@flag trial_break <step>` and `@end` after an `@checkpoint`. `Main` clears the
  flag, plays that step, and goes back to the trial, which resumes at the checkpoint (`RECESS_RESUME` covers a debug start at the step).
  Case 3's `recess` step is `scripts/screens/recess3d_screen.gd` (extends the 3D Free Time screen): the Grand Hall on Day 6, every
  guest standing about with a short `recess_<id>` talk, and Snapjaw at the cupboard under the stairs, whose `recess_darkroom` hands
  over the 7 AM roll and ends it. With `--2d` the step plays story `recess_walk` instead. Debug: `-- --chapter=3 --start=recess`.
  After a correct vote, `confession` (in `story_case3.gd`) plays on the courtroom stage; its endings are in 1g.
  **Evidence photographs**: `tools/render_evidence3.gd` renders `art/evidence/*.jpg` from the real rooms with the standees posed
  (run windowed, muted; then `--import`). `rooms3.gd` builds the Library and Gallery for them with photo metas (its header).
  Icons: `tools/gen_clue_icons3.py` (`art/props/clue_<id>.svg` for every Case 3 Drop).
  **Story minigames:** a daily story can play a minigame outside the trial (Case 3's Day 4 Tea-Time Tribunal, a no-stakes Splash Debate).
  Its data lives in `scripts/data/story_minigames3.gd` (`trial_data_index.gd` `STORY_PATHS`, looked up after the trial's own table), so the
  trial's file and numbers stay the trial's; its Truth Drops are `clues.gd` `STORY3`, neither required nor optional, so the investigation's
  counts, stages and checks never see them. `check_content.py` (`story_trial`, `STORY3`) and `check_depth.py` (`STORY_MINIGAMES`) know both.
  The convince a story minigame moves is thrown away by `Game.start_trial()`.
- Chapter 3's places are `scripts/world3d/rooms3.gd`: 31 spaces (island, prison, house, the servants' passage, a bedroom per guest
  sharing one layout) with `opens_day` (and `opens_stage` for the passage) in `SPACES`, Free Time hubs in `FREE_SPACES` /
  `FREE_BY_DAY`, and every examinable thing of the case built as a named `k.hotspot` anchor (listed above each builder) that
  becomes examinable once `investigation_data3.gd` lists its id. A space shows the story day it is visited on (`_day`: the flow
  step's day, `k.set_meta("day")`, or `--day3d=<n>`); Day 6 is the morning after. Outdoor spaces raise the camera's far plane
  so the bay reaches the horizon. Ledger pages are `ledger_page` anchors (from Day 3), one per space that has one.
  2D backgrounds (story scenes and `--2d`): `art/bg/manor_*.svg` from `tools/gen_mansion_bgs.py` (`--list` names them).
- The `quake` step is `scripts/screens/quake_screen.gd` (about 55 s, extends `cutscene_base.gd`): the earthquake, the flood, the tunnel and the island.
  The step before it, Chapter 3's `aftermath`, is the short deck scene that leads into it; Case 2's epilogue ends on one small tremor.
  Art: `art/props/qk_*.svg` (`tools/gen_quake_art.py`, which draws the Mudlark and the cave from `tools/gen_drain_art.py`), plus the drain's
  `dr_*` cave and ship. SFX: `audio/sfx/qk_*.wav` (`tools/gen_quake_audio.py`). Its last frame is `art/bg/manor_shore.svg` if a shore background
  exists (`SHORE_BGS`), else `qk_shore`. The forward smokestack is sheared in the tunnel and stays sheared (`CUT_SHADER`, and `qk_shore` draws
  the wreck that way). Debug: `-- --chapter=3 --start=quake --quake-t=<seconds>`; with `--shot=<png>` it saves exactly that frame.
  Test with `-- --chapter=3 --autotest` (straight into Case 3), `-- --pick-case=3 --autotest` (the Choose Case route through the end of Case 2),
  and `-- --autotest --continue` (resume from the save file).

## 1e. Depth systems (case3-depth)
- **Difficulty** per chapter in `chapters.gd` (`threshold`, `penalty_scale`, `hint_loops`, `hint_on_request`, `ending`, `missing_cap`, `ammo_min`; meanings in its header).
  `Game.convince_threshold()` reads it, `Game.mistake` applies `penalty_scale`, the vote and the Convince Meter use the threshold. `ammo_min` tops a debate's Drops up from the notebook at positions fixed by the segment id.
- **Player-ended investigations** (`"ending": "choice"`): nothing ends by itself. Finish (the top-bar button, or **T**; in 3D also in the key strip) appears once the last stage has played, at once in a chapter without stages, and from then on always works, whatever the player holds: it asks "Am I finished here?" and a yes ends it. It never looks at which `Clues.required()` Drops are held, so pressing it tells the player nothing, and the counter shows only Truth Drops found. While open rooms still have things unexamined, Mochi muses after 4 minutes without a find (then every 2.5), ending with the name of some open room with things still unexamined, picked without regard to what they are; this too never depends on the Drops held. Examining everything open also brings up Finish, so an old save whose Drops were all found before the stages existed can't get stuck short of them, and `_snippet` grants anything still missing at that point, as it always has.
- **At the trial** a segment whose Truth Drop the player lacks has another guest bring it up (`Game.pay_missing`, capped by `missing_cap`). Optional segment key `"missing": {speaker, expr, text}` replaces the stock line. This is how a player who finished the investigation without a required Drop still gets it, and `tools/check_depth.py` proves a strong run that pays the whole cap can still win.
- **Stages**: in investigation data, `const STAGES := [{"after": int, "script": String}]`. A stage plays when that many required Drops have been found during the investigation (`inv_start_clues` and Drops held on arrival don't count). A room or space with `"opens_stage": n` is shut until the nth stage has played; a hotspot with it isn't there (nor counted in its room's numbers) until then, and joins the room you're standing in when the stage plays (`_open_new_hotspots`).
- **Alibi Board**: `scripts/data/alibis.gd` (`Alibis.entries()`, `HOURS` per chapter), notebook tab `alibi`. The story reveals entries with `@alibi` (section 3). The victim stays on the board until the body is found (`Chapters.step_reached`), so an early look gives nothing away. State in `Game.alibi_seen`, `alibi_marks`, `alibi_rows`, saved with the checkpoint; older saves load with none.
- **Logbook**: notebook tab `log`, opened with **L** in the same hook as Esc (`Main._unhandled_input`): anywhere except the title screen and a screen wipe. Sections: Timeline, Places and things, People, Transcript (last 200 lines), Trial record, Your notes. Rules and Mochi's wording: `scripts/data/log_rules.gd`, which `tools/check_content.py` reads too. State: `Game.log` (entries; the story writes them with `@log`, and rooms entered and things examined write themselves), `Game.log_transcript`, `Game.log_note`, saved with the checkpoint; a save without them starts empty. Every entry looks alike: no counts, highlights or "new" marks. `@evening` asks at the end of a day whether to go over the Trust and Doubt marks, and suggests nothing.
- **Play-time recorder**: `Game.phase_seconds`, keyed `"<chapter>:<step>"`, active seconds per flow step. It leaves out the notebook, the title screen, anyone gone quiet for 5 minutes and the previous case's ending that Choose Case replays on the way into a case. It is read from the save at start-up, kept through Choose Case (only the chosen case's own numbers restart), written with the checkpoint and again on leaving (`Game.flush_play_time`), so it can be read from `splash_trial_save.json` in the save folder.
- **Pausing**: the notebook pauses the tree. `get_tree().create_timer` runs through a pause unless its second argument is false, and `await get_tree().process_frame` keeps coming too, so any new wait that counts time has to allow for that. `tools/logtest.gd` drives the game with real key events and proves everything stops.
- **Evidence viewer**: `scripts/ui/evidence_viewer.gd` opens a Truth Drop's `"images"` from the notebook (V or the button), from a Present segment (V or the button) and from a debate or rebuttal (V, on the loaded Drop). It's also the `evidence` trial segment. A picture is an SVG (redrawn sharp when zoomed) or a photograph, `res://art/evidence/<id>.jpg` (drawn at 1280 wide, loaded whole past 1x; `tools/prepare_export.py` keeps the raw file in exports). L in pictures opened from the notebook closes them and turns to the Log.
- **Ammo**: a debate's or rebuttal's tray shows only Drops in the notebook (one another guest handed over in the trial counts), topped up to `ammo_min` (`TrialCommon._ammo_list`).
- **Mid-trial checkpoint**: `@checkpoint <label> [floor]` (with a `@label` of the same name) saves the convince there, but never less than `floor`; Retry and Continue resume at it, with the music and background the lines before the label set. `tools/check_depth.py` proves a careful run from the label starting at the floor still reaches the vote, and prints the floor needed. Cleared when the vote is won.
- **Checks**: `python3 tools/check_depth.py`. Depth rules are warnings until a chapter sets `"depth_checked": true` in `chapters.gd`, then errors. `--names` shows who is involved (spoilers).
- **Test fixtures** in `scripts/data/trial_data_test.gd`, not part of any case: `-- --minigame=t_<id> --autotest` tries a wrong answer and then solves it; `-- --trial-fixture=false_finish --autotest [--wrong-path]` runs the false finish through the real trial flow to the execution or the Game Over. Screenshots: `--notebook=alibi`, `--evidence=<clue> [--evidence-zoom=3]`, `--fast-nudge`.

## 1f. Animated story scenes (case3-depth)
- `@anim <id>` plays a scene from `scripts/data/anim_scenes.gd` on top of the dialogue, through `scripts/ui/story_anim.gd`, and the script
  carries on when it ends or is skipped (hold Space / Enter / mouse for a second; about 0.3 s under autotest). Formats and their lengths:
  `slam` 6 to 12 s, `cutout` 15 to 35 s, `broadcast` 20 to 30 s (the Warden's shopping channel, on worn tape), `full` 45 to 60 s.
- A scene is data: `[time, kind, {args}]` beats (the kinds and their arguments are listed in the data file's header). They build a layered
  cut-out stage with a parallax camera (`far`, `back`, `mid`, `front`), screen-fixed layers (`over`, `top`), slanted cut-ins (`panel`,
  `slam`, `title`, `badge`, `pop`, `say` captions, which also go into the Logbook transcript) and tape furniture (`onair`, `ticker`, `price`).
  Art: `art/props/an_*.svg` (`tools/gen_anim_art.py`); sound: `an_jingle`, `an_kaching`, `an_tvoff` (`tools/gen_anim_audio.py`).
- `scripts/screens/cutscene_base.gd` is the clock-driven scaffolding (timeline, keyframe animator, hit-stop, skip, particles, tape shader)
  for new cutscenes, copied from `drain_screen.gd`, which keeps its own copy. `story_anim.gd` extends it; so can new full-screen cutscenes.
- Checks: `tools/check_content.py` checks every `@anim` id and every beat (kinds, arguments, art, sound, colours, ids made before use, length
  within the format's range). `tools/check_depth.py` estimates play time in script order (230 words a minute plus half a second a line) and
  flags any stretch of more than 12 minutes without an animated beat (an `@anim`, a minigame or a cutscene screen).
- Debug: `-- --anim=<id>` plays one scene through the real `@anim` command. `--anim-t=<seconds>` starts there; with `--shot=<png>` too,
  it saves exactly that frame and quits. `fixture_full` exercises the long format and is never placed in a story.

## 1g. Case 3 endings (spoilers: docs/DESIGN3.md, "Endings")
- From Case 3 on, punishments are brutal and on screen (rule in `docs/DESIGN3.md`). The three ending screens extend `cutscene_base.gd`
  and replace its tape shader with `execution3_screen.gd`'s `TAPE_SHADER`, which greys everything but the blood (`red_keep`).
- Flow after a correct vote: `chapters.gd` `"after_vote": "confession"` sends `Main` to the `confession` step, which plays story id
  `confession` on the courtroom stage (`trial_screen.gd` with `params.script`; `SCREENS["confession"]`) and is skipped while no such
  script exists. Then `execution` (`execution3_screen.gd`), `epilogue`, `caiman_kill` (`caiman_kill_screen.gd`), `epilogue_after`
  (both halves in `scripts/data/story/story_end3.gd`, the third file of chapter 3 in `story.gd`) and `credits`.
- A wrong vote goes to `gameover`; a chapter's `"gameover"` key names its own screen (`gameover3_screen.gd`, which must emit
  `{"action": "retry"|"title"}` like the stock one). Choose Case's bridge now stops at whichever step leads to `credits`.
- Credits options per chapter: `credits_cast`, `credits_mourned`, `credits_quiet` (header of `chapters.gd`).
- Art and sound: `tools/gen_end3_art.py` (`sp_*`, `wv_*`, `ck_*`, `art/bg/end3_*`), `tools/gen_end3_audio.py` (`execution_press`,
  `execution_lineup`, `sp_*`, `wv_*`, `ck_*`). Debug: `-- --chapter=3 --start=execution --exec3-t=<s>`, `--start=gameover --wrong3-t=<s>`,
  `--start=caiman_kill --kill-t=<s>`; with `--shot=<png>` each saves exactly that frame (give a long `--shot-delay` as a safety net).

## 1d. 3D walk-around version (branch `3d-version`, release `v3-3d`)
An additional version of the game; `main` (2D, v3) is untouched. Story scenes, the trial, minigames, executions and
cutscenes are exactly the 2D ones. Only two screens are 3D (main.gd `SCREENS_3D`; `--2d` restores the 2D screens):
- `scripts/screens/investigation3d_screen.gd` **extends** the 2D investigation screen and only replaces the room view:
  same data (investigation_data*.gd), same story ids, `seen_<id>` flags, clue rewards, completion rule, map/notebook,
  banners and autotest path (autotest activates every hotspot/person through the 3D `_activate`).
  Exits are doors (`k.door`), following the map links; `k.link_door(hotspot, room)` turns an examinable door into an
  exit once it has been examined (ship corridor, cabin 2). Arriving through a door spawns you in front of the door back.
- `scripts/screens/freetime3d_screen.gd`: same flow as freetime_screen.gd (intro, 3 visits, `hangout_<id>` full screen,
  `hangouts_done`, outro, same autotest picks) in a walkable hub.
- `scripts/world3d/`: `kit.gd` (primitive meshes, inline shaders, lights, stock props, standees from the portraits,
  anchors), `player3d.gd` (first-person WASD + mouse), `hud3d.gd` (crosshair, controls strip, markers),
  `mouse_guard.gd` (captures the mouse while walking, frees it for dialogue/menus/pause), `rooms1.gd` / `rooms2.gd`
  (one builder per room id + `hub`). Every hotspot id of a room must get an object via `k.hotspot(id, ...)` (a missing
  one gets a fallback pedestal and a warning); people stand at `k.person(char, pos)`.
- Standees use **full-body art** `art/chars_full/<id>_<normal|sad|angry>.svg` (640x920, made by `tools/gen_chars_full.py`, which reuses the
  heads, hats and props of `tools/gen_chars.py` so a standee matches its dialogue portrait). Feet stand on the line y = 916; relative heights
  are baked into the art. `k.standee` falls back to the floating bust if a file is missing. After changing a character's height, update
  `Kit.FULL_TOP` (canvas y of the top of the art).
- **Walkable world (release v3-3d-2):** besides the rooms of investigation_data*.gd there are connecting spaces, listed in `SPACES` of
  rooms1.gd / rooms2.gd (name + map pin position; `FREE_SPACES` / `FREE_START` for Free Time). The investigation screen merges them into a
  stand-in for `Inv` (`WorldData`): they have no hotspots or people, `ROOM_ORDER` still lists only the real rooms, so the map, the progress
  rules and the autotest are unchanged. A space is one continuous walkable area, possibly over several floors; `k.door(to, ...)` joins spaces
  (each door needs a matching door back, used as the arrival spot). Kit additions: `plan` (any right-angled floor shape), `wall_run` (openings),
  `slab`, `stairs` (visible steps + ramp collider), `rail`, `lift` (two stops, same or another space, see lift_ride.gd), `note` (flavour only,
  never a clue). The map only travels to rooms already reached on foot (their enter script has been seen).
  In Free Time, `k.mode == "freetime"` adds the guests (`k.person`) and sets the lighting; doors outside FREE_SPACES stay closed.
  **Tests:** `Godot --headless --path . -s tools/walktest.gd` (every door has a way back; on foot you can reach and see every door, lift, hotspot,
  person and note; every staircase carries a walking player to the top; every guest has a Free Time spot). `-- --chapter=N --start=freetime
  --autotest --tour3d` really uses every door, lift and note in the running game. Keep waist-high blockers (pools) below 0.5 m, or they stop the
  crosshair reaching things behind them.
- Still no imports: the 3D look is built from primitives + inline shader code, the portraits/backgrounds are the same
  runtime-loaded SVGs. Renderer: Forward+ (`rendering_device/fallback_to_opengl3=true`).
- Saves: the project name is "Splash Trial 3D", so its user folder (saves/settings) is separate from the 2D game;
  `Game._inherit_unlock()` reads the 2D settings to offer Chapter 2 if it was unlocked there.
- Debug: `--room3d=<room or space>` (start the investigation there, intros skipped), `--door3d=<room>` (walk through that
  door on arrival), `--map3d` (open the map on arrival), `--cam=x,y,z,tx,ty,tz` (camera; y = eye height), `--skip-intro`, `--space3d=<id>` (free time). Combine with `--start=investigation` /
  `--start=freetime`, `--chapter=2` and `--shot=`.

## 2. Flow (scripts/core/main.gd)
title → prologue → freetime(3 slots) → motive → evening → night → discovery → investigation → investigation_end →
trial → (flag vote_correct ? execution → epilogue → credits : gameover → retry trial | title).
Story steps are played full-screen by `story_screen.gd` using the story script with the same id.
`Game.main.goto(step)`, `Game.main.open_notebook("clues")` are available to screens. Esc opens the pause menu (Truth Drops, Skills, Settings).

### Screen contract
```gdscript
extends Control
signal finished(result: Dictionary)
func setup(params: Dictionary) -> void   # optional, called BEFORE add_child
```
Main adds the screen full-rect under a themed Control, fades in, and listens for `finished` (one shot).
- title: emits `{"action": "new"|"continue"|"credits"|"quit"}`; show Continue only if `Game.has_save()`. Autotest → "new".
- freetime: params `{"slots": 3}`; emits `{}`.
- investigation: emits `{}` after playing `investigation_complete`: when the player finishes (`"ending": "choice"`), or on the last required clue (`"auto"`).
- execution: emits `{}` (video done/skipped). credits: emits `{}` (params may contain `from_title`). gameover: emits `{"action":"retry"|"title"}`.

## 3. Story DSL (played by scripts/core/script_player.gd)
One command per line. Blank lines and `#comments` ignored. Text lines:
```
coco: Ahoy, matey!                 # speaker line (speaker = cast id). Name tag + blip voice.
coco[happy]: Ha!                   # speaker line + set expression (normal|happy|shock|angry|sad)
think: I have a bad feeling.       # Mochi's inner thought (shown in light-blue italics, parentheses added automatically - DON'T add your own)
narr: The lights flickered.        # narration (no name). A line with no "speaker:" prefix is also narration.
mochi: Um, hello?                  # the player speaking aloud (portrait not shown)
voice: Who's there?                # unknown voice, shows "???"
all: WHAT?!                        # everyone at once
*word*                             # highlights a key word in yuzu orange
```
Commands:
```
@bg <bg_id> [instant]      @bg none               # background (art/bg/<id>.svg), crossfades
@music <track_id>          @music stop            # loops; see audio ids
@sfx <sfx_id>
@show <char> [expr] [pos]  # pos: farleft left center right farright (or 0..1). Slides in.
@expr <char> <expr>
@hide <char>   @hide all
@intro <char>              # big name/talent intro card; afterwards the char is shown at center
@label <name>   @jump <name>   @end
@choice [prompt text]      # followed by option lines:
> Option text -> label_name
@flag <name> [true|false|int|string]
@if <flag> -> <label>      @ifnot <flag> -> <label>
@clue <clue_id>            # adds a Truth Drop + popup (skipped silently if already owned)
@skill <skill_id>          # grants a skill + popup
@convince +5 / -5          # trial only
@wait <seconds>
@flash [#rrggbb]   @shake [strength]
@card TITLE TEXT | optional subtitle      # banner card
@shout <char> TEXT!        # dramatic cut-in, e.g. @shout mochi THAT DOESN'T FLOAT!
@minigame <trial_data_id>  # runs a trial minigame (blocks until done)
@textbox hide|show
@emit <event> [args]       # signal for host screens
@alibi <char> motive       # fills in the Alibi Board. Also: @alibi <char> <when>, @alibi <char> <when> proof, @alibi <char> all
@alibi row <when>          # adds a row, e.g. @alibi row 9:47 PM, when the trial changes which time matters
@checkpoint <label> [floor] # trial only: Retry and Continue come back to this label with the convince from here (at least floor)
@log timeline 9:30 PM | Everyone met in the lobby.   # adds a Logbook entry. The time before " | " is optional
@log places <text>         # (rooms entered and things examined are written automatically)
@log people <char> <text>  # what a guest told Mochi
@log trial #id <text>      # what the group accepted; the #id is optional. @log strike <id> crosses it out once it's disproved
@evening [question]        # small end-of-day prompt that offers to open the player's Trust and Doubt marks
@anim <id>                 # plays an animated scene from scripts/data/anim_scenes.gd over the dialogue (blocks; see 1f)
```
In the trial (and investigation talks) the player runs in **auto_portrait** mode: each speaker line shows that speaker centered,
so `@show` isn't needed there. In story scenes use `@show/@hide` explicitly (multiple characters on screen).
Text is plain (no backslashes, no triple quotes). Keep lines ≤ ~150 characters (textbox fits ~3 lines at 25px).

## 4. Data (all fixed ids)
- Cast: `scripts/data/cast.gd` (ids, names, talents, colors). Expressions: normal, happy, shock, angry, sad.
- Clues: `scripts/data/clues.gd` — 14 Truth Drops (all REQUIRED). Skills: `scripts/data/skills.gd` (BY_CHAR map).
- Investigation rooms/hotspots/people: `scripts/data/investigation_data.gd` (script ids it references must exist in story_case).
- Trial minigame data: `scripts/data/trial_data.gd`.

## 5. Minigame contract (scripts/trial/*.gd)
```gdscript
extends Control
signal finished(result: Dictionary)      # result may include "flags": {name: value} (applied to Game)
func setup(data: Dictionary) -> void     # data = trial_data entry + {"id": id}; called BEFORE add_child
```
- ScriptPlayer creates it with `load(path).new()`, full-rect in its `minigame_layer`, hides portraits while it runs, then awaits `finished`.
  The trial background stays visible underneath (draw your own dim/overlay as needed). The **Convince Meter HUD occupies the top strip y 0–75
  (x 390–890)** — keep your UI out of it.
- Convince economy: call `Game.reward(Game.REWARD_X)` / `Game.mistake(Game.PENALTY_X)` (constants in game.gd). Skills are handled inside
  reward/mistake (encore, iron_hide, deep_roots, first_aid). Minigame-specific skills you must implement:
  `scoop_sense` (debate: correct weak spot sparkles after first loop), `power_nap` (multiply all your timers/durations by `Game.timer_scale()`),
  `hypothesis` (choice/present/character: cross out one plainly wrong option; never in a `free` choice, never the `vote_option`, never an `early` answer), `autocomplete` (bubbles: next correct letter shimmers),
  `sleight_of_paw` (rebuttal: timing window 40% wider), `en_garde` (rebuttal: counters reward ×2), `artists_eye` (rewind: cross out one wrong option per panel).
- Wrong answers never end the minigame — the player retries until correct (each mistake costs convince). Show clear feedback
  (shake, red flash, `Audio.sfx("wrong")`, optional "wrong" line from data). Correct → big feedback (`Audio.sfx("break")`, flash, a
  "THAT DOESN'T FLOAT!" style banner for debates/rebuttal), then emit `finished`.
- Speaker lines inside minigames: show `Assets.portrait(speaker, expr)` + name tag (Cast colors) — no need to use ScriptPlayer.
- **Autotest**: when `Game.autotest`, solve correctly after ~0.3 s (exercise the success path, optionally one wrong attempt first), then emit.
- Clue names/descriptions: `Clues.clue_name(id)`, `Clues.desc(id)`; icons `Assets.clue_icon(id)` (may be null → draw a text card).
- Input: mouse first; keyboard optional. Use `_unhandled_input`/`_gui_input`; mark events handled.

### Data formats (see real data in scripts/data/trial_data.gd)
- **debate**: `drops` (clue ids loaded as ammo), `statements` [{speaker, expr, text}] where `{phrase}` marks a weak spot,
  `answer` {statement, weak (index of the {..} within that statement), drop}, optional `wrong` [lines], `hint`, `title`.
  Gameplay ("Splash Debate"): statements float across the screen one at a time (≈3.2 s each × timer_scale), looping. Weak-spot phrases glow
  orange and are clickable targets. The player picks a Truth Drop (ammo cylinder/list, keys 1–4 or click) and clicks a weak spot to
  fire a water shot. Correct pair → break. Wrong drop/spot → mistake. Shooting non-weak text does nothing. After each full loop without
  success: no penalty (timeouts never cost convince), restart the loop; after 2 loops show `hint`.
- **choice**: `prompt`, `options` [text], `answer` (index), `speaker`, `wrong` {speaker, expr, text}.
- **present**: pick any owned Truth Drop (`Game.clues`) — `answer` = clue id, or a list of two clue ids presented together in either order (`REWARD_PAIR`). In a two-part question only the pair is ever scored: a double-click (like ADD!) puts a card in a slot, or takes it back out.
- **character**: pick a capybara portrait from `Cast.survivors()` minus `exclude` — `answer` = char id, or `answers: [ids]` to pick several and confirm (`REWARD_PAIR`). A wrong confirm crosses out one wrong pick, if there is one. Keys: arrows move between portraits, Space/Enter picks; with `answers`, Space picks and Enter confirms.
- **choice** extras: `free: true` (any option; no reward or penalty; `option_flags: [flag per option]`). `vote_option: index`: that option ends the segment with flag `voted_early`; the script branches on it into a `vote` with `false_vote: true` and the wrong-vote ending.
- **early** (present, debate and rebuttal only): `early: {clue id: line}` lists Truth Drops that are right but too soon: no cost, Mochi says the line (a String, or {speaker, expr, text}), and `Game.pay_early` adds `EARLY_BONUS` when that Drop comes up for real. Only Truth Drop ids: the flag belongs to no segment, so `Game.note_early` ignores anything else and `tools/check_depth.py` rejects it.
- **roll_call**: `title`, `prompt`, `entries` [{guest, expr, claim, answer, wrong}]. `answer` is a guest, a list of guests (any is right) or `"nobody"`. `REWARD_ROLL` / `PENALTY_ROLL` per guest. The cards are everyone alive at the trial (Mochi too) except the guest speaking, plus Nobody, so `tools/check_depth.py` requires every answer to be one of those. Keys: arrows move between the cards, Space/Enter picks.
- **time_pick**: `title`, `speaker`, `expr`, `prompt`, `wrong`, `from`, `to`, `step` (minutes), `tolerance`, `answer` = `"8:05 PM"` or `["8:05 PM", "9:15 PM"]` for a window. `REWARD_TIME` / `PENALTY_TIME`.
- **evidence**: `clue` (or inline `images`), `speaker`, `prompt`, `answers` [picture indexes, any order], `wrong`. The player leafs through the pictures and picks the ones asked for.
- **bubbles** ("Bubble Letters"): `prompt`, `answer` (word), `decoys` (extra letters), `time` (sec × timer_scale). Letter bubbles drift/bob
  upward; pop letters in order to spell the word; wrong letter → `PENALTY_BUBBLES`; time out → no penalty, restart; solved → `REWARD_BUBBLES`.
- **rebuttal** ("Rebuttal Showdown"): `opponent`, `intro`, `lines` [text], `final` {text with {weak}, drops, answer}, `time_per_line`.
  Phase 1: opponent fires each line; a timing ring shrinks onto a target — press Space/click when it overlaps to COUNTER
  (`REWARD_COUNTER`, ×2 with en_garde) else miss (`PENALTY_COUNTER` for a mistimed press, nothing if no press). Phase 2: final line with weak spot — choose a drop and fire at it
  (`REWARD_REBUTTAL` / `PENALTY_REBUTTAL`, retry until correct).
- **rewind** ("Case Rewind"): `panels` [{caption with ___, options, answer, bg}], `culprit`, `finale`. Comic-panel sequence: each panel
  shows a dimmed mini background + caption; choose the option to fill the blank (`REWARD_REWIND_PANEL` / `PENALTY_REWIND`). After all
  panels: replay all filled panels quickly, show `finale` with the culprit's shocked portrait, `REWARD_REWIND`.
- rewind panels can set `"jam": true` (optional `jam_text`): no option fits, picking any costs nothing, the reel stops there with flag `rewind_jammed` and the next segment takes over. Panels after a jam never play, so the strip can look its usual length.
- **vote**: `culprit`, `fallback`, `threshold` (the chapter's `threshold` wins if it has one). Player picks one capybara from `Cast.survivors()` (Mochi can't vote for themself — exclude "mochi").
  Then a slot-machine reel spins through portraits and lands on the MAJORITY: if `Game.convince >= threshold` the group follows the
  player's pick; otherwise the group votes `fallback` (if the player picked the fallback, the majority is still the fallback).
  Show a tally (e.g. 13 votes when convinced; when not convinced: fallback 9, the player's pick 3, others 1). Emit
  `{"flags": {"vote_correct": majority == culprit, "voted": pick, "majority": majority}}`.

## 6. Art specs
All art is SVG 1.1 rendered by ThorVG at 1.5× (preview with tools/svg2png.gd — what you see is what the game shows).
Allowed: path, rect, circle, ellipse, polygon, polyline, line, g, defs, linearGradient, radialGradient, clipPath, mask, opacity,
transform, stroke-linejoin/linecap. **Forbidden**: `<text>`, `<filter>` (blur/shadow), `<image>`, external refs, CSS `<style>` classes,
fonts. (Fake shadows with semi-transparent shapes.)
- **Portraits** `art/chars/<id>_<expr>.svg` — width=480 height=600 viewBox="0 0 480 600", transparent background, bust-up (head + shoulders/chest,
  cut off at the bottom edge), character centered, head top ~ y 40–90. 16 ids (15 capybaras + snapjaw) × 5 expressions
  (normal, happy, shock, angry, sad). Cute chibi-anime style with bold dark outlines (#2a1a10, 5–7px, round joins), soft cel-shading
  (one shadow tone), big expressive eyes with highlights. Capybara anatomy: boxy rounded head, small round ears on top, big
  blunt snout with nostrils, tiny eyes set high (anime-enlarged OK), short whiskers. Each character's outfit/props from DESIGN.md §2 must make
  them instantly distinguishable (silhouette + color). Expression effects: happy (closed ^^ eyes or sparkles, blush), shock (white eyes,
  sweat drop, open mouth), angry (furrowed brows, anger mark, teeth), sad (droopy brows, tears). Snapjaw = robotic caiman bust.
- **Backgrounds** `art/bg/<id>.svg` — 1280×720, full-bleed, painterly-flat anime BG style with simple perspective, warm lantern lighting
  (resort = Japanese hot-spring inn + luxury hotel + sinister touches: steel shutters, Snapjaw logos/cameras). Characters stand in front, so keep
  the lower-left (x<330, y>340) and lower-right (x>950, y>340) zones visually calm.
  Required ids: `title` (key art: steamy hot spring at night, capybara silhouettes, NO text — the logo is drawn in code), `lobby`, `dining`, `kitchen`,
  `lounge` (small stage with red curtain half-drawn, chairs), `giftshop` (capybara mannequins on pedestals, one EMPTY pedestal, shelves of plushies,
  price-tag gun on counter), `changing` (lockers, stack of wooden buckets, coat hooks one labeled with a red mark, side door), `bath` (outdoor yuzu
  hot spring at night, steam, foam-cushioned rocks, floating yuzu, stone lantern), `bath_body` (same bath in pale morning light with Captain Coco
  floating face-down — cartoon, non-graphic: white captain hat floating, striped shirt; red headband on front-right edge), `sauna`, `garden` (morning garden stone path between
  two doors, rose bush in the middle, stone lanterns), `storage` (dim closet behind stage, mannequin, magic trunk with stars, prop boxes), `hallway` (guest
  wing with doors/nameplates), `room` (Mochi's guest room, futon, night), `trial` (the Trial Pool: circular underground chamber, ring of 15 wooden podiums
  around a glowing turquoise pool, Snapjaw's throne on a rock island, dramatic lighting; keep center x 400–880 relatively uncluttered for the speaker portrait).
  **Investigation hotspots**: for every room in `scripts/data/investigation_data.gd`, the object named by each hotspot label must be drawn INSIDE its `rect`
  (bath hotspots go on `bath_body`).
- **Clue icons** `art/props/clue_<id>.svg` — 200×200, transparent bg, one per Truth Drop id (14), item-card style illustration (no text; for
  documents draw a paper with scribble lines).

## 7. Audio specs (generated; mono or stereo 16-bit PCM WAV, 32 kHz or 44.1 kHz)
Music (seamless loops, 40–90 s): `title`, `daily`, `tension`, `investigate`, `snapjaw`, `trial`, `trial_climax`, `execution`, `sad`, `credits`, `gameover`.
SFX: `blip` (very short soft tick), `select`, `confirm`, `cancel`, `clue` (acquired jingle), `chime` (announcement ding-dong), `body_found` (dramatic
announcement stinger), `whoosh`, `shout`, `shoot` (water squirt), `break` (glassy splash crash), `wrong` (buzzer), `pop` (bubble), `tick`, `heartbeat`,
`gavel`, `slot` (reel tick), `drumroll`, `splash`, `door`, `poof` (magic), `firework`, `boom`, `cheer`, `gasp`, `sizzle`, `static`, `correct` (bright ding).

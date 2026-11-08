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
8. Original content only — no names/characters/catchphrases/art from existing franchises. No gore.

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
- Blood (execution only): stylized dark red, never pink.

## 1c. Chapters (v3)
- `scripts/data/chapters.gd` holds per-chapter data (victim, culprit, dead-before list, first step, step order "next",
  execution screen, investigation data file, free-time auto picks). `Game.chapter` (1|2) writes `Chapters.current`, which the
  data scripts read: `Story` (story_daily/story_case vs story_daily2/story_case2), `Clues.order()/required()` (ORDER vs ORDER2),
  `trial_data_index.gd` (trial_data vs trial_data2), investigation_data vs investigation_data2, `Cast.survivors()` /
  `alive_at_start()` / `roster_alive()`.
- Chapter 2 spoilers + content: docs/DESIGN2.md. Flow: aftermath → drain (cutscene screen) → prologue → ... like chapter 1.
- Chapter 1's credits unlock chapter 2 (`Game.chapter_unlocked`, saved in settings) and lead straight into it. The title shows
  "Chapter 2" once unlocked. Saves store the chapter.
- Debug: `--chapter=2` with any of `--start=`, `--script=`, `--minigame=` (e.g. `-- --chapter=2 --start=drain --autotest`).
  `python3 tools/check_content.py` checks both chapters.

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
- investigation: emits `{}` when all required clues are collected (after playing `investigation_complete`).
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
  `hypothesis` (choice/present/character: cross out one wrong option), `autocomplete` (bubbles: next correct letter shimmers),
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
- **present**: pick any owned Truth Drop (`Game.clues`) — `answer` = clue id.
- **character**: pick a capybara portrait from `Cast.survivors()` minus `exclude` — `answer` = char id.
- **bubbles** ("Bubble Letters"): `prompt`, `answer` (word), `decoys` (extra letters), `time` (sec × timer_scale). Letter bubbles drift/bob
  upward; pop letters in order to spell the word; wrong letter → `PENALTY_BUBBLES`; time out → no penalty, restart; solved → `REWARD_BUBBLES`.
- **rebuttal** ("Rebuttal Showdown"): `opponent`, `intro`, `lines` [text], `final` {text with {weak}, drops, answer}, `time_per_line`.
  Phase 1: opponent fires each line; a timing ring shrinks onto a target — press Space/click when it overlaps to COUNTER
  (`REWARD_COUNTER`, ×2 with en_garde) else miss (`PENALTY_COUNTER` for a mistimed press, nothing if no press). Phase 2: final line with weak spot — choose a drop and fire at it
  (`REWARD_REBUTTAL` / `PENALTY_REBUTTAL`, retry until correct).
- **rewind** ("Case Rewind"): `panels` [{caption with ___, options, answer, bg}], `culprit`, `finale`. Comic-panel sequence: each panel
  shows a dimmed mini background + caption; choose the option to fill the blank (`REWARD_REWIND_PANEL` / `PENALTY_REWIND`). After all
  panels: replay all filled panels quickly, show `finale` with the culprit's shocked portrait, `REWARD_REWIND`.
- **vote**: `culprit`, `fallback`, `threshold`. Player picks one capybara from `Cast.survivors()` (Mochi can't vote for themself — exclude "mochi").
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

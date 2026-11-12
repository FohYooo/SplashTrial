# SPLASH TRIAL

An original capybara murder-mystery trial game. Fifteen capybaras are trapped in a luxury hot-spring resort by
**Warden Snapjaw**. Hang out with your fellow guests, survive the night, investigate a murder,
and convince everyone of the truth at the **Splash Trial**, or you'll all pay the price.

- **Chapter 1: Murder at Yuzu Springs**
- **Chapter 2: Murder on the Mudlark** (new in v3; it follows straight on from Chapter 1. After you finish Chapter 1
  once, the title screen also gets a **Chapter 2** button.)
- **Chapter 3: Murder at Warden's Rest** (new in v4, in the 3D version only.)

> The game continues in the **3D version** (release **v4**, branch `case3-depth`), where you walk around in 3D and
> can play all three chapters. This branch is the classic 2D version, with Chapters 1 and 2.

**All the hard work done by Foh, Noomie and Dani, little bit of help from Claude.**

## How to download and play (Windows)
1. Go to the [latest release](https://github.com/FohYooo/SplashTrial/releases/latest) and download
   **`SplashTrial-3D-windows.zip`**, the 3D version with all three chapters. For the classic 2D version, go to the
   [v3 release](https://github.com/FohYooo/SplashTrial/releases/tag/v3) and download **`SplashTrial-v3-windows.zip`**
   instead. The guide picture below shows an older file name, but the steps are the same. The "Source code" links
   are not the game.
2. Right-click the zip, choose **Extract All…**, then **Extract**.
3. Double-click **`SplashTrial3D.exe`** (or **`SplashTrial.exe`** for the 2D version). There's nothing to install.
   If Windows says *"Windows protected your PC"*, click **More info → Run anyway**. It only asks the first time.

The 3D version keeps its own save, so it never overwrites your 2D save.

The zip also holds `GODOT_COPYRIGHT.txt`, the engine's open-source license notices. Just leave it next to the exe.

![Step-by-step guide: how to download and play Splash Trial](docs/download-guide.png)

## Controls
| Action | Input |
|---|---|
| Advance dialogue | Left click / Space / Enter |
| Fast-forward dialogue | Hold Ctrl |
| Pause menu (Truth Drops, Skills, Settings) | Esc |
| Fullscreen | F11 or Alt+Enter |
| Investigation map / notebook | M / N |
| Splash Debate: pick a Truth Drop | 1-4 or click; then click a glowing weak spot to fire |
| Rebuttal Showdown: counter | Space or click when the ring hits the target |

## How the trial works
Your **Convince Meter** rises when you argue well and drops with every mistake. At the vote you must
point out the culprit **and** have at least **60%** convince. Otherwise the others ignore you and vote with their gut.
Skills learned during Free Time make the trial easier.

## For developers
- Godot **4.7.2**, GDScript, GL Compatibility renderer. Open the folder in Godot or run
  `Godot --path . ` (add `-- --autotest` to auto-play the whole game).
- Design bibles (spoilers!): `docs/DESIGN.md` (Chapter 1), `docs/DESIGN2.md` (Chapter 2). Engine contracts and the
  chapter system: `docs/ARCHITECTURE.md`. Add `--chapter=2` to any debug flag to work on Chapter 2.
- Art (`art/`) is generated SVG and audio (`audio/`) is generated WAV, both loaded at runtime. Generators live in `tools/`.
- Export: `python3 tools/prepare_export.py`, then
  `Godot --headless --path . --export-release "Windows Desktop" build/v3/SplashTrial.exe`, then
  `Godot --headless --script tools/gen_licenses.gd -- out=build/v3/GODOT_COPYRIGHT.txt` and zip both files together.
  The credits also show the Godot MIT license and the FreeType / Mbed TLS / ENet notices.

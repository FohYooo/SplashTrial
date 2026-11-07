# SPLASH TRIAL: Murder at Yuzu Springs

An original capybara murder-mystery trial game. Fifteen capybaras are trapped in a luxury hot-spring resort by
**Warden Snapjaw**. Hang out with your fellow guests, survive the night, investigate a murder,
and convince everyone of the truth at the **Splash Trial**, or you'll all pay the price.

**All the hard work done by Foh, Noomie and Dani, little bit of help from Claude.**

## Playing (Windows)
Unzip `build/SplashTrial-v2-windows.zip` and run `SplashTrial.exe`. It's a single self-contained file; the zip also holds
`GODOT_COPYRIGHT.txt` (the engine's open-source license notices, which must ship with the game). Windows SmartScreen may warn
about an unknown publisher the first time; click *More info → Run anyway*.

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
- Design bible (spoilers!): `docs/DESIGN.md`. Engine contracts: `docs/ARCHITECTURE.md`.
- Art (`art/`) is generated SVG and audio (`audio/`) is generated WAV, both loaded at runtime. Generators live in `tools/`.
- Export: `python3 tools/prepare_export.py`, then
  `Godot --headless --path . --export-release "Windows Desktop" build/v2/SplashTrial.exe`, then
  `Godot --headless --script tools/gen_licenses.gd -- out=build/v2/GODOT_COPYRIGHT.txt` and zip both files together.
  The credits also show the Godot MIT license and the FreeType / Mbed TLS / ENet notices.

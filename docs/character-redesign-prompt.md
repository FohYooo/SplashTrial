# Prompt: capybara character redesign (SPLASH TRIAL)

Copy everything below the line into the other agent.

---

You are the character designer for **SPLASH TRIAL**, an original anime-style murder-mystery "class trial" game about 15 capybaras trapped in a luxury hot-spring resort by a robotic caiman mastermind. All the art is cute chibi-anime: bold dark outlines, soft cel-shading, big expressive eyes.

## The problem

In the first design every capybara was drawn from **one shared head template**: the same head silhouette, eyes, brows, muzzle, nose, ears and mouth. Only the hats, outfits and fur colours changed. Without the costume, you couldn't tell who was who.

Your job is to give every character a **distinct face and silhouette**: you should recognise them from the face alone. Keep their outfits, accessories, colour palette and personality so they still read as the same characters.

## The first design (reference)

- All original portrait files (16 characters × 5 expressions, SVG): https://github.com/FohYooo/SplashTrial/tree/v2/art/chars
- The generator script that drew them: https://github.com/FohYooo/SplashTrial/blob/v2/tools/gen_chars.py
- Each character's neutral portrait (open one in the browser to see it):

| id | link |
|---|---|
| mochi | https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/mochi_normal.svg |
| coco | https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/coco_normal.svg |
| wisp | https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/wisp_normal.svg |
| bruno | https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/bruno_normal.svg |
| lulu | https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/lulu_normal.svg |
| pepper | https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/pepper_normal.svg |
| duchess | https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/duchess_normal.svg |
| bramble | https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/bramble_normal.svg |
| nibs | https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/nibs_normal.svg |
| zuzu | https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/zuzu_normal.svg |
| reginald | https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/reginald_normal.svg |
| grub | https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/grub_normal.svg |
| tumble | https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/tumble_normal.svg |
| marigold | https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/marigold_normal.svg |
| fennel | https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/fennel_normal.svg |
| snapjaw | https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/snapjaw_normal.svg |

Every file name follows `<id>_<expression>.svg`, with expression one of `normal`, `happy`, `shock`, `angry` or `sad`. For example, Bruno angry is https://github.com/FohYooo/SplashTrial/blob/v2/art/chars/bruno_angry.svg. Raw files are at `https://raw.githubusercontent.com/FohYooo/SplashTrial/v2/art/chars/<id>_<expression>.svg`.

(A redesign pass has already been done locally but isn't on GitHub yet; the first design above is the starting point.)

## The cast

All are capybaras except Snapjaw. Talents are written as "Ace <Talent>".

| id | Name | Talent | Look (keep) | Personality (show it in the face) |
|---|---|---|---|---|
| mochi | Mochi (the player, they/them) | Ace Bath Connoisseur | warm caramel fur, a little yuzu fruit on their head, white towel round the neck, orange hoodie | earnest, curious, kind, quietly sharp |
| coco | Captain Coco | Ace Sailor | reddish-brown fur, white captain's hat with gold anchor, navy/white striped shirt, gold pocket-watch chain | loud, bold, protective, big laugh |
| wisp | Wisp Vanderloo | Ace Magician | dark chocolate fur, tall black top hat, violet cape with silver stars, white gloves, monocle | theatrical, polite, mysterious |
| bruno | Bruno Brawnsworth | Ace Wrestler | huge, dark brown fur, red headband, wrestling singlet, scar on one eyebrow | gentle giant, talks about himself in the third person |
| lulu | Lulu Starling | Ace Pop Idol | light golden fur, big pink bow, sparkly pink dress, microphone, pink glitter cheeks | bubbly on the outside, secretly anxious |
| pepper | Pepper Quill | Ace Journalist | sandy fur, newsboy cap with PRESS card, camera on a strap, notebook | fast-talking, nosy, rival-detective energy |
| duchess | Duchess Velveteen | Ace Fashion Designer | pale cream fur, wide sun hat with feather, pearl necklace, lilac shawl | haughty, dramatic, "Darling" |
| bramble | Bramble Thistlewood | Ace Gardener | olive-brown fur, flower crown, green overalls, trowel | slow, soft, poetic, observant |
| nibs | Professor Nibs | Ace Chemist | grey-brown fur, round goggles on the forehead, lab coat, bow tie | pedantic, "Hypothetically speaking..." |
| zuzu | Zuzu Byte (they/them) | Ace Hacker | dark grey fur, cat-ear headphones, black hoodie, glowing laptop sticker | terse, deadpan, internet slang |
| reginald | Sir Reginald Puddlesworth III | Ace Fencer | tawny fur, white fencing jacket, plumed beret, thin moustache, fencing foil | pompous, honourable, "I say!" |
| grub | Grub Pemberton | Ace Chef | chubby, toffee fur, tall chef's hat, white chef coat, wooden spoon | cheerful, food puns, feeds everyone |
| tumble | Old Man Tumble | Ace Napper | grey-white grizzled fur, droopy nightcap, half-closed eyes, blanket shawl | always sleepy, rambling, accidentally wise |
| marigold | Marigold Fern | Ace Nurse | soft orange-brown fur, white nurse cap with green cross, light-blue scrubs, stethoscope | caring, worried, precise |
| fennel | Fennel Dauber | Ace Painter | light brown fur with paint smudges, red beret, long scarf, paintbrush behind the ear | dramatic artiste, "Magnifique!" |
| snapjaw | Warden Snapjaw (mastermind) | — | robotic caiman: green scales on the left half, chrome on the right, top hat, monocle, red eye, toothy grin, bow tie | gleeful, theatrical, mocking; already distinct, light touch-ups only |

## What to vary per character

Each of these should differ between characters:
- **Head shape and proportions:** round and chubby (Grub), broad and square with a heavy jaw (Bruno), long and narrow (Duchess, Nibs), small, droopy and wrinkled (Tumble), sharp and angular (Pepper, Zuzu), soft oval (Marigold, Lulu)...
- **Eyes:** size, shape (round, almond, sleepy half-lidded, sharp narrow, huge sparkly idol eyes), lashes, eyelids, iris colour, spacing, highlights.
- **Brows:** thick, thin and arched, bushy and white, raised on one side, none.
- **Muzzle and nose:** size and shape (wide, button, pointed, boxer's broken nose, long).
- **Mouth and teeth:** shape, buck teeth, a fang, a chipped tooth.
- **Cheeks and markings:** freckles, paint smudges, scars, wrinkles, stubble, fur patches, a forehead stripe.
- **Ears:** small round, notched, pointy, floppy, tufted.
- **Hair and facial hair:** tufts, fringes, sideburns, moustaches, beards.
- **Body:** shoulder width and posture (Bruno huge, Grub chubby, Tumble small and hunched, Lulu petite).

**Test:** remove the hats and outfits, and a stranger should still tell all 15 capybaras apart. The set must still look like one cohesive art style.

## Expressions (all 5 per character, each must look like *that* character's face)

- **normal:** neutral, in character.
- **happy:** closed ^^ eyes or sparkles, blush.
- **shock:** white eyes, sweat drop, open mouth.
- **angry:** furrowed brows, anger mark, teeth.
- **sad:** droopy brows, tears.

## Technical constraints (the game depends on these)

- **Format:** SVG 1.1, `width="480" height="600" viewBox="0 0 480 600"`, transparent background. Same file names as the first design (`<id>_<expression>.svg`, 16 ids × 5 expressions = 80 files).
- **Framing:** bust-up, cut off at the bottom edge, character horizontally centred, top of the head at about y 40–90. Keep the eyes in roughly the same vertical band as the first design: the game crops the top of the portraits and shows them small.
- **Allowed elements:** path, rect, circle, ellipse, polygon, polyline, line, g, defs, linearGradient, radialGradient, clipPath, mask, opacity, transform, stroke-linejoin/linecap.
- **Forbidden elements:** `<text>`, `<filter>` (no blur or drop shadows; fake shadows with semi-transparent shapes), `<image>`, external references, CSS `<style>` classes, fonts.
- **Style:** bold dark outlines (`#2a1a10`, 5–7 px, round joins), one shadow tone of cel-shading, big eyes with highlights. Capybara anatomy: boxy rounded head, small ears on top, big blunt snout with nostrils, short whiskers.
- **Content:** original content only, nothing copied from existing franchises.

## Deliverables

1. The 80 SVG files.
2. One contact sheet of all 16 neutral portraits side by side.
3. One sheet per character showing its 5 expressions.
4. A "faces only" sheet with hats and outfits removed, to prove the faces are distinct.
5. A short note per character on what makes their face unique.

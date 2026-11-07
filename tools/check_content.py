#!/usr/bin/env python3
"""Cross-checks all story scripts against art, audio, cast, clues, skills, minigames and labels.
Usage: python3 tools/check_content.py   (exit code 1 if errors)"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def rd(p): return open(os.path.join(ROOT, p), encoding="utf-8").read()

def scripts_from(path):
    src = rd(path)
    return {m.group(1): m.group(2) for m in re.finditer(r'"([a-z0-9_]+)":\s*"""(.*?)"""', src, re.S)}

daily = scripts_from("scripts/data/story/story_daily.gd")
case = scripts_from("scripts/data/story/story_case.gd")
allscripts = {**daily, **case}
dups = set(daily) & set(case)

cast_src = rd("scripts/data/cast.gd")
CAST = set(re.findall(r'^\t"([a-z]+)":\s*\{"name"', cast_src, re.M))
EXPR = {"normal", "happy", "shock", "angry", "sad"}
CLUES = set(re.findall(r'^\t"([a-z_]+)": \{\n\t\t"name"', rd("scripts/data/clues.gd"), re.M))
SKILLS = set(re.findall(r'^\t"([a-z_]+)": \{"name"', rd("scripts/data/skills.gd"), re.M))
by_char = dict(re.findall(r'"([a-z]+)": "([a-z_]+)"', rd("scripts/data/skills.gd").split("const SKILLS")[0]))
TRIAL = set(re.findall(r'^\t"([a-z_]+)": \{\n\t\t"type"', rd("scripts/data/trial_data.gd"), re.M))
inv_src = rd("scripts/data/investigation_data.gd")
INV_SCRIPTS = set(re.findall(r'"(?:script|enter_script)": "([a-z_]+)"', inv_src))
BGS = {f[:-4] for f in os.listdir(os.path.join(ROOT, "art/bg")) if f.endswith(".svg")}
MUSIC = {os.path.splitext(f)[0] for f in os.listdir(os.path.join(ROOT, "audio/music")) if f.endswith((".wav", ".ogg"))}
SFX = {os.path.splitext(f)[0] for f in os.listdir(os.path.join(ROOT, "audio/sfx")) if f.endswith((".wav", ".ogg"))}
POS = {"farleft", "left", "center", "right", "farright"}
HEADS = CAST | {"narr", "think", "voice", "all"}

errors, warns = [], []
def err(s, m): errors.append(f"[{s}] {m}")
def warn(s, m): warns.append(f"[{s}] {m}")

required = {"prologue", "freetime_intro", "motive", "evening", "night", "discovery", "epilogue",
            "investigation_start", "investigation_complete", "investigation_end", "trial"}
required |= {f"hangout_{c}" for c in by_char}
required |= INV_SCRIPTS
for r in sorted(required - set(allscripts)):
    err("missing", f"script id '{r}' is not defined")
for d in sorted(dups):
    err("dup", f"script id '{d}' defined in both story files")

for sid, text in allscripts.items():
    labels = set(re.findall(r"^\s*@label\s+(\S+)", text, re.M))
    for n, line in enumerate(text.split("\n"), 1):
        L = line.strip()
        if not L or L.startswith("#"):
            continue
        if "\\" in L:
            err(sid, f"line {n}: backslash")
        if L.startswith("@"):
            parts = L[1:].split()
            op, args = parts[0].lower(), parts[1:]
            if op == "bg" and args and args[0] != "none" and args[0] not in BGS: err(sid, f"line {n}: unknown bg '{args[0]}'")
            elif op == "music" and args and args[0] not in MUSIC | {"stop", "none"}: err(sid, f"line {n}: unknown music '{args[0]}'")
            elif op == "sfx" and args and args[0] not in SFX: err(sid, f"line {n}: unknown sfx '{args[0]}'")
            elif op in ("show", "intro", "expr", "hide", "shout") and args and args[0] not in CAST | {"all"}: err(sid, f"line {n}: unknown char '{args[0]}'")
            elif op == "show" and len(args) > 1 and args[1] not in EXPR: err(sid, f"line {n}: unknown expr '{args[1]}'")
            elif op == "show" and len(args) > 2 and args[2] not in POS and not re.match(r"^[0-9.]+$", args[2]): err(sid, f"line {n}: bad pos '{args[2]}'")
            elif op == "expr" and len(args) > 1 and args[1] not in EXPR: err(sid, f"line {n}: unknown expr '{args[1]}'")
            elif op == "clue" and args and args[0] not in CLUES: err(sid, f"line {n}: unknown clue '{args[0]}'")
            elif op == "skill" and args and args[0] not in SKILLS: err(sid, f"line {n}: unknown skill '{args[0]}'")
            elif op == "minigame" and args and args[0] not in TRIAL: err(sid, f"line {n}: unknown minigame '{args[0]}'")
            elif op == "jump" and args and args[0] not in labels: err(sid, f"line {n}: jump to missing label '{args[0]}'")
            elif op in ("if", "ifnot"):
                m = re.match(r"@if(?:not)?\s+(\S+)\s*->\s*(\S+)", L)
                if not m: err(sid, f"line {n}: bad if syntax")
                elif m.group(2) not in labels: err(sid, f"line {n}: if to missing label '{m.group(2)}'")
            elif op not in {"bg","music","sfx","show","expr","hide","label","jump","end","choice","flag","if","ifnot","clue","skill","convince","wait","flash","shake","card","intro","shout","minigame","textbox","emit"}:
                err(sid, f"line {n}: unknown command @{op}")
        elif L.startswith(">"):
            m = re.match(r">\s*(.*?)\s*->\s*(\S+)\s*$", L)
            if m and m.group(2) not in labels: err(sid, f"line {n}: choice to missing label '{m.group(2)}'")
        else:
            m = re.match(r"^([A-Za-z_]+)(\[([a-z_]+)\])?\s*:", L)
            if m:
                head = m.group(1).lower()
                if head in HEADS:
                    if m.group(3) and m.group(3) not in EXPR: err(sid, f"line {n}: unknown expr '{m.group(3)}'")
                    body = L[m.end():].strip()
                    if head == "think" and body.startswith("(") and body.endswith(")"): warn(sid, f"line {n}: think line has its own parentheses")
                elif len(head) < 12:
                    warn(sid, f"line {n}: '{m.group(1)}:' is not a speaker id - shown as narration")
            if len(L) > 170: warn(sid, f"line {n}: long line ({len(L)} chars)")

# clue coverage
given = set()
for t in allscripts.values():
    given |= set(re.findall(r"^\s*@clue\s+(\S+)", t, re.M))
for c in sorted(CLUES - given):
    err("clues", f"clue '{c}' is never given by any script")
for c, s in by_char.items():
    t = allscripts.get(f"hangout_{c}", "")
    if f"@skill {s}" not in t:
        err(f"hangout_{c}", f"does not grant @skill {s}")
trial = allscripts.get("trial", "")
for t in sorted(TRIAL):
    if f"@minigame {t}" not in trial:
        err("trial", f"minigame '{t}' not used in trial script")

total_lines = sum(len([l for l in t.split("\n") if l.strip()]) for t in allscripts.values())
print(f"{len(allscripts)} scripts, {total_lines} lines; bgs={len(BGS)} music={len(MUSIC)} sfx={len(SFX)}")
for w in warns[:60]: print("WARN ", w)
if len(warns) > 60: print(f"... {len(warns)-60} more warnings")
for e in errors: print("ERROR", e)
print(f"{len(errors)} errors, {len(warns)} warnings")
sys.exit(1 if errors else 0)

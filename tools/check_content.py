#!/usr/bin/env python3
"""Cross-checks all story scripts against art, audio, cast, clues, skills, minigames and labels,
for every chapter (1: story_daily/story_case/trial_data/investigation_data, 2 and 3: the *2 and *3 files).
Which story scripts a chapter needs comes from its step order in scripts/data/chapters.gd.
Usage: python3 tools/check_content.py   (exit code 1 if errors)"""
import ast, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def rd(p): return open(os.path.join(ROOT, p), encoding="utf-8").read()
def ex(p): return os.path.exists(os.path.join(ROOT, p))

def scripts_from(path):
    if not ex(path):
        return {}
    src = rd(path)
    return {m.group(1): m.group(2) for m in re.finditer(r'"([a-z0-9_]+)":\s*"""(.*?)"""', src, re.S)}

cast_src = rd("scripts/data/cast.gd")
CAST = set(re.findall(r'^\t"([a-z]+)":\s*\{"name"', cast_src, re.M))
NAMES = dict(re.findall(r'^\t"([a-z]+)":\s*\{"name":\s*"([^"]+)"', cast_src, re.M))
ROSTER = set(re.findall(r'"([a-z]+)"', re.search(r'const ROSTER := \[(.*?)\]', cast_src, re.S).group(1)))
EXPR = {"normal", "happy", "shock", "angry", "sad"}
clue_src = rd("scripts/data/clues.gd")
ALL_CLUES = set(re.findall(r'^\t"([a-z0-9_]+)": \{\n\t\t"name"', clue_src, re.M))
def clue_list(name):
    m = re.search(name + r' := \[(.*?)\]', clue_src, re.S)
    return set(re.findall(r'"([a-z0-9_]+)"', m.group(1))) if m else set()
main_src = rd("scripts/core/main.gd")
STORY_STEPS = set(re.findall(r'"([a-z0-9_]+)"', re.search(r'const STORY_STEPS := \[(.*?)\]', main_src, re.S).group(1)))
_ft = re.search(r'const FREETIME_STEPS := \[(.*?)\]', main_src, re.S)
FREETIME_STEPS = set(re.findall(r'"([a-z0-9_]+)"', _ft.group(1))) if _ft else {"freetime"}   # all played by the free-time screen
SCREENS = dict(re.findall(r'^\t"([a-z0-9_]+)": "res://([^"]+)"', re.search(r'const SCREENS := \{(.*?)^\}', main_src, re.S | re.M).group(1), re.M))
chapters_src = rd("scripts/data/chapters.gd")
def chapter_block(ch):
    return re.search(r'^\t%d: \{\n(.*?)^\t\},' % ch, chapters_src, re.S | re.M).group(1)
def chapter_steps(block):
    return set(re.findall(r'"([a-z0-9_]+)"', re.search(r'"next": \{(.*?)\n\t\t\}', block, re.S).group(1)))
SKILLS = set(re.findall(r'^\t"([a-z_]+)": \{"name"', rd("scripts/data/skills.gd"), re.M))
by_char_all = dict(re.findall(r'"([a-z]+)": "([a-z_]+)"', rd("scripts/data/skills.gd").split("const SKILLS")[0]))
BGS = {f[:-4] for f in os.listdir(os.path.join(ROOT, "art/bg")) if f.endswith(".svg")}
MUSIC = {os.path.splitext(f)[0] for f in os.listdir(os.path.join(ROOT, "audio/music")) if f.endswith((".wav", ".ogg"))}
SFX = {os.path.splitext(f)[0] for f in os.listdir(os.path.join(ROOT, "audio/sfx")) if f.endswith((".wav", ".ogg"))}
POS = {"farleft", "left", "center", "right", "farright"}

# Logbook rules live in scripts/data/log_rules.gd, so the game and this checker read the same list.
log_src = rd("scripts/data/log_rules.gd")
def gd_str(s): return s.replace('\\\\', '\\')
def log_list(name):
    body = re.search(r'const %s := \[(.*?)\]\s*$' % name, log_src, re.S | re.M).group(1)
    return [gd_str(x) for x in re.findall(r'"((?:[^"\\]|\\.)*)"', "\n".join(l for l in body.split("\n") if not l.strip().startswith("#")))]
def log_const(name):
    return gd_str(re.search(r'const %s := "((?:[^"\\]|\\.)*)"' % name, log_src).group(1))
LOG_WRITTEN = set(log_list("WRITTEN"))
# Animated scenes live in scripts/data/anim_scenes.gd as plain data, read here with a small GDScript literal reader.
def gd_literal(src, name):
    """Value of `const NAME := <literal>` (dicts, arrays, strings, numbers, bools) in a GDScript source."""
    m = re.search(r"^const %s\s*:?=\s*" % re.escape(name), src, re.M)
    if not m:
        return None
    out, depth, q, i, text = [], 0, None, m.end(), src
    while i < len(text):
        c = text[i]
        if q:
            out.append(c)
            if c == "\\":
                out.append(text[i + 1]); i += 2; continue
            if c == q:
                q = None
        elif c == '"':
            q = c; out.append(c)
        elif c == "#":
            while i < len(text) and text[i] != "\n":
                i += 1
            continue
        else:
            out.append(c)
            if c in "[{(":
                depth += 1
            elif c in "]})":
                depth -= 1
                if depth == 0:
                    break
            elif c == "\n" and depth == 0:
                break
        i += 1
    expr = "".join(out)
    expr = re.sub(r"\btrue\b", "True", re.sub(r"\bfalse\b", "False", expr))
    return ast.literal_eval(expr)

anim_src = rd("scripts/data/anim_scenes.gd") if ex("scripts/data/anim_scenes.gd") else ""
ANIM = gd_literal(anim_src, "DATA") or {}
ANIM_FORMATS = gd_literal(anim_src, "FORMATS") or {}
ANIM_KINDS = gd_literal(anim_src, "KINDS") or {}
ANIM_FIXTURES = set(gd_literal(anim_src, "FIXTURES") or [])
ANIM_EASES = {"linear", "sine", "out", "in", "expo", "back", "expo_in"}
ANIM_LAYERS = {"far", "back", "mid", "front", "over", "top"}
ANIM_COLS = {"aqua", "gold", "yuzu", "danger", "violet", "good", "ink", "white"}
ANIM_MAKES = {"actor", "glow", "panel", "slam", "title", "badge", "pop", "price"}
ANIM_USES = {"move", "expr", "hop", "shudder", "out", "slab"}
PROPS = {f[:-4] for f in os.listdir(os.path.join(ROOT, "art/props")) if f.endswith(".svg")}

LOG_BANNED = log_list("BANNED")
LOG_MAX_LEN = 170
HEADS = CAST | {"narr", "think", "voice", "all"}

errors, warns = [], []
def err(s, m): errors.append(f"[ch{CH}:{s}] {m}")
def warn(s, m): warns.append(f"[ch{CH}:{s}] {m}")

def log_words(sid, n, text):
    """The Logbook never flags, connects or counts, and speaks as Mochi. Reports the rule and line, not the words."""
    for pat in LOG_BANNED:
        if re.search(pat, text, re.I):
            err(sid, f"line {n}: Logbook text breaks a writing rule (/{pat}/, see log_rules.gd)")
    if len(text) > LOG_MAX_LEN:
        err(sid, f"line {n}: Logbook text is too long ({len(text)} chars, max {LOG_MAX_LEN})")

def parse_log(rest):
    """Same grammar as LogRules.parse in log_rules.gd. Returns (sec, who, id, clock, text) or None."""
    m = re.match(r"(\S+)\s+(.*)$", rest)
    if not m: return None
    sec, text = m.group(1), m.group(2).strip()
    who = entry_id = clock = ""
    if sec == "strike": return (sec, who, text, clock, "")
    if sec not in LOG_WRITTEN or not text: return None
    if sec == "people":
        m = re.match(r"(\S+)\s+(.*)$", text)
        if not m: return None
        who, text = m.group(1), m.group(2).strip()
    elif sec == "trial" and text.startswith("#"):
        m = re.match(r"#(\S+)\s+(.*)$", text)
        if not m: return None
        entry_id, text = m.group(1), m.group(2).strip()
    if " | " in text:
        clock, text = (x.strip() for x in text.split(" | ", 1))
    return (sec, who, entry_id, clock, text)

def median(xs):
    xs = sorted(xs)
    return xs[len(xs) // 2] if xs else 0

def log_balance(culprit, living, entries):
    """No guest may stand out in the Logbook, the culprit least of all. Messages stay spoiler-free: they never name anyone."""
    people = [e for e in entries if e[0] == "people"]
    if not people:
        return
    def stands_out(what, per_guest, tol):
        others = [v for g, v in per_guest.items() if g != culprit]
        typical = median(others)
        if culprit in per_guest and abs(per_guest[culprit] - typical) > tol(typical):
            err("log", f"a guest's {what} stands out from the rest (typical {typical:g}, range {min(others):g} to {max(others):g}); rebalance before release")
    number = {g: sum(1 for e in people if e[1] == g) for g in living}
    stands_out("People entry count", number, lambda t: max(2, round(t * 0.34)))
    said = {g: [e for e in people if e[1] == g] for g in living if number[g]}
    if len(said) > 1 and culprit in said:
        stands_out("average People entry length", {g: sum(len(e[4].split()) for e in es) / len(es) for g, es in said.items()}, lambda t: max(4, t * 0.5))
        stands_out("share of People entries with a time on them", {g: sum(1 for e in es if e[3]) / len(es) for g, es in said.items()}, lambda t: 0.4)
    timeline = [e for e in entries if e[0] == "timeline"]
    if timeline:
        mentions = {g: sum(1 for e in timeline if re.search(r"\b%s\b" % re.escape(NAMES.get(g, g)), e[4], re.I)) for g in living}
        stands_out("count of Timeline mentions", mentions, lambda t: max(2, round(t * 0.5)))

CHAPTERS = {
    1: {"files": ["scripts/data/story/story_daily.gd", "scripts/data/story/story_case.gd"],
        "trial": "scripts/data/trial_data.gd", "inv": "scripts/data/investigation_data.gd",
        "clues": ["ORDER"], "gone": set(), "victim": "coco"},
    2: {"files": ["scripts/data/story/story_daily2.gd", "scripts/data/story/story_case2.gd"],
        "trial": "scripts/data/trial_data2.gd", "inv": "scripts/data/investigation_data2.gd",
        "clues": ["ORDER2"], "gone": {"coco", "wisp"}, "victim": "marigold"},
    3: {"files": ["scripts/data/story/story_daily3.gd", "scripts/data/story/story_case3.gd", "scripts/data/story/story_end3.gd"],
        "trial": "scripts/data/trial_data3.gd", "inv": "scripts/data/investigation_data3.gd",
        "clues": ["ORDER3", "OPTIONAL3", "TRIAL3", "STORY3"], "gone": {"coco", "wisp", "marigold", "tumble"}, "victim": "nibs",
        # minigames the daily story plays outside the trial (trial_data_index.gd STORY_PATHS)
        "story_trial": "scripts/data/story_minigames3.gd"},
}
total_scripts = total_lines = 0
anim_used = set()

def anim_chars(scene):
    return {str(b[2].get("char")) for b in scene.get("beats", []) if len(b) > 2 and isinstance(b[2], dict) and b[2].get("char")}

CH = 0
for step, path in sorted(SCREENS.items()):
    if not ex(path):
        err("screens", f"screen '{step}' script is missing: {path}")
for CH, cfg in CHAPTERS.items():
    tables = [scripts_from(f) for f in cfg["files"]]
    if not any(tables):
        warn("files", "no story files yet - chapter skipped")
        continue
    allscripts, dups = {}, set()
    for t in tables:
        dups |= set(allscripts) & set(t)
        allscripts.update(t)
    CLUES = set().union(*(clue_list(n) for n in cfg["clues"]))
    TRIAL = set(re.findall(r'^\t"([a-z0-9_]+)": \{\n\t\t"type"', rd(cfg["trial"]), re.M)) if ex(cfg["trial"]) else set()
    st_path = cfg.get("story_trial", "")
    STORY_TRIAL = set(re.findall(r'^\t"([a-z0-9_]+)": \{\n\t\t"type"', rd(st_path), re.M)) if st_path and ex(st_path) else set()
    INV_SCRIPTS = set(re.findall(r'"(?:script|enter_script)": "([a-z0-9_]+)"', rd(cfg["inv"])))
    by_char = {c: s for c, s in by_char_all.items() if c not in cfg["gone"]}
    block = chapter_block(CH)
    log_seen, log_ids, log_struck = [], set(), set()
    steps = chapter_steps(block)
    for s in sorted(steps - STORY_STEPS - set(SCREENS) - FREETIME_STEPS):
        err("steps", f"step '{s}' is neither a story step (main.gd STORY_STEPS) nor a screen (main.gd SCREENS or FREETIME_STEPS)")
    for key in ("execution", "investigation", "rooms3d"):
        m = re.search(r'"%s": "res://([^"]+)"' % key, block)
        if not m or not ex(m.group(1)):
            err("files", f"chapters.gd '{key}' is missing or points to a file that does not exist")
    m = re.search(r'"gameover": "res://([^"]+)"', block)
    if m and not ex(m.group(1)):
        err("files", "chapters.gd 'gameover' points to a file that does not exist")
    m = re.search(r'"after_vote": "([a-z0-9_]+)"', block)
    if m and m.group(1) not in steps:
        err("steps", f"after_vote '{m.group(1)}' is not in the step order")
    first = re.search(r'"first_step": "([a-z0-9_]+)"', block).group(1)
    if first not in steps:
        err("steps", f"first_step '{first}' is not in the step order")
    required = (steps & STORY_STEPS) | {"freetime_intro", "investigation_start", "investigation_complete", "trial"}
    required |= {f"hangout_{c}" for c in by_char}
    required |= INV_SCRIPTS
    for r in sorted(required - set(allscripts)):
        err("missing", f"script id '{r}' is not defined")
    for d in sorted(dups):
        err("dup", f"script id '{d}' defined in more than one story file")
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
                elif op == "minigame" and args and args[0] not in TRIAL | STORY_TRIAL: err(sid, f"line {n}: unknown minigame '{args[0]}'")
                elif op == "jump" and args and args[0] not in labels: err(sid, f"line {n}: jump to missing label '{args[0]}'")
                elif op in ("if", "ifnot"):
                    m = re.match(r"@if(?:not)?\s+(\S+)\s*->\s*(\S+)", L)
                    if not m: err(sid, f"line {n}: bad if syntax")
                    elif m.group(2) not in labels: err(sid, f"line {n}: if to missing label '{m.group(2)}'")
                elif op == "log":
                    p = parse_log(L[4:].strip())
                    if p is None:
                        err(sid, f"line {n}: bad @log line (see log_rules.gd for the sections and forms)")
                    elif p[0] == "strike":
                        log_struck.add((sid, n, p[2]))
                    else:
                        log_seen.append(p)
                        if p[2]: log_ids.add(p[2])
                        log_words(sid, n, p[4])
                        if p[0] == "people" and (p[1] not in ROSTER or p[1] == "mochi" or p[1] in cfg["gone"]):
                            err(sid, f"line {n}: @log people has an unknown or absent guest")
                elif op == "evening":
                    if len(parts) > 1: log_words(sid, n, L[8:].strip())
                elif op == "anim":
                    if not args: err(sid, f"line {n}: @anim needs a scene id")
                    elif args[0] not in ANIM or args[0] in ANIM_FIXTURES: err(sid, f"line {n}: unknown @anim scene '{args[0]}' (scripts/data/anim_scenes.gd)")
                    else:
                        anim_used.add(args[0])
                        if anim_chars(ANIM[args[0]]) & set(cfg["gone"]):
                            warn(sid, f"line {n}: @anim {args[0]} shows a guest who is gone by this chapter (fine for a flashback)")
                elif op not in {"bg","music","sfx","show","expr","hide","label","jump","end","choice","flag","if","ifnot","clue","skill","convince","wait","flash","shake","card","intro","shout","minigame","textbox","emit","alibi","checkpoint","log","evening","anim"}:
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
    for t in sorted(STORY_TRIAL):
        if not any(f"@minigame {t}" in x for x in allscripts.values()):
            err("story", f"story minigame '{t}' is not used in any script")
        if t in TRIAL:
            err("story", f"story minigame '{t}' has the same id as a trial minigame")

    for sid, n, entry_id in sorted(log_struck):
        if entry_id not in log_ids:
            err(sid, f"line {n}: @log strike has no matching '@log trial #{entry_id} ...' in this chapter")
    living = (ROSTER - set(cfg["gone"])) - {"mochi"}
    log_balance(re.search(r'"culprit": "([a-z]+)"', block).group(1), living, log_seen)

    total_scripts += len(allscripts)
    total_lines += sum(len([l for l in t.split("\n") if l.strip()]) for t in allscripts.values())

# animated scenes: every beat well-formed, every asset there, ids made before they are used
CH = 0
def anim_col(c):
    return isinstance(c, str) and (c in CAST or c in ANIM_COLS or re.fullmatch(r"#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?", c))

def check_anim(aid, sc):
    where = f"anim:{aid}"
    fmt = ANIM_FORMATS.get(sc.get("format"))
    if fmt is None:
        err(where, f"unknown format '{sc.get('format')}'")
        return
    length = sc.get("length", 0)
    if not isinstance(length, (int, float)) or not fmt["min"] <= length <= fmt["max"]:
        err(where, f"length {length} s is outside the {sc['format']} range ({fmt['min']:g} to {fmt['max']:g} s)")
    if sc.get("in", "wipe") not in ("wipe", "cut", "tv") or sc.get("out", "wipe") not in ("wipe", "cut", "tv", "jaw"):
        err(where, "\"in\" must be wipe, cut or tv and \"out\" wipe, cut, tv or jaw")
    if "music" in sc and sc["music"] not in MUSIC:
        err(where, f"unknown music '{sc['music']}'")
    made, last = set(), -1.0
    for i, b in enumerate(sc.get("beats", [])):
        at = f"beat {i + 1}"
        if not isinstance(b, list) or len(b) not in (2, 3) or not isinstance(b[0], (int, float)) or not isinstance(b[1], str):
            err(where, f"{at}: a beat is [time, kind, {{args}}]")
            continue
        t, kind, a = b[0], b[1], (b[2] if len(b) > 2 else {})
        if not isinstance(a, dict):
            err(where, f"{at}: args must be a dictionary"); continue
        if t < last:
            err(where, f"{at}: beats must be in time order ({t} after {last})")
        last = t
        if not 0 <= t <= length:
            err(where, f"{at}: time {t} is outside the scene (0 to {length})")
        if kind not in ANIM_KINDS:
            err(where, f"{at}: unknown beat kind '{kind}'"); continue
        for k in ANIM_KINDS[kind]:
            if k not in a:
                err(where, f"{at}: {kind} needs \"{k}\"")
        bid = a.get("id")
        if kind in ANIM_MAKES and isinstance(bid, str):
            if bid.startswith("_"):
                err(where, f"{at}: ids starting with _ are reserved")
            made.add(bid)
        elif kind in ANIM_USES and bid not in made:
            err(where, f"{at}: {kind} uses id '{bid}' before any beat makes it")
        if kind == "clear":
            made.clear()
        if "char" in a and a["char"] not in CAST:
            err(where, f"{at}: unknown char '{a['char']}'")
        if "expr" in a and a["expr"] not in EXPR:
            err(where, f"{at}: unknown expr '{a['expr']}'")
        if "art" in a and a["art"] not in BGS | PROPS:
            err(where, f"{at}: art '{a['art']}' is in neither art/bg nor art/props")
        if kind == "sfx" or (kind in ("hit", "slam", "title", "price") and "sfx" in a):
            sid_ = a["id"] if kind == "sfx" else a["sfx"]
            if sid_ not in SFX: err(where, f"{at}: unknown sfx '{sid_}'")
        if kind == "music" and a["id"] not in MUSIC | {"stop"}:
            err(where, f"{at}: unknown music '{a['id']}'")
        if "ease" in a and a["ease"] not in ANIM_EASES:
            err(where, f"{at}: unknown ease '{a['ease']}'")
        if "layer" in a and a["layer"] not in ANIM_LAYERS:
            err(where, f"{at}: unknown layer '{a['layer']}'")
        for ck in ("col", "edge", "plate_col", "line_col", "tint", "sil"):
            if ck in a and not anim_col(a[ck]):
                err(where, f"{at}: bad colour '{a[ck]}' in \"{ck}\"")
        for c in a.get("cols", []):
            if not anim_col(c): err(where, f"{at}: bad colour '{c}' in \"cols\"")
        points = {"at"} | {"move": {"to"}, "actor": {"from"}, "hit": {"lines"}, "blade": {"a", "b"}}.get(kind, set())
        for pk in sorted(points & set(a)):
            if not (isinstance(a[pk], list) and len(a[pk]) == 2 and all(isinstance(v, (int, float)) for v in a[pk])):
                err(where, f"{at}: \"{pk}\" must be [x, y]")
        if kind == "panel" and a.get("from", "left") not in ("left", "right", "top", "bottom"):
            err(where, f"{at}: panel \"from\" must be left, right, top or bottom")
        if kind == "panel" and not (isinstance(a.get("rect"), list) and len(a["rect"]) == 4):
            err(where, f"{at}: panel \"rect\" must be [x, y, w, h]")
        for tk in ("text", "title", "sub", "small", "yell", "line", "was", "now", "tag", "tab"):
            if isinstance(a.get(tk), str) and "\\" in a[tk]:
                err(where, f"{at}: backslash in \"{tk}\"")
        if kind == "say":
            if a.get("who", "narr") not in HEADS:
                err(where, f"{at}: unknown speaker '{a.get('who')}'")
            text = str(a.get("text", ""))
            if len(text) > 110:
                err(where, f"{at}: caption too long ({len(text)} chars, max 110)")
            if "dur" in a and a["dur"] < len(text) / 22.0:
                warn(where, f"{at}: caption is on screen too briefly to read ({a['dur']} s for {len(text)} chars)")

for aid, sc in sorted(ANIM.items()):
    check_anim(aid, sc)
unplaced = sorted(set(ANIM) - anim_used - ANIM_FIXTURES)
if unplaced:
    warn("anim", f"{len(unplaced)} animated scenes are not placed in any story yet: {', '.join(unplaced)}")

# the entries the game writes by itself have to obey the same rules as the story's
CH = 0
for name in ("PLACE_LINES", "THING_LINES"):
    for line in log_list(name):
        if "%s" not in line: err("log_rules", f"{name}: every line needs a %s for the name")
        log_words("log_rules", name, line)
for name in ("EVENING_PROMPT", "EVENING_OPEN", "EVENING_SKIP"):
    log_words("log_rules", name, log_const(name))

print(f"{total_scripts} scripts, {total_lines} lines; bgs={len(BGS)} music={len(MUSIC)} sfx={len(SFX)} anim scenes={len(ANIM)}")
for w in warns[:60]: print("WARN ", w)
if len(warns) > 60: print(f"... {len(warns)-60} more warnings")
for e in errors: print("ERROR", e)
print(f"{len(errors)} errors, {len(warns)} warnings")
sys.exit(1 if errors else 0)

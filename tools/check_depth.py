#!/usr/bin/env python3
"""Checks the rules that keep a case fair and hard: everyone is considered, nothing gives the killer away, and the
trial's numbers work out. Reads the same data files the game does.

Usage: python3 tools/check_depth.py   (exit code 1 if errors)

Two kinds of rule:
  Always errors: the data must be well-formed whatever state a case is in (difficulty keys, the shape of every trial
    segment, picture files, alibi wording, stage triggers, a strong run reaching the vote, and a careful run reaching
    it from every mid-trial @checkpoint at the least convince a Retry can come back with).
  Depth rules: every guest has an alibi, a motive, a room and trial lines; no give-away labels; balanced evidence and
    attention; a careless run really fails. These are warnings until a chapter sets "depth_checked": true in
    chapters.gd, after which they are errors. Cases 1 and 2 get there in Package 5, Case 3 in Packages 9 and 10.

Output stays spoiler-free: it says what kind of thing is wrong and for which chapter, never who the killer is.
Add --names to see the guests and Truth Drops involved (spoilers)."""
import ast, os, re, statistics, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOW_NAMES = "--names" in sys.argv


def rd(p): return open(os.path.join(ROOT, p), encoding="utf-8").read()
def ex(p): return os.path.exists(os.path.join(ROOT, p))


def strip_comments(src):
    """Removes GDScript # comments, leaving # inside strings alone."""
    out, i, n, q = [], 0, len(src), None
    while i < n:
        c = src[i]
        if q:
            out.append(c)
            if c == "\\":
                out.append(src[i + 1]); i += 2; continue
            if src.startswith(q, i):
                out.extend(q[1:]); i += len(q); q = None; continue
        elif src.startswith('"""', i):
            out.append('"""'); q = '"""'; i += 3; continue
        elif c == '"':
            out.append(c); q = '"'
        elif c == "#":
            while i < n and src[i] != "\n":
                i += 1
            continue
        else:
            out.append(c)
        i += 1
    return "".join(out)


def gd_const(src, name, default=None):
    """Value of `const NAME := <literal>` in a GDScript source, or default."""
    m = re.search(r"^const %s\s*:?=\s*" % re.escape(name), src, re.M)
    if not m:
        return default
    text = strip_comments(src[m.end():])
    depth, end, q = 0, None, False
    i = 0
    while i < len(text):
        c = text[i]
        if q:
            if c == "\\":
                i += 1
            elif c == '"':
                q = False
        elif c == '"':
            q = True
        elif c in "[{(":
            depth += 1
        elif c in "]})":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
        elif c == "\n" and depth == 0:
            end = i
            break
        i += 1
    expr = text[:end]
    expr = re.sub(r"\btrue\b", "True", expr)
    expr = re.sub(r"\bfalse\b", "False", expr)
    expr = re.sub(r"\bnull\b", "None", expr)
    return ast.literal_eval(expr)


def scripts_from(path):
    if not ex(path):
        return {}
    return {m.group(1): m.group(2) for m in re.finditer(r'"([a-z0-9_]+)":\s*"""(.*?)"""', rd(path), re.S)}


game_src = rd("scripts/core/game.gd")
NUM = dict((k, float(v)) for k, v in re.findall(r"^const ((?:REWARD|PENALTY)_[A-Z_]+|BASE_CONVINCE|MISSING_COST)\s*:=\s*([0-9.]+)", game_src, re.M))
CH_DATA = gd_const(rd("scripts/data/chapters.gd"), "CH")
LAST = max(CH_DATA)
clue_src = rd("scripts/data/clues.gd")
CLUES = gd_const(clue_src, "CLUES")
ORDER = {1: gd_const(clue_src, "ORDER"), 2: gd_const(clue_src, "ORDER2"), 3: gd_const(clue_src, "ORDER3")}
OPTIONAL = {3: gd_const(clue_src, "OPTIONAL3", [])}
# handed over in the trial (clues.gd TRIAL3): part of the case's evidence, never found in the investigation
TRIAL_GIVEN = {3: gd_const(clue_src, "TRIAL3", [])}
cast_src = rd("scripts/data/cast.gd")
CHARS = dict(re.findall(r'^\t"([a-z]+)":\s*\{"name": "([^"]+)"', cast_src, re.M))
GUESTS = [c for c in gd_const(cast_src, "ORDER") if c != "mochi"]
alibi_src = rd("scripts/data/alibis.gd")
ALIBI_DATA = gd_const(alibi_src, "DATA", {})
ALIBI_HOURS = gd_const(alibi_src, "HOURS", {})

STORY = {
    1: ("scripts/data/story/story_daily.gd", "scripts/data/story/story_case.gd", "scripts/data/trial_data.gd", "scripts/data/investigation_data.gd"),
    2: ("scripts/data/story/story_daily2.gd", "scripts/data/story/story_case2.gd", "scripts/data/trial_data2.gd", "scripts/data/investigation_data2.gd"),
    3: ("scripts/data/story/story_daily3.gd", "scripts/data/story/story_case3.gd", "scripts/data/trial_data3.gd", "scripts/data/investigation_data3.gd"),
}
# minigames the daily story plays outside the trial (trial_data_index.gd STORY_PATHS): checked for shape, never counted
# in the trial's numbers or its lines
STORY_MINIGAMES = {3: "scripts/data/story_minigames3.gd"}
# Cases 1 and 2 are left exactly as released (the user's decision, plan Part 0): their difficulty is the table's
# "Now" column and the depth rules don't apply to them. Case 3 uses the plan's difficulty table (section 1.4).
RELEASED = {1, 2}
EXPECT = {
    1: {"threshold": 60.0, "penalty_scale": 1.0, "hint_loops": 2, "hint_on_request": False, "ending": "auto"},
    2: {"threshold": 60.0, "penalty_scale": 1.0, "hint_loops": 2, "hint_on_request": False, "ending": "auto"},
    3: {"threshold": 70.0, "penalty_scale": 1.5, "hint_on_request": True, "ending": "choice"},
}
AMMO_MIN = {1: 0, 2: 0, 3: 5}
BANNED = re.compile(r"\b(confirmed|unconfirmed|suspect|suspects|suspicious|verified|cleared|guilty|innocent|solid alibi|airtight)\b", re.I)
PKG = {3: "Packages 9 and 10"}

# animation cadence (plan section 1.6): no more than about 12 minutes of plain walking or dialogue without an
# animated beat (an @anim scene, a minigame or a cutscene screen), estimated from the script order. Reading speed is
# the plan's (section 1.5): 230 words a minute plus half a second a line.
CADENCE_MAX = 12 * 60
WPM = 230.0
LINE_S = 0.5
VISIT_WALK = 30.0        # walking to a guest in Free Time
SPOT_WALK = 20.0         # walking to and looking at one hotspot or guest in the investigation
SCREEN_STEPS = {"drain", "quake", "execution", "caiman_kill"}   # flow steps that are animated cutscenes in their own right
# the case after the vote (confession, endings): not forced-scene attention, since by then the answer is out
ENDING_STEPS = {"confession", "epilogue", "epilogue_after", "caiman_kill"}

errors, warns = [], []
pending_rules = set()


def err(ch, msg): errors.append(f"[ch{ch}] {msg}")
def warn(ch, msg): warns.append(f"[ch{ch}] {msg}")


def depth(ch, rule, msg):
    """A depth rule: an error once the chapter declares itself checked, a warning until then. Released cases are
    left as they are, so the rules don't apply to them."""
    if ch in RELEASED:
        return
    if CH_DATA[ch].get("depth_checked"):
        err(ch, f"{rule}: {msg}")
    else:
        pending_rules.add(rule)
        warn(ch, f"{rule}: {msg} ({PKG[ch]})")


def names(items):
    return " [" + ", ".join(sorted(items)) + "]" if SHOW_NAMES and items else ""


def spoken(text):
    """Speaker -> line count in a story script."""
    out = {}
    for line in text.split("\n"):
        m = re.match(r"\s*([a-z]+)(\[[a-z]+\])?\s*:", line)
        if m and m.group(1) in CHARS:
            out[m.group(1)] = out.get(m.group(1), 0) + 1
    return out


def clue_given(text):
    return set(re.findall(r"^\s*@clue\s+(\S+)", text, re.M))


# ------------------------------------------------------------------ animation cadence
def plain_segments(text):
    """Seconds of plain reading between animated beats in one story script, along the path autotest takes (first
    choice, @if never taken). Returns [before the first beat, between beats..., after the last]."""
    lines = text.split("\n")
    cmds, labels, i = [], {}, 0
    while i < len(lines):
        L = lines[i].strip()
        i += 1
        if not L or L.startswith("#"):
            continue
        if L.startswith("@"):
            op = L[1:].split()[0].lower() if len(L) > 1 else ""
            rest = L[1 + len(op):].strip()
            if op == "label":
                labels[rest] = len(cmds)
            elif op == "choice":
                opts = []
                while i < len(lines) and lines[i].strip().startswith(">"):
                    m = re.search(r"->\s*(\S+)\s*$", lines[i].strip())
                    opts.append(m.group(1) if m else "")
                    i += 1
                cmds.append(("choice", opts))
            else:
                cmds.append((op, rest))
        elif not L.startswith(">"):
            cmds.append(("say", L))
    segs, pc, seen = [0.0], 0, set()
    while pc < len(cmds) and pc not in seen:
        seen.add(pc)
        op, arg = cmds[pc]
        pc += 1
        if op == "say":
            m = re.match(r"^[A-Za-z_]+(\[[a-z_]+\])?\s*:", arg)
            body = arg[m.end():] if m else arg
            segs[-1] += len(body.split()) / WPM * 60.0 + LINE_S
        elif op in ("anim", "minigame"):
            segs.append(0.0)
        elif op == "jump":
            pc = labels.get(arg, pc)
        elif op == "choice":
            segs[-1] += 2.0
            if arg and arg[0]:
                pc = labels.get(arg[0], pc)
        elif op == "wait":
            segs[-1] += float(arg) if re.fullmatch(r"[0-9.]+", arg or "") else 1.0
        elif op in ("card", "intro", "shout", "clue", "skill"):
            segs[-1] += 1.5
        elif op == "end":
            break
    return segs


def flow_order(info):
    out, step = [], info["first_step"]
    while step and step not in out:
        out.append(step)
        step = info["next"].get(step) or (info.get("after_vote", "execution") if step == "trial" else "")
    return out


def cadence(ch, info, allscripts, rooms, stages, finds):
    """Walks the case in flow order and reports every stretch of plain play longer than CADENCE_MAX."""
    state = {"plain": 0.0, "since": info["first_step"], "longest": 0.0}
    long_runs = []

    def feed(segs, step):
        state["plain"] += segs[0]
        for seg in segs[1:]:
            beat(step)
            state["plain"] += seg

    def beat(step):
        state["longest"] = max(state["longest"], state["plain"])
        if state["plain"] > CADENCE_MAX:
            long_runs.append((state["plain"], state["since"], step))
        state["plain"], state["since"] = 0.0, step

    def total(sid):
        return sum(plain_segments(allscripts.get(sid, "")))

    for step in flow_order(info):
        if step in SCREEN_STEPS:
            beat(step)
        elif re.fullmatch(r"freetime\d*", step):
            slots = info.get("freetime_slots", 3)
            slots = int(slots.get(step, 3)) if isinstance(slots, dict) else int(slots)
            visits = sorted((total(k) for k in allscripts if k.startswith("hangout_")), reverse=True)[:slots]
            feed(plain_segments(allscripts.get("freetime_intro", "")), step)
            for v in visits:
                feed([v + VISIT_WALK], step)
            feed(plain_segments(allscripts.get("freetime_outro", "")), step)
        elif step == "investigation":
            spots = [h.get("script", "") for r in rooms.values() for h in r.get("hotspots", []) + r.get("people", [])]
            share = (sum(total(sc) for sc in spots) + SPOT_WALK * len(spots)) / max(finds, 1)
            feed(plain_segments(allscripts.get("investigation_start", "")), step)
            done = 0
            for st in stages:
                feed([share * max(st.get("after", 0) - done, 0)], step)
                done = max(done, st.get("after", 0))
                feed(plain_segments(allscripts.get(st.get("script", ""), "")), step)
            feed([share * max(finds - done, 0)], step)
            feed(plain_segments(allscripts.get("investigation_complete", "")), step)
        else:
            feed(plain_segments(allscripts.get(step, "")), step)
    beat("the end")
    print(f"ch{ch}: longest stretch without an animated scene is about {state['longest'] / 60.0:.0f} min (limit {CADENCE_MAX // 60})")
    for secs, a, b in long_runs:
        depth(ch, "animation cadence", f"about {secs / 60.0:.0f} minutes of plain play without an animated scene, from {a} to {b}")


# ------------------------------------------------------------------ one trial segment
def check_segment(ch, sid, d, known_clues, living):
    t = d.get("type")
    if t == "debate":
        drops = d.get("drops", [])
        ans = d.get("answer", {})
        if ans.get("drop") not in drops:
            err(ch, f"{sid}: the answer's Truth Drop is not in the ammo list")
        if len(drops) > 6:
            err(ch, f"{sid}: {len(drops)} Truth Drops loaded, at most 6 fit")
        st = d.get("statements", [])
        if not 0 <= ans.get("statement", 0) < len(st):
            err(ch, f"{sid}: answer statement out of range")
        else:
            weak = re.findall(r"\{[^}]*\}", st[ans.get("statement", 0)].get("text", ""))
            if ans.get("weak", 0) >= len(weak):
                err(ch, f"{sid}: answer weak spot out of range")
        for c in drops:
            if c not in CLUES:
                err(ch, f"{sid}: unknown Truth Drop in ammo")
    elif t == "present":
        a = d.get("answer")
        for c in (a if isinstance(a, list) else [a]):
            if c not in known_clues:
                err(ch, f"{sid}: answer is not one of this chapter's Truth Drops")
        if isinstance(a, list) and (len(a) != 2 or a[0] == a[1]):
            err(ch, f"{sid}: a two-part present needs two different Truth Drops")
    elif t == "character":
        ans = d.get("answers", [d.get("answer")])
        for g in ans:
            if g not in CHARS:
                err(ch, f"{sid}: answer is not a character")
        if "answers" in d and len(set(ans)) < 2:
            err(ch, f"{sid}: \"answers\" is for several guests")
    elif t == "choice":
        opts = d.get("options", [])
        if not d.get("free") and not 0 <= int(d.get("answer", 0)) < len(opts):
            err(ch, f"{sid}: answer out of range")
        if "vote_option" in d and (d["vote_option"] == d.get("answer") or not 0 <= d["vote_option"] < len(opts)):
            err(ch, f"{sid}: vote_option must be a real option other than the answer")
    elif t == "roll_call":
        if not d.get("entries"):
            err(ch, f"{sid}: no entries")
        # the cards on offer are everyone still alive at the trial (Mochi too) except the guest speaking, plus Nobody
        at_trial = set(living) | {"mochi"}
        for e in d.get("entries", []):
            guest = e.get("guest")
            if guest not in CHARS:
                err(ch, f"{sid}: entry for an unknown guest")
            elif guest not in at_trial:
                err(ch, f"{sid}: entry for a guest who is not alive at this trial")
            a = e.get("answer", "nobody")
            for g in (a if isinstance(a, list) else [a]):
                if g == "nobody":
                    continue
                if g not in CHARS:
                    err(ch, f"{sid}: entry answer is not a guest or \"nobody\"")
                elif g not in at_trial:
                    err(ch, f"{sid}: entry answer names a guest who is not alive at this trial, so it can never be picked")
                elif g == guest:
                    err(ch, f"{sid}: entry answer is the guest speaking, who is never offered as their own backup")
    elif t == "time_pick":
        def mins(w):
            m = re.match(r"(\d+)(?::(\d+))?\s*([AP])", str(w).upper())
            if not m:
                err(ch, f"{sid}: cannot read the time '{w}'")
                return 0
            h = int(m.group(1)) % 12
            return (h + 12 if m.group(3) == "A" else h) * 60 + int(m.group(2) or 0)
        lo, hi = mins(d.get("from", "6 PM")), mins(d.get("to", "12 AM"))
        a = d.get("answer")
        step = int(d.get("step", 5))
        for w in (a if isinstance(a, list) else [a]):
            v = mins(w)
            if not lo <= v <= hi:
                err(ch, f"{sid}: answer is off the timeline")
            elif (v - lo) % step and not d.get("tolerance"):
                err(ch, f"{sid}: answer cannot be reached in steps of {step} minutes")
        if isinstance(a, list) and len(a) != 2:
            err(ch, f"{sid}: a window needs two times")
    elif t == "rewind":
        for p in d.get("panels", []):
            if p.get("jam"):
                continue
            if not 0 <= int(p.get("answer", 0)) < len(p.get("options", [])):
                err(ch, f"{sid}: panel answer out of range")
    elif t == "evidence":
        imgs = d.get("images", CLUES.get(d.get("clue", ""), {}).get("images", []))
        if not imgs:
            err(ch, f"{sid}: has no pictures to pick from")
        for a in d.get("answers", []):
            if not 0 <= a < len(imgs):
                err(ch, f"{sid}: picture answer out of range")
        if not d.get("answers"):
            err(ch, f"{sid}: no answers")
    # "early" answers are Truth Drops only: their flag belongs to no segment, so an option number or a guest would pay
    # the bonus on some unrelated later answer (Game.note_early ignores anything else)
    if d.get("early") and t not in ("present", "debate", "rebuttal"):
        err(ch, f"{sid}: only a segment that takes a Truth Drop (present, debate, rebuttal) can list early answers")
    for c in d.get("early", {}):
        if c not in CLUES:
            err(ch, f"{sid}: early list names an unknown Truth Drop")


def reward_of(d, careful):
    """(reward, penalty if the player gets it wrong) for one segment."""
    t = d.get("type")
    if t == "debate":
        return NUM["REWARD_DEBATE"], NUM["PENALTY_DEBATE"]
    if t == "choice":
        if d.get("free"):
            return 0.0, 0.0
        return NUM["REWARD_CHOICE"], NUM["PENALTY_CHOICE"]
    if t in ("present", "character"):
        two = isinstance(d.get("answer"), list) or "answers" in d
        return NUM["REWARD_PAIR"] if two else NUM["REWARD_CHOICE"], NUM["PENALTY_CHOICE"]
    if t == "evidence":
        return NUM["REWARD_PAIR"] if len(d.get("answers", [])) > 1 else NUM["REWARD_CHOICE"], NUM["PENALTY_CHOICE"]
    if t == "bubbles":
        return NUM["REWARD_BUBBLES"], NUM["PENALTY_BUBBLES"]
    if t == "rebuttal":
        n = len(d.get("lines", []))
        return (n * NUM["REWARD_COUNTER"] if careful else 0.0) + NUM["REWARD_REBUTTAL"], NUM["PENALTY_REBUTTAL"] + n * 0.5 * NUM["PENALTY_COUNTER"]
    if t == "rewind":
        panels, jammed = [], False
        for p in d.get("panels", []):
            if p.get("jam"):
                jammed = True
                break
            panels.append(p)
        return len(panels) * NUM["REWARD_REWIND_PANEL"] + (0.0 if jammed else NUM["REWARD_REWIND"]), len(panels) * NUM["PENALTY_REWIND"]
    if t == "roll_call":
        n = len(d.get("entries", []))
        return n * NUM["REWARD_ROLL"], n * NUM["PENALTY_ROLL"]
    if t == "time_pick":
        return NUM["REWARD_TIME"], NUM["PENALTY_TIME"]
    return 0.0, 0.0


def simulate(trial_text, data, scale, careful, start=None):
    v = NUM["BASE_CONVINCE"] if start is None else start
    for m in re.finditer(r"^\s*@(minigame|convince)\s+(\S+)", trial_text, re.M):
        if m.group(1) == "convince":
            v += float(m.group(2).replace("+", ""))
        else:
            d = data.get(m.group(2))
            if d is None:
                continue
            r, p = reward_of(d, careful)
            if not careful:
                v -= p * scale
                v = max(v, 0.0)
            v += r
        v = min(max(v, 0.0), 100.0)
    return v


def check_checkpoints(ch, trial_text, data, scale, threshold, cap):
    """`@checkpoint <label> [floor]`: after a Game Over, Retry and Continue resume at the label with the convince saved
    there, never less than the floor (Game.set_trial_checkpoint). The worst a player can arrive with is therefore the
    floor, so a careful run from the label starting at the floor must still reach the vote."""
    for m in re.finditer(r"^[ \t]*@checkpoint(?:[ \t]+(\S+))?(?:[ \t]+(\S+))?[ \t]*$", trial_text, re.M):
        label, fl = m.group(1), m.group(2)
        if not label:
            err(ch, "a @checkpoint has no label")
            continue
        lm = re.search(r"^[ \t]*@label[ \t]+%s[ \t]*$" % re.escape(label), trial_text, re.M)
        if not lm:
            err(ch, f"@checkpoint {label} has no @label of that name")
            continue
        try:
            floor_v = float(fl) if fl else 0.0
        except ValueError:
            err(ch, f"@checkpoint {label}: the convince floor '{fl}' is not a number")
            continue
        rest = trial_text[lm.end():]
        need = next((v0 for v0 in range(0, 101) if simulate(rest, data, scale, True, float(v0)) >= threshold), None)
        print(f"ch{ch}: checkpoint {label} resumes with at least {floor_v:g} convince; a careful run from there needs {need if need is not None else 'more than 100'}")
        if need is None:
            err(ch, f"after @checkpoint {label} even a careful run from full convince cannot reach the vote ({threshold:.0f})")
        elif floor_v < need:
            err(ch, f"@checkpoint {label}: a Retry that resumes with {floor_v:g} convince can never win; give it a floor of at least {need} (@checkpoint {label} {need})")
        elif simulate(rest, data, scale, True, max(floor_v - cap, 0.0)) < threshold:
            depth(ch, "winnable at the cap", f"after @checkpoint {label} a careful run that still has to pay for missing Truth Drops up to the cap cannot reach the vote")


# ------------------------------------------------------------------ one chapter
for ch in range(1, LAST + 1):
    info = CH_DATA[ch]
    # difficulty keys
    for k, v in EXPECT[ch].items():
        if k not in info:
            err(ch, f"chapters.gd is missing \"{k}\"")
        elif info[k] != v:
            err(ch, f"\"{k}\" is {info[k]}, the difficulty table says {v}")
    if "hint_loops" not in info:
        err(ch, "chapters.gd is missing \"hint_loops\"")
    if info.get("ending") == "choice" and "missing_cap" not in info:
        err(ch, "chapters.gd is missing \"missing_cap\"")
    if info.get("ammo_min", 0) != AMMO_MIN[ch]:
        err(ch, f"\"ammo_min\" should be {AMMO_MIN[ch]}")

    culprit, victim = info["culprit"], info["victim"]
    living = [g for g in GUESTS if g not in info["gone"] and g != victim]
    daily_f, case_f, trial_f, inv_f = STORY[ch]
    daily, case = scripts_from(daily_f), scripts_from(case_f)
    allscripts = {**daily, **case}
    inv_src = rd(inv_f)
    rooms = gd_const(inv_src, "ROOMS", {})
    stages = gd_const(inv_src, "STAGES", [])
    trial_data = gd_const(rd(trial_f), "DATA", {})
    required = list(ORDER[ch])
    optional = list(OPTIONAL.get(ch, []))
    known = set(required) | set(optional) | set(TRIAL_GIVEN.get(ch, []))

    # required and optional Truth Drops
    for c in sorted(set(required) & set(optional)):
        err(ch, "a Truth Drop is listed as both required and optional")
    for c in sorted(set(TRIAL_GIVEN.get(ch, [])) & (set(required) | set(optional))):
        err(ch, "a Truth Drop the trial hands over is also listed as required or optional")
    for c in sorted(known):
        for img in CLUES.get(c, {}).get("images", []):
            art = img.get("art", "")
            paths = [art] if art.startswith("res://") else [f"art/props/{art}.svg", f"art/bg/{art}.svg"]
            if not any(ex(p.replace("res://", "")) for p in paths):
                err(ch, "a Truth Drop picture points to art that does not exist")

    # trial segments
    for sid, d in trial_data.items():
        check_segment(ch, sid, d, known, living)
    if ch in STORY_MINIGAMES and ex(STORY_MINIGAMES[ch]):
        for sid, d in gd_const(rd(STORY_MINIGAMES[ch]), "DATA", {}).items():
            check_segment(ch, sid, d, set(CLUES), living)

    # alibi board
    table = ALIBI_DATA.get(ch, {})
    if ch not in ALIBI_HOURS:
        err(ch, "alibis.gd has no HOURS for this chapter")
    added = set()
    for t in allscripts.values():
        added |= {w.strip() for w in re.findall(r"^\s*@alibi\s+row\s+(.+)$", t, re.M)}
    rows = set(ALIBI_HOURS.get(ch, [])) | added
    for g, e in table.items():
        if g not in CHARS:
            err(ch, "alibis.gd has an entry for an unknown guest")
        text = " ".join([e.get("motive", "")] + [s.get("where", "") + " " + s.get("proof", "") for s in e.get("slots", [])])
        if BANNED.search(text):
            err(ch, "alibis.gd weighs the evidence for the player (words like confirmed or suspect are not allowed)")
        for s in e.get("slots", []):
            if s.get("when") not in rows:
                err(ch, "alibis.gd has a time that is neither an hourly row nor added with @alibi row")
    for sid, t in allscripts.items():
        for m in re.finditer(r"^\s*@alibi\s+(\S+)\s+(.+)$", t, re.M):
            who, field = m.group(1), m.group(2).strip()
            if who == "row":
                continue
            e = table.get(who)
            if who not in CHARS:
                err(ch, f"{sid}: @alibi names an unknown guest")
            elif field not in ("motive", "all") and e is not None:
                whens = {s.get("when") for s in e.get("slots", [])}
                if field not in whens and field.removesuffix(" proof") not in whens:
                    err(ch, f"{sid}: @alibi names a time the guest has no entry for")

    missing_alibi = [g for g in living if not table.get(g, {}).get("slots")]
    missing_motive = [g for g in living if not table.get(g, {}).get("motive")]
    if missing_alibi:
        depth(ch, "alibi rows", f"{len(missing_alibi)} of {len(living)} living guests have no alibi rows yet" + names(missing_alibi))
    if missing_motive:
        depth(ch, "motives", f"{len(missing_motive)} of {len(living)} living guests have no motive yet" + names(missing_motive))
    if table:
        backed = {g: sum(1 for s in table.get(g, {}).get("slots", []) if s.get("proof")) for g in living}
        no_proof = [g for g in living if g != culprit and backed[g] == 0]
        if len(no_proof) < 3:
            depth(ch, "missing alibis", f"only {len(no_proof)} innocent guests have nothing backing them up (at least 3 needed)")
        if backed and (backed.get(culprit, 0) == max(backed.values()) or backed.get(culprit, 0) == min(backed.values())):
            depth(ch, "killer's row", "the killer has the best or the worst backed-up row on the board")
        if sum(1 for g in living if backed[g] > 0) >= len(living) - 1:
            depth(ch, "the notebook clears too many", "the board backs up everyone but one guest")

    # everyone has a room and trial lines
    present = {p.get("char") for r in rooms.values() for p in r.get("people", [])}
    no_room = [g for g in living if g not in present]
    if no_room:
        depth(ch, "room presence", f"{len(no_room)} living guests stand in no room during the investigation" + names(no_room))
    trial_text = case.get("trial", "")
    in_trial = dict(spoken(trial_text))
    for d in trial_data.values():
        for st in d.get("statements", []):
            in_trial[st.get("speaker")] = in_trial.get(st.get("speaker"), 0) + 1
        if d.get("speaker"):
            in_trial[d["speaker"]] = in_trial.get(d["speaker"], 0) + 1
        for e in d.get("entries", []):
            in_trial[e.get("guest")] = in_trial.get(e.get("guest"), 0) + 1
    no_lines = [g for g in living if not in_trial.get(g)]
    if no_lines:
        depth(ch, "trial lines", f"{len(no_lines)} living guests say nothing in the trial" + names(no_lines))

    # labels that point at one guest
    def label_counts(items):
        out = {g: 0 for g in GUESTS if g not in info["gone"]}
        for label in items:
            for g in out:
                if re.search(r"\b%s\b" % re.escape(CHARS[g]), label):
                    out[g] += 1
        return out
    room_labels = [r.get("name", "") for r in rooms.values()]
    rc = label_counts(room_labels)
    named_rooms = [g for g, n in rc.items() if n]
    if len(named_rooms) == 1:
        depth(ch, "give-away labels", "exactly one guest has a room named after them" + names(named_rooms))
    dc = label_counts([CLUES[c]["name"] for c in known if c in CLUES])
    top = max(dc.values()) if dc else 0
    leaders = [g for g, n in dc.items() if n == top]
    if top > 0 and len(leaders) == 1:
        depth(ch, "give-away labels", f"one guest has more Truth Drops named after them than anyone else ({top})" + names(leaders))
    for label in room_labels + [CLUES[c]["name"] for c in known if c in CLUES]:
        if re.search(r"\b(hidden|secret|suspicious|murder|killer|culprit)\b", label, re.I):
            depth(ch, "give-away labels", "a room or Truth Drop label tells you it matters" + names([label]))

    # evidence balance: how many Truth Drops are about each living guest
    def about_count(g):
        n = 0
        for c in known:
            e = CLUES.get(c, {})
            about = e.get("about")
            if about is not None:
                n += 1 if g in about else 0
            elif re.search(r"\b%s\b" % re.escape(CHARS[g]), e.get("name", "") + " " + e.get("desc", "")):
                n += 1
        return n
    counts = {g: about_count(g) for g in living}
    if culprit in counts and len(known) > 3:
        med = statistics.median(counts.values())
        if abs(counts[culprit] - med) > 1:
            depth(ch, "evidence balance", f"the killer has {counts[culprit]} Truth Drops about them, the median is {med:g} (must be within one)")
        if counts[culprit] == min(counts.values()):
            depth(ch, "evidence balance", "the killer has the fewest Truth Drops about them")

    # forced-scene attention
    forced = {}
    steps = set(info["next"]) | set(info["next"].values())
    for sid in steps - ENDING_STEPS - {"trial", "execution", "credits", "investigation", "freetime"}:
        for g, n in spoken(allscripts.get(sid, "")).items():
            forced[g] = forced.get(g, 0) + n
    attention = {g: forced.get(g, 0) for g in living}
    if culprit in attention and sum(attention.values()) > 20:
        med = statistics.median(attention.values())
        if attention[culprit] == max(attention.values()) or attention[culprit] > med * 1.5:
            depth(ch, "forced-scene attention", f"the killer gets {attention[culprit]} forced-scene lines, the median is {med:g}")
        elif attention[culprit] == min(attention.values()):
            depth(ch, "forced-scene attention", "the killer gets the fewest forced-scene lines")

    # stages: reachable from required finds alone, counting only what is found during the investigation
    start = set(info.get("inv_start_clues", [])) | clue_given(allscripts.get("investigation_start", ""))
    for sid in steps:
        if sid in allscripts and sid != "investigation":
            start |= clue_given(allscripts[sid]) if sid in info["next"] and list(info["next"]).index(sid) < list(info["next"]).index("investigation") else set()
    find_here = [c for c in required if c not in start]
    prev_after = 0
    for s in stages:
        if s.get("script") not in allscripts:
            err(ch, "a stage plays a script that does not exist")
        if s.get("after", 0) < 1:
            err(ch, "a stage must trigger after at least one Truth Drop")
        if s.get("after", 0) < prev_after:
            err(ch, "stages must be listed in the order they trigger")
        prev_after = s.get("after", 0)
    fired, found = [], set()
    def collect():
        have = set()
        for r in rooms.values():
            if len(fired) >= r.get("opens_stage", 0):
                for h in r.get("hotspots", []) + r.get("people", []):
                    have |= clue_given(allscripts.get(h.get("script", ""), ""))
                have |= clue_given(allscripts.get(r.get("enter_script", ""), ""))
        for s in fired:
            have |= clue_given(allscripts.get(s.get("script", ""), ""))
        return have & set(find_here)
    while True:
        found = collect()
        due = [s for s in stages if s not in fired and s.get("after", 0) <= len(found)]
        if not due:
            break
        fired.append(due[0])
    for s in stages:
        if s not in fired:
            err(ch, "a stage can never trigger: not enough required Truth Drops can be found before it")
    unreachable = set(find_here) - found
    if unreachable:
        err(ch, f"{len(unreachable)} required Truth Drops cannot be found in any open room or stage" + names(unreachable))

    # the trial's numbers
    if trial_text:
        scale = float(info.get("penalty_scale", 1.0))
        threshold = float(info.get("threshold", 60.0))
        strong = simulate(trial_text, trial_data, scale, True)
        careless = simulate(trial_text, trial_data, scale, False)
        print(f"ch{ch}: strong run ends at {strong:.0f}, careless run at {careless:.0f}, vote needs {threshold:.0f}")
        if strong < threshold:
            err(ch, f"a strong run only reaches {strong:.0f}, the vote needs {threshold:.0f}")
        if careless >= threshold:
            depth(ch, "careless run", f"a careless run still reaches the vote ({careless:.0f} of {threshold:.0f})")
        cap = float(info.get("missing_cap", 18.0))
        at_cap = simulate(trial_text.replace("@bg", f"@convince -{cap:g}\n@bg", 1), trial_data, scale, True)
        if at_cap < threshold:
            depth(ch, "winnable at the cap", f"a strong run missing Truth Drops up to the cap ends at {at_cap:.0f}, the vote needs {threshold:.0f}")
        check_checkpoints(ch, trial_text, trial_data, scale, threshold, cap)

    # animated scenes often enough
    cadence(ch, info, allscripts, rooms, stages, len(find_here))

for w in warns:
    print("WARN ", w)
for e in errors:
    print("ERROR", e)
print(f"{len(errors)} errors, {len(warns)} warnings")
if pending_rules:
    print("Depth rules still warnings (not enforced until the chapter sets \"depth_checked\": true): " + ", ".join(sorted(pending_rules)))
sys.exit(1 if errors else 0)

#!/usr/bin/env python3
"""
Verify all levels in puzzles.js against the dictionaries.
Checks:
1. Every level has start, end, moves (4 moves), and solution (5 words: start, w1, w2, w3, end).
2. Each step in solution is a valid move according to moves[i]:
   - anagram
   - homophone
   - compound
   - verb
3. All words are valid English words from words.txt.
"""

import os
import sys
import json
import re

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DICT_DIR = os.path.join(BASE_DIR, "dict")
PUZZLES_PATH = os.path.join(BASE_DIR, "puzzles.js")

def load_data():
    with open(os.path.join(DICT_DIR, "homophones.json")) as f:
        homo_groups = json.load(f)["groups"]
    with open(os.path.join(DICT_DIR, "compounds.json")) as f:
        comp_pairs = json.load(f)["compounds"]
    with open(os.path.join(DICT_DIR, "irregular-verbs.json")) as f:
        irreg_verbs = json.load(f)["verbs"]
    with open(os.path.join(DICT_DIR, "regular-verbs.json")) as f:
        reg_verbs = set(json.load(f)["verbs"])
    with open(os.path.join(DICT_DIR, "words.txt")) as f:
        words = set(w.strip().lower() for w in f if w.strip())

    homo_map = {}
    for g in homo_groups:
        for w in g:
            homo_map.setdefault(w.lower(), set()).update(x.lower() for x in g if x != w)

    comp_map = {}
    for a, b in comp_pairs:
        a_l, b_l = a.lower(), b.lower()
        comp_map.setdefault(a_l, set()).add(b_l)
        comp_map.setdefault(b_l, set()).add(a_l)

    verb_groups = []
    verb_by_word = {}

    def add_verb_group(forms):
        clean_forms = set(x.lower() for x in forms if x and x.lower() in words)
        if len(clean_forms) >= 2:
            idx = len(verb_groups)
            verb_groups.append(clean_forms)
            for w in clean_forms:
                verb_by_word.setdefault(w, set()).add(idx)

    for r in irreg_verbs:
        forms = [r.get("base"), r.get("past"), r.get("pastp"), r.get("ing"), r.get("third")]
        add_verb_group(forms)

    VOWELS = set("aeiou")
    def should_double(base):
        if len(base) < 2: return False
        last = base[-1]
        prev = base[-2]
        if last in VOWELS or prev not in VOWELS: return False
        if len(base) >= 3 and base[-3] in VOWELS: return False
        if last in "wxy": return False
        return True

    for base in reg_verbs:
        b = base.lower()
        forms = [b]
        if b.endswith(('s', 'x', 'z', 'ch', 'sh')):
            forms.append(b + "es")
        elif b.endswith('y') and len(b) > 1 and b[-2] not in VOWELS:
            forms.append(b[:-1] + "ies")
        else:
            forms.append(b + "s")

        if b.endswith('e'):
            forms.append(b + "d")
        elif b.endswith('y') and len(b) > 1 and b[-2] not in VOWELS:
            forms.append(b[:-1] + "ied")
        elif should_double(b):
            forms.append(b + b[-1] + "ed")
        else:
            forms.append(b + "ed")

        if b.endswith('ie'):
            forms.append(b[:-2] + "ying")
        elif b.endswith('e') and not b.endswith(('ee', 'oe', 'ye')):
            forms.append(b[:-1] + "ing")
        elif should_double(b):
            forms.append(b + b[-1] + "ing")
        else:
            forms.append(b + "ing")

        add_verb_group(forms)

    return {
        "words": words,
        "homo_map": homo_map,
        "comp_map": comp_map,
        "verb_by_word": verb_by_word,
        "verb_groups": verb_groups,
    }

def is_valid_move(w1, w2, mtype, ctx):
    w1, w2 = w1.lower(), w2.lower()
    if w1 == w2:
        return False
    if w1 not in ctx["words"] or w2 not in ctx["words"]:
        return False

    if mtype == "anagram":
        return sorted(w1) == sorted(w2)

    elif mtype == "homophone":
        if w2 in ctx["homo_map"].get(w1, set()):
            return True
        for suf in ("s", "ed", "ing"):
            if w1.endswith(suf) and len(w1) > len(suf) + 1 and w2.endswith(suf) and len(w2) > len(suf) + 1:
                base1 = w1[:-len(suf)]
                base2 = w2[:-len(suf)]
                if base2 in ctx["homo_map"].get(base1, set()):
                    return True
        return False

    elif mtype == "compound":
        return w2 in ctx["comp_map"].get(w1, set())

    elif mtype == "verb":
        groups1 = ctx["verb_by_word"].get(w1, set())
        groups2 = ctx["verb_by_word"].get(w2, set())
        common = groups1.intersection(groups2)
        return len(common) > 0

    return False

def verify_all():
    print("Loading dictionary rules...")
    ctx = load_data()

    print(f"Reading {PUZZLES_PATH}...")
    with open(PUZZLES_PATH) as f:
        content = f.read()

    # Extract JSON from window.TWIXTLE_LEVELS = [...]
    match = re.search(r'window\.TWIXTLE_LEVELS\s*=\s*(\[.*\]);?', content, re.DOTALL)
    if not match:
        print("ERROR: Could not parse window.TWIXTLE_LEVELS from puzzles.js")
        sys.exit(1)

    levels = json.loads(match.group(1))
    print(f"Verifying {len(levels)} levels...")

    errors = 0
    for idx, lvl in enumerate(levels):
        lvl_num = lvl.get("level", idx + 1)
        start = lvl.get("start", "").lower()
        end = lvl.get("end", "").lower()
        moves = lvl.get("moves", [])
        solution = [w.lower() for w in lvl.get("solution", [])]

        if not start or not end:
            print(f"[Level {lvl_num}] ERROR: Missing start/end word.")
            errors += 1
            continue

        if len(moves) != 4:
            print(f"[Level {lvl_num}] ERROR: moves count is {len(moves)}, expected 4.")
            errors += 1
            continue

        if len(solution) != 5:
            print(f"[Level {lvl_num}] ERROR: solution length is {len(solution)}, expected 5 words.")
            errors += 1
            continue

        if solution[0] != start:
            print(f"[Level {lvl_num}] ERROR: solution[0] '{solution[0]}' != start '{start}'.")
            errors += 1
            continue

        if solution[-1] != end:
            print(f"[Level {lvl_num}] ERROR: solution[-1] '{solution[-1]}' != end '{end}'.")
            errors += 1
            continue

        # Check each transition
        for step_i in range(4):
            w_from = solution[step_i]
            w_to = solution[step_i + 1]
            mtype = moves[step_i]

            if not is_valid_move(w_from, w_to, mtype, ctx):
                print(f"[Level {lvl_num}] ERROR at step {step_i + 1} ({mtype}): '{w_from}' -> '{w_to}' is INVALID.")
                errors += 1

    if errors == 0:
        print(f"SUCCESS: All {len(levels)} levels are 100% verified and legally solvable!")
    else:
        print(f"FAILURE: Found {errors} errors across levels.")
        sys.exit(1)

if __name__ == "__main__":
    verify_all()

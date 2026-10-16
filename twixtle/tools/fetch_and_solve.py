#!/usr/bin/env python3
"""
Twixtle Puzzle Generator & Solver (500+ High-Quality Levels)
Fetches official daily puzzles and generates high-quality, verified 4-step word chain puzzles
using only familiar, everyday English vocabulary (filtered against the top 20,000 common words).
"""

import os
import sys
import json
import time
import random
import urllib.request
import itertools

TWIXTLE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DICT_DIR = os.path.join(TWIXTLE_DIR, "dict")
COMMON_20K_PATH = os.path.join(DICT_DIR, "common_20k.txt")

def ensure_common_words():
    if not os.path.exists(COMMON_20K_PATH):
        print("Downloading 20,000 common English words dataset...")
        try:
            url = "https://raw.githubusercontent.com/first20hours/google-10000-english/master/20k.txt"
            req = urllib.request.urlopen(url, timeout=10)
            with open(COMMON_20K_PATH, "wb") as f:
                f.write(req.read())
            print(f"Saved {COMMON_20K_PATH}")
        except Exception as e:
            print(f"Warning: Could not download 20k.txt: {e}")
            return set()
    with open(COMMON_20K_PATH) as f:
        return set(w.strip().lower() for w in f if w.strip())

def load_dictionaries():
    print("Loading dictionaries...")
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

    # Anagram buckets
    anagram_buckets = {}
    for w in words:
        sw = "".join(sorted(w))
        anagram_buckets.setdefault(sw, []).append(w)

    # Verb groups
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
        # 3rd person singular
        if b.endswith(('s', 'x', 'z', 'ch', 'sh')):
            forms.append(b + "es")
        elif b.endswith('y') and len(b) > 1 and b[-2] not in VOWELS:
            forms.append(b[:-1] + "ies")
        else:
            forms.append(b + "s")
        # Past / past participle
        if b.endswith('e'):
            forms.append(b + "d")
        elif b.endswith('y') and len(b) > 1 and b[-2] not in VOWELS:
            forms.append(b[:-1] + "ied")
        elif should_double(b):
            forms.append(b + b[-1] + "ed")
        else:
            forms.append(b + "ed")
        # -ing
        if b.endswith('ie'):
            forms.append(b[:-2] + "ying")
        elif b.endswith('e') and not b.endswith(('ee', 'oe', 'ye')):
            forms.append(b[:-1] + "ing")
        elif should_double(b):
            forms.append(b + b[-1] + "ing")
        else:
            forms.append(b + "ing")

        add_verb_group(forms)

    print(f"Dictionaries ready: {len(words)} words, {len(homo_map)} homophone roots, {len(comp_map)} compound roots, {len(verb_groups)} verb groups.")
    return {
        "words": words,
        "homo_map": homo_map,
        "comp_map": comp_map,
        "anagram_buckets": anagram_buckets,
        "verb_by_word": verb_by_word,
        "verb_groups": verb_groups,
    }

def get_valid_moves(w, mtype, ctx):
    res = set()
    w = w.lower()
    if mtype == "anagram":
        sw = "".join(sorted(w))
        for cand in ctx["anagram_buckets"].get(sw, []):
            if cand != w:
                res.add(cand)
    elif mtype == "homophone":
        if w in ctx["homo_map"]:
            res.update(ctx["homo_map"][w])
        # Try suffix propagation (-s, -ed, -ing)
        for suf in ("s", "ed", "ing"):
            if w.endswith(suf) and len(w) > len(suf) + 1:
                base = w[:-len(suf)]
                for alt_base in ctx["homo_map"].get(base, []):
                    alt_w = alt_base + suf
                    if alt_w in ctx["words"] and alt_w != w:
                        res.add(alt_w)
    elif mtype == "compound":
        if w in ctx["comp_map"]:
            res.update(ctx["comp_map"][w])
    elif mtype == "verb":
        for g_idx in ctx["verb_by_word"].get(w, []):
            for cand in ctx["verb_groups"][g_idx]:
                if cand != w:
                    res.add(cand)
    return res

def solve_puzzle(start, target, moves, ctx):
    start = start.lower()
    target = target.lower()
    paths = [[start]]
    for m in moves:
        next_paths = []
        for p in paths:
            curr = p[-1]
            cands = get_valid_moves(curr, m, ctx)
            for c in cands:
                if c not in p:
                    next_paths.append(p + [c])
        paths = next_paths
        if not paths:
            break
    solutions = [p for p in paths if p[-1] == target]
    return solutions

def harvest_and_build(ctx, target_count=550):
    common_20k = ensure_common_words()
    print(f"Loaded {len(common_20k)} common vocabulary filter words.")

    puzzles = []
    seen_pairs = set()

    # 1. First, preserve any existing verified archive levels from puzzles.js if present
    puzzles_file = os.path.join(TWIXTLE_DIR, "puzzles.js")
    if os.path.exists(puzzles_file):
        try:
            with open(puzzles_file) as f:
                content = f.read()
            import re
            m = re.search(r'window\.TWIXTLE_LEVELS\s*=\s*(\[.*\]);?', content, re.DOTALL)
            if m:
                existing = json.loads(m.group(1))
                for p in existing:
                    # Keep authentic archive days (from official twixtle.games archive)
                    date_val = p.get("date", "")
                    if date_val.startswith("2026-"):
                        pair_key = (p["start"].lower(), p["end"].lower())
                        if pair_key not in seen_pairs:
                            seen_pairs.add(pair_key)
                            puzzles.append(p)
                print(f"Retained {len(puzzles)} authentic historical archive puzzles.")
        except Exception as e:
            print(f"Notice: Could not load existing puzzles.js: {e}")

    # If we need more archive puzzles, fetch from archive.php
    if len(puzzles) < 150:
        try:
            print("Fetching archive from twixtle.games...")
            url = "https://twixtle.games/api/archive.php?today=2026-10-17"
            req = urllib.request.urlopen(url, timeout=10)
            data = json.loads(req.read().decode())
            days = data.get("days", [])
            for d in days:
                date_str = d["date"]
                start_w = d["start"].lower()
                end_w = d["end"].lower()
                pair_key = (start_w, end_w)
                if pair_key in seen_pairs:
                    continue

                # Query state.php for reveal_moves
                moves = None
                try:
                    s_url = f"https://twixtle.games/api/state.php?date={date_str}"
                    s_req = urllib.request.urlopen(s_url, timeout=5)
                    s_data = json.loads(s_req.read().decode())
                    moves = s_data.get("reveal_moves")
                except Exception:
                    pass

                if moves:
                    sols = solve_puzzle(start_w, end_w, moves, ctx)
                    if sols:
                        seen_pairs.add(pair_key)
                        puzzles.append({
                            "start": start_w,
                            "end": end_w,
                            "moves": moves,
                            "solution": sols[0],
                            "date": date_str,
                        })
        except Exception as e:
            print(f"Archive fetch notice: {e}")

    print(f"Starting generator with {len(puzzles)} base puzzles. Target: {target_count} total levels.")

    # 2. Generate high-quality puzzles using familiar common words (common_20k)
    # Permutations of the 4 moves
    move_types = ["anagram", "compound", "homophone", "verb"]
    all_perms = list(itertools.permutations(move_types))
    random.seed(2026)
    random.shuffle(all_perms)

    # Filter candidate starter words:
    # Must be in common_20k, 3-6 chars long, and have homophone or compound moves
    starters = [
        w for w in ctx["words"]
        if w in common_20k and 3 <= len(w) <= 6 and (w in ctx["homo_map"] or w in ctx["comp_map"])
    ]
    random.shuffle(starters)

    def get_common_moves(w, m):
        cands = get_valid_moves(w, m, ctx)
        # Quality filter: Must be recognized in common_20k and between 3-7 letters
        return [c for c in cands if c in common_20k and 3 <= len(c) <= 7]

    print("Generating high-quality levels using common vocabulary...")
    perm_idx = 0
    attempts = 0

    for w_start in starters:
        if len(puzzles) >= target_count:
            break

        # Rotate across diverse move permutations
        selected_perms = all_perms[perm_idx % len(all_perms):] + all_perms[:perm_idx % len(all_perms)]
        perm_idx += 1

        for perm in selected_perms[:6]:
            attempts += 1
            # Search 4 steps
            paths = [[w_start]]
            for m in perm:
                next_paths = []
                for p in paths:
                    cands = get_common_moves(p[-1], m)
                    for c in cands:
                        if c not in p:
                            next_paths.append(p + [c])
                if not next_paths:
                    paths = []
                    break
                paths = next_paths[:20]

            if paths:
                # Filter paths where all 5 words are mutually distinct and length >= 3
                good_paths = [p for p in paths if len(set(p)) == 5 and p[0] != p[-1]]
                if good_paths:
                    chosen = random.choice(good_paths)
                    w_end = chosen[-1]
                    pair_key = (w_start, w_end)

                    if pair_key not in seen_pairs:
                        sols = solve_puzzle(w_start, w_end, list(perm), ctx)
                        if sols:
                            seen_pairs.add(pair_key)
                            puzzles.append({
                                "start": w_start,
                                "end": w_end,
                                "moves": list(perm),
                                "solution": sols[0],
                                "date": f"level-{len(puzzles)+1}",
                            })
                            if len(puzzles) % 25 == 0 or len(puzzles) >= target_count:
                                print(f"[{len(puzzles)}/{target_count}] {w_start} -> {w_end} ({', '.join(perm)}) : {' -> '.join(sols[0])}")
                            break

    print(f"\nCompleted puzzle generation: {len(puzzles)} levels generated.")

    # Number the levels sequentially: Level 1, Level 2, ... Level N
    final_levels = []
    for idx, p in enumerate(puzzles, 1):
        final_levels.append({
            "level": idx,
            "start": p["start"],
            "end": p["end"],
            "moves": p["moves"],
            "solution": p["solution"],
            "date": p.get("date", f"level-{idx}"),
        })

    # Write out to puzzles.js
    out_file = os.path.join(TWIXTLE_DIR, "puzzles.js")
    with open(out_file, "w", encoding="utf-8") as f:
        f.write(f"// Twixtle {len(final_levels)} Verified Offline Level Progression for Kobo eReader\n")
        f.write("window.TWIXTLE_LEVELS = ")
        json.dump(final_levels, f, indent=2)
        f.write(";\n")

    print(f"\n=======================================================")
    print(f"SUCCESS: Generated {len(final_levels)} verified levels in {out_file}!")
    print(f"File size: {os.path.getsize(out_file) / 1024:.1f} KB")
    print(f"=======================================================")

if __name__ == "__main__":
    ctx = load_dictionaries()
    harvest_and_build(ctx, target_count=550)

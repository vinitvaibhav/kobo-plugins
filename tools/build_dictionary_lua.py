#!/usr/bin/env python3
"""
Build dictionary data for twixtle.koplugin in Lua format.
Generates:
- twixtle.koplugin/dict_data.lua
- twixtle.koplugin/words.txt
"""

import os
import json
import shutil

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DICT = os.path.join(BASE_DIR, "twixtle", "dict")
PLUGIN_DIR = os.path.join(BASE_DIR, "twixtle.koplugin")

def main():
    print("Reading source dictionaries...")
    with open(os.path.join(SRC_DICT, "homophones.json")) as f:
        homo_groups = json.load(f)["groups"]
    with open(os.path.join(SRC_DICT, "compounds.json")) as f:
        comp_pairs = json.load(f)["compounds"]
    with open(os.path.join(SRC_DICT, "irregular-verbs.json")) as f:
        irreg_verbs = json.load(f)["verbs"]
    with open(os.path.join(SRC_DICT, "regular-verbs.json")) as f:
        reg_verbs = json.load(f)["verbs"]

    out_file = os.path.join(PLUGIN_DIR, "dict_data.lua")
    print(f"Writing {out_file}...")

    with open(out_file, "w", encoding="utf-8") as f:
        f.write("-- Twixtle Curated Offline Dictionaries for KOReader\n")
        f.write("local M = {}\n\n")

        # Homophones
        f.write("M.homophones = {\n")
        for g in homo_groups:
            items = ", ".join(f'"{w.lower()}"' for w in g if w)
            f.write(f"    {{ {items} }},\n")
        f.write("}\n\n")

        # Compounds
        f.write("M.compounds = {\n")
        for a, b in comp_pairs:
            f.write(f'    {{ "{a.lower()}", "{b.lower()}" }},\n')
        f.write("}\n\n")

        # Irregular verbs
        f.write("M.irregular_verbs = {\n")
        for r in irreg_verbs:
            forms = [r.get("base"), r.get("past"), r.get("pastp"), r.get("ing"), r.get("third")]
            clean = [f'"{x.lower()}"' for x in forms if x]
            f.write(f"    {{ {', '.join(clean)} }},\n")
        f.write("}\n\n")

        # Regular verbs
        f.write("M.regular_verbs = {\n")
        for b in reg_verbs:
            f.write(f'    "{b.lower()}",\n')
        f.write("}\n\n")

        f.write("return M\n")

    # Copy words.txt
    shutil.copy(os.path.join(SRC_DICT, "words.txt"), os.path.join(PLUGIN_DIR, "words.txt"))
    print(f"Copied words.txt ({os.path.getsize(os.path.join(PLUGIN_DIR, 'words.txt'))} bytes)")
    print(f"Generated dict_data.lua ({os.path.getsize(out_file)} bytes)")

if __name__ == "__main__":
    main()

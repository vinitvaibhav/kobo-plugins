#!/usr/bin/env python3
"""
Compiles raw dictionary files into a single, highly-optimized dict/data.js
that loads synchronously in Kobo's browser via <script> tag without CORS issues.
"""

import json
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DICT_DIR = os.path.join(SCRIPT_DIR, "..", "dict")

def main():
    print("Reading raw dictionary files...")
    
    with open(os.path.join(DICT_DIR, "homophones.json"), "r", encoding="utf-8") as f:
        homo_data = json.load(f)["groups"]

    with open(os.path.join(DICT_DIR, "compounds.json"), "r", encoding="utf-8") as f:
        comp_data = json.load(f)["compounds"]

    with open(os.path.join(DICT_DIR, "irregular-verbs.json"), "r", encoding="utf-8") as f:
        irreg_data = json.load(f)["verbs"]

    with open(os.path.join(DICT_DIR, "regular-verbs.json"), "r", encoding="utf-8") as f:
        reg_data = json.load(f)["verbs"]

    with open(os.path.join(DICT_DIR, "words.txt"), "r", encoding="utf-8") as f:
        words_list = [w.strip().lower() for w in f if w.strip()]

    # Clean and filter
    print(f"Loaded {len(words_list)} words, {len(homo_data)} homophone groups, {len(comp_data)} compound pairs.")

    out_file = os.path.join(DICT_DIR, "data.js")
    with open(out_file, "w", encoding="utf-8") as f:
        f.write("// Twixtle Offline Dictionary Bundle for Kobo eReader\n")
        f.write("window.TWIXTLE_DICT = {\n")
        
        # Homophones
        f.write("  homophones: ")
        json.dump(homo_data, f, separators=(',', ':'))
        f.write(",\n")

        # Compounds
        f.write("  compounds: ")
        json.dump(comp_data, f, separators=(',', ':'))
        f.write(",\n")

        # Irregular Verbs
        clean_irreg = []
        for r in irreg_data:
            forms = [r.get("base"), r.get("past"), r.get("pastp"), r.get("ing"), r.get("third")]
            clean_irreg.append([x.lower() for x in forms if x])
        f.write("  irregularVerbs: ")
        json.dump(clean_irreg, f, separators=(',', ':'))
        f.write(",\n")

        # Regular Verbs
        f.write("  regularVerbs: ")
        json.dump([v.lower() for v in reg_data], f, separators=(',', ':'))
        f.write(",\n")

        # Words (as compact packed string separated by space)
        packed_words = " ".join(words_list)
        f.write("  wordsPacked: ")
        json.dump(packed_words, f)
        f.write("\n};\n")

    size_kb = os.path.getsize(out_file) / 1024
    print(f"Successfully generated {out_file} ({size_kb:.1f} KB)")

if __name__ == "__main__":
    main()

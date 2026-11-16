#!/usr/bin/env python3
"""Patches build_corpus.py to match expanded JMdict XML entity text strings
(e.g. 'yojijukugo', 'transitive verb', 'intransitive verb', 'idiomatic expression')."""

from pathlib import Path

target = Path("tools/corpus-builder/build_corpus.py")
src = target.read_text(encoding="utf-8")

old_pos_block = '''POS_BITS = {
    "n": 1 << 0, "v1": 1 << 1, "v5": 1 << 2, "vs": 1 << 3,
    "vt": 1 << 4, "vi": 1 << 5, "adj-i": 1 << 6, "adj-na": 1 << 7,
    "adv": 1 << 8, "exp": 1 << 9, "prt": 1 << 10, "yoji": 1 << 11,
    "id": 1 << 12, "on-mim": 1 << 13, "hon": 1 << 14, "hum": 1 << 15,
    "pol": 1 << 16, "col": 1 << 17, "sl": 1 << 18, "arch": 1 << 19,
    "ksb": 1 << 20, "proverb": 1 << 21,
}'''

new_pos_block = '''POS_BITS = {
    "n": 1 << 0, "v1": 1 << 1, "v5": 1 << 2, "vs": 1 << 3,
    "vt": 1 << 4, "vi": 1 << 5, "adj-i": 1 << 6, "adj-na": 1 << 7,
    "adv": 1 << 8, "exp": 1 << 9, "prt": 1 << 10, "yoji": 1 << 11,
    "id": 1 << 12, "on-mim": 1 << 13, "hon": 1 << 14, "hum": 1 << 15,
    "pol": 1 << 16, "col": 1 << 17, "sl": 1 << 18, "arch": 1 << 19,
    "ksb": 1 << 20, "proverb": 1 << 21,
}

def map_pos_text(text: str) -> int:
    t = text.strip("&;").lower()
    if t in POS_BITS:
        return POS_BITS[t]
    bits = 0
    if t.startswith("noun") or t == "n":
        bits |= POS_BITS["n"]
    if "ichidan verb" in t:
        bits |= POS_BITS["v1"]
    if "godan verb" in t:
        bits |= POS_BITS["v5"]
    if "suru" in t:
        bits |= POS_BITS["vs"]
    if "transitive verb" in t and "intransitive" not in t:
        bits |= POS_BITS["vt"]
    if "intransitive verb" in t:
        bits |= POS_BITS["vi"]
    if "adjective (keiyoushi)" in t:
        bits |= POS_BITS["adj-i"]
    if "adjectival nouns" in t or "quasi-adjectives" in t:
        bits |= POS_BITS["adj-na"]
    if t.startswith("adverb"):
        bits |= POS_BITS["adv"]
    if t.startswith("expressions"):
        bits |= POS_BITS["exp"]
    if t == "particle":
        bits |= POS_BITS["prt"]
    return bits

def map_misc_text(text: str) -> int:
    t = text.strip("&;").lower()
    if t in POS_BITS:
        return POS_BITS[t]
    bits = 0
    if "yojijukugo" in t:
        bits |= POS_BITS["yoji"]
    if "idiomatic expression" in t:
        bits |= POS_BITS["id"]
    if "proverb" in t:
        bits |= POS_BITS["proverb"]
    if "onomatopoeic" in t or "mimetic" in t:
        bits |= POS_BITS["on-mim"]
    if "honorific" in t or "sonkeigo" in t:
        bits |= POS_BITS["hon"]
    if "humble" in t or "kenjougo" in t:
        bits |= POS_BITS["hum"]
    if "polite" in t or "teineigo" in t:
        bits |= POS_BITS["pol"]
    if "colloquial" in t:
        bits |= POS_BITS["col"]
    if "slang" in t:
        bits |= POS_BITS["sl"]
    if "archaism" in t or "archaic" in t:
        bits |= POS_BITS["arch"]
    return bits'''

old_sense_loop = '''                    for pos_el in sense.findall("pos"):
                        code = (pos_el.text or "").strip("&;")
                        if code in POS_BITS:
                            s_pos |= POS_BITS[code]
                    for misc_el in sense.findall("misc"):
                        mcode = (misc_el.text or "").strip("&;")
                        if mcode == "yoji":
                            is_yoji = True
                            s_pos |= POS_BITS["yoji"]
                        elif mcode == "id":
                            is_idiom = True
                            s_pos |= POS_BITS["id"]
                        elif mcode == "proverb":
                            is_proverb = True
                            s_pos |= POS_BITS["proverb"]
                        elif mcode in POS_BITS:
                            s_pos |= POS_BITS[mcode]'''

new_sense_loop = '''                    for pos_el in sense.findall("pos"):
                        if pos_el.text:
                            s_pos |= map_pos_text(pos_el.text)
                    for misc_el in sense.findall("misc"):
                        if misc_el.text:
                            mbits = map_misc_text(misc_el.text)
                            s_pos |= mbits
                            if mbits & POS_BITS["yoji"]:
                                is_yoji = True
                            if mbits & POS_BITS["id"]:
                                is_idiom = True
                            if mbits & POS_BITS["proverb"]:
                                is_proverb = True'''

assert old_pos_block in src, "POS_BITS block not found"
assert old_sense_loop in src, "Sense loop block not found"

src = src.replace(old_pos_block, new_pos_block).replace(old_sense_loop, new_sense_loop)
target.write_text(src, encoding="utf-8")
print("Patched tools/corpus-builder/build_corpus.py successfully.")

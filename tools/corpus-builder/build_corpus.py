#!/usr/bin/env python3
"""
Dai-Jishow Offline Corpus Compiler (build_corpus.py)
====================================================
Ingests open Japanese linguistic corpora (JMdict, KANJIDIC2, KanjiVG, Kanjium
pitch accents, Tatoeba example sentences, and JMnedict proper names) and compiles
them into a single, normalized, read-only SQLite database (`daijishow.db`).

Design Principles:
  - Zero-bloat runtime: Tables use `WITHOUT ROWID` and covering B-tree indexes
    so the C++20 core can memory-map (`mmap`) the database and answer prefix
    and graph queries in < 0.2 ms with near-zero active RAM.
  - All XML entity expansions (e.g., `&yoji;` -> `"yojijukugo"`) and graph
    deduplication rules are baked directly into this mainline pipeline.
"""

import argparse
import bz2
import gzip
import math
import re
import sqlite3
import struct
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Set, Tuple

from pack_kanjivg import extract_component_radicals, pack_strokes_blob

RAW_DIR = Path(__file__).parent / "raw_data"

SCHEMA_SQL = """
PRAGMA journal_mode = OFF;
PRAGMA synchronous = OFF;
PRAGMA page_size = 4096;

-- Primary vocabulary & proper-name headword table.
-- WITHOUT ROWID clusters rows directly on `entry_id` B-tree pages.
CREATE TABLE entries (
    entry_id        INTEGER PRIMARY KEY,
    kanji_head      TEXT,
    kana_head       TEXT NOT NULL,
    alt_forms       TEXT,
    pos_mask        INTEGER NOT NULL DEFAULT 0,
    register_mask   INTEGER NOT NULL DEFAULT 0,
    pitch_accent    INTEGER NOT NULL DEFAULT 255, -- 255=unknown, 0=Heiban, 1..N=drop mora
    freq_overall    INTEGER NOT NULL DEFAULT 999999,
    freq_novel      INTEGER NOT NULL DEFAULT 999999,
    freq_anime      INTEGER NOT NULL DEFAULT 999999,
    freq_news       INTEGER NOT NULL DEFAULT 999999,
    pair_entry_id   INTEGER,                    -- Transitive <-> Intransitive partner ID
    is_name         INTEGER NOT NULL DEFAULT 0  -- 0=general vocab, 1=JMnedict proper name
) WITHOUT ROWID;

-- Covering B-tree indexes for sub-millisecond prefix range scans (`>= q AND < q + U+FFFF`).
-- Partitioning by `is_name` keeps general dictionary lookups isolated from 740k proper names.
CREATE INDEX idx_entries_kana  ON entries(is_name, kana_head, freq_overall);
CREATE INDEX idx_entries_kanji ON entries(is_name, kanji_head, freq_overall);
CREATE INDEX idx_entries_name_len2_suffix
    ON entries(is_name, SUBSTR(kanji_head, 2, 1), freq_overall)
    WHERE is_name = 1 AND kanji_head IS NOT NULL AND LENGTH(kanji_head) = 2;

CREATE TABLE senses (
    entry_id        INTEGER NOT NULL,
    sense_idx       INTEGER NOT NULL,
    pos_mask        INTEGER NOT NULL DEFAULT 0,
    en_glosses      TEXT NOT NULL,
    ja_glosses      TEXT,
    misc_notes      TEXT,
    PRIMARY KEY (entry_id, sense_idx)
) WITHOUT ROWID;

-- Contentless FTS5 index for fast English gloss full-text search without duplicating strings.
CREATE VIRTUAL TABLE entries_fts USING fts5(
    kanji_head,
    kana_head,
    en_glosses,
    content='',
    tokenize='unicode61 remove_diacritics 0'
);

CREATE TABLE kanji (
    codepoint       INTEGER PRIMARY KEY,
    strokes         INTEGER NOT NULL,
    grade           INTEGER NOT NULL,
    jlpt            INTEGER NOT NULL,
    kanken          INTEGER NOT NULL DEFAULT 0,
    freq_rank       INTEGER NOT NULL,
    radical_id      INTEGER NOT NULL,
    jis_code        INTEGER NOT NULL,
    skip_code       INTEGER NOT NULL,
    four_corner     INTEGER NOT NULL,
    kyujitai_cp     INTEGER,
    phonetic_cp     INTEGER,
    on_readings     TEXT NOT NULL,
    kun_readings    TEXT NOT NULL,
    meanings        TEXT NOT NULL,
    stroke_blob     BLOB NOT NULL               -- Quantized uint16 polyline stroke vectors
) WITHOUT ROWID;

CREATE TABLE kanji_radicals (
    radical_id      INTEGER NOT NULL,
    codepoint       INTEGER NOT NULL,
    PRIMARY KEY (radical_id, codepoint)
) WITHOUT ROWID;

-- Precomputed Dokusha directional compound graph:
-- edge_kind: 0=Left(Prefix) Vocab, 1=Right(Suffix) Vocab, 2=Yojijukugo, 3=Left Name, 4=Right Name
CREATE TABLE kanji_edges (
    center_cp       INTEGER NOT NULL,
    edge_kind       INTEGER NOT NULL,
    rank            INTEGER NOT NULL,
    neighbor_cp     INTEGER NOT NULL,
    top_entry_id    INTEGER NOT NULL,
    compound_cnt    INTEGER NOT NULL,
    pmi_score       REAL NOT NULL,
    PRIMARY KEY (center_cp, edge_kind, rank)
) WITHOUT ROWID;

CREATE TABLE idioms (
    entry_id         INTEGER PRIMARY KEY,
    idiom_kind       INTEGER NOT NULL,          -- 1=Yojijukugo, 2=Kan'yoku, 3=Kotowaza
    literal_gloss    TEXT,
    figurative_gloss TEXT NOT NULL,
    en_equivalent    TEXT,
    etymology_note   TEXT,
    anchor_lemmas    TEXT NOT NULL
) WITHOUT ROWID;

CREATE TABLE idiom_triggers (
    lemma_entry_id  INTEGER NOT NULL,
    idiom_entry_id  INTEGER NOT NULL,
    PRIMARY KEY (lemma_entry_id, idiom_entry_id)
) WITHOUT ROWID;

CREATE TABLE collocations (
    head_entry_id   INTEGER NOT NULL,
    rel_type        INTEGER NOT NULL,
    collocate_id    INTEGER NOT NULL,
    mi_score        REAL NOT NULL,
    PRIMARY KEY (head_entry_id, rel_type, collocate_id)
) WITHOUT ROWID;

CREATE TABLE keigo_ladders (
    base_entry_id   INTEGER PRIMARY KEY,
    teineigo_id     INTEGER,
    sonkeigo_id     INTEGER,
    kenjogo_id      INTEGER
) WITHOUT ROWID;

CREATE TABLE sentences (
    sent_id         INTEGER PRIMARY KEY,
    jp_text         TEXT NOT NULL,
    en_text         TEXT NOT NULL,
    token_spans     BLOB NOT NULL               -- Packed [byte_off:u16, byte_len:u16, entry_id:u32]
) WITHOUT ROWID;

CREATE TABLE sentence_index (
    entry_id        INTEGER NOT NULL,
    sent_id         INTEGER NOT NULL,
    PRIMARY KEY (entry_id, sent_id)
) WITHOUT ROWID;
"""

POS_BITS = {
    "n": 1 << 0, "v1": 1 << 1, "v5": 1 << 2, "vs": 1 << 3,
    "vt": 1 << 4, "vi": 1 << 5, "adj-i": 1 << 6, "adj-na": 1 << 7,
    "adv": 1 << 8, "exp": 1 << 9, "prt": 1 << 10, "yoji": 1 << 11,
    "id": 1 << 12, "on-mim": 1 << 13, "hon": 1 << 14, "hum": 1 << 15,
    "pol": 1 << 16, "col": 1 << 17, "sl": 1 << 18, "arch": 1 << 19,
    "ksb": 1 << 20, "proverb": 1 << 21,
}

def map_pos_text(text: str) -> int:
    """Maps both short EDICT codes and XML-expanded JMdict entity descriptions to POS bitmasks."""
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
    """Maps XML-expanded JMdict <misc> descriptions (yojijukugo, idioms, keigo, etc.) to bitmasks."""
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
    return bits

def is_kanji(ch: str) -> bool:
    cp = ord(ch)
    return (0x4E00 <= cp <= 0x9FFF) or (0x3400 <= cp <= 0x4DBF)

def pack_skip(skip_str: str) -> int:
    try:
        a, b, c = (int(x) for x in skip_str.split("-"))
        return ((a & 0xF) << 20) | ((b & 0x3FF) << 10) | (c & 0x3FF)
    except Exception:
        return 0

def pack_four_corner(fc_str: str) -> int:
    digits = "".join(ch for ch in fc_str if ch.isdigit())[:5]
    if len(digits) < 4:
        return 0
    val = 0
    for d in digits.ljust(5, "0"):
        val = (val << 4) | int(d)
    return val

def priority_to_rank(pri_tags: List[str]) -> int:
    if "ichi1" in pri_tags or "news1" in pri_tags or "spec1" in pri_tags:
        return 2500
    if "ichi2" in pri_tags or "news2" in pri_tags or "spec2" in pri_tags:
        return 12000
    for t in pri_tags:
        if t.startswith("nf"):
            try:
                return int(t[2:]) * 500
            except ValueError:
                pass
    return 150000

def load_kanjium_accents(path: Path) -> Dict[Tuple[str, str], int]:
    accents: Dict[Tuple[str, str], int] = {}
    if not path.exists():
        print(f"[warn]  {path.name} not found; skipping pitch accents")
        return accents
    print(f"[parse] {path.name} ...")
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 3:
                orth, read, acc_str = parts[0].strip(), parts[1].strip(), parts[2].strip()
                m = re.search(r"(\d+)", acc_str)
                if m:
                    pos = int(m.group(1))
                    accents[(orth, read)] = pos
                    accents.setdefault(("", read), pos)
    print(f"[done]  Loaded {len(accents)} pitch-accent entries")
    return accents

def parse_kanjivg(gz_path: Path) -> Dict[int, Tuple[bytes, List[int]]]:
    if not gz_path.exists():
        print(f"[warn]  {gz_path.name} not found; skipping stroke vectors")
        return {}
    print(f"[parse] {gz_path.name} ...")
    out: Dict[int, Tuple[bytes, List[int]]] = {}
    with gzip.open(gz_path, "rb") as f:
        for _, elem in ET.iterparse(f, events=("end",)):
            if elem.tag.endswith("kanji"):
                kid = elem.attrib.get("id", "")
                if "_" in kid:
                    try:
                        cp = int(kid.split("_")[-1], 16)
                        paths = [p.attrib["d"] for p in elem.iter() if p.tag.endswith("path") and "d" in p.attrib]
                        rads = extract_component_radicals(elem)
                        out[cp] = (pack_strokes_blob(paths), rads)
                    except ValueError:
                        pass
                elem.clear()
    print(f"[done]  Loaded {len(out)} KanjiVG stroke diagrams & sub-radical trees")
    return out

def parse_kanjidic2(gz_path: Path, conn: sqlite3.Connection, kvg_map: Dict[int, Tuple[bytes, List[int]]]) -> None:
    if not gz_path.exists():
        raise FileNotFoundError(f"Missing {gz_path}. Run fetch_sources.py first.")
    print(f"[parse] {gz_path.name} ...")
    cur = conn.cursor()
    count = 0
    rad_links = 0
    with gzip.open(gz_path, "rb") as f:
        for _, elem in ET.iterparse(f, events=("end",)):
            if elem.tag == "character":
                literal = elem.findtext("literal")
                if literal and len(literal) == 1:
                    cp = ord(literal)
                    misc = elem.find("misc")
                    grade = int(misc.findtext("grade") or 0) if misc is not None else 0
                    strokes = int(misc.findtext("stroke_count") or 0) if misc is not None else 0
                    freq = int(misc.findtext("freq") or 999999) if misc is not None else 999999
                    jlpt = int(misc.findtext("jlpt") or 0) if misc is not None else 0

                    rad_id = 0
                    for rv in elem.findall("radical/rad_value"):
                        if rv.attrib.get("rad_type") == "classical":
                            rad_id = int(rv.text or 0)

                    jis_code = 0
                    for cp_el in elem.findall("codepoint/cp_value"):
                        if cp_el.attrib.get("cp_type") == "jis208":
                            try:
                                r, c = (int(x) for x in (cp_el.text or "0-0").split("-"))
                                jis_code = (r << 8) | c
                            except ValueError:
                                pass

                    skip_code = 0
                    four_corner = 0
                    for qc in elem.findall("query_code/q_code"):
                        qt = qc.attrib.get("qc_type")
                        if qt == "skip":
                            skip_code = pack_skip(qc.text or "")
                        elif qt == "four_corner":
                            four_corner = pack_four_corner(qc.text or "")

                    on_r, kun_r, meanings = [], [], []
                    for r_el in elem.findall("reading_meaning/rmgroup/reading"):
                        rt = r_el.attrib.get("r_type")
                        if rt == "ja_on" and r_el.text:
                            on_r.append(r_el.text)
                        elif rt == "ja_kun" and r_el.text:
                            kun_r.append(r_el.text)
                    for m_el in elem.findall("reading_meaning/rmgroup/meaning"):
                        if "m_lang" not in m_el.attrib and m_el.text:
                            meanings.append(m_el.text)

                    blob, sub_rads = kvg_map.get(cp, (b"\x00", []))
                    cur.execute(
                        "INSERT OR IGNORE INTO kanji VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                        (cp, strokes, grade, jlpt, 0, freq, rad_id, jis_code, skip_code, four_corner,
                         None, None, ",".join(on_r), ",".join(kun_r), "; ".join(meanings), blob),
                    )
                    all_rads = set(sub_rads)
                    if rad_id > 0:
                        all_rads.add(rad_id)
                    for r in all_rads:
                        cur.execute("INSERT OR IGNORE INTO kanji_radicals VALUES (?,?)", (r, cp))
                        rad_links += 1
                    count += 1
                elem.clear()
    print(f"[done]  Inserted {count} kanji records ({rad_links} multi-radical links)")

def emit_dedup_edges(adj_map: Dict[int, List[Tuple[float, int, int, int]]], edge_kind: int, max_rank: int) -> List[Tuple]:
    rows = []
    for cp, items in adj_map.items():
        items.sort(key=lambda x: -x[0])
        seen_eids: Set[int] = set()
        seen_neighbors: Set[int] = set()
        rank = 0
        for score, neighbor, eid, cnt in items:
            if eid in seen_eids or neighbor in seen_neighbors:
                continue
            seen_eids.add(eid)
            seen_neighbors.add(neighbor)
            rows.append((cp, edge_kind, rank, neighbor, eid, cnt, round(score, 3)))
            rank += 1
            if rank >= max_rank:
                break
    return rows

def parse_jmdict_and_build_graphs(
    gz_path: Path,
    conn: sqlite3.Connection,
    accents: Dict[Tuple[str, str], int],
) -> Dict[str, int]:
    if not gz_path.exists():
        raise FileNotFoundError(f"Missing {gz_path}. Run fetch_sources.py first.")
    print(f"[parse] {gz_path.name} ...")
    cur = conn.cursor()

    pair_stats: Dict[Tuple[int, int], Tuple[int, int, int]] = {}
    kanji_doc_freq: Dict[int, int] = defaultdict(int)
    yoji_entries: List[Tuple[str, int, int]] = []
    total_compounds = 0
    entry_count = 0

    surface_to_best: Dict[str, Tuple[int, int]] = {}
    pending_xrefs: List[Tuple[int, str, int]] = []
    entry_pos_map: Dict[int, int] = {}

    with gzip.open(gz_path, "rb") as f:
        for _, elem in ET.iterparse(f, events=("end",)):
            if elem.tag == "entry":
                eid = int(elem.findtext("ent_seq") or 0)
                k_elems = [ke.findtext("keb") for ke in elem.findall("k_ele") if ke.findtext("keb")]
                r_elems = [re_el.findtext("reb") for re_el in elem.findall("r_ele") if re_el.findtext("reb")]
                pri_tags = [p.text for p in elem.findall("k_ele/ke_pri") if p.text] + \
                           [p.text for p in elem.findall("r_ele/re_pri") if p.text]

                kanji_head = k_elems[0] if k_elems else None
                kana_head = r_elems[0] if r_elems else ""
                alt_forms = "|".join(k_elems[1:] + r_elems[1:]) or None
                freq_rank = priority_to_rank(pri_tags)

                pitch = accents.get((kanji_head or "", kana_head), accents.get(("", kana_head), 255))

                all_en_glosses: List[str] = []
                entry_pos_mask = 0
                is_yoji = False
                is_idiom = False
                is_proverb = False

                for s_idx, sense in enumerate(elem.findall("sense")):
                    s_pos = 0
                    for pos_el in sense.findall("pos"):
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
                                is_proverb = True

                    for xref_el in sense.findall("xref"):
                        if xref_el.text:
                            target = xref_el.text.split("・")[0].strip()
                            if target:
                                pending_xrefs.append((eid, target, s_pos))

                    entry_pos_mask |= s_pos
                    glosses = [
                        g.text for g in sense.findall("gloss")
                        if g.text and g.attrib.get("{http://www.w3.org/XML/1998/namespace}lang", "eng") == "eng"
                    ]
                    if glosses:
                        gloss_str = "; ".join(glosses)
                        all_en_glosses.append(gloss_str)
                        cur.execute("INSERT INTO senses VALUES (?,?,?,?,?,?)",
                                    (eid, s_idx, s_pos, gloss_str, None, None))

                if kana_head and all_en_glosses:
                    joined_en = " / ".join(all_en_glosses)
                    cur.execute(
                        "INSERT INTO entries VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                        (eid, kanji_head, kana_head, alt_forms, entry_pos_mask, 0, pitch,
                         freq_rank, freq_rank, freq_rank, freq_rank, None, 0),
                    )
                    cur.execute(
                        "INSERT INTO entries_fts(rowid, kanji_head, kana_head, en_glosses) VALUES (?,?,?,?)",
                        (eid, kanji_head or "", kana_head, joined_en),
                    )
                    entry_count += 1
                    entry_pos_map[eid] = entry_pos_mask

                    for form in k_elems + r_elems:
                        prev_s = surface_to_best.get(form)
                        if prev_s is None or freq_rank < prev_s[0]:
                            surface_to_best[form] = (freq_rank, eid)

                    seen_pairs_for_entry: Set[Tuple[int, int]] = set()
                    for k_form in k_elems:
                        if len(k_form) == 2 and is_kanji(k_form[0]) and is_kanji(k_form[1]):
                            c1, c2 = ord(k_form[0]), ord(k_form[1])
                            if c1 != c2 and c1 != 0x3005 and c2 != 0x3005 and (c1, c2) not in seen_pairs_for_entry:
                                seen_pairs_for_entry.add((c1, c2))
                                kanji_doc_freq[c1] += 1
                                kanji_doc_freq[c2] += 1
                                total_compounds += 1
                                prev = pair_stats.get((c1, c2))
                                if prev is None:
                                    pair_stats[(c1, c2)] = (freq_rank, eid, 1)
                                else:
                                    best_f = min(prev[0], freq_rank)
                                    best_e = eid if freq_rank < prev[0] else prev[1]
                                    pair_stats[(c1, c2)] = (best_f, best_e, prev[2] + 1)

                    if (is_yoji or is_idiom or is_proverb) and kanji_head:
                        kind = 1 if is_yoji else (3 if is_proverb else 2)
                        anchors = ",".join(dict.fromkeys(ch for ch in kanji_head if is_kanji(ch)))
                        cur.execute(
                            "INSERT OR IGNORE INTO idioms VALUES (?,?,?,?,?,?,?)",
                            (eid, kind, None, joined_en, None, None, anchors),
                        )
                        if is_yoji and len(kanji_head) == 4 and all(is_kanji(ch) for ch in kanji_head):
                            yoji_entries.append((kanji_head, eid, freq_rank))

                elem.clear()

    print(f"[done]  Inserted {entry_count} dictionary entries")

    linked_pairs = 0
    for eid, target, s_pos in pending_xrefs:
        target_info = surface_to_best.get(target)
        if not target_info:
            continue
        tid = target_info[1]
        if tid == eid:
            continue
        t_pos = entry_pos_map.get(tid, 0)
        is_vt_vi = ((s_pos & POS_BITS["vt"]) and (t_pos & POS_BITS["vi"])) or \
                   ((s_pos & POS_BITS["vi"]) and (t_pos & POS_BITS["vt"]))
        if is_vt_vi:
            cur.execute("UPDATE entries SET pair_entry_id = ? WHERE entry_id = ? AND pair_entry_id IS NULL", (tid, eid))
            cur.execute("UPDATE entries SET pair_entry_id = ? WHERE entry_id = ? AND pair_entry_id IS NULL", (eid, tid))
            linked_pairs += 1
    print(f"[done]  Linked {linked_pairs} transitive/intransitive verb pairs")

    print(f"[graph] Building Dokusha fisheye edges from {len(pair_stats)} unique 2-kanji pairs & {len(yoji_entries)} yojijukugo ...")
    left_adj: Dict[int, List[Tuple[float, int, int, int]]] = defaultdict(list)
    right_adj: Dict[int, List[Tuple[float, int, int, int]]] = defaultdict(list)
    yoji_adj: Dict[int, List[Tuple[float, int, int, int]]] = defaultdict(list)

    for (c1, c2), (best_freq, best_eid, cnt) in pair_stats.items():
        p_xy = cnt / max(1, total_compounds)
        p_x = kanji_doc_freq[c1] / max(1, total_compounds)
        p_y = kanji_doc_freq[c2] / max(1, total_compounds)
        pmi = math.log2(max(1e-9, p_xy / (p_x * p_y)))
        score = (1_000_000.0 / max(100, best_freq)) + max(0.0, pmi) * 10.0

        left_adj[c2].append((score, c1, best_eid, cnt))
        right_adj[c1].append((score, c2, best_eid, cnt))

    for word, eid, freq_rank in yoji_entries:
        score = 1_000_000.0 / max(100, freq_rank)
        cps = [ord(ch) for ch in word]
        for idx, cp in enumerate(cps):
            partner = cps[(idx + 1) % 4]
            if partner != cp:
                yoji_adj[cp].append((score, partner, eid, 1))

    # Cache up to 160 directional edges per side so the C++ fisheye pre-cache loads everything in one query
    edge_rows = []
    edge_rows.extend(emit_dedup_edges(left_adj, 0, 160))
    edge_rows.extend(emit_dedup_edges(right_adj, 1, 160))
    edge_rows.extend(emit_dedup_edges(yoji_adj, 2, 60))

    cur.executemany("INSERT INTO kanji_edges VALUES (?,?,?,?,?,?,?)", edge_rows)
    print(f"[done]  Inserted {len(edge_rows)} deduplicated directional + yojijukugo fisheye edges")

    return {k: v[1] for k, v in surface_to_best.items()}

def parse_tatoeba_sentences(conn: sqlite3.Connection, surface_to_eid: Dict[str, int], max_pairs: int = 80000) -> None:
    jpn_path = RAW_DIR / "tatoeba_jpn.tsv.bz2"
    eng_path = RAW_DIR / "tatoeba_eng.tsv.bz2"
    links_path = RAW_DIR / "tatoeba_jpn_eng.tsv.bz2"
    if not (jpn_path.exists() and eng_path.exists() and links_path.exists()):
        print("[warn]  Tatoeba files not found; skipping example sentences")
        return

    print("[parse] Tatoeba JP-EN sentence corpus ...")
    jpn_map: Dict[int, str] = {}
    with bz2.open(jpn_path, "rt", encoding="utf-8", errors="ignore") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 3:
                try:
                    jpn_map[int(parts[0])] = parts[2]
                except ValueError:
                    pass

    eng_map: Dict[int, str] = {}
    with bz2.open(eng_path, "rt", encoding="utf-8", errors="ignore") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 3:
                try:
                    eng_map[int(parts[0])] = parts[2]
                except ValueError:
                    pass

    cur = conn.cursor()
    seen_jp: Set[str] = set()
    sent_count = 0
    idx_count = 0

    with bz2.open(links_path, "rt", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if sent_count >= max_pairs:
                break
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 2:
                continue
            try:
                j_id, e_id = int(parts[0]), int(parts[1])
            except ValueError:
                continue
            jp_text = jpn_map.get(j_id)
            en_text = eng_map.get(e_id)
            if not jp_text or not en_text or jp_text in seen_jp:
                continue
            seen_jp.add(jp_text)

            spans_bytes = bytearray()
            linked_eids: Set[int] = set()
            pos = 0
            n = len(jp_text)
            while pos < n:
                matched = False
                for length in range(min(8, n - pos), 1, -1):
                    sub = jp_text[pos:pos + length]
                    eid = surface_to_eid.get(sub)
                    if eid and any(is_kanji(c) for c in sub):
                        b_off = len(jp_text[:pos].encode("utf-8"))
                        b_len = len(sub.encode("utf-8"))
                        spans_bytes.extend(struct.pack("<HHI", b_off, b_len, eid))
                        linked_eids.add(eid)
                        pos += length
                        matched = True
                        break
                if not matched:
                    pos += 1

            sent_count += 1
            cur.execute("INSERT INTO sentences VALUES (?,?,?,?)", (sent_count, jp_text, en_text, bytes(spans_bytes)))
            for eid in linked_eids:
                cur.execute("INSERT OR IGNORE INTO sentence_index VALUES (?,?)", (eid, sent_count))
                idx_count += 1

    print(f"[done]  Inserted {sent_count} JP-EN example sentences ({idx_count} lemma links)")

def parse_jmnedict(gz_path: Path, conn: sqlite3.Connection) -> None:
    if not gz_path.exists():
        print(f"[warn]  {gz_path.name} not found; skipping proper names")
        return
    print(f"[parse] {gz_path.name} (proper names) ...")
    cur = conn.cursor()
    count = 0

    name_pair_stats: Dict[Tuple[int, int], Tuple[int, int]] = {}

    with gzip.open(gz_path, "rb") as f:
        for _, elem in ET.iterparse(f, events=("end",)):
            if elem.tag == "entry":
                raw_id = int(elem.findtext("ent_seq") or 0)
                eid = 10_000_000 + raw_id
                k_elems = [ke.findtext("keb") for ke in elem.findall("k_ele") if ke.findtext("keb")]
                r_elems = [re_el.findtext("reb") for re_el in elem.findall("r_ele") if re_el.findtext("reb")]
                kanji_head = k_elems[0] if k_elems else None
                kana_head = r_elems[0] if r_elems else ""
                glosses = [t.text for t in elem.findall("trans/trans_det") if t.text]
                if kana_head and glosses:
                    joined = "; ".join(glosses)
                    cur.execute(
                        "INSERT OR IGNORE INTO entries VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                        (eid, kanji_head, kana_head, None, 1, 0, 255, 250000, 250000, 250000, 250000, None, 1),
                    )
                    cur.execute("INSERT OR IGNORE INTO senses VALUES (?,?,?,?,?,?)", (eid, 0, 1, joined, None, None))
                    cur.execute(
                        "INSERT INTO entries_fts(rowid, kanji_head, kana_head, en_glosses) VALUES (?,?,?,?)",
                        (eid, kanji_head or "", kana_head, joined),
                    )
                    count += 1

                    for k_form in k_elems:
                        if len(k_form) == 2 and is_kanji(k_form[0]) and is_kanji(k_form[1]):
                            c1, c2 = ord(k_form[0]), ord(k_form[1])
                            if c1 != c2 and c1 != 0x3005 and c2 != 0x3005:
                                prev = name_pair_stats.get((c1, c2))
                                if prev is None:
                                    name_pair_stats[(c1, c2)] = (eid, 1)
                                else:
                                    name_pair_stats[(c1, c2)] = (prev[0], prev[1] + 1)
                elem.clear()
    print(f"[done]  Inserted {count} JMnedict proper-name entries")

    # Precompute directional name edges (edge_kind 3 = left/prefix name, 4 = right/suffix name)
    name_left_adj: Dict[int, List[Tuple[float, int, int, int]]] = defaultdict(list)
    name_right_adj: Dict[int, List[Tuple[float, int, int, int]]] = defaultdict(list)
    for (c1, c2), (best_eid, cnt) in name_pair_stats.items():
        score = 2.5 + math.log2(1.0 + cnt)
        name_left_adj[c2].append((score, c1, best_eid, cnt))
        name_right_adj[c1].append((score, c2, best_eid, cnt))

    name_edge_rows = []
    name_edge_rows.extend(emit_dedup_edges(name_left_adj, 3, 160))
    name_edge_rows.extend(emit_dedup_edges(name_right_adj, 4, 160))
    cur.executemany("INSERT INTO kanji_edges VALUES (?,?,?,?,?,?,?)", name_edge_rows)
    print(f"[done]  Inserted {len(name_edge_rows)} precomputed JMnedict fisheye edges")

def main() -> None:
    parser = argparse.ArgumentParser(description="Compile Dai-Jishow SQLite corpus")
    parser.add_argument("--out", type=Path, default=Path("build/daijishow.db"), help="Output SQLite path")
    parser.add_argument("--include-names", action="store_true", help="Include JMnedict proper names")
    parser.add_argument("--max-sentences", type=int, default=80000, help="Max Tatoeba JP-EN pairs to index")
    args = parser.parse_args()

    args.out.parent.mkdir(parents=True, exist_ok=True)
    if args.out.exists():
        args.out.unlink()

    conn = sqlite3.connect(str(args.out))
    conn.executescript(SCHEMA_SQL)

    accents = load_kanjium_accents(RAW_DIR / "kanjium_accents.txt")
    kvg_map = parse_kanjivg(RAW_DIR / "kanjivg.xml.gz")
    parse_kanjidic2(RAW_DIR / "kanjidic2.xml.gz", conn, kvg_map)
    surface_to_eid = parse_jmdict_and_build_graphs(RAW_DIR / "JMdict_e.gz", conn, accents)
    parse_tatoeba_sentences(conn, surface_to_eid, max_pairs=args.max_sentences)

    if args.include_names:
        parse_jmnedict(RAW_DIR / "JMnedict.xml.gz", conn)

    conn.commit()
    print("[opt]   Running ANALYZE & VACUUM for mmap alignment ...")
    conn.execute("ANALYZE;")
    conn.execute("VACUUM;")
    conn.close()
    print(f"[ready] {args.out} ({args.out.stat().st_size / 1_048_576:.2f} MB)")

if __name__ == "__main__":
    main()

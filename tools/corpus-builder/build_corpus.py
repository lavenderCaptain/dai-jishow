#!/usr/bin/env python3
"""Compiles JMdict, KANJIDIC2, KanjiVG, and derived Dokusha graphs into daijishow.db."""

import argparse
import gzip
import math
import sqlite3
import struct
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from pack_kanjivg import pack_strokes_blob

RAW_DIR = Path(__file__).parent / "raw_data"

SCHEMA_SQL = """
PRAGMA journal_mode = OFF;
PRAGMA synchronous = OFF;
PRAGMA page_size = 4096;

CREATE TABLE entries (
    entry_id        INTEGER PRIMARY KEY,
    kanji_head      TEXT,
    kana_head       TEXT NOT NULL,
    alt_forms       TEXT,
    pos_mask        INTEGER NOT NULL DEFAULT 0,
    register_mask   INTEGER NOT NULL DEFAULT 0,
    pitch_accent    INTEGER NOT NULL DEFAULT 255,
    freq_overall    INTEGER NOT NULL DEFAULT 999999,
    freq_novel      INTEGER NOT NULL DEFAULT 999999,
    freq_anime      INTEGER NOT NULL DEFAULT 999999,
    freq_news       INTEGER NOT NULL DEFAULT 999999,
    pair_entry_id   INTEGER,
    is_name         INTEGER NOT NULL DEFAULT 0
) WITHOUT ROWID;

CREATE TABLE senses (
    entry_id        INTEGER NOT NULL,
    sense_idx       INTEGER NOT NULL,
    pos_mask        INTEGER NOT NULL DEFAULT 0,
    en_glosses      TEXT NOT NULL,
    ja_glosses      TEXT,
    misc_notes      TEXT,
    PRIMARY KEY (entry_id, sense_idx)
) WITHOUT ROWID;

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
    stroke_blob     BLOB NOT NULL
) WITHOUT ROWID;

CREATE TABLE kanji_radicals (
    radical_id      INTEGER NOT NULL,
    codepoint       INTEGER NOT NULL,
    PRIMARY KEY (radical_id, codepoint)
) WITHOUT ROWID;

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
    idiom_kind       INTEGER NOT NULL,
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
    token_spans     BLOB NOT NULL
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
}

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

def build_sample_data(conn: sqlite3.Connection) -> None:
    """Populates a realistic mini-corpus for immediate C++/UI development."""
    cur = conn.cursor()

    sample_entries = [
        (1001, "称賛", "しょうさん", "賞賛", POS_BITS["n"] | POS_BITS["vs"] | POS_BITS["vt"], 0, 0, 3200, None, "praise; admiration; applause", "ほめたたえること。"),
        (1002, "愛称", "あいしょう", None, POS_BITS["n"], 0, 0, 4100, None, "pet name; nickname; term of endearment", "親しみをこめて呼ぶ名前。"),
        (1003, "名称", "めいしょう", None, POS_BITS["n"], 0, 0, 1800, None, "name; title; designation", "物事の呼び名。"),
        (1004, "称号", "しょうごう", None, POS_BITS["n"], 0, 0, 5600, None, "title; degree; appellation", "身分や資格を表す呼び名。"),
        (1005, "自称", "じしょう", None, POS_BITS["n"] | POS_BITS["vs"], 0, 0, 4900, None, "self-styled; self-proclaimed", "自分でそう名乗ること。"),
        (1006, "異称", "いしょう", None, POS_BITS["n"], 0, 0, 28000, None, "another name; alias; epithet", "通常の呼び名と異なる名。"),
        (1007, "開く", "あく", None, POS_BITS["v5"] | POS_BITS["vi"], 0, 0, 650, 1008, "to open (intransitive); to become empty", "閉じていたものが開いた状態になる。"),
        (1008, "開ける", "あける", None, POS_BITS["v1"] | POS_BITS["vt"], 0, 3, 720, 1007, "to open (transitive); to unwrap", "閉じたものを開いた状態にする。"),
        (1009, "猫の手も借りたい", "ねこのてもかりたい", None, POS_BITS["exp"] | POS_BITS["id"], 0, 255, 9500, None, "to be extremely busy (so busy one would borrow a cat's paw)", "非常に忙しくて誰でもいいから手伝ってほしい様子。"),
        (1010, "一石二鳥", "いっせきにちょう", None, POS_BITS["n"] | POS_BITS["yoji"], 0, 255, 6200, None, "killing two birds with one stone", "一つの行為で二つの利益を得ること。"),
    ]

    for eid, khead, kread, alt, pos, reg, pitch, freq, pair_id, en_g, ja_g in sample_entries:
        cur.execute(
            "INSERT INTO entries VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (eid, khead, kread, alt, pos, reg, pitch, freq, freq, freq, freq, pair_id, 0),
        )
        cur.execute("INSERT INTO senses VALUES (?,?,?,?,?,?)", (eid, 0, pos, en_g, ja_g, None))
        cur.execute("INSERT INTO entries_fts(rowid, kanji_head, kana_head, en_glosses) VALUES (?,?,?,?)",
                    (eid, khead or "", kread, en_g))

    # Idioms
    cur.execute(
        "INSERT INTO idioms VALUES (?,?,?,?,?,?,?)",
        (1009, 2, "Want to borrow even a cat's paw", "To be swamped with work / extremely busy",
         "Up to one's eyeballs in work", None, "猫,手,借りる"),
    )
    cur.execute(
        "INSERT INTO idioms VALUES (?,?,?,?,?,?,?)",
        (1010, 1, "One stone, two birds", "Achieving two goals with a single effort",
         "Kill two birds with one stone", "From Jin Shu (Book of Jin)", "一,石,二,鳥"),
    )

    # Sample Kanji ('称', '賛', '愛', '開')
    dummy_blob = pack_strokes_blob(["M 20,20 L 80,20", "M 50,15 L 50,90"])
    sample_kanji = [
        (ord("称"), 10, 8, 2, 3, 1180, 115, 0x3E4E, pack_skip("1-5-5"), pack_four_corner("2799.2"),
         ord("稱"), None, "ショウ", "たた.える,とな.える", "appellation, praise, admire, title", dummy_blob),
        (ord("賛"), 15, 5, 2, 5, 920, 154, 0x3B3F, pack_skip("2-8-7"), pack_four_corner("2480.6"),
         ord("贊"), None, "サン", "たす.ける,たた.える", "approve, praise, title, assist", dummy_blob),
        (ord("愛"), 13, 4, 3, 7, 640, 61, 0x3026, pack_skip("2-4-9"), pack_four_corner("2024.7"),
         None, None, "アイ", "いと.しい,め.でる", "love, affection, favourite", dummy_blob),
        (ord("開"), 12, 3, 4, 8, 210, 169, 0x332B, pack_skip("3-8-4"), pack_four_corner("7744.1"),
         None, None, "カイ", "ひら.く,あ.く,あ.ける", "open, unfold, unseal", dummy_blob),
    ]
    for row in sample_kanji:
        cur.execute("INSERT INTO kanji VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", row)
        cur.execute("INSERT INTO kanji_radicals VALUES (?,?)", (row[6], row[0]))

    # Dokusha Prefix/Suffix Edges around '称'
    edges = [
        (ord("称"), 0, 0, ord("愛"), 1002, 1, 8.4),
        (ord("称"), 0, 1, ord("名"), 1003, 1, 9.1),
        (ord("称"), 0, 2, ord("自"), 1005, 1, 7.8),
        (ord("称"), 0, 3, ord("異"), 1006, 1, 5.2),
        (ord("称"), 1, 0, ord("賛"), 1001, 1, 8.9),
        (ord("称"), 1, 1, ord("号"), 1004, 1, 7.6),
    ]
    cur.executemany("INSERT INTO kanji_edges VALUES (?,?,?,?,?,?,?)", edges)

    # Sample Sentence
    jp = "彼の勇気ある行動は多くの人々から称賛された。"
    en = "His courageous actions were praised by many people."
    # Span for '称賛' at UTF-8 byte offset 39, length 6 -> entry_id 1001
    off = len("彼の勇気ある行動は多くの人々から".encode("utf-8"))
    spans = struct.pack("<HHI", off, len("称賛".encode("utf-8")), 1001)
    cur.execute("INSERT INTO sentences VALUES (?,?,?,?)", (1, jp, en, spans))
    cur.execute("INSERT INTO sentence_index VALUES (?,?)", (1001, 1))

def parse_kanjivg(gz_path: Path) -> Dict[int, Tuple[bytes, List[int]]]:
    """Returns {codepoint: (packed_stroke_blob, [radical_ids])}."""
    if not gz_path.exists():
        print(f"[warn] {gz_path} not found; skipping stroke vectors")
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
                        out[cp] = (pack_strokes_blob(paths), [])
                    except ValueError:
                        pass
                elem.clear()
    print(f"[done]  Loaded {len(out)} KanjiVG stroke diagrams")
    return out

def parse_kanjidic2(gz_path: Path, conn: sqlite3.Connection, kvg_map: Dict[int, Tuple[bytes, List[int]]]) -> None:
    if not gz_path.exists():
        raise FileNotFoundError(f"Missing {gz_path}. Run fetch_sources.py first or use --sample.")
    print(f"[parse] {gz_path.name} ...")
    cur = conn.cursor()
    count = 0
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

                    blob = kvg_map.get(cp, (b"\x00", []))[0]
                    cur.execute(
                        "INSERT OR IGNORE INTO kanji VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                        (cp, strokes, grade, jlpt, 0, freq, rad_id, jis_code, skip_code, four_corner,
                         None, None, ",".join(on_r), ",".join(kun_r), "; ".join(meanings), blob),
                    )
                    if rad_id > 0:
                        cur.execute("INSERT OR IGNORE INTO kanji_radicals VALUES (?,?)", (rad_id, cp))
                    count += 1
                elem.clear()
    print(f"[done]  Inserted {count} kanji records")

def parse_jmdict_and_build_graphs(gz_path: Path, conn: sqlite3.Connection) -> None:
    if not gz_path.exists():
        raise FileNotFoundError(f"Missing {gz_path}. Run fetch_sources.py first or use --sample.")
    print(f"[parse] {gz_path.name} ...")
    cur = conn.cursor()

    # Track 2-kanji compounds for Dokusha Fisheye Graph:
    # pair_stats[(c1, c2)] = (best_freq, best_entry_id, count)
    pair_stats: Dict[Tuple[int, int], Tuple[int, int, int]] = {}
    kanji_doc_freq: Dict[int, int] = defaultdict(int)
    total_compounds = 0
    entry_count = 0

    with gzip.open(gz_path, "rb") as f:
        for _, elem in ET.iterparse(f, events=("end",)):
            if elem.tag == "entry":
                eid = int(elem.findtext("ent_seq") or 0)
                k_elems = [ke.findtext("keb") for ke in elem.findall("k_ele") if ke.findtext("keb")]
                r_elems = [re_el.findtext("reb") for re_el in elem.findall("r_ele") if re_el.findtext("reb")]
                pri_tags = [p.text for p in elem.findall("k_ele/ke_pri") if p.text] +                            [p.text for p in elem.findall("r_ele/re_pri") if p.text]

                kanji_head = k_elems[0] if k_elems else None
                kana_head = r_elems[0] if r_elems else ""
                alt_forms = "|".join(k_elems[1:] + r_elems[1:]) or None
                freq_rank = priority_to_rank(pri_tags)

                all_en_glosses: List[str] = []
                entry_pos_mask = 0
                is_yoji = False
                is_idiom = False

                for s_idx, sense in enumerate(elem.findall("sense")):
                    s_pos = 0
                    for pos_el in sense.findall("pos"):
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
                        elif mcode in POS_BITS:
                            s_pos |= POS_BITS[mcode]

                    entry_pos_mask |= s_pos
                    glosses = [g.text for g in sense.findall("gloss") if g.text and g.attrib.get("{http://www.w3.org/XML/1998/namespace}lang", "eng") == "eng"]
                    if glosses:
                        gloss_str = "; ".join(glosses)
                        all_en_glosses.append(gloss_str)
                        cur.execute("INSERT INTO senses VALUES (?,?,?,?,?,?)",
                                    (eid, s_idx, s_pos, gloss_str, None, None))

                if kana_head and all_en_glosses:
                    joined_en = " / ".join(all_en_glosses)
                    cur.execute(
                        "INSERT INTO entries VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                        (eid, kanji_head, kana_head, alt_forms, entry_pos_mask, 0, 255,
                         freq_rank, freq_rank, freq_rank, freq_rank, None, 0),
                    )
                    cur.execute(
                        "INSERT INTO entries_fts(rowid, kanji_head, kana_head, en_glosses) VALUES (?,?,?,?)",
                        (eid, kanji_head or "", kana_head, joined_en),
                    )
                    entry_count += 1

                    # Index 2-kanji compounds for Dokusha Fisheye Explorer
                    if kanji_head and len(kanji_head) == 2 and is_kanji(kanji_head[0]) and is_kanji(kanji_head[1]):
                        c1, c2 = ord(kanji_head[0]), ord(kanji_head[1])
                        if c1 != c2 and c1 != 0x3005 and c2 != 0x3005:
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

                    # Index Idioms & Yojijukugo
                    if (is_yoji or is_idiom) and kanji_head:
                        kind = 1 if is_yoji else 2
                        anchors = ",".join(dict.fromkeys(ch for ch in kanji_head if is_kanji(ch)))
                        cur.execute(
                            "INSERT OR IGNORE INTO idioms VALUES (?,?,?,?,?,?,?)",
                            (eid, kind, None, joined_en, None, None, anchors),
                        )

                elem.clear()

    print(f"[done]  Inserted {entry_count} dictionary entries")
    print(f"[graph] Building Dokusha prefix/suffix fisheye edges from {len(pair_stats)} unique 2-kanji pairs ...")

    left_adj: Dict[int, List[Tuple[float, int, int, int]]] = defaultdict(list)
    right_adj: Dict[int, List[Tuple[float, int, int, int]]] = defaultdict(list)

    for (c1, c2), (best_freq, best_eid, cnt) in pair_stats.items():
        # Combine frequency rank + Pointwise Mutual Information
        p_xy = cnt / max(1, total_compounds)
        p_x = kanji_doc_freq[c1] / max(1, total_compounds)
        p_y = kanji_doc_freq[c2] / max(1, total_compounds)
        pmi = math.log2(max(1e-9, p_xy / (p_x * p_y)))
        score = (1_000_000.0 / max(100, best_freq)) + max(0.0, pmi) * 10.0

        left_adj[c2].append((score, c1, best_eid, cnt))   # c1 precedes center c2
        right_adj[c1].append((score, c2, best_eid, cnt))  # c2 follows center c1

    edge_rows = []
    for cp, items in left_adj.items():
        items.sort(key=lambda x: -x[0])
        for rank, (score, neighbor, eid, cnt) in enumerate(items[:40]):
            edge_rows.append((cp, 0, rank, neighbor, eid, cnt, round(score, 3)))

    for cp, items in right_adj.items():
        items.sort(key=lambda x: -x[0])
        for rank, (score, neighbor, eid, cnt) in enumerate(items[:40]):
            edge_rows.append((cp, 1, rank, neighbor, eid, cnt, round(score, 3)))

    cur.executemany("INSERT INTO kanji_edges VALUES (?,?,?,?,?,?,?)", edge_rows)
    print(f"[done]  Inserted {len(edge_rows)} directional fisheye edges")

def main() -> None:
    parser = argparse.ArgumentParser(description="Compile Dai-Jishow SQLite corpus")
    parser.add_argument("--out", type=Path, default=Path("build/daijishow.db"), help="Output SQLite path")
    parser.add_argument("--sample", action="store_true", help="Build fast sample DB without downloading XML")
    args = parser.parse_args()

    args.out.parent.mkdir(parents=True, exist_ok=True)
    if args.out.exists():
        args.out.unlink()

    conn = sqlite3.connect(str(args.out))
    conn.executescript(SCHEMA_SQL)

    if args.sample:
        print("[mode]  Building sample daijishow.db ...")
        build_sample_data(conn)
    else:
        kvg_map = parse_kanjivg(RAW_DIR / "kanjivg.xml.gz")
        parse_kanjidic2(RAW_DIR / "kanjidic2.xml.gz", conn, kvg_map)
        parse_jmdict_and_build_graphs(RAW_DIR / "JMdict_e.gz", conn)

    conn.commit()
    print("[opt]   Running ANALYZE & VACUUM for mmap alignment ...")
    conn.execute("ANALYZE;")
    conn.execute("VACUUM;")
    conn.close()
    print(f"[ready] {args.out} ({args.out.stat().st_size / 1_048_576:.2f} MB)")

if __name__ == "__main__":
    main()

# 04 — Master Corpus Inventory & SQLite Schema

`tools/corpus-builder` compiles open linguistic datasets into a single normalized, read-only SQLite database (`daijishow.db`) shared identically across all platforms.

> **Status snapshot.** The tables below are the **designed** schema; the
> **current `daijishow.db`** ships a subset. As of the current build:
> `entries` (~963k), `senses` (~998k), `kanji` (13,108), `kanji_edges`
> (~384k), `kanji_radicals` (~33k), `idioms` (4,177), `sentences` (80,000) and
> `sentence_index` (~193k) are populated. `collocations`, `keigo_ladders`, and
> `idiom_triggers` exist in the schema but are **empty (0 rows)** in the current
> ETL — the macOS UI guards them, so those sections simply render nothing until
> the ETL fills them. Designed-but-not-yet-ingested sources (Wiktionary monolingual
> *Kokugo* glosses, BCCWJ/Jiten split frequency ranks, NINJAL collocations) are
> listed below as targets.
>
> **Licenses:** JMdict / JMnedict are **CC BY 4.0**; KANJIDIC2 is **CC BY-SA
> 4.0**; KanjiVG and the Kanjium pitch accents are **Open Source**; Tatoeba
> sentences are **CC BY 2.0**. The About window credits all of these.

---

## 1. Master Linguistic Source Stack

| Domain | Upstream Source(s) | What It Provides |
| :--- | :--- | :--- |
| **Core Bilingual Lexicon** | **JMdict** + **Jitendex** enrichments | ~210k entries, headwords, readings, POS bitmasks, dialect/register tags, antonyms/xrefs |
| **Proper Names** | **JMnedict (ENAMDICT)** | ~740k people, places, train stations, companies, historical names (`is_name = 1`) |
| **Monolingual Glosses** | **Wiktionary Japanese Monolingual Dump** | Native *Kokugo* definitions (all words tokenized for recursive "jump" lookups) |
| **Kanji Metadata** | **KANJIDIC2** + **Kanjium** + **CHISE IDS** | *On/Kun* readings, strokes, grade, JLPT, Kanken, SKIP, 4-Corner, JIS, *Kyūjitai/Shinjitai*, phonetic series |
| **Stroke Vectors & Radicals** | **KanjiVG** | Stroke-by-stroke vector paths (quantized to `uint16` binary blobs) + sub-component radical trees |
| **Pitch Accent** | **Kanjium Pitch Accent** + **UniDic** | Tokyo pitch-accent drop positions (`Heiban`, `Atamadaka`, `Nakadaka`, `Odaka`) |
| **Frequency Profiles** | **BCCWJ** + **Jiten / JPDB** | Separate frequency ranks for Novels, Anime/Drama, News, and Spoken Japanese |
| **Example Sentences** | **Tatoeba / Tanaka Corpus** | ~100k deduplicated JP/EN sentence pairs pre-indexed by lemmatized `entry_id` |
| **Idioms & Proverbs** | **JMdict (`yoji`/`id`)** + **Wiktionary / Wikiquote** | *Yojijukugo* (四字熟語), *Kan'yōku* (慣用句), and *Kotowaza* (ことわざ) with literal + figurative glosses |
| **Grammar & Collocations** | **Open Grammar Lists** + **NINJAL-LWP** | Compound grammar patterns (`〜に違いない`) and statistical `Noun + を + Verb` collocations |
| **Keigo & Transitivity** | **JMdict (`hon`/`hum`)** + **Transitivity Pair Lists** | Honorific/humble register ladders and *Jidōshi ↔ Tadōshi* verb pairs (`開く ↔ 開ける`) |
| **Optional User Plugins** | **Yomitan ZIP Format** | Runtime `ATTACH DATABASE` importer for user-supplied dictionaries |

---

## 2. Normalized SQLite DDL (`daijishow.db`)

```sql
PRAGMA journal_mode = OFF;
PRAGMA synchronous = OFF;
PRAGMA page_size = 4096;

-- Core Dictionary Entries (General + Proper Names + Monolingual Kokugo)
CREATE TABLE entries (
    entry_id        INTEGER PRIMARY KEY,
    kanji_head      TEXT,
    kana_head       TEXT NOT NULL,
    alt_forms       TEXT,
    pos_mask        INTEGER NOT NULL,
    register_mask   INTEGER NOT NULL DEFAULT 0, -- pol, hon, hum, col, sl, arch, on-mim, dialect
    pitch_accent    INTEGER NOT NULL DEFAULT 255, -- 255 = unknown, 0 = heiban, 1..N = drop mora
    freq_overall    INTEGER NOT NULL DEFAULT 999999,
    freq_novel      INTEGER NOT NULL DEFAULT 999999,
    freq_anime      INTEGER NOT NULL DEFAULT 999999,
    freq_news       INTEGER NOT NULL DEFAULT 999999,
    pair_entry_id   INTEGER,                    -- Transitive/Intransitive partner entry_id
    is_name         INTEGER NOT NULL DEFAULT 0
) WITHOUT ROWID;

CREATE TABLE senses (
    entry_id        INTEGER NOT NULL,
    sense_idx       INTEGER NOT NULL,
    pos_mask        INTEGER NOT NULL,
    en_glosses      TEXT NOT NULL,
    ja_glosses      TEXT,                       -- Monolingual Kokugo definition
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

-- Kanji Reference & Quantized Binary Stroke Polylines
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
    stroke_blob     BLOB NOT NULL               -- Quantized uint16 stroke polylines
) WITHOUT ROWID;

CREATE TABLE kanji_radicals (
    radical_id      INTEGER NOT NULL,
    codepoint       INTEGER NOT NULL,
    PRIMARY KEY (radical_id, codepoint)
) WITHOUT ROWID;

-- Dokusha Spatial Fisheye Graph (Compounds, Yojijukugo & Confusables)
CREATE TABLE kanji_edges (
    center_cp       INTEGER NOT NULL,
    edge_kind       INTEGER NOT NULL,           -- 0 = Prefix Compound, 1 = Suffix Compound, 2 = Yojijukugo, 3 = Confusable
    rank            INTEGER NOT NULL,
    neighbor_cp     INTEGER NOT NULL,
    top_entry_id    INTEGER NOT NULL,
    compound_cnt    INTEGER NOT NULL,
    pmi_score       REAL NOT NULL,
    PRIMARY KEY (center_cp, edge_kind, rank)
) WITHOUT ROWID;

-- Idioms, Proverbs & Conjugated Multi-Word Trigger Index
CREATE TABLE idioms (
    entry_id         INTEGER PRIMARY KEY,
    idiom_kind       INTEGER NOT NULL,          -- 1 = Yojijukugo, 2 = Kan'yoku, 3 = Kotowaza
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

-- Collocations & Keigo Register Ladders
CREATE TABLE collocations (
    head_entry_id   INTEGER NOT NULL,
    rel_type        INTEGER NOT NULL,           -- 1 = Noun+を+Verb, 2 = Adj+Noun, 3 = Adv+Verb
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

-- Lemmatized Example Sentences
CREATE TABLE sentences (
    sent_id         INTEGER PRIMARY KEY,
    jp_text         TEXT NOT NULL,
    en_text         TEXT NOT NULL,
    token_spans     BLOB NOT NULL               -- Binary [byte_off:u16, byte_len:u16, entry_id:u32] array
) WITHOUT ROWID;

CREATE TABLE sentence_index (
    entry_id        INTEGER NOT NULL,
    sent_id         INTEGER NOT NULL,
    PRIMARY KEY (entry_id, sent_id)
) WITHOUT ROWID;
```

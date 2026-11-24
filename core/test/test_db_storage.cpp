/**
 * @file test_db_storage.cpp
 * @brief DB-backed integration tests using a hermetic in-memory SQLite fixture.
 *
 * Mirrors the exact `SCHEMA_SQL` schema from `tools/corpus-builder/build_corpus.py`
 * on a tiny deterministic `:memory:` database (~20 rows) so the C++ test suite
 * verifies every SQL query, FTS5 fallback, ruby solver, stroke-blob decoder,
 * token-span mapper, radical search, idiom ranking, fisheye graph path, and C
 * ABI marshalling without touching the 221 MB production corpus.
 */
#include "dj_test.hpp"
#include "dj_internal.hpp"

#include <sqlite3.h>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

namespace {

constexpr const char* kSchemaSql = R"SQL(
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

CREATE INDEX idx_entries_kana  ON entries(is_name, kana_head, freq_overall);
CREATE INDEX idx_entries_kanji ON entries(is_name, kanji_head, freq_overall);

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
)SQL";

std::vector<uint8_t> make_stroke_blob(const std::vector<std::vector<std::pair<uint16_t, uint16_t>>>& strokes) {
    std::vector<uint8_t> blob;
    blob.push_back(static_cast<uint8_t>(strokes.size()));
    for (const auto& s : strokes) {
        blob.push_back(static_cast<uint8_t>(s.size()));
        for (const auto& pt : s) {
            blob.push_back(static_cast<uint8_t>(pt.first & 0xFF));
            blob.push_back(static_cast<uint8_t>((pt.first >> 8) & 0xFF));
            blob.push_back(static_cast<uint8_t>(pt.second & 0xFF));
            blob.push_back(static_cast<uint8_t>((pt.second >> 8) & 0xFF));
        }
    }
    return blob;
}

std::vector<uint8_t> make_token_span(uint16_t b_off, uint16_t b_len, uint32_t entry_id) {
    return {
        static_cast<uint8_t>(b_off & 0xFF),
        static_cast<uint8_t>((b_off >> 8) & 0xFF),
        static_cast<uint8_t>(b_len & 0xFF),
        static_cast<uint8_t>((b_len >> 8) & 0xFF),
        static_cast<uint8_t>(entry_id & 0xFF),
        static_cast<uint8_t>((entry_id >> 8) & 0xFF),
        static_cast<uint8_t>((entry_id >> 16) & 0xFF),
        static_cast<uint8_t>((entry_id >> 24) & 0xFF),
    };
}

struct DbFixture {
    sqlite3* db = nullptr;

    DbFixture() {
        int rc = sqlite3_open(":memory:", &db);
        if (rc != SQLITE_OK) return;
        exec(kSchemaSql);
        seed();
    }

    ~DbFixture() {
        if (db) sqlite3_close(db);
    }

    void exec(const char* sql) {
        char* err = nullptr;
        int rc = sqlite3_exec(db, sql, nullptr, nullptr, &err);
        if (rc != SQLITE_OK) {
            std::fprintf(stderr, "SQLite fixture error: %s\nSQL: %s\n", err ? err : "unknown", sql);
            if (err) sqlite3_free(err);
        }
        CHECK_EQ(rc, SQLITE_OK);
    }

    void insert_kanji(uint32_t cp, int strokes, int grade, int jlpt, int freq, int rad,
                      int skip, int fc, uint32_t kyu,
                      const char* on, const char* kun, const char* meanings,
                      const std::vector<uint8_t>& blob) {
        sqlite3_stmt* stmt = nullptr;
        sqlite3_prepare_v2(
            db,
            "INSERT INTO kanji (codepoint, strokes, grade, jlpt, freq_rank, radical_id, jis_code, skip_code, four_corner, kyujitai_cp, on_readings, kun_readings, meanings, stroke_blob) "
            "VALUES (?1, ?2, ?3, ?4, ?5, ?6, 0, ?7, ?8, ?9, ?10, ?11, ?12, ?13);",
            -1, &stmt, nullptr);
        sqlite3_bind_int64(stmt, 1, cp);
        sqlite3_bind_int(stmt, 2, strokes);
        sqlite3_bind_int(stmt, 3, grade);
        sqlite3_bind_int(stmt, 4, jlpt);
        sqlite3_bind_int(stmt, 5, freq);
        sqlite3_bind_int(stmt, 6, rad);
        sqlite3_bind_int(stmt, 7, skip);
        sqlite3_bind_int(stmt, 8, fc);
        if (kyu) sqlite3_bind_int64(stmt, 9, kyu);
        else sqlite3_bind_null(stmt, 9);
        sqlite3_bind_text(stmt, 10, on, -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 11, kun, -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 12, meanings, -1, SQLITE_TRANSIENT);
        sqlite3_bind_blob(stmt, 13, blob.data(), static_cast<int>(blob.size()), SQLITE_TRANSIENT);
        CHECK_EQ(sqlite3_step(stmt), SQLITE_DONE);
        sqlite3_finalize(stmt);
    }

    void seed() {
        // Core entries
        exec(R"SQL(
            INSERT INTO entries (entry_id, kanji_head, kana_head, alt_forms, pos_mask, pitch_accent, freq_overall, pair_entry_id, is_name) VALUES
              (1,  '日本',   'にほん',   'にっぽん', 1, 2, 10,   NULL, 0),
              (2,  '日本語', 'にほんご', '',         1, 0, 50,   NULL, 0),
              (3,  '日本花', 'にほんばな', '',       1, 0, 120,  NULL, 1),
              (4,  '二本',   'にほん',   '',         1, 1, 200,  NULL, 0),
              (5,  '食べる', 'たべる',   '',         2, 2, 20,   NULL, 0),
              (6,  '開ける', 'あける',   '',         18, 0, 30,  7,    0),
              (7,  '開く',   'あく',     '',         36, 0, 40,  6,    0),
              (8,  '学校',   'がっこう', '',         1, 0, 15,   NULL, 0),
              (9,  '山車',   'だし',     '',         1, 1, 800,  NULL, 0),
              (10, '矛山車', 'ほこだし', '',         1, 0, 5000, NULL, 0),
              (11, '山車屋', 'だしや',   '',         1, 0, 6000, NULL, 0),
              (12, '酒',     'さけ',     '',         1, 0, 80,   NULL, 0),
              (13, '為',     'ため',     '',         1, 2, 90,   NULL, 0),
              (14, '穴',     'あな',     '',         1, 2, 300,  NULL, 0),
              (15, '銀行',   'ぎんこう', '',         1, 0, 60,   NULL, 0),
              (16, NULL,     'ばんく',   '',         1, 1, 50,   NULL, 0),
              (17, '堤',     'つつみ',   '',         1, 0, 400,  NULL, 0),
              (18, '口座',   'こうざ',   '',         1, 0, 500,  NULL, 0),
              (19, '川',     'かわ',     '',         1, 2, 70,   NULL, 0),
              (20, '川越',   'かわごえ', '',         1, 0, 100,  NULL, 1),
              (21, '川越',   'かわこし', '',         1, 0, 900,  NULL, 0),
              (22, '山',     'やま',     '',         1, 2, 25,   NULL, 0),
              (30, '犬も歩けば棒に当たる', 'いぬもあるけばぼうにあたる', '', 4096, 255, 400, NULL, 0),
              (31, '犬猿の仲',             'けんえんのなか',             '', 2048, 255, 350, NULL, 0),
              (32, '忠犬',                 'ちゅうけん',                 '', 1,    0,   900, NULL, 0),
              (33, '狂犬病',               'きょうけんびょう',           '', 1,    3,   950, NULL, 0),
              (34, '犬死に',               'いぬじに',                   '', 4096, 0,   600, NULL, 0);

            INSERT INTO senses (entry_id, sense_idx, pos_mask, en_glosses, ja_glosses) VALUES
              (1,  0, 1, 'Japan', 'にほん'),
              (2,  0, 1, 'Japanese language', NULL),
              (3,  0, 1, 'Nihonbana (surname)', NULL),
              (4,  0, 1, 'two long objects', NULL),
              (5,  0, 2, 'to eat; consume', 'たべる'),
              (5,  1, 2, 'to live on (income)', NULL),
              (6,  0, 18, 'to open (a door)', NULL),
              (7,  0, 36, 'to open (intransitive)', NULL),
              (8,  0, 1, 'school', NULL),
              (9,  0, 1, 'festival float', NULL),
              (10, 0, 1, 'halberd float', NULL),
              (11, 0, 1, 'float shop', NULL),
              (12, 0, 1, 'alcohol; sake', NULL),
              (13, 0, 1, 'benefit; sake; advantage', NULL),
              (14, 0, 1, 'hole; to bore', NULL),
              (15, 0, 1, 'bank (financial)', NULL),
              (16, 0, 1, 'bank', NULL),
              (17, 0, 1, 'river bank', NULL),
              (18, 0, 1, 'bank account', NULL),
              (19, 0, 1, 'river', NULL),
              (20, 0, 1, 'Kawagoe', NULL),
              (21, 0, 1, 'river crossing', NULL),
              (22, 0, 1, 'mountain', NULL),
              (30, 0, 4096, 'every dog has its day', NULL),
              (31, 0, 2048, 'like cats and dogs', NULL),
              (34, 0, 4096, 'meaningless death', NULL);

            INSERT INTO entries_fts (rowid, kanji_head, kana_head, en_glosses) VALUES
              (1,  '日本', 'にほん', 'Japan'),
              (8,  '学校', 'がっこう', 'school'),
              (12, '酒',   'さけ',   'alcohol; sake'),
              (13, '為',   'ため',   'benefit; sake; advantage'),
              (14, '穴',   'あな',   'hole; to bore'),
              (15, '銀行', 'ぎんこう', 'bank (financial)'),
              (16, '',     'ばんく',   'bank'),
              (17, '堤',   'つつみ',   'river bank'),
              (18, '口座', 'こうざ',   'bank account');

            INSERT INTO idioms (entry_id, idiom_kind, literal_gloss, figurative_gloss, anchor_lemmas) VALUES
              (30, 3, 'even a dog walking hits a pole', 'every dog has its day', '犬,歩,棒,当'),
              (31, 1, 'relationship of dog and monkey', 'bad terms', '犬,猿,仲'),
              (34, 2, 'dying like a dog', 'useless death', '犬死,犬');
        )SQL");

        // Kanji entries + radicals + fisheye edges
        auto blob_day = make_stroke_blob({
            {{0, 0}, {32768, 65535}},
            {{65535, 0}, {65535, 32768}, {0, 32768}}
        });
        auto blob_empty = make_stroke_blob({});
        insert_kanji(0x65E5, 4, 1, 5, 1, 72, 102, 60104, 0x66F0, "ニチ,ジツ", "ひ,か", "day; sun; Japan", blob_day);
        insert_kanji(0x672C, 5, 1, 5, 2, 75, 405, 50230, 0, "ホン", "もと", "book; origin", blob_empty);
        insert_kanji(0x5B66, 8, 1, 5, 3, 39, 203, 90407, 0x5B78, "ガク", "まな.ぶ", "study; learning", blob_empty);
        insert_kanji(0x6821, 10, 1, 5, 4, 75, 104, 40948, 0, "コウ", "", "school", blob_empty);
        insert_kanji(0x98DF, 9, 2, 5, 5, 184, 309, 80732, 0, "ショク,ジキ", "た.べる,く.う", "eat; food", blob_empty);
        insert_kanji(0x77DB, 5, 8, 1, 600, 110, 305, 17222, 0, "ム", "ほこ", "halberd", blob_empty);
        insert_kanji(0x5C4B, 9, 3, 4, 200, 44, 303, 77214, 0, "オク", "や", "roof; house; shop", blob_empty);
        insert_kanji(0x5C71, 3, 1, 5, 10, 46, 403, 22770, 0, "サン", "やま", "mountain", blob_empty);

        exec(R"SQL(
            INSERT INTO kanji_radicals (radical_id, codepoint) VALUES
              (72, 0x65E5),
              (1,  0x65E5),
              (75, 0x672C),
              (1,  0x672C),
              (75, 0x6821),
              (46, 0x5C71);

            INSERT INTO kanji_edges (center_cp, edge_kind, rank, neighbor_cp, top_entry_id, compound_cnt, pmi_score) VALUES
              (0x65E5, 1, 0, 0x672C, 1, 42, 3.2);
        )SQL");

        // Sentence 1: pre-tokenized token span for "日本" (6 bytes at offset 0) + uncovered "の" + uncovered "山" (U+5C71)
        // Also tests UTF-16 offset after 3-byte Japanese chars.
        const std::string jp1 = "日本の山";
        std::vector<uint8_t> sp1 = make_token_span(0, 6, 1);
        sqlite3_stmt* sstmt = nullptr;
        sqlite3_prepare_v2(db, "INSERT INTO sentences (sent_id, jp_text, en_text, token_spans) VALUES (100, ?1, 'Mountains of Japan.', ?2);", -1, &sstmt, nullptr);
        sqlite3_bind_text(sstmt, 1, jp1.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_blob(sstmt, 2, sp1.data(), static_cast<int>(sp1.size()), SQLITE_TRANSIENT);
        CHECK_EQ(sqlite3_step(sstmt), SQLITE_DONE);
        sqlite3_finalize(sstmt);

        // Sentence 2: "川越の歴史" (no pre-tokenized spans) -> tests greedy name-before-の ("川越" -> かわごえ, id 20)
        // Sentence 3: "食べる。" (no pre-tokenized spans) -> tests verb-stem fallback ("食べ" matches "食べる")
        const std::string jp2 = "川越の山";
        const std::string jp3 = "食べた";
        sqlite3_prepare_v2(db, "INSERT INTO sentences (sent_id, jp_text, en_text, token_spans) VALUES (101, ?1, 'Mountain of Kawagoe.', X'');", -1, &sstmt, nullptr);
        sqlite3_bind_text(sstmt, 1, jp2.c_str(), -1, SQLITE_TRANSIENT);
        CHECK_EQ(sqlite3_step(sstmt), SQLITE_DONE);
        sqlite3_finalize(sstmt);

        sqlite3_prepare_v2(db, "INSERT INTO sentences (sent_id, jp_text, en_text, token_spans) VALUES (102, ?1, 'Ate.', X'');", -1, &sstmt, nullptr);
        sqlite3_bind_text(sstmt, 1, jp3.c_str(), -1, SQLITE_TRANSIENT);
        CHECK_EQ(sqlite3_step(sstmt), SQLITE_DONE);
        sqlite3_finalize(sstmt);

        exec(R"SQL(
            INSERT INTO sentence_index (entry_id, sent_id) VALUES
              (1, 100),
              (1, 101),
              (1, 102);
        )SQL");
    }
};

} // namespace

TEST(db_search_words_modes_and_ranking) {
    DbFixture fx;

    // Prefix scan excludes names by default, puts exact match first, then freq order.
    auto hits = dj::db_search_words(fx.db, "日本", DJ_SEARCH_AUTO, false, 10);
    CHECK_EQ(hits.size(), 2u);
    CHECK_EQ(hits[0].entry_id, 1u);
    CHECK_EQ(hits[1].entry_id, 2u);

    // include_names = true surfaces JMnedict proper name 日本花
    auto with_names = dj::db_search_words(fx.db, "日本", DJ_SEARCH_AUTO, true, 10);
    CHECK_EQ(with_names.size(), 3u);
    CHECK_EQ(with_names[2].entry_id, 3u);
    CHECK(with_names[2].is_name);

    // Clean romaji in AUTO transliterates to kana and matches 日本 / 日本語 / 二本
    auto romaji = dj::db_search_words(fx.db, "nihon", DJ_SEARCH_AUTO, false, 10);
    CHECK_EQ(romaji.size(), 3u);
    CHECK_EQ(romaji[0].entry_id, 1u);

    // Clean romaji with zero kana matches ("bore" -> "ぼれ") falls back to FTS5 English
    auto romaji_en_fallback = dj::db_search_words(fx.db, "bore", DJ_SEARCH_AUTO, false, 10);
    CHECK_EQ(romaji_en_fallback.size(), 1u);
    CHECK_EQ(romaji_en_fallback[0].entry_id, 14u);

    // DJ_SEARCH_ENGLISH bypasses romaji -> kana so "sake" finds 為 ("benefit; sake; advantage") & 酒 ("alcohol; sake")
    auto en_sake = dj::db_search_words(fx.db, "sake", DJ_SEARCH_ENGLISH, false, 10);
    CHECK_EQ(en_sake.size(), 2u);

    // FTS5 relevance tier + kanji preference for tier 0:
    // 15 (銀行, "bank (financial)") -> tier 0 + has kanji
    // 16 (ばんく, "bank")           -> tier 0 + kana only
    // 18 (口座, "bank account")     -> tier 1
    // 17 (堤,   "river bank")       -> tier 2
    auto banks = dj::db_search_words(fx.db, "bank", DJ_SEARCH_AUTO, false, 10);
    CHECK_EQ(banks.size(), 4u);
    CHECK_EQ(banks[0].entry_id, 15u);
    CHECK_EQ(banks[1].entry_id, 16u);
    CHECK_EQ(banks[2].entry_id, 18u);
    CHECK_EQ(banks[3].entry_id, 17u);

    // DJ_SEARCH_HOMONYMS matches kana_head only ("にほん" matches 日本 and 二本, not 日本語)
    auto hom = dj::db_search_words(fx.db, "にほん", DJ_SEARCH_HOMONYMS, false, 10);
    CHECK_EQ(hom.size(), 2u);

    // DJ_SEARCH_EXACT matches exact kanji_head or kana_head
    auto exact = dj::db_search_words(fx.db, "食べる", DJ_SEARCH_EXACT, false, 10);
    CHECK_EQ(exact.size(), 1u);
    CHECK_EQ(exact[0].entry_id, 5u);

    // DJ_SEARCH_ANY performs substring match
    auto any = dj::db_search_words(fx.db, "本", DJ_SEARCH_ANY, false, 10);
    CHECK_EQ(any.size(), 3u);

    // Empty / limit 0 guards
    CHECK_EQ(dj::db_search_words(fx.db, "", DJ_SEARCH_AUTO, false, 10).size(), 0u);
    CHECK_EQ(dj::db_search_words(fx.db, "日本", DJ_SEARCH_AUTO, false, 0).size(), 0u);
    CHECK_EQ(dj::db_search_words(nullptr, "日本", DJ_SEARCH_AUTO, false, 10).size(), 0u);
}

TEST(db_get_random_words_filters_and_limits) {
    DbFixture fx;
    auto sample = dj::db_get_random_words(fx.db, 50, false, 3);
    CHECK(sample.size() > 0u && sample.size() <= 3u);
    for (const auto& h : sample) {
        CHECK(!h.is_name);
        CHECK(h.freq_rank <= 50u);
    }
    CHECK_EQ(dj::db_get_random_words(fx.db, 50, false, 0).size(), 0u);
}

TEST(db_get_entry_detail_ruby_senses_and_sentences) {
    DbFixture fx;

    // Missing / invalid entry
    dj::OwnedEntryDetail missing;
    CHECK(!dj::db_get_entry_detail(fx.db, 0, missing));
    CHECK(!dj::db_get_entry_detail(fx.db, 9999, missing));

    // Paired transitivity + okurigana ruby splitting (開ける -> 開[あ] け[] る[])
    dj::OwnedEntryDetail open_det;
    CHECK(dj::db_get_entry_detail(fx.db, 6, open_det));
    CHECK_EQ_STR(open_det.paired_kanji, "開く");
    CHECK_EQ_STR(open_det.paired_kana, "あく");

    // 2-kanji split using kanji candidate readings + geminate tolerance (学校 -> 学[がっ] 校[こう])
    dj::OwnedEntryDetail school;
    CHECK(dj::db_get_entry_detail(fx.db, 8, school));
    CHECK_EQ(school.ruby_cells.size(), 2u);
    CHECK_EQ_STR(school.ruby_cells[0].surface, "学");
    CHECK_EQ_STR(school.ruby_cells[0].furigana, "がっ");
    CHECK_EQ(school.ruby_cells[0].kanji_cp, 0x5B66u);
    CHECK_EQ_STR(school.ruby_cells[1].surface, "校");
    CHECK_EQ_STR(school.ruby_cells[1].furigana, "こう");

    // 3-kanji 1+2 jukujikun subword split (矛山車 -> 矛[ほこ] + 山車[だし])
    dj::OwnedEntryDetail float12;
    CHECK(dj::db_get_entry_detail(fx.db, 10, float12));
    CHECK_EQ(float12.ruby_cells.size(), 2u);
    CHECK_EQ_STR(float12.ruby_cells[0].surface, "矛");
    CHECK_EQ_STR(float12.ruby_cells[0].furigana, "ほこ");
    CHECK_EQ_STR(float12.ruby_cells[1].surface, "山車");
    CHECK_EQ_STR(float12.ruby_cells[1].furigana, "だし");

    // 3-kanji 2+1 jukujikun subword split (山車屋 -> 山車[だし] + 屋[や])
    dj::OwnedEntryDetail float21;
    CHECK(dj::db_get_entry_detail(fx.db, 11, float21));
    CHECK_EQ(float21.ruby_cells.size(), 2u);
    CHECK_EQ_STR(float21.ruby_cells[0].surface, "山車");
    CHECK_EQ_STR(float21.ruby_cells[0].furigana, "だし");
    CHECK_EQ_STR(float21.ruby_cells[1].surface, "屋");
    CHECK_EQ_STR(float21.ruby_cells[1].furigana, "や");

    // Multiple senses + sense 0 back-fill into header.primary_gloss
    dj::OwnedEntryDetail eat;
    CHECK(dj::db_get_entry_detail(fx.db, 5, eat));
    CHECK_EQ(eat.senses.size(), 2u);
    CHECK_EQ_STR(eat.header.primary_gloss, "to eat; consume");
    CHECK_EQ_STR(eat.senses[0].ja_glosses, "たべる");
    CHECK_EQ(eat.ruby_cells.size(), 3u);
    CHECK_EQ_STR(eat.ruby_cells[0].surface, "食");
    CHECK_EQ_STR(eat.ruby_cells[0].furigana, "た");
    CHECK_EQ_STR(eat.ruby_cells[1].surface, "べ");
    CHECK_EQ_STR(eat.ruby_cells[1].furigana, "");
    CHECK_EQ_STR(eat.ruby_cells[2].surface, "る");
    CHECK_EQ_STR(eat.ruby_cells[2].furigana, "");

    // Sentences on entry 1: pre-tokenized span + greedy fallback + name-before-の + verb stem
    dj::OwnedEntryDetail jp;
    CHECK(dj::db_get_entry_detail(fx.db, 1, jp));
    CHECK_EQ(jp.sentences.size(), 3u);

    // Sentence 100: "日本の山" -> token 0: "日本" (utf16 off=0, len=2, id=1), token 1: "山" (off=3, len=1, id=22)
    CHECK_EQ(jp.sentences[0].sent_id, 100u);
    CHECK_EQ(jp.sentences[0].tokens.size(), 2u);
    CHECK_EQ(jp.sentences[0].tokens[0].utf16_offset, 0u);
    CHECK_EQ(jp.sentences[0].tokens[0].utf16_length, 2u);
    CHECK_EQ(jp.sentences[0].tokens[0].entry_id, 1u);
    CHECK_EQ_STR(jp.sentences[0].tokens[0].kana_reading, "にほん");
    CHECK_EQ(jp.sentences[0].tokens[1].utf16_offset, 3u);
    CHECK_EQ(jp.sentences[0].tokens[1].utf16_length, 1u);
    CHECK_EQ(jp.sentences[0].tokens[1].entry_id, 22u);

    // Sentence 101: "川越の山" -> "川越" followed by 'の' prefers proper name entry 20 ("かわごえ")
    CHECK_EQ(jp.sentences[1].sent_id, 101u);
    CHECK_EQ(jp.sentences[1].tokens.size(), 2u);
    CHECK_EQ(jp.sentences[1].tokens[0].entry_id, 20u);
    CHECK_EQ_STR(jp.sentences[1].tokens[0].kana_reading, "かわごえ");

    // Sentence 102: "食べた" -> verb stem "食べ" matches entry 5 ("食べる") and drops final kana -> "たべ"
    CHECK_EQ(jp.sentences[2].sent_id, 102u);
    CHECK_EQ(jp.sentences[2].tokens.size(), 1u);
    CHECK_EQ(jp.sentences[2].tokens[0].entry_id, 5u);
    CHECK_EQ_STR(jp.sentences[2].tokens[0].kana_reading, "たべ");
}

TEST(db_get_kanji_detail_strokes_and_radicals) {
    DbFixture fx;

    dj::OwnedKanjiDetail missing;
    CHECK(!dj::db_get_kanji_detail(fx.db, 0, missing));
    CHECK(!dj::db_get_kanji_detail(fx.db, 0x9999, missing));

    dj::OwnedKanjiDetail day;
    CHECK(dj::db_get_kanji_detail(fx.db, 0x65E5, day));
    CHECK_EQ(day.codepoint, 0x65E5u);
    CHECK_EQ_STR(std::string(day.utf8_glyph), "日");
    CHECK_EQ(day.strokes, 4u);
    CHECK_EQ(day.grade, 1u);
    CHECK_EQ(day.jlpt, 5u);
    CHECK_EQ(day.radical_id, 72u);
    CHECK_EQ(day.kyujitai_cp, 0x66F0u);
    CHECK_EQ_STR(day.on_readings, "ニチ,ジツ");
    CHECK_EQ_STR(day.kun_readings, "ひ,か");
    CHECK_EQ_STR(day.meanings, "day; sun; Japan");

    // Decoded stroke blob: 2 strokes (2 pts, then 3 pts) normalized to [0..1]
    CHECK_EQ(day.strokes_points.size(), 2u);
    CHECK_EQ(day.strokes_points[0].size(), 2u);
    CHECK(std::fabs(day.strokes_points[0][1].x - (32768.0f / 65535.0f)) < 1e-4f);
    CHECK(std::fabs(day.strokes_points[0][1].y - 1.0f) < 1e-4f);
    CHECK_EQ(day.strokes_points[1].size(), 3u);

    // Primary radical 72 first (not duplicated by kanji_radicals row 72), then additional radical 1
    CHECK_EQ_STR(day.component_radicals, "日 (#72)   一 (#1)");
}

TEST(db_search_radicals_intersection_and_strokes) {
    DbFixture fx;

    // Single radical 75 -> 本 (5 strokes, freq 2) and 校 (10 strokes, freq 4)
    uint8_t rad75[] = {75};
    auto all_75 = dj::db_search_radicals(fx.db, rad75, 1, 0, 0);
    CHECK_EQ(all_75.size(), 2u);
    CHECK_EQ(all_75[0], 0x672Cu);
    CHECK_EQ(all_75[1], 0x6821u);

    // Two-radical intersection (1 and 75) -> 本 only
    uint8_t rad_both[] = {1, 75};
    auto inter = dj::db_search_radicals(fx.db, rad_both, 2, 0, 0);
    CHECK_EQ(inter.size(), 1u);
    CHECK_EQ(inter[0], 0x672Cu);

    // Stroke filter +/- tolerance: 9 +/- 1 selects 校 (10 strokes) only
    auto stroke_filt = dj::db_search_radicals(fx.db, rad75, 1, 9, 1);
    CHECK_EQ(stroke_filt.size(), 1u);
    CHECK_EQ(stroke_filt[0], 0x6821u);
}

TEST(db_idioms_kanji_and_entry_ranking) {
    DbFixture fx;

    // Exact anchor token check avoids substring false positive "犬死" when searching for "犬" (Wait: entry 34 has '犬死,犬', let's check all 3 match in freq order: 31 (350), 30 (400), 34 (600))
    auto k_idioms = dj::db_get_kanji_idioms(fx.db, 0x72AC, 10); // 犬
    CHECK_EQ(k_idioms.size(), 3u);
    CHECK_EQ(k_idioms[0].entry_id, 31u);
    CHECK_EQ(k_idioms[1].entry_id, 30u);
    CHECK_EQ(k_idioms[2].entry_id, 34u);

    // Entry 34 itself is an idiom: db_get_entry_idioms places exact match first, then related idioms
    auto e_idioms = dj::db_get_entry_idioms(fx.db, 34, 5);
    CHECK_EQ(e_idioms.size(), 3u);
    CHECK_EQ(e_idioms[0].entry_id, 34u);

    // Respects limit
    CHECK_EQ(dj::db_get_kanji_idioms(fx.db, 0x72AC, 2).size(), 2u);
}

TEST(capi_engine_wraps_db_and_fisheye_cleanly) {
    DbFixture fx;
    dj_engine eng;
    eng.db = fx.db;

    const dj_word_hit_t* hits = nullptr;
    size_t n = dj_dict_search(&eng, "school", DJ_SEARCH_AUTO, false, 10, &hits);
    CHECK_EQ(n, 1u);
    CHECK(hits != nullptr);
    CHECK_EQ(hits[0].entry_id, 8u);
    CHECK_EQ_STR(hits[0].kanji_head, "学校");

    dj_entry_detail_t detail{};
    CHECK(dj_dict_get_entry_detail(&eng, 8, &detail));
    CHECK_EQ(detail.ruby_cell_count, 2u);

    dj_kanji_detail_t kdet{};
    CHECK(dj_kanji_get_detail(&eng, 0x65E5, &kdet));
    CHECK_EQ(kdet.polyline_count, 2u);

    const uint32_t* rad_cps = nullptr;
    uint8_t rad46[] = {46};
    CHECK_EQ(dj_kanji_search_radicals(&eng, rad46, 1, 0, 0, &rad_cps), 1u);
    CHECK_EQ(rad_cps[0], 0x5C71u);

    const dj_idiom_t* idioms = nullptr;
    CHECK_EQ(dj_dict_get_kanji_idioms(&eng, 0x72AC, 2, &idioms), 2u);
    CHECK(idioms != nullptr);

    // Fisheye solver on precomputed kanji_edges row (日 -> 本 via 日本)
    size_t left_ov = 0, right_ov = 0;
    const dj_fisheye_node_t* nodes = nullptr;
    size_t nnodes = dj_graph_solve_fisheye(
        &eng, 0x65E5, DJ_EDGE_COMPOUNDS, false, false, 0.0f, 0.0f, 1.5f, 12,
        &left_ov, &right_ov, &nodes);
    CHECK_EQ(nnodes, 1u);
    CHECK(nodes != nullptr);
    CHECK_EQ(nodes[0].codepoint, 0x672Cu);
    CHECK_EQ_STR(nodes[0].compound_word, "日本");

    // Clear eng.db before stack destructor (DbFixture closes fx.db)
    eng.db = nullptr;
}

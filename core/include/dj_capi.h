/**
 * @file dj_capi.h
 * @brief Flat C11 ABI boundary of the Dai-Jishow core engine.
 *
 * This header is the *only* contract between the C++20 core (`core/`) and the
 * native platform shells (SwiftUI + Metal on Apple, Jetpack Compose + AGSL on
 * Android, and the C test CLI). Only plain C types, UTF-8 strings, and
 * out-parameters cross the boundary, so no runtime, exceptions, or RTTI are
 * involved.
 *
 * Memory ownership contract
 * -------------------------
 * Every string (`const char*`) and array (`const T*`) returned through an
 * `out_*` parameter points into a per-engine arena owned by the
 * `dj_engine_t` handle. The data stays valid until the *next* call that
 * touches the same arena on the same handle (a later search invalidates
 * earlier hits, a later detail lookup invalidates earlier detail data, and so
 * on). Hosts therefore never call `free()` on these pointers.
 *
 * Coordinate space
 * ----------------
 * All spatial values (`norm_x`, `norm_y`, `dj_point_t`) are normalized floats
 * in roughly `[-1.0, +1.0]`, ready to be consumed directly as GPU shader
 * uniforms.
 */
#ifndef DJ_CAPI_H
#define DJ_CAPI_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Opaque engine handle.
 *
 * Owns the read-only SQLite connection, every result arena referenced by the
 * structs below, and the small session state (recent-kanji ring). Create one
 * per app launch, destroy on shutdown.
 */
typedef struct dj_engine dj_engine_t;

/**
 * Dictionary lookup strategy, selected by the UI based on user intent.
 *
 * - `DJ_SEARCH_AUTO`     — engine infers: romaji input is transliterated to
 *                          kana first, otherwise a prefix scan is used.
 * - `DJ_SEARCH_PREFIX`   — B-tree range scan on the entry head.
 * - `DJ_SEARCH_EXACT`    — head must match the query exactly.
 * - `DJ_SEARCH_ANY`      — substring match (`LIKE`) on either head.
 * - `DJ_SEARCH_HOMONYMS` — match on the kana reading only.
 * - `DJ_SEARCH_ENGLISH`  — force the English-gloss FTS index against the raw
 *                          query (bypasses the romaji→kana step), so a romaji
 *                          query that also names an English word still surfaces
 *                          the English-gloss matches.
 */
typedef enum {
    DJ_SEARCH_AUTO     = 0,
    DJ_SEARCH_PREFIX   = 1,
    DJ_SEARCH_EXACT    = 2,
    DJ_SEARCH_ANY      = 3,
    DJ_SEARCH_HOMONYMS = 4,
    DJ_SEARCH_ENGLISH  = 5
} dj_search_mode_t;

/** Edge family to visualize in the fisheye kanji graph around a center kanji. */
typedef enum {
    DJ_EDGE_COMPOUNDS  = 0,
    DJ_EDGE_COMPONENTS = 1,
    DJ_EDGE_YOJIJUKUGO = 2
} dj_fisheye_mode_t;

/** Normalized 2D point in `[-1.0, +1.0]`, used for stroke geometry. */
typedef struct {
    float x;
    float y;
} dj_point_t;

/**
 * One kanji stroke as an ordered polyline of normalized points.
 * `points` is a dense, `point_count`-long array owned by the engine arena.
 */
typedef struct {
    const dj_point_t* points;
    size_t            point_count;
} dj_stroke_polyline_t;

/**
 * One row of dictionary search results (the "hit list" shown under the
 * search field). Field meanings:
 *
 * - `entry_id`      — the `entries.entry_id` this row belongs to.
 * - `kanji_head`    — kanji surface form ("" if the entry is kana-only).
 * - `kana_head`     — the kana reading.
 * - `alt_forms`     — alternative surface forms, if any.
 * - `primary_gloss` — the sense-0 English gloss (first meaning).
 * - `pos_mask`      — bitmask of part-of-speech tags.
 * - `pitch_accent`  — pitch-accent nucleus; `255` means unknown/absent.
 * - `freq_rank`     — corpus frequency rank (lower = more common).
 * - `pair_entry_id` — a related/paired entry id; `0` if none.
 * - `is_name`       — true when the entry is a proper name.
 */
typedef struct {
    uint32_t    entry_id;
    const char* kanji_head;
    const char* kana_head;
    const char* alt_forms;
    const char* primary_gloss;
    uint64_t    pos_mask;
    uint8_t     pitch_accent;
    uint32_t    freq_rank;
    uint32_t    pair_entry_id;
    bool        is_name;
} dj_word_hit_t;

/**
 * One surface-form cell of an entry head, with the optional furigana that
 * annotates it. `kanji_cp` is non-zero only when the cell is a single,
 * stand-alone kanji — the UI uses it to link the glyph into the kanji
 * explorer / fisheye graph.
 */
typedef struct {
    const char* surface;
    const char* furigana;
    uint32_t    kanji_cp;
} dj_ruby_cell_t;

/** One numbered sense (meaning) of a dictionary entry. */
typedef struct {
    uint32_t    sense_idx;
    uint64_t    pos_mask;
    const char* en_glosses;
    const char* ja_glosses;
} dj_sense_t;

/**
 * One token (dictionary word) inside an example sentence.
 *
 * `utf16_offset` / `utf16_length` are UTF-16 code-unit coordinates into
 * `dj_sentence_t::jp_text`, so a host can hand them straight to its text
 * rendering stack (e.g. SwiftUI text spans) to underline or paint the token.
 */
typedef struct {
    uint16_t    utf16_offset;
    uint16_t    utf16_length;
    uint32_t    entry_id;
    const char* kana_reading;
} dj_sentence_token_t;

/** One bilingual example sentence with its token breakdown. */
typedef struct {
    uint32_t                   sent_id;
    const char*                jp_text;
    const char*                en_text;
    const dj_sentence_token_t* tokens;
    size_t                     token_count;
} dj_sentence_t;

/**
 * Full dictionary entry detail: head, paired entry, ruby, senses, and example
 * sentences. All pointers remain valid until the next call on the same
 * engine handle.
 */
typedef struct {
    dj_word_hit_t         header;
    const char*           paired_kanji;
    const char*           paired_kana;
    const dj_ruby_cell_t* ruby_cells;
    size_t                ruby_cell_count;
    const dj_sense_t*     senses;
    size_t                sense_count;
    const dj_sentence_t*  sentences;
    size_t                sentence_count;
} dj_entry_detail_t;

/**
 * Full kanji detail for the kanji explorer view.
 *
 * `on_readings` / `kun_readings` / `meanings` are UTF-8 strings in corpus
 * format (typically `;`-separated, with pitch-accent dots and okurigana
 * dashes). `stroke_polylines` carries the quantized KanjiVG stroke geometry
 * used for the writing animation.
 */
typedef struct {
    uint32_t                    codepoint;
    const char*                 utf8_glyph;
    uint8_t                     strokes;
    uint8_t                     grade;
    uint8_t                     jlpt;
    uint32_t                    freq_rank;
    uint8_t                     radical_id;
    uint32_t                    skip_code;
    uint32_t                    four_corner;
    uint32_t                    kyujitai_cp;
    const char*                 on_readings;
    const char*                 kun_readings;
    const char*                 meanings;
    const char*                 component_radicals;
    const dj_stroke_polyline_t* stroke_polylines;
    size_t                      polyline_count;
} dj_kanji_detail_t;

/**
 * One bubble in the fisheye kanji graph.
 *
 * `norm_x` / `norm_y` are normalized to `[-1.0, +1.0]` where `(0,0)` is the
 * center kanji, and are ready to be passed directly to a GPU shader as a
 * uniform. `share_pct` is this bubble's frequency share within its side.
 */
typedef struct {
    uint32_t    codepoint;
    const char* utf8_glyph;
    uint8_t     side;                /* 0 = left/prefix, 1 = right/suffix */
    uint8_t     commonality_tier;    /* 0 = Core, 1 = Joyo, 2 = Literary, 3 = Kyujitai/Non-Joyo */
    uint8_t     is_overflow_preview; /* 0 = main bubble, 1 = overflow sub-bubble for "+N more" */
    uint32_t    top_entry_id;
    const char* compound_word;
    const char* compound_kana;
    const char* compound_gloss;
    float       share_pct;           /* Compound frequency share % within this side */
    float       norm_x;
    float       norm_y;
    float       scale;
    float       opacity;
} dj_fisheye_node_t;

/**
 * An idiom, yojijukugo (4-character compound), or proverb (`kotowaza`) stored
 * in the `idioms` table and linked back to its dictionary entry.
 */
typedef struct {
    uint32_t    entry_id;
    uint8_t     idiom_kind;        /* 1 = Yojijukugo, 2 = Kan'yoku, 3 = Kotowaza */
    const char* kanji_head;
    const char* kana_head;
    const char* figurative_gloss;
    const char* anchor_lemmas;
} dj_idiom_t;

/**
 * Create an engine handle backed by `db_path`.
 *
 * The database is opened read-only, without mutexes (the host must serialize
 * access per handle), and memory-mapped: a 256 MiB `mmap` window plus a
 * 64 MiB page cache, so the OS faults in only the 4 KiB B-tree pages a query
 * actually touches.
 *
 * @param db_path  Filesystem path to `daijishow.db`.
 * @return A new handle, or `NULL` if the path is bad / cannot be opened.
 */
dj_engine_t* dj_engine_create(const char* db_path);

/**
 * Destroy an engine handle and release its SQLite connection and arenas.
 * Safe to call with `NULL`.
 */
void dj_engine_destroy(dj_engine_t* engine);

/**
 * Search the dictionary.
 *
 * @param engine        Engine handle.
 * @param utf8_query    UTF-8 query (kanji, kana, romaji, or English gloss).
 * @param mode          Lookup strategy (see `dj_search_mode_t`).
 * @param include_names If `true`, also include proper-name entries.
 * @param limit         Maximum number of hits to return.
 * @param out_hits      Receives a pointer to a dense hit array (may be `NULL`
 *                      if only the count is wanted). Points into the engine
 *                      arena — valid until the next call on `engine`.
 * @return Number of hits.
 */
size_t dj_dict_search(
    dj_engine_t*          engine,
    const char*           utf8_query,
    dj_search_mode_t      mode,
    bool                  include_names,
    size_t                limit,
    const dj_word_hit_t** out_hits);

/**
 * Sample random dictionary words filtered by prevalence tier.
 *
 * @param engine        Engine handle.
 * @param max_freq_rank Maximum freq_overall rank (e.g. 2500 for Core, 12000 for Common, 150000 for all).
 * @param include_names If true, also include proper names.
 * @param limit         Number of words to sample.
 * @param out_hits      Receives a pointer to a dense hit array (arena-owned).
 * @return Number of words sampled.
 */
size_t dj_dict_get_random_words(
    dj_engine_t*          engine,
    uint32_t              max_freq_rank,
    bool                  include_names,
    size_t                limit,
    const dj_word_hit_t** out_hits);

/**
 * Load the full detail for one dictionary entry (head, ruby, senses, and up
 * to 8 example sentences with token spans).
 *
 * @param engine    Engine handle.
 * @param entry_id  The entry to load.
 * @param out_detail Receives the detail. All nested pointers live in the
 *                   engine arena — valid until the next call on `engine`.
 * @return `true` on success, `false` if the entry does not exist.
 */
bool dj_dict_get_entry_detail(
    dj_engine_t*       engine,
    uint32_t           entry_id,
    dj_entry_detail_t* out_detail);

/**
 * Load the full detail for one kanji (metadata, readings, meanings, and the
 * quantized KanjiVG stroke polylines).
 *
 * @param engine    Engine handle.
 * @param codepoint The Unicode codepoint of the kanji.
 * @param out_detail Receives the detail (arena-owned, valid until the next
 *                   call on `engine`).
 * @return `true` on success, `false` if the kanji is not in the corpus.
 */
bool dj_kanji_get_detail(
    dj_engine_t*       engine,
    uint32_t           codepoint,
    dj_kanji_detail_t* out_detail);

/**
 * Find kanji containing a set of Kangxi radicals (optionally within a stroke
 * range), sorted by frequency.
 *
 * @param engine           Engine handle.
 * @param radical_ids      Kangxi radical ids (1..214) to match on.
 * @param radical_count    Number of radicals in `radical_ids` (capped at 7).
 * @param target_strokes   Target stroke count (`0` to disable the filter).
 * @param stroke_tolerance Stroke-count tolerance applied to the target.
 * @param out_codepoints   Receives a pointer to a dense codepoint array
 *                         (arena-owned, valid until the next call on
 *                         `engine`). May be `NULL` if only the count is
 *                         wanted.
 * @return Number of codepoints.
 */
size_t dj_kanji_search_radicals(
    dj_engine_t*     engine,
    const uint8_t*   radical_ids,
    size_t           radical_count,
    int16_t          target_strokes,
    int8_t           stroke_tolerance,
    const uint32_t** out_codepoints);

/**
 * Load idioms, yojijukugo, and proverbs (`idioms` table) anchored by a
 * single kanji codepoint, ordered by corpus frequency.
 */
size_t dj_dict_get_kanji_idioms(
    dj_engine_t*       engine,
    uint32_t           codepoint,
    size_t             limit,
    const dj_idiom_t** out_idioms);

/**
 * Load idioms, yojijukugo, and proverbs linked to a dictionary entry
 * (either directly via `entry_id` or sharing its kanji components).
 */
size_t dj_dict_get_entry_idioms(
    dj_engine_t*       engine,
    uint32_t           entry_id,
    size_t             limit,
    const dj_idiom_t** out_idioms);

/**
 * Solve the fisheye kanji graph around a center kanji.
 *
 * Returns one node per neighbor kanji, laid out in normalized `[-1,1]`
 * coordinates on both the left (`side == 0`) and right (`side == 1`)
 * hemispheres, with per-bubble scale/opacity and a precomputed frequency
 * share. Overflow beyond `max_per_side` is reported through the
 * `out_*_overflow` counters (and also emitted as `is_overflow_preview` nodes
 * for the "+N more" fan).
 *
 * @param engine            Engine handle.
 * @param center_codepoint  The center kanji to build the graph around.
 * @param mode              Edge family to visualize (see `dj_fisheye_mode_t`).
 * @param include_names     If `true`, also include proper-name compounds.
 * @param has_focus         If `true`, apply the fisheye lens at `focus_*`.
 * @param focus_norm_x      Focus point X (normalized `[-1,1]`).
 * @param focus_norm_y      Focus point Y (normalized `[-1,1]`).
 * @param aspect_ratio      Viewport aspect ratio (width / height).
 * @param max_per_side      Maximum bubbles to show per side.
 * @param out_left_overflow  Receives the number of hidden left-side bubbles
 *                          (may be `NULL`).
 * @param out_right_overflow Receives the number of hidden right-side bubbles
 *                          (may be `NULL`).
 * @param out_nodes         Receives a pointer to a dense node array
 *                          (arena-owned, valid until the next call on
 *                          `engine`). May be `NULL` if only the counts are
 *                          wanted.
 * @return Total number of nodes (visible + overflow previews).
 */
size_t dj_graph_solve_fisheye(
    dj_engine_t*              engine,
    uint32_t                  center_codepoint,
    dj_fisheye_mode_t         mode,
    bool                      include_names,
    bool                      has_focus,
    float                     focus_norm_x,
    float                     focus_norm_y,
    float                     aspect_ratio,
    size_t                    max_per_side,
    size_t*                   out_left_overflow,
    size_t*                   out_right_overflow,
    const dj_fisheye_node_t** out_nodes);

/**
 * Push a kanji onto the front of the 6-slot recent-kanji ring (deduplicated,
 * most-recent first).
 *
 * @param engine    Engine handle.
 * @param codepoint The kanji just viewed.
 */
void   dj_state_push_recent_kanji(dj_engine_t* engine, uint32_t codepoint);

/**
 * Read the recent-kanji ring into `out_six` (most-recent first).
 *
 * @param engine  Engine handle.
 * @param out_six  A 6-element `uint32_t` array to fill.
 * @return Number of valid entries written (0..6).
 */
size_t dj_state_get_recent_kanji(dj_engine_t* engine, uint32_t out_six[6]);

#ifdef __cplusplus
}
#endif

#endif /* DJ_CAPI_H */

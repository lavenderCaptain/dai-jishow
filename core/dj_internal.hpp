/**
 * @file dj_internal.hpp
 * @brief Internal C++ representation behind the flat C11 ABI.
 *
 * The public API (`dj_capi.h`) passes `const char*` / `const T*` pointers
 * that the host never frees. Those pointers are produced here: each `Owned*`
 * struct is a C++ value type that *owns* its strings and nested arrays, and
 * `dj_capi.cpp` marshals them into fixed `dj_*_t` ABI structs whose pointers
 * point into the owned storage.
 *
 * The `dj_engine` struct (defined outside the `dj` namespace so it can be
 * referenced from C as `struct dj_engine`) is the per-handle arena: one
 * owned container per ABI family. Because each call rebuilds its own arena,
 * the result of any call remains valid until the *next* call that writes to
 * the same arena (see the memory-ownership contract in `dj_capi.h`).
 */
#pragma once

#include "include/dj_capi.h"
#include <sqlite3.h>
#include <array>
#include <cstdint>
#include <string>
#include <vector>

namespace dj {

/// Owned C++ row of dictionary search results (C++ side of `dj_word_hit_t`).
struct OwnedWordHit {
    uint32_t    entry_id = 0;
    std::string kanji_head;
    std::string kana_head;
    std::string alt_forms;
    std::string primary_gloss;
    uint64_t    pos_mask = 0;
    uint8_t     pitch_accent = 255;
    uint32_t    freq_rank = 999999;
    uint32_t    pair_entry_id = 0;
    bool        is_name = false;
};

/// One owned ruby (furigana) cell for an entry head.
struct OwnedRubyCell {
    std::string surface;
    std::string furigana;
    uint32_t    kanji_cp = 0;
};

/// One owned numbered sense (meaning) of a dictionary entry.
struct OwnedSense {
    uint32_t    sense_idx = 0;
    uint64_t    pos_mask = 0;
    std::string en_glosses;
    std::string ja_glosses;
};

/// One owned token (dictionary word) inside an example sentence.
struct OwnedSentenceToken {
    uint16_t    utf16_offset = 0;
    uint16_t    utf16_length = 0;
    uint32_t    entry_id = 0;
    std::string kana_reading;
};

/// One owned bilingual example sentence with its token breakdown.
struct OwnedSentence {
    uint32_t                        sent_id = 0;
    std::string                     jp_text;
    std::string                     en_text;
    std::vector<OwnedSentenceToken> tokens;
};

/// Full owned dictionary entry detail (C++ side of `dj_entry_detail_t`).
struct OwnedEntryDetail {
    OwnedWordHit               header;
    std::string                paired_kanji;
    std::string                paired_kana;
    std::vector<OwnedRubyCell> ruby_cells;
    std::vector<OwnedSense>    senses;
    std::vector<OwnedSentence> sentences;
};

/// Full owned kanji detail (C++ side of `dj_kanji_detail_t`).
struct OwnedKanjiDetail {
    uint32_t                             codepoint = 0;
    char                                 utf8_glyph[8] = {0};
    uint8_t                              strokes = 0;
    uint8_t                              grade = 0;
    uint8_t                              jlpt = 0;
    uint32_t                             freq_rank = 999999;
    uint8_t                              radical_id = 0;
    uint32_t                             skip_code = 0;
    uint32_t                             four_corner = 0;
    uint32_t                             kyujitai_cp = 0;
    std::string                          on_readings;
    std::string                          kun_readings;
    std::string                          meanings;
    std::string                          component_radicals;
    std::vector<std::vector<dj_point_t>> strokes_points;
};

/// One owned node in the fisheye kanji graph (C++ side of `dj_fisheye_node_t`).
struct OwnedFisheyeNode {
    uint32_t    codepoint = 0;
    char        utf8_glyph[8] = {0};
    uint8_t     side = 0;
    uint8_t     commonality_tier = 1;
    uint8_t     is_overflow_preview = 0;
    uint32_t    top_entry_id = 0;
    std::string compound_word;
    std::string compound_kana;
    std::string compound_gloss;
    float       share_pct = 0.0f;
    float       norm_x = 0.0f;
    float       norm_y = 0.0f;
    float       scale = 1.0f;
    float       opacity = 1.0f;
};

/// @return `true` if `input` is purely ASCII and contains at least one letter
///         (i.e. it is plausibly romaji rather than kanji/kana/English).
bool is_ascii_romaji(const std::string& input);

/// Transliterate romaji to kana. See `dj_nlp/romaji.cpp` for the state machine.
std::string romaji_to_kana(const std::string& input, bool to_katakana = false);

/// Encode a single Unicode codepoint as up to 4 bytes of UTF-8 into `out[8]`.
void encode_utf8(uint32_t cp, char out[8]);

/// Search the dictionary (C++ side of `dj_dict_search`).
std::vector<OwnedWordHit> db_search_words(
    sqlite3* db,
    const std::string& query,
    dj_search_mode_t mode,
    bool include_names,
    size_t limit);

/// Load full entry detail (C++ side of `dj_dict_get_entry_detail`).
bool db_get_entry_detail(sqlite3* db, uint32_t entry_id, OwnedEntryDetail& out);

/// Load full kanji detail (C++ side of `dj_kanji_get_detail`).
bool db_get_kanji_detail(sqlite3* db, uint32_t codepoint, OwnedKanjiDetail& out);

/// Find kanji by Kangxi radical set (C++ side of `dj_kanji_search_radicals`).
std::vector<uint32_t> db_search_radicals(
    sqlite3* db,
    const uint8_t* radical_ids,
    size_t radical_count,
    int16_t target_strokes,
    int8_t stroke_tolerance);

/// Solve the fisheye graph (C++ side of `dj_graph_solve_fisheye`).
std::vector<OwnedFisheyeNode> solve_fisheye_graph(
    sqlite3* db,
    uint32_t center_cp,
    dj_fisheye_mode_t mode,
    bool include_names,
    bool has_focus,
    float focus_x,
    float focus_y,
    float aspect_ratio,
    size_t max_per_side,
    size_t& out_left_overflow,
    size_t& out_right_overflow);

} // namespace dj

/**
 * Per-engine arena (the concrete type behind the opaque `dj_engine_t`).
 *
 * Each `owned_*` container is the single source of truth for one ABI family,
 * and each `abi_*` container is the flattened `dj_*_t` view whose string and
 * array pointers point into the matching `owned_*` storage. Rebuilding an
 * `owned_*` container invalidates the previous `abi_*` pointers, which is
 * exactly the "valid until the next call on this handle" contract the host
 * relies on.
 */
struct dj_engine {
    sqlite3* db = nullptr;

    // Search hits.
    std::vector<dj::OwnedWordHit> owned_hits;
    std::vector<dj_word_hit_t>    abi_hits;

    // Entry detail (header + ruby + senses + sentences).
    dj::OwnedEntryDetail              owned_entry;
    std::vector<dj_ruby_cell_t>       abi_ruby_cells;
    std::vector<dj_sense_t>           abi_senses;
    std::vector<dj_sentence_token_t>  abi_sent_tokens;
    std::vector<dj_sentence_t>        abi_sentences;

    // Kanji detail (metadata + stroke polylines).
    dj::OwnedKanjiDetail              owned_kanji;
    std::vector<dj_stroke_polyline_t> abi_polylines;

    // Radical search + fisheye graph.
    std::vector<uint32_t>             abi_radical_cps;
    std::vector<dj::OwnedFisheyeNode> owned_fisheye;
    std::vector<dj_fisheye_node_t>    abi_fisheye;

    // Session state: the 6-slot recent-kanji ring (most-recent first).
    std::array<uint32_t, 6> recent_kanji{};
    size_t                  recent_kanji_count = 0;
};

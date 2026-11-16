#pragma once

#include "include/dj_capi.h"
#include <sqlite3.h>
#include <string>
#include <vector>

namespace dj {

struct OwnedWordHit {
    uint32_t entry_id = 0;
    std::string kanji_head;
    std::string kana_head;
    std::string alt_forms;
    std::string primary_gloss;
    uint64_t pos_mask = 0;
    uint8_t pitch_accent = 255;
    uint32_t freq_rank = 999999;
    uint32_t pair_entry_id = 0;
    bool is_name = false;
};

struct OwnedSense {
    uint32_t sense_idx = 0;
    uint64_t pos_mask = 0;
    std::string en_glosses;
    std::string ja_glosses;
};

struct OwnedSentenceToken {
    uint16_t utf16_offset = 0;
    uint16_t utf16_length = 0;
    uint32_t entry_id = 0;
    std::string kana_reading;
};

struct OwnedSentence {
    uint32_t sent_id = 0;
    std::string jp_text;
    std::string en_text;
    std::vector<OwnedSentenceToken> tokens;
    std::vector<dj_sentence_token_t> c_tokens;
};

struct OwnedRubyCell {
    std::string surface;
    std::string furigana;
    uint32_t kanji_cp = 0;
};

struct OwnedEntryDetail {
    OwnedWordHit header;
    std::string paired_kanji;
    std::string paired_kana;
    std::vector<OwnedRubyCell> ruby_cells;
    std::vector<dj_ruby_cell_t> c_ruby_cells;
    std::vector<OwnedSense> senses;
    std::vector<dj_sense_t> c_senses;
    std::vector<OwnedSentence> sentences;
    std::vector<dj_sentence_t> c_sentences;
};

struct OwnedKanjiDetail {
    uint32_t codepoint = 0;
    char utf8_glyph[8]{};
    uint8_t strokes = 0;
    uint8_t grade = 0;
    uint8_t jlpt = 0;
    uint32_t freq_rank = 999999;
    uint8_t radical_id = 0;
    uint32_t skip_code = 0;
    uint32_t four_corner = 0;
    uint32_t kyujitai_cp = 0;
    std::string on_readings;
    std::string kun_readings;
    std::string meanings;
    std::string component_radicals;
    std::vector<std::vector<dj_point_t>> strokes_points;
    std::vector<dj_stroke_polyline_t> c_polylines;
};

struct OwnedFisheyeNode {
    uint32_t codepoint = 0;
    char utf8_glyph[8]{};
    uint8_t side = 0;
    uint8_t commonality_tier = 1;
    uint32_t top_entry_id = 0;
    std::string compound_word;
    std::string compound_kana;
    std::string compound_gloss;
    float norm_x = 0.0f;
    float norm_y = 0.0f;
    float scale = 1.0f;
    float opacity = 1.0f;
};

struct OwnedZCard {
    uint64_t stack_id = 0;
    dj_card_kind_t kind = DJ_CARD_HOME;
    uint32_t target_id = 0;
    std::string title_badge;
};

std::string romaji_to_kana(const std::string& input, bool katakana);
bool is_ascii_romaji(const std::string& s);
void encode_utf8(uint32_t cp, char out[8]);

std::vector<OwnedWordHit> db_search_words(
    sqlite3* db,
    const std::string& query,
    dj_search_mode_t mode,
    bool include_names,
    size_t limit);

bool db_get_entry_detail(
    sqlite3* db,
    uint32_t entry_id,
    OwnedEntryDetail& out);

bool db_get_kanji_detail(
    sqlite3* db,
    uint32_t codepoint,
    OwnedKanjiDetail& out);

std::vector<uint32_t> db_search_radicals(
    sqlite3* db,
    const uint8_t* radical_ids,
    size_t radical_count,
    int16_t target_strokes,
    int8_t stroke_tolerance);

std::vector<OwnedFisheyeNode> solve_fisheye_graph(
    sqlite3* db,
    uint32_t center_cp,
    dj_fisheye_mode_t mode,
    float focus_x,
    float focus_y,
    float aspect_ratio,
    size_t max_per_side);

} // namespace dj

struct dj_engine_s {
    sqlite3* db = nullptr;

    std::string arena_str;
    std::vector<dj::OwnedWordHit> arena_word_storage;
    std::vector<dj_word_hit_t> arena_word_c;

    dj::OwnedEntryDetail arena_entry_detail;
    dj::OwnedKanjiDetail arena_kanji_detail;

    std::vector<uint32_t> arena_cp_storage;

    std::vector<dj::OwnedFisheyeNode> arena_fisheye_storage;
    std::vector<dj_fisheye_node_t> arena_fisheye_c;

    uint64_t next_stack_id = 1;
    bool zoomed_out = false;
    std::vector<dj::OwnedZCard> z_stack;
    std::vector<dj_zcard_t> arena_zstack_c;
    std::vector<uint32_t> recent_kanji;
};

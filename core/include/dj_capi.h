/**
 * @file dj_capi.h
 * @brief Flat C11 Application Binary Interface (ABI) for the Dai-Jishow C++20 Core Engine.
 */

#ifndef DJ_CAPI_H
#define DJ_CAPI_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct dj_engine_s dj_engine_t;

// --- Lifecycle Management ---
dj_engine_t* dj_engine_create(const char* corpus_db_path);
void         dj_engine_destroy(dj_engine_t* engine);

// --- 1. NLP & Wa-puro Romaji Parser ---
const char* dj_nlp_romaji_to_kana(dj_engine_t* engine, const char* romaji, bool katakana);

// --- 2. Dictionary Lookup & Full Entry Detail ---
typedef enum {
    DJ_SEARCH_AUTO = 0,
    DJ_SEARCH_EXACT = 1,
    DJ_SEARCH_INITIAL = 2,
    DJ_SEARCH_ANY = 3,
    DJ_SEARCH_HOMONYMS = 4
} dj_search_mode_t;

typedef struct {
    uint32_t entry_id;
    const char* kanji_head;
    const char* kana_head;
    const char* alt_forms;
    const char* primary_gloss;
    uint64_t pos_mask;
    uint8_t pitch_accent;
    uint32_t freq_rank;
    uint32_t pair_entry_id;
    bool is_name;
} dj_word_hit_t;

size_t dj_dict_search(dj_engine_t* engine,
                      const char* query,
                      dj_search_mode_t mode,
                      bool include_names,
                      size_t limit,
                      const dj_word_hit_t** out_hits);

typedef struct {
    uint32_t sense_idx;
    uint64_t pos_mask;
    const char* en_glosses;
    const char* ja_glosses;
} dj_sense_t;

typedef struct {
    uint16_t utf16_offset;
    uint16_t utf16_length;
    uint32_t entry_id;
    const char* kana_reading;
} dj_sentence_token_t;

typedef struct {
    uint32_t sent_id;
    const char* jp_text;
    const char* en_text;
    const dj_sentence_token_t* tokens;
    size_t token_count;
} dj_sentence_t;

typedef struct {
    const char* surface;
    const char* furigana;
    uint32_t kanji_cp;
} dj_ruby_cell_t;

typedef struct {
    dj_word_hit_t header;
    const char* paired_kanji;
    const char* paired_kana;
    const dj_ruby_cell_t* ruby_cells;
    size_t ruby_cell_count;
    const dj_sense_t* senses;
    size_t sense_count;
    const dj_sentence_t* sentences;
    size_t sentence_count;
} dj_entry_detail_t;

bool dj_dict_get_entry_detail(dj_engine_t* engine,
                              uint32_t entry_id,
                              dj_entry_detail_t* out_detail);

// --- 3. Kanji Detail, Vector Stroke Polylines & Multi-Radical Intersection ---
typedef struct {
    float x;
    float y;
} dj_point_t;

typedef struct {
    const dj_point_t* points;
    size_t point_count;
} dj_stroke_polyline_t;

typedef struct {
    uint32_t codepoint;
    char utf8_glyph[8];
    uint8_t strokes;
    uint8_t grade;
    uint8_t jlpt;
    uint32_t freq_rank;
    uint8_t radical_id;
    uint32_t skip_code;
    uint32_t four_corner;
    uint32_t kyujitai_cp;
    const char* on_readings;
    const char* kun_readings;
    const char* meanings;
    const char* component_radicals; ///< Formatted component radicals (e.g. "雨 (#173), 田 (#102)")
    const dj_stroke_polyline_t* stroke_polylines;
    size_t polyline_count;
} dj_kanji_detail_t;

bool dj_kanji_get_detail(dj_engine_t* engine,
                         uint32_t codepoint,
                         dj_kanji_detail_t* out_detail);

size_t dj_kanji_search_radicals(dj_engine_t* engine,
                                const uint8_t* radical_ids,
                                size_t radical_count,
                                int16_t target_strokes,
                                int8_t stroke_tolerance,
                                const uint32_t** out_codepoints);

// --- 4. Dokusha Spatial Fisheye Graph Solver ---
typedef enum {
    DJ_EDGE_COMPOUNDS = 0,
    DJ_EDGE_YOJIJUKUGO = 2
} dj_fisheye_mode_t;

typedef struct {
    uint32_t codepoint;
    char utf8_glyph[8];
    uint8_t side;
    uint8_t commonality_tier; ///< 0=Everyday Core, 1=Standard Joyo, 2=Literary/Rare, 3=Kyujitai/Traditional
    uint32_t top_entry_id;
    const char* compound_word;
    const char* compound_kana;
    const char* compound_gloss;
    float norm_x;
    float norm_y;
    float scale;
    float opacity;
} dj_fisheye_node_t;

size_t dj_graph_solve_fisheye(dj_engine_t* engine,
                              uint32_t center_codepoint,
                              dj_fisheye_mode_t mode,
                              float focus_x,
                              float focus_y,
                              float aspect_ratio,
                              size_t max_per_side,
                              const dj_fisheye_node_t** out_nodes);

// --- 5. 3D Time Machine Z-Stack & Persistent 6-Kanji Compound Ring ---
typedef enum {
    DJ_CARD_HOME = 0,
    DJ_CARD_LENS_READER = 1,
    DJ_CARD_WORD_ENTRY = 2,
    DJ_CARD_KANJI_DETAIL = 3,
    DJ_CARD_FISHEYE_EXPLORER = 4,
    DJ_CARD_RADICAL_BUILDER = 5
} dj_card_kind_t;

typedef struct {
    uint64_t stack_id;
    dj_card_kind_t kind;
    uint32_t target_id;
    const char* title_badge;
    int32_t z_depth;
    float blur_radius;
    float scale;
} dj_zcard_t;

void   dj_state_push_card(dj_engine_t* engine, dj_card_kind_t kind, uint32_t target_id, const char* badge);
void   dj_state_focus_depth(dj_engine_t* engine, int32_t z_depth);
void   dj_state_set_zoomed_out(dj_engine_t* engine, bool zoomed_out);
bool   dj_state_is_zoomed_out(dj_engine_t* engine);
size_t dj_state_get_zstack(dj_engine_t* engine, const dj_zcard_t** out_cards);

size_t dj_state_get_recent_kanji(dj_engine_t* engine, uint32_t out_codepoints[6]);
void   dj_state_push_recent_kanji(dj_engine_t* engine, uint32_t codepoint);

#ifdef __cplusplus
}
#endif
#endif // DJ_CAPI_H
